# AgentNotch audit — 2026-09-25

## Remediation in 0.2.0

Publication note: this document preserves observations made during the initial
local audit. References below to no remote and an unperformed spoken-phrase test
describe that moment. The maintainer subsequently confirmed dictation and the
recording indicator in 0.2.1. No private audio or transcript is included here.

The findings below describe the **pre-fix baseline**. This section records the
subsequent changes; it does not erase the original evidence.

| Findings | Implemented remediation | Verification |
| --- | --- | --- |
| A01, A07 | Post-update model delivery, intrinsic content measurement, actual cutout center/width, no sliding transition through the camera region | Repeated open/close and content grow/shrink regression scenarios; eight installed-GUI layout checks passed |
| A02, A08 | Retry after start/finalization failure, cancellation of obsolete preparation, no automatic expansion during speech | Mocked speech failure/retry, finalization/retry and release-during-preparation tests |
| A03 | Explicit press lifecycle, modifier bypass, pending-space flush before following character, focus/session cancellation and independent release handling | Pure lifecycle regressions; physical keyboard/shortcut validation still required with GUI Accessibility approval |
| A04 | Persistent GUI permission/tap monitoring, distinct status messages, voice-permission setup button, sanitized diagnostics from the actual GUI | Installed GUI confirmed Accessibility, microphone and speech authorization were absent; prior terminal-only success was misleading. User approval remains required |
| A05 | Native audio capture plus converter, cancellation checks, tap tracking independent of engine success, worker error propagation and cleanup on failures | Synthetic stereo 48 kHz → mono 16 kHz conversion and lifecycle mock tests; physical microphone/transcription remains a manual check |
| A06 | Original PID validation and targeted paste, complete clipboard representations, change-count guarded restore, explicit Copy fallback and honest attempted-paste notice | Isolated pasteboard round-trip and intervening-copy tests; no input was injected into a real user document |
| A09 | Source/age/stale labels; errors displayed alongside retained cache; cached bridge validation | Stale-data regression and parser checks |
| A10 | Persistent login preference; loaded fallback service check and bootout on disable | Source review; actual next-login behavior remains a manual check |
| A11 | Stop exact installed executable, refuse replacement if it does not stop, install then launch; duplicate GUI instance guard | Installation replacement exercised locally; single GUI process verified |
| A12 | Serialized refresh, cooperative subprocess cancellation, bounded stdout, drained stderr, termination handling, initialization handshake | Sleeping subprocess cancellation regression; usage provider checked in installed GUI |
| A13 | Empty-bucket fallback, finite/range-checked numeric values, bounded percent formatting | Malformed-number and empty-bucket regression plus original parser tests |
| A14 | Manual languages and absence of Whisper explicitly documented | Documentation review; these are not advertised as implemented features |
| A15 | Portable behavioral runner plus XCTest wrapper | Twelve regression scenarios and four parser/format tests; full Xcode is absent locally, so the portable runner was used |

No claim of end-to-end voice success is made before physical permission approval
and a spoken-phrase test. Developer ID signing/notarization and a public remote
are outside this personal build's current release configuration.

Final installed-GUI verification (0.2.0): all eight layout checks passed; the
collapsed panel measured 419 × 44 points. Accessibility trust, microphone
authorization, speech authorization and event-tap availability all reported
true in the actual GUI process on the final check. This supersedes the earlier
missing-permission observation. A physical spoken-phrase/paste test remains
unperformed; no audio or transcript was recorded by this audit.

Scope: all application Swift files, scripts, package manifest, permissions,
installation and existing tests. This is an audit of the current experimental
implementation, not a declaration that the defects below are fixed.

Evidence levels: **reproduced** means a targeted local experiment was run;
**confirmed in code** means the failure path is directly present; **unverified**
means a GUI/device-specific test is still required. No live dictation or text
injection into the user's applications was performed. The GUI process was not
running when inspected. Only one indexed installed AgentNotch application was
found. Its parser self-tests passed. No matching crash report was found in the
inspected diagnostic-report paths; that does not establish crash-free behavior.

## High-priority findings

