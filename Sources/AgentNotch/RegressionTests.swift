import AppKit
import AVFoundation

@MainActor
final class RegressionTests {
    private var failures: [String] = []
    static func run() async -> Int32 {
        let suite = RegressionTests()
        suite.testSpaceModifiersAndTypingOrder()
        suite.testLongPressReleaseAndCancelCanRestart()
        await suite.testWindowOpenCloseWithoutUsageRefresh()
        await suite.testContentGrowthAndShrink()
        await suite.testVoiceFailureCanRetryWithoutRelaunch()
        await suite.testReleaseDuringPreparationCancels()
        await suite.testFinalizationFailureCanRetry()
        await suite.testSubprocessCancellation()
        suite.testClipboardRoundTripAndInterveningCopy()
        do {
            try suite.testAudioSampleRateConversion()
            try suite.testEmptyCodexBucketsFallBackAndInvalidNumbers()
        } catch { suite.failures.append("Thrown: \(error)") }
        suite.testStaleSnapshotIsVisibleAsStale()
        for failure in suite.failures { print("FAIL: \(failure)") }
        print("Regression scenarios: 12; failures: \(suite.failures.count)")
        return suite.failures.isEmpty ? 0 : 1
    }

    private func XCTAssertTrue(_ value: Bool, _ message: String = "", line: UInt = #line) {
        if !value { failures.append("line \(line): expected true. \(message)") }
    }
    private func XCTAssertFalse(_ value: Bool, _ message: String = "", line: UInt = #line) {
        XCTAssertTrue(!value, message, line: line)
    }
    private func XCTAssertEqual<T: Equatable>(_ lhs: T, _ rhs: T, line: UInt = #line) {
        if lhs != rhs { failures.append("line \(line): \(lhs) != \(rhs)") }
    }
    private func XCTAssertEqual(_ lhs: CGFloat, _ rhs: CGFloat, accuracy: CGFloat, line: UInt = #line) {
        XCTAssertTrue(abs(lhs - rhs) <= accuracy, "geometry mismatch", line: line)
    }
    private func XCTAssertGreaterThan<T: Comparable>(_ lhs: T, _ rhs: T, line: UInt = #line) {
        XCTAssertTrue(lhs > rhs, "expected \(lhs) > \(rhs)", line: line)
    }
    private func XCTAssertNil<T>(_ value: T?, line: UInt = #line) {
        XCTAssertTrue(value == nil, "expected nil", line: line)
    }
    private func XCTFail(_ message: String) { failures.append(message) }
    private func XCTUnwrap<T>(_ value: T?) throws -> T {
        guard let value else { throw LocalSpeechError.noAudioFormat }
        return value
    }
    func testSpaceModifiersAndTypingOrder() {
        var press = SpacePress()
        XCTAssertFalse(press.begin(allowed: true, modified: true))
        XCTAssertFalse(press.begin(allowed: false, modified: false))
        XCTAssertTrue(press.begin(allowed: true, modified: false))
        XCTAssertTrue(press.interruptTyping(), "Pending space must flush before the next character")
        XCTAssertFalse(press.threshold(), "Typing must cancel the recording timer")
        XCTAssertEqual(press.release(), .forwarded)
        XCTAssertEqual(press.state, .idle)
    }

    func testLongPressReleaseAndCancelCanRestart() {
        var press = SpacePress()
        for _ in 0..<10 {
            XCTAssertTrue(press.begin(allowed: true, modified: false))
            XCTAssertTrue(press.threshold())
            XCTAssertEqual(press.release(), .speaking)
            XCTAssertEqual(press.state, .idle)
        }
    }

    @MainActor
    func testWindowOpenCloseWithoutUsageRefresh() async {
        _ = NSApplication.shared
        let model = AppModel(speechService: FakeSpeech())
        let panel = NotchPanelController(model: model, show: false)
        let compact = panel.frame
        for _ in 0..<4 {
            model.isExpanded = true
            try? await Task.sleep(for: .milliseconds(120))
            XCTAssertGreaterThan(panel.frame.height, compact.height + 50)
            XCTAssertEqual(panel.frame.maxY, compact.maxY, accuracy: 1)
            model.isExpanded = false
            try? await Task.sleep(for: .milliseconds(120))
            XCTAssertEqual(panel.frame.height, compact.height, accuracy: 1)
        }
    }

    @MainActor
    func testContentGrowthAndShrink() async {
        _ = NSApplication.shared
        let model = AppModel(speechService: FakeSpeech())
        model.isExpanded = true
        let panel = NotchPanelController(model: model, show: false)
        let initial = panel.frame.height
        model.liveTranscript = "Synthetic transcript for layout regression."
        try? await Task.sleep(for: .milliseconds(120))
        XCTAssertGreaterThan(panel.frame.height, initial)
        model.liveTranscript = ""
        try? await Task.sleep(for: .milliseconds(120))
        XCTAssertEqual(panel.frame.height, initial, accuracy: 1)
    }

    @MainActor
    func testVoiceFailureCanRetryWithoutRelaunch() async {
        let speech = FakeSpeech()
        speech.failStart = true
        let model = AppModel(speechService: speech)
        model.beginSpeech()
        try? await Task.sleep(for: .milliseconds(40))
        guard case .failed = model.speechState else { return XCTFail("Expected recoverable failure") }
        speech.failStart = false
        model.beginSpeech()
        try? await Task.sleep(for: .milliseconds(40))
        XCTAssertEqual(model.speechState, .listening)
        XCTAssertFalse(model.isExpanded, "Dictation must not open the notch unexpectedly")
        await model.finishSpeech()
        XCTAssertEqual(model.speechState, .idle)
        XCTAssertEqual(speech.starts, 2)
    }

