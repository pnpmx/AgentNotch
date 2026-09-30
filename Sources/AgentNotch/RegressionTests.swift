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
        suite.testEveryInterfaceStringIsTranslated()
        suite.testCachedLabelsFollowInterfaceLanguage()
        suite.testAgentEventParsing()
        do { try suite.testAgentConfigEdits() } catch { suite.failures.append("Agent config: \(error)") }
        suite.testLimitTracker()
        suite.testFillerRemoval()
        suite.testSessionLifecycle()
        suite.testWeeklyStats()
        suite.testAvailabilityAfterReset()
        for failure in suite.failures { print("FAIL: \(failure)") }
        print("Regression scenarios: 21; failures: \(suite.failures.count)")
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
        XCTAssertTrue(old.ageLabel.contains(tr("outdated")))
    }

    func testAgentEventParsing() {
        let stop: [String: Any] = ["hook_event_name": "Stop", "cwd": "/Users/x/my-app/",
                                   "last_assistant_message": "Fixed   the\ntests."]
        let event = AgentEvents.fromClaudeHook(stop, at: 5)
        XCTAssertEqual(event?.kind, .done)
        XCTAssertEqual(event?.message, "Fixed the tests.")
        XCTAssertEqual(event?.project, "my-app")
        XCTAssertNil(AgentEvents.fromClaudeHook(["hook_event_name": "Stop", "agent_id": "sub"], at: 0))
        let permission: [String: Any] = ["hook_event_name": "Notification", "notification_type": "permission_prompt",
                                         "message": "Claude wants to run: Bash"]
        XCTAssertEqual(AgentEvents.fromClaudeHook(permission, at: 0)?.kind, .permission)
        XCTAssertNil(AgentEvents.fromClaudeHook(["hook_event_name": "Notification", "notification_type": "auth_success"], at: 0))
        let codex = AgentEvents.fromCodexNotify(#"{"type":"agent-turn-complete","cwd":"/src/web","last-assistant-message":"Done."}"#, at: 1)
        XCTAssertEqual(codex?.source, "codex")
        XCTAssertEqual(codex?.project, "web")
        XCTAssertNil(AgentEvents.fromCodexNotify("nope", at: 1))
    }

    func testAgentConfigEdits() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent("agentnotch-cfg-\(UUID())")
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let settings = directory.appendingPathComponent("settings.json")
        try Data(#"{"permissions":{"allow":["Bash"]},"hooks":{"Stop":[{"matcher":"*","hooks":[{"type":"command","command":"say done"}]}]}}"#.utf8)
            .write(to: settings)
        try AgentConfig.setClaudeDefaults(model: "opus", effort: "xhigh", at: settings)
        XCTAssertEqual(AgentConfig.claudeConfiguration(at: settings).model, "opus")
        XCTAssertEqual(AgentConfig.claudeConfiguration(at: settings).effort, "xhigh")
        try AgentConfig.installClaudeHooks(command: "\"/A/AgentNotch\" --agent-event claude", at: settings)
        try AgentConfig.installClaudeHooks(command: "\"/A/AgentNotch\" --agent-event claude", at: settings)
        let raw = try JSONSerialization.jsonObject(with: Data(contentsOf: settings)) as? [String: Any]
        let stop = (raw?["hooks"] as? [String: Any])?["Stop"] as? [[String: Any]]
        XCTAssertEqual(stop?.count, 2)
        XCTAssertEqual(((raw?["permissions"] as? [String: Any])?["allow"] as? [String])?.first, "Bash")
        XCTAssertTrue(AgentConfig.claudeConfiguration(at: settings).hooksInstalled)
        do { try AgentConfig.setClaudeDefaults(model: "gpt", effort: nil, at: settings); XCTFail("invalid model accepted") }
        catch {}

        let toml = "# c\nmodel = \"a\"\n\n[projects.\"/p\"]\nmodel = \"inner\"\n"
        XCTAssertEqual(AgentConfig.tomlGet(toml, "model"), "a")
        let set = AgentConfig.tomlSet(toml, "model_reasoning_effort", "\"high\"")
        XCTAssertTrue(set.contains("model = \"a\"\nmodel_reasoning_effort = \"high\"\n\n[projects"))
        XCTAssertTrue(AgentConfig.tomlSet(set, "model", nil).contains("model = \"inner\""))
        XCTAssertNil(AgentConfig.tomlGet(AgentConfig.tomlSet(set, "model", nil), "model"))
        let notify = try AgentConfig.installingCodexNotify(in: "model = \"m\"\n", executable: "/A/AgentNotch")
        XCTAssertTrue(notify.contains("notify = ['/A/AgentNotch', '--agent-event', 'codex']"))
        XCTAssertEqual(try AgentConfig.installingCodexNotify(in: notify, executable: "/A/AgentNotch"), notify)
        do { _ = try AgentConfig.installingCodexNotify(in: "notify = [\"bash\"]\n", executable: "/A"); XCTFail("replaced notify") }
        catch {}
        XCTAssertTrue(AgentConfig.isSafeIdentifier("gpt-6.1-sol"))
        XCTAssertFalse(AgentConfig.isSafeIdentifier("x\"\nnotify = []"))
    }

    func testLimitTracker() {
        func snapshot(_ at: TimeInterval, _ percent: Double, reset: TimeInterval) -> UsageSnapshot {
            UsageSnapshot(source: .claude, windows: [UsageWindow(id: "claude-five_hour", label: "5 horas", usedPercent: percent,
                                                               resetsAt: Date(timeIntervalSince1970: reset), durationMinutes: nil)],
                          fetchedAt: Date(timeIntervalSince1970: at), plan: nil)
        }
        var tracker = LimitTracker()
        XCTAssertTrue(tracker.update(snapshot(0, 50, reset: 100_000)).isEmpty)
        XCTAssertEqual(tracker.update(snapshot(600, 60, reset: 100_000)).count, 0)
        XCTAssertEqual(tracker.update(snapshot(1200, 81, reset: 100_000)).count, 1)
        XCTAssertEqual(tracker.update(snapshot(1500, 85, reset: 100_000)).count, 0)
        XCTAssertTrue(tracker.projection(for: "claude-five_hour") != nil)
        let reset = tracker.update(snapshot(1800, 2, reset: 118_000))
        XCTAssertEqual(reset.count, 1)
        if case .reset = reset.first {} else { XCTFail("expected reset") }
        var pace = LimitTracker()
        for i in 0...3 { _ = pace.update(snapshot(TimeInterval(i * 600), 40 + Double(i) * 10, reset: 100_000)) }
        XCTAssertEqual(pace.projection(for: "claude-five_hour")?.timeIntervalSince1970, 3600)
    }

    func testFillerRemoval() {
        XCTAssertEqual(TranscriptCleanup.removeFillers("Um, fix the, uh, login bug"), "Fix the, login bug")
        XCTAssertEqual(TranscriptCleanup.removeFillers("the umbrella test"), "The umbrella test")
        XCTAssertEqual(TranscriptCleanup.removeFillers("este bug es raro"), "Bug es raro")
    }

    func testSessionLifecycle() {
        var sessions: AgentSessions.Sessions = [:]
        AgentSessions.applyStatusLine(&sessions, ["session_id": "s1", "model": ["display_name": "Opus"],
                                                  "cost": ["total_cost_usd": 1.0, "total_lines_added": 10, "total_lines_removed": 2]], now: 1_000)
        AgentSessions.prune(&sessions, now: 2_000)
        XCTAssertEqual(sessions["s1"]?.costUsd, 1.0)
        AgentSessions.applyClaudeHook(&sessions, ["session_id": "s1", "hook_event_name": "UserPromptSubmit",
                                                  "prompt": "Add tests", "cwd": "/w/my-app"], now: 2_000)
        AgentSessions.applyClaudeHook(&sessions, ["session_id": "s1", "hook_event_name": "PreToolUse", "tool_name": "Write",
                                                  "tool_input": ["file_path": "/w/my-app/auth.ts", "file_text": "SECRET"]], now: 3_000)
        XCTAssertEqual(sessions["s1"]?.activity, SessionActivity(kind: "edit", detail: "auth.ts"))
        AgentSessions.applyStatusLine(&sessions, ["session_id": "s1",
                                                  "cost": ["total_cost_usd": 1.42, "total_lines_added": 166, "total_lines_removed": 25]], now: 4_000)
        let task = AgentSessions.applyClaudeHook(&sessions, ["session_id": "s1", "hook_event_name": "Stop",
                                                             "last_assistant_message": "Done."], now: 242_000)
        XCTAssertEqual(task?.durationSecs, 240)
        XCTAssertTrue(abs((task?.costUsd ?? 0) - 0.42) < 1e-9)
        XCTAssertEqual(task?.linesAdded, 156)
        XCTAssertEqual(sessions["s1"]?.state, .done)
        XCTAssertEqual(sessions["s1"]?.project, "my-app")
        XCTAssertTrue(sessions["s1"]?.handoffPrompt.contains("Add tests") == true)
        XCTAssertNil(AgentSessions.applyClaudeHook(&sessions, ["session_id": "s1", "hook_event_name": "Stop", "agent_id": "x"], now: 1))
        let long = AgentSessions.activity(tool: "Bash", input: ["command": String(repeating: "x", count: 200)])
        XCTAssertEqual(long.detail.count, AgentSessions.detailLimit)
    }

    func testWeeklyStats() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC")!
        let today = Date(timeIntervalSince1970: 1_790_726_400) // 2026-09-30, a Wednesday
        var stats: AgentStats.Stats = [:]
        let task = TaskSummary(costUsd: 0.5, durationSecs: 1800, linesAdded: 100, linesRemoved: 1)
        AgentStats.record(&stats, date: today, source: "claude", model: "Opus", project: "my-app", task: task, calendar: calendar)
        AgentStats.record(&stats, date: today, source: "claude", model: "Opus", project: "my-app", task: task, calendar: calendar)
        AgentStats.record(&stats, date: today.addingTimeInterval(-86_400), source: "codex", model: nil, project: "api",
                          task: TaskSummary(costUsd: nil, durationSecs: 0), calendar: calendar)
        let week = AgentStats.weekSummary(stats, today: today, calendar: calendar)
        XCTAssertEqual(week.tasks, 3)
        XCTAssertEqual(week.linesAdded, 200)
        XCTAssertEqual(week.topModel, "Opus")
        XCTAssertEqual(week.topProject, "my-app")
        XCTAssertEqual(week.dailyTasks, [0, 0, 0, 0, 0, 1, 2])
        XCTAssertEqual(week.busyHours, 1.0)
        XCTAssertEqual(week.to, "2026-09-30")
    }

    func testAvailabilityAfterReset() {
        var tracker = LimitTracker()
        let reset = Date(timeIntervalSince1970: 5_000)
        _ = tracker.update(UsageSnapshot(source: .claude, windows: [UsageWindow(id: "claude-five_hour", label: "5 horas",
            usedPercent: 97, resetsAt: reset, durationMinutes: nil)], fetchedAt: Date(timeIntervalSince1970: 0), plan: nil))
        XCTAssertTrue(tracker.dueAvailable(now: Date(timeIntervalSince1970: 4_999)).isEmpty)
        XCTAssertEqual(tracker.dueAvailable(now: reset).count, 1)
        XCTAssertTrue(tracker.dueAvailable(now: Date(timeIntervalSince1970: 6_000)).isEmpty)
    }

    func testEveryInterfaceStringIsTranslated() {
        let languages = UILanguage.allCases.filter { $0 != .system && $0 != .en }.map(\.rawValue)
        func specifiers(_ text: String) -> [String] {
            // Positional forms (%2$@) are allowed; compare the argument types.
            let regex = try! NSRegularExpression(pattern: "%(?:\\d+\\$)?([@d])")
            return regex.matches(in: text, range: NSRange(text.startIndex..., in: text))
                .map { String(text[Range($0.range(at: 1), in: text)!]) }
                .sorted()
        }
        for (key, translations) in L10n.table {
            for language in languages {
                guard let value = translations[language], !value.isEmpty else {
                    XCTFail("Missing \(language) translation for \"\(key)\""); continue
                }
                if specifiers(value) != specifiers(key) {
                    XCTFail("Format specifiers differ in \(language) for \"\(key)\"")
                }
            }
            if Set(translations.keys) != Set(languages) { XCTFail("Unexpected languages for \"\(key)\"") }
        }
    }

    func testCachedLabelsFollowInterfaceLanguage() {
        let previous = L10n.current
        defer { L10n.current = previous }
        // A snapshot cached while the app was Spanish-only.
        let cached = UsageWindow(id: "claude-five_hour", label: "5 horas", usedPercent: 10, resetsAt: nil, durationMinutes: nil)
        let weekly = UsageWindow(id: "codex-GPT-secondary", label: "GPT semanal", usedPercent: 10, resetsAt: nil, durationMinutes: 43_200)
        L10n.current = .en
        XCTAssertEqual(cached.displayLabel, "5 hours")
        XCTAssertEqual(weekly.displayLabel, "GPT weekly")
        XCTAssertEqual(SpeechState.listening.shortLabel, "Listening…")
        XCTAssertEqual(UsageFormatting.resetDescription(Date(timeIntervalSince1970: 4_900), now: Date(timeIntervalSince1970: 1_000)), "reset 1 h 5 min")
        L10n.current = .de
        XCTAssertEqual(cached.displayLabel, "5 Stunden")
        XCTAssertEqual(UsageFormatting.resetDescription(Date(timeIntervalSince1970: 4_900), now: Date(timeIntervalSince1970: 1_000)), "Reset 1 Std. 5 Min.")
        L10n.current = .fr
        XCTAssertEqual(weekly.displayLabel, "GPT hebdo")
    }
}

@MainActor
private final class FakeSpeech: SpeechServing {
    var onPartialText: ((String) -> Void)?
    var onFailure: ((Error) -> Void)?
    var isRunning = false
    var contextualStrings: [String] = []
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