### A01 — Window size uses the previous published state (reproduced)

`NotchPanelController.swift:39–53,80–103`: subscribers discard their incoming
value and immediately read the model again. Combine `@Published` publishes in
`willSet`, before that stored property changes. The same problem applies to
expanded state, transcript presence and usage window count.

A minimal experiment using the exact subscription pattern produced:

```text
incoming=true stored=false height=44
AFTER OPEN: expanded=true windowHeight=44
incoming=false stored=true height=294
AFTER CLOSE: expanded=false windowHeight=294
```

Opening therefore puts expanded content in the compact window; closing can
leave a large black window with only the compact contents. A later usage update
resizes again with the now-current expanded state, explaining delayed apparent
expansion/collapse. Disabling window animation or adding notch padding cannot
fix this ordering error. A preview opened expanded before subscription bypasses
the defect and is not an adequate test.

Fix direction: derive geometry from incoming values or a coherent post-update
snapshot; measure the rendered content instead of estimating heights. Verify
repeated open/close cycles without refreshing usage, then repeat while usage and
transcript updates arrive.

Reference: [Apple Published documentation](https://developer.apple.com/documentation/combine/published).

### A02 — Voice errors leave dictation permanently blocked (confirmed in code)

`AppModel.swift:134–168`: start accepts only `.idle`. Start/stop failures set
`.failed`; there is no retry/reset action. `finishSpeech` explicitly preserves
that failure. Granting microphone access after a denial does not reset the
state. Restarting the app is the only implemented recovery.

Fix direction: explicit retryable state transitions and cleanup on every
failure. Verify denial → grant → retry without restarting.

### A03 — Space handling can lose key-up and intercept shortcuts (confirmed in code)

`HoldSpaceMonitor.swift:123–162`: both key-down and key-up require the current
frontmost app to be supported. If focus changes while holding Space, key-up is
ignored and the pending/recording state can remain active. Modifier flags are
never checked: Command-Space, Control-Space and other combinations can be
swallowed when delivered to this tap. Normal Space is injected only on release,
so subsequent typed characters may arrive before the delayed space.

Fix direction: track the accepted press independently of later focus; preserve
modified shortcuts; cancel on focus/session changes; test rapid typing,
auto-repeat, key-up after focus loss and modifier combinations.

### A04 — Permission diagnosis was not testing the GUI process (unverified root cause)

`main.swift:112–119`: `--accessibility-status` and `--event-tap-status` create a
separate process launched from the calling terminal/agent. Success there does
not prove the separately launched GUI has the same effective permission or a
working tap. The previous captures still showed the activation button despite
successful CLI checks. Those checks were insufficient evidence.

`HoldSpaceMonitor.swift:90–112` stops checking after 120 attempts; granting
permission later requires another action. Failed tap creation exposes only a
Boolean and is conflated with missing Accessibility permission. A disabled tap
is reenabled without verifying success or updating availability.

Fix direction: expose sanitized diagnostics from the running GUI itself,
distinguish trust from tap availability, and test actual physical press/release
in a disposable editor. Exact cause of the user's permission loop remains open.

### A05 — Audio conversion and error cleanup are incomplete (confirmed risk)

`SpeechService.swift:52–97`: the microphone's format is read but the tap is
installed directly with the analyzer's preferred format. There is no conversion
when the device format differs. This is a device/format-dependent failure path,
not a reproduced crash on this machine.

Tasks and the audio tap are created before `engine.start()` succeeds. A thrown
start error has no rollback; `cancel()` removes the tap only if `isRunning` is
true. `stop()` can also throw during finalization before cleanup. Results and
analysis task failures are suppressed with `try?`, allowing errors to look like
empty successful dictation. First-use asset download has no progress or explicit
cancellation when Space is released.

Fix direction: capture in the device format, convert to the analyzer format,
track installed resources independently, propagate worker failures and guarantee
cleanup on all exits. Test hardware-format mismatch and startup/finalization
failure. Apple's example includes an explicit conversion step:
[SpeechAnalyzer WWDC25](https://developer.apple.com/videos/play/wwdc2025/277/).

### A06 — Paste destination and clipboard preservation are unsafe (confirmed in code)

`TextInjector.swift:6–24`, `AppModel.swift:159–163`: the destination is not captured
when recording starts. Command-V goes to whichever application is frontmost at
completion. Only the previous plain-text clipboard value is saved; images,
files, rich text and multiple pasteboard items are lost. String equality is not
enough to detect intervening clipboard changes. The UI says “Texto insertado”
without observing whether insertion succeeded.

Fix direction: verify the original destination before insertion, preserve all
pasteboard representations and use its change count; report attempted versus
confirmed insertion honestly. Test with synthetic clipboard data only.

## Additional findings

| ID | Priority | Evidence and impact | Required change |
| --- | --- | --- | --- |
| A07 | Medium | `NotchPanelController.swift:84–98` hardcodes expanded height to 294 + increments. `NotchView.swift:38` clamps the camera gap to 240; the panel centers on the screen, not on the measured cutout. Current display reports a 209 × 38 pt exclusion region, so that clamp is not the demonstrated local cause. | Measure content and actual exclusion geometry; test the current scale, different scales, multiple displays and no-notch fallback. |
| A08 | Medium | `AppModel.swift:142` unconditionally expands after speech preparation, even if Space was released during permissions/model download. Nothing restores the prior collapsed state after recording. | Make recording and expansion policy explicit; cancel obsolete preparation; test delayed startup and release. |
| A09 | Medium | `ClaudeUsageProvider.swift:29–31` accepts bridge snapshots indefinitely. Both refresh failure paths retain old snapshots, and `NotchView.swift:139` shows those in preference to the error. No age/source appears, contrary to the previous README. | Mark stale data, show its age/source and surface refresh errors alongside retained values. |
| A10 | Medium | `main.swift:81–90` reenables login launch every startup if disabled. `LaunchAtLoginController.swift:10–12` treats plist existence as enabled; disabling removes the plist without unloading a loaded service. | Persist user preference and reconcile actual service registration. Test disable → quit → reopen and next login. |
| A11 | Medium | `scripts/install-local.sh:25–28` replaces the bundle without stopping a running GUI, checking for duplicate processes or relaunching. The old executable may remain in memory. | Coordinate process shutdown, verified replacement and single-instance restart. |
| A12 | Medium | `CodexUsageProvider.swift:55–60` never drains stderr; enough output can block the child. There is no cancellation handler or termination handler, overlapping refreshes are allowed, and older results can overwrite newer results. | Drain stderr without logging secrets, bound/cancel subprocess work, serialize refresh and discard obsolete responses. |
| A13 | Medium | `UsageParser.swift:15–26` does not fall back when `rateLimitsByLimitId` exists but is empty. Numeric parsing accepts non-finite/out-of-range values before integer formatting/conversion. | Validate numeric inputs and add fallback/edge-case fixtures. |
| A14 | Low | Locale selection is manual with six options; automatic multilingual dictation and Whisper fallback are not implemented. | Document actual capabilities; do not advertise language autodetection or a fallback engine. |
| A15 | High validation gap | `SelfTests.swift` has three synthetic parser checks and one date-format check. There is no test target and no coverage of any interaction defect above. | Add behavioral regression coverage and installed-GUI end-to-end checks before calling the app stable. |

## Open-source readiness

The reviewed source set contains no detected personal absolute home paths,
credential literals, private keys, account snapshots, proprietary app bundles or
third-party vendored assets. System SDK imports and external CLI integrations
are documented separately. Pattern scanning is not a proof that no secret or
licensing issue could exist.

Repository preparation adds an MIT license, contribution/security guidance and
ignore rules for local builds, runtime data, secrets and screenshots. Only
reviewed source and documentation should enter the first commit. No account
configuration or diagnostic screenshot belongs in history. No remote repository
or public release has been created by this audit.

Source can be shared as an explicitly experimental project. A stable binary
release is blocked by A01–A06 and missing interaction validation. The audit does
not certify speech, Accessibility, physical notch visibility or login behavior
as working on the user's machine.
