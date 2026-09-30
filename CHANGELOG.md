# Changelog

## 0.6.0

- Compact panel: one tab at a time (**Sessions · Limits · Voice**), opening on
  Sessions when there is activity. Agent alerts merge into their session row as
  an unread mark with a badge on the tab; rows are one line with details on
  demand; at most four sessions show, and ones finished over an hour ago hide.
- Replies are shown as plain text (Markdown tables and emphasis, and Codex JSON
  replies, are cleaned). No "+0/−0" for tasks that changed no lines.
- Setup buttons only appear when something still needs connecting.
- Live dictation text only appears while dictating; past dictations and the
  language menus live in the Voice tab.

## 0.5.0

- Sessions panel: every Claude Code and Codex session at once, with project,
  model, state and live activity ("editing auth.ts", "running npm test").
  Adds `UserPromptSubmit` and `PreToolUse` hooks (press **Enable agent
  alerts** again to add them); only a short description of each action is
  kept, never file contents. Parallel hooks write under a file lock.
- The notch shows the overall state: a moving glow while working, a breathing
  outline while an agent waits, a flash and a trackpad tap when one finishes.
- Drop files on the notch to paste their paths where you are typing.
- Last response of each session with copy, and "Continue in Codex/Claude",
  which copies a handoff prompt with the project, the request and the progress.
- Cost per task ($, time, lines added/removed) on finished alerts.
- Countdown when a limit is nearly used up, and a notice when it is available.
- One reminder when a session has been waiting for you for three minutes.
- "Your week": a shareable weekly summary image saved to the Desktop.

## 0.4.1

- Downloadable disk image: each release now includes `AgentNotch-mac.dmg`,
  built by GitHub Actions. Drag AgentNotch to Applications; no Xcode needed.
- App icon.
- Release workflow signs with Developer ID and notarizes automatically when
  signing secrets are configured; until then builds are ad-hoc signed and
  macOS asks once to confirm under Privacy & Security.

## 0.4.0

- Agent alerts: Claude Code hooks and Codex's notify program report when an
  agent finishes, needs approval or is waiting; a dot pulses in the notch and
  the panel lists what happened per project. **Enable agent alerts** installs
  both, preserving existing hooks and never replacing another notify program.
- Default model and effort for new Claude Code and Codex sessions from the
  settings (gear). Codex options come from the models Codex itself lists.
- Live Claude Code session line: model, effort, cost and context used.
- Limit alerts at 80% and 95%, a notice when a limit resets, and a pace
  projection ("at this pace: 100% at 16:40").
- Dictation: custom vocabulary passed to SpeechAnalyzer as contextual
  strings, optional Enter after pasting, filler-word removal, and a history
  of recent dictations.
- The panel accepts keyboard input only while settings are open.

## 0.3.0

- Localize the interface in English, Spanish, Italian, French, German and
  Portuguese. It follows the macOS language by default; an **Interface
  language** menu (panel and menu bar) overrides it and applies immediately.
  Dictation language remains a separate setting.
- Usage-window labels are derived from stable ids, so snapshots cached in an
  earlier language render in the current one.
- Regression suite checks every string has all translations with matching
  format specifiers.

## 0.2.1

- Show a small blinking red microphone in the compact panel's Codex wing while
  listening, safely outside the camera cutout. Preparation and transcription use
  orange indicators; idle restores the usage ring without resizing the panel.
- Respect Reduce Motion with a steady recording indicator.

## 0.2.0

- Fix stale `@Published` reads causing clipped expansion, delayed resizing and
  black space after collapse. Measure SwiftUI content and reserve the actual
  camera exclusion area.
- Respect modified Space shortcuts; preserve typing order and cancel a held
  press when focus/session changes. Retry permission checks in the GUI process.
- Add explicit voice-permission setup and sanitized GUI diagnostics.
- Allow retry after voice errors, cancel preparation on release and avoid
  automatic panel expansion during voice startup.
- Convert native microphone audio to the analyzer format, clean up partial
  startup/finalization and propagate analysis failures.
- Validate the original paste destination, preserve clipboard representations
  and keep a Copy fallback. Label synthetic insertion as an attempted paste.
- Show usage source, age, stale state and refresh errors. Harden numeric parsing
  and empty Codex bucket fallback; bound/drain/cancel usage subprocesses.
- Preserve login preference and manage fallback registration. Stop the installed
  process before replacing it and launch one updated copy.
- Add twelve portable behavioral regressions plus an XCTest wrapper. The four
  original parser/format tests remain.

Validation: release build with warnings as errors, portable regressions, parser
tests and installed-GUI layout checks. Real microphone dictation, physical
shortcut behavior and next-login launch still need user/device validation.
The final installed GUI confirmed Accessibility, microphone and speech permission
plus an active event tap. OS approval cannot be supplied by the application or
inferred from a separate terminal process.