    @MainActor
    func testReleaseDuringPreparationCancels() async {
        let speech = FakeSpeech()
        speech.delay = true
        let model = AppModel(speechService: speech)
        model.beginSpeech()
        await model.finishSpeech()
        XCTAssertEqual(model.speechState, .idle)
        XCTAssertFalse(speech.isRunning)
        XCTAssertFalse(model.isExpanded)
    }

    func testFinalizationFailureCanRetry() async {
        let speech = FakeSpeech()
        let model = AppModel(speechService: speech)
        model.beginSpeech()
        try? await Task.sleep(for: .milliseconds(40))
        speech.failStop = true
        await model.finishSpeech()
        guard case .failed = model.speechState else { return XCTFail("Expected finalization error") }
        XCTAssertFalse(speech.isRunning)
        speech.failStop = false
        model.beginSpeech()
        try? await Task.sleep(for: .milliseconds(40))
        XCTAssertEqual(model.speechState, .listening)
        await model.cancelSpeech()
    }

    func testSubprocessCancellation() async {
        let provider = CodexUsageProvider(executable: URL(fileURLWithPath: "/bin/sleep"), arguments: ["30"])
        let start = Date()
        let task = Task { try await provider.fetch() }
        try? await Task.sleep(for: .milliseconds(60))
        task.cancel()
        do { _ = try await task.value; XCTFail("Cancellation must throw") }
        catch is CancellationError { }
        catch { XCTFail("Wrong cancellation error: \(error)") }
        XCTAssertTrue(Date().timeIntervalSince(start) < 2, "Cancellation should not wait for request timeout")
    }

    func testClipboardRoundTripAndInterveningCopy() {
        let board = NSPasteboard(name: .init("AgentNotchTests.\(UUID())"))
        defer { board.releaseGlobally() }
        let data = Data([0, 1, 2, 255])
        let type = NSPasteboard.PasteboardType("org.agentnotch.synthetic")
        board.setData(data, forType: type)
        board.setString("previous", forType: .string)
        let saved = ClipboardSnapshot(board)
        board.clearContents(); board.setString("dictation", forType: .string)
        saved.restore(to: board, ifUnchanged: board.changeCount)
        XCTAssertEqual(board.data(forType: type), data)
        XCTAssertEqual(board.string(forType: .string), "previous")
        let count = board.changeCount
        board.clearContents(); board.setString("new copy", forType: .string)
        saved.restore(to: board, ifUnchanged: count)
        XCTAssertEqual(board.string(forType: .string), "new copy")
    }

    func testAudioSampleRateConversion() throws {
        let input = try XCTUnwrap(AVAudioFormat(standardFormatWithSampleRate: 48_000, channels: 2))
        let output = try XCTUnwrap(AVAudioFormat(standardFormatWithSampleRate: 16_000, channels: 1))
        let buffer = try XCTUnwrap(AVAudioPCMBuffer(pcmFormat: input, frameCapacity: 4_800))
        buffer.frameLength = 4_800
        for channel in 0..<2 { buffer.floatChannelData![channel].initialize(repeating: 0, count: 4_800) }
        let converter = try AudioBufferConverter(from: input, to: output)
        let result = try converter.convert(buffer)
        XCTAssertEqual(result.format.sampleRate, 16_000)
        XCTAssertEqual(result.format.channelCount, 1)
        XCTAssertGreaterThan(result.frameLength, 0)
    }

    func testEmptyCodexBucketsFallBackAndInvalidNumbers() throws {
        let root: [String: Any] = ["result": ["rateLimitsByLimitId": [:], "rateLimits": [
            "primary": ["usedPercent": 120, "windowDurationMins": Double.infinity, "resetsAt": -1]
        ]]]
        let result = try UsageParser.parseCodexResponse(root)
        XCTAssertEqual(result.primary?.usedPercent, 100)
        XCTAssertNil(result.primary?.durationMinutes)
        XCTAssertNil(result.primary?.resetsAt)
        XCTAssertEqual(UsageFormatting.percent(.nan), "--")
        XCTAssertEqual(UsageFormatting.percent(.infinity), "--")
    }

    func testStaleSnapshotIsVisibleAsStale() {
        let old = UsageSnapshot(source: .claude, windows: [], fetchedAt: Date().addingTimeInterval(-3600), plan: nil)
        XCTAssertTrue(old.isStale)
        XCTAssertTrue(old.ageLabel.contains("desactualizado"))
    }
}

@MainActor
private final class FakeSpeech: SpeechServing {
    var onPartialText: ((String) -> Void)?
    var onFailure: ((Error) -> Void)?
    var isRunning = false
    var failStart = false
    var failStop = false
    var delay = false
    var starts = 0
    func start(localeIdentifier: String) async throws {
        starts += 1
        if failStart { throw LocalSpeechError.microphoneDenied }
        if delay { try await Task.sleep(for: .seconds(30)) }
        try Task.checkCancellation()
        isRunning = true
    }
    func stop() async throws -> String {
        if failStop { throw LocalSpeechError.noAudioFormat }
        isRunning = false
        return ""
    }
    func cancel() async { isRunning = false }
}
