import Foundation

private final class CodexRequestState: @unchecked Sendable {
    private let lock = NSLock()
    private var buffer = Data()
    private var finished = false

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
            return "No encuentro el ejecutable de Codex."
        case .launchFailed(let message):
            return "No se pudo iniciar Codex: \(message)"
        case .timedOut:
            return "Codex tardó demasiado en responder."
        case .serverError(let message):
            return message
        }
    }
}

final class CodexUsageProvider {
    func fetch() async throws -> UsageSnapshot {
        try await withCheckedThrowingContinuation { continuation in
            guard let executable = Self.findCodexExecutable() else {
                continuation.resume(throwing: CodexUsageError.executableNotFound)
                return
            }

            let process = Process()
            let input = Pipe()
            let output = Pipe()
            let errors = Pipe()
            process.executableURL = executable
            process.arguments = ["app-server"]
            process.standardInput = input
            process.standardOutput = output
            process.standardError = errors

            let state = CodexRequestState()

            @Sendable func finish(_ result: Result<UsageSnapshot, Error>) {
                guard state.claimFinish() else { return }
                output.fileHandleForReading.readabilityHandler = nil
                if process.isRunning { process.terminate() }
                continuation.resume(with: result)
            }

            output.fileHandleForReading.readabilityHandler = { handle in
                let chunk = handle.availableData
                guard !chunk.isEmpty else { return }
                let current = state.append(chunk)

                guard let text = String(data: current, encoding: .utf8) else { return }
                for line in text.split(separator: "\n", omittingEmptySubsequences: true) {
                    guard let data = line.data(using: .utf8),
                          let object = try? JSONSerialization.jsonObject(with: data),
                          let dictionary = object as? [String: Any]
                    else { continue }

                    if let id = dictionary["id"] as? NSNumber, id.intValue == 2 {
                        if let error = dictionary["error"] as? [String: Any] {
                            finish(.failure(CodexUsageError.serverError(error["message"] as? String ?? "Codex devolvió un error.")))
                        } else {
                            do { finish(.success(try UsageParser.parseCodexResponse(dictionary))) }
                            catch { finish(.failure(error)) }
                        }
                    }
                }
            }

            do {
                try process.run()
                let messages: [[String: Any]] = [
                    [
                        "method": "initialize",
                        "id": 1,
                        "params": [
                            "clientInfo": ["name": "agent_notch", "title": "Agent Notch", "version": "0.1.0"]
                        ]
                    ],
                    ["method": "initialized", "params": [:]],
                    ["method": "account/rateLimits/read", "id": 2, "params": ["excludeResetCreditDetails": true]]
                ]
                for message in messages {
                    let data = try JSONSerialization.data(withJSONObject: message)
                    input.fileHandleForWriting.write(data)
                    input.fileHandleForWriting.write(Data([0x0A]))
                }
            } catch {
                finish(.failure(CodexUsageError.launchFailed(error.localizedDescription)))
                return
            }

            DispatchQueue.global().asyncAfter(deadline: .now() + 12) {
                finish(.failure(CodexUsageError.timedOut))
            }
        }
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
