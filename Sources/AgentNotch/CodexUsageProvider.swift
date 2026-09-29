import Foundation

private final class CodexRequestState: @unchecked Sendable {
    private let lock = NSLock()
    private var buffer = Data()
    private var finished = false
    private var cancelAction: (() -> Void)?
    private var cancelled = false
    private var initialized = false

    func claimInitialization() -> Bool {
        lock.withLock {
            guard !initialized, !finished else { return false }
            initialized = true
            return true
        }
    }

    func send(_ message: [String: Any], to handle: FileHandle) throws {
        var data = try JSONSerialization.data(withJSONObject: message)
        data.append(0x0A)
        try lock.withLock {
            guard !finished else { return }
            try handle.write(contentsOf: data)
        }
    }

    func registerCancellation(_ action: @escaping () -> Void) {
        let callNow = lock.withLock { cancelAction = action; return cancelled }
        if callNow { action() }
    }

    func cancel() {
        let action = lock.withLock { cancelled = true; return cancelAction }
        action?()
    }

    func launch(_ process: Process) throws -> Bool {
        try lock.withLock {
            guard !finished, !cancelled else { return false }
            try process.run()
            return true
        }
    }

    func append(_ data: Data) -> Data {
        lock.withLock {
            buffer.append(data)
            return buffer
        }
    }

    func claimFinish() -> Bool {
        lock.withLock {
            guard !finished else { return false }
            finished = true
            cancelAction = nil
            return true
        }
    }
}

enum CodexUsageError: LocalizedError {
    case executableNotFound
    case launchFailed(String)
    case timedOut
    case serverError(String)

    var errorDescription: String? {
        switch self {
        case .executableNotFound:
            return tr("Can't find the Codex executable.")
        case .launchFailed(let message):
            return tr("Couldn't start Codex: %@", message)
        case .timedOut:
            return tr("Codex took too long to respond.")
        case .serverError(let message):
            return message
        }
    }
}

final class CodexUsageProvider {
    private let executableOverride: URL?
    private let arguments: [String]
    init(executable: URL? = nil, arguments: [String] = ["app-server"]) {
        executableOverride = executable
        self.arguments = arguments
    }
    func fetch() async throws -> UsageSnapshot {
        let state = CodexRequestState()
        return try await withTaskCancellationHandler {
        try await withCheckedThrowingContinuation { continuation in
            guard let executable = executableOverride ?? Self.findCodexExecutable() else {
                continuation.resume(throwing: CodexUsageError.executableNotFound)
                return
            }

            let process = Process()
            let input = Pipe()
            let output = Pipe()
            let errors = Pipe()
            process.executableURL = executable
            process.arguments = arguments
            process.standardInput = input
            process.standardOutput = output
            process.standardError = errors

            @Sendable func finish(_ result: Result<UsageSnapshot, Error>) {
                guard state.claimFinish() else { return }
                output.fileHandleForReading.readabilityHandler = nil
                errors.fileHandleForReading.readabilityHandler = nil
                process.terminationHandler = nil
                try? input.fileHandleForWriting.close()
                if process.isRunning { process.terminate() }
                continuation.resume(with: result)
            }

            errors.fileHandleForReading.readabilityHandler = { handle in _ = handle.availableData }
            process.terminationHandler = { _ in
                // Give pending stdout delivery a turn before reporting an early exit.
                DispatchQueue.global().asyncAfter(deadline: .now() + 0.1) {
                    finish(.failure(CodexUsageError.serverError(tr("Codex closed the connection."))))
                }
            }

            output.fileHandleForReading.readabilityHandler = { handle in
                let chunk = handle.availableData
                guard !chunk.isEmpty else { return }
                let current = state.append(chunk)
                guard current.count <= 2 * 1_024 * 1_024 else {
                    finish(.failure(CodexUsageError.serverError(tr("Codex response too large."))))
                    return
                }

                guard let text = String(data: current, encoding: .utf8) else { return }
                for line in text.split(separator: "\n", omittingEmptySubsequences: true) {
                    guard let data = line.data(using: .utf8),
                          let object = try? JSONSerialization.jsonObject(with: data),
                          let dictionary = object as? [String: Any]
                    else { continue }

                    if let id = dictionary["id"] as? NSNumber, id.intValue == 1, state.claimInitialization() {
                        if dictionary["error"] != nil {
                            finish(.failure(CodexUsageError.serverError(tr("Codex rejected initialization."))))
                            return
                        }
                        do {
                            try state.send(["method": "initialized", "params": [:]], to: input.fileHandleForWriting)
                            try state.send(["method": "account/rateLimits/read", "id": 2,
                                            "params": ["excludeResetCreditDetails": true]], to: input.fileHandleForWriting)
                        } catch { finish(.failure(error)) }
                    }
                    if let id = dictionary["id"] as? NSNumber, id.intValue == 2 {
                        if let error = dictionary["error"] as? [String: Any] {
                            finish(.failure(CodexUsageError.serverError(error["message"] as? String ?? tr("Codex returned an error."))))
                        } else {
                            do { finish(.success(try UsageParser.parseCodexResponse(dictionary))) }
                            catch { finish(.failure(error)) }
                        }
                    }
                }
            }

            state.registerCancellation { finish(.failure(CancellationError())) }
            do {
                guard try state.launch(process) else { finish(.failure(CancellationError())); return }
                try state.send([
                        "method": "initialize",
                        "id": 1,
                        "params": [
                            "clientInfo": ["name": "agent_notch", "title": "Agent Notch", "version": "0.3.0"]
                        ]
                    ], to: input.fileHandleForWriting)
            } catch {
                finish(.failure(CodexUsageError.launchFailed(error.localizedDescription)))
                return
            }

            DispatchQueue.global().asyncAfter(deadline: .now() + 12) {
                finish(.failure(CodexUsageError.timedOut))
            }
        }
        } onCancel: { state.cancel() }
    }

    private static func findCodexExecutable() -> URL? {
        let home = FileManager.default.homeDirectoryForCurrentUser.path
        let candidates = [
            "/opt/homebrew/bin/codex",
            "/usr/local/bin/codex",
            "\(home)/.local/bin/codex"
        ]
        return candidates.first(where: { FileManager.default.isExecutableFile(atPath: $0) }).map(URL.init(fileURLWithPath:))
    }
}
