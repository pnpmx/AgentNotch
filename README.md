# AgentNotch

[![CI](https://github.com/pnpmx/AgentNotch/actions/workflows/ci.yml/badge.svg)](https://github.com/pnpmx/AgentNotch/actions/workflows/ci.yml)
[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](LICENSE)

Experimental native macOS notch panel for Codex and Claude Code: usage limits,
alerts when an agent finishes or needs you, default model and effort, and local
push-to-talk dictation using Apple's SpeechAnalyzer.

Windows and Linux: see [AgentNotch for Windows and Linux](https://github.com/pnpmx/AgentNotch-Windows).
Website: [agentnotch.vercel.app](https://agentnotch.vercel.app).

**Experimental software.** Version 0.4 adds the agent features below. Version
0.2 addressed the defects in the initial
[audit](AUDIT.md). Behavioral regression tests cover window state, keyboard
lifecycle, voice recovery, audio conversion, clipboard restoration and request
cancellation. Physical microphone dictation and OS permission approval still
require an installed-app check on each machine.

The maintainer has confirmed dictation, the blinking recording indicator and the
0.4 agent features on a MacBook Air M2. This is a personal verification, not a compatibility guarantee
for other hardware or accounts. The interface is available in English, Spanish,
Italian, French, German and Portuguese; it follows the macOS language unless you
pick one under **Interface language**.

## Requirements

- Apple Silicon Mac, macOS 26 or later, Swift 6.2 or later.
- Codex CLI installed and signed in separately for Codex usage. Lookup currently
  checks `/opt/homebrew/bin`, `/usr/local/bin` and `~/.local/bin`.
- Claude Code for the optional status-line integration. Claude Desktop usage
  history is an optional, undocumented local fallback that may change.
- Accessibility and microphone permissions for dictation. The current
  implementation also requests Speech Recognition permission.

No third-party Swift packages or hosted speech API key are needed. Speech uses
on-device models; initial language downloads require network access. Codex usage
retrieval may contact services through the authenticated CLI.

## Download

Get **`AgentNotch-mac.dmg`** from the [latest release](https://github.com/pnpmx/AgentNotch/releases/latest),
open it and drag AgentNotch to Applications (macOS 26+, Apple Silicon).
Release builds are not notarized yet: the first time, open the app, then go to
**System Settings → Privacy & Security** and click **Open Anyway**. To avoid
that step, build it yourself as below.

## Build and install

From the repository root:

```sh
git clone https://github.com/pnpmx/AgentNotch.git
cd AgentNotch
swift build -c release
swift run -c release AgentNotch --self-test
swift run -c release AgentNotch --regression-test
```

To install and launch a personal, ad-hoc signed build:

```sh
scripts/install-local.sh
```

The installer stages its build under `.build`, installs one app in
`~/Applications`, and moves any replaced installation to the Trash. It stops the matching executable before
replacement and launches the new copy. Builds are not notarized.

Optionally connect Claude Code:

```sh
scripts/configure-claude.sh
```

This changes `~/.claude/settings.json`, saves a backup, and refuses to replace an
unrelated existing status line. Cached usage shows its source, age and stale
state, together with refresh errors. Not every account supplies every limit.

## Agents, limits and dictation options (0.4)

Open the panel and use the gear for settings.

- **Agent alerts.** **Enable agent alerts** adds `Stop` and `Notification`
  hooks to `~/.claude/settings.json` (after a backup, keeping existing hooks)
  and a `notify` program to `~/.codex/config.toml` (never replacing one you
  already use). Both run `AgentNotch --agent-event …`, which records when an
  agent finishes, asks for approval or waits; a dot pulses in the notch and the
  panel lists the event with its project. Applies to sessions started
  afterwards.
- **Default model and effort** for new Claude Code sessions (`model`,
  `effortLevel`) and Codex sessions (`model`, `model_reasoning_effort`). Codex
  options come from its own `models_cache.json`. Open sessions keep their model;
  use `/model` there.
- **Session line** under Claude Code: model, effort, cost and context used,
  from the status line.
- **Limit alerts** at 80% and 95%, a notice on reset, and a pace projection
  ("at this pace: 100% at 16:40") from recent readings.
- **Dictation:** a vocabulary of names and terms (passed to SpeechAnalyzer as
  contextual strings, best effort), optional Enter after pasting, filler-word
  removal, and a history of recent dictations to copy again.

The panel accepts keyboard input only while settings are open.

## Sessions, live activity and Wrapped (0.5)

- **Sessions panel** with every Claude Code and Codex session, its project,
  model, state and what it is doing now (from `UserPromptSubmit` and
  `PreToolUse` hooks; only short descriptions such as a file name are kept).
  Open a session for its last response, **Copy response**, and **Continue in
  Codex/Claude**, which copies a handoff prompt for the other agent.
- The notch glows while agents work, breathes while one waits for you and
  flashes with a trackpad tap when one finishes.
- **Drop files on the notch** to paste their paths where you are typing.
- Finished alerts show cost, time and lines changed; limits show a countdown
  near 100% and announce when they are available again.
- **Your week** renders a shareable summary image (tasks, lines, cost, hours,
  favourite model, top project, busiest day) to the Desktop. Statistics stay
  local in `~/Library/Application Support/AgentNotch/stats.json`.

## Interaction and current limitations

Click the top strip to expand usage details. Hold Space for 280 ms in a supported
frontmost editor/terminal to start dictation, then release to transcribe and
attempt to paste into the original application. Modified Space shortcuts pass
through; focus changes cancel dictation. The transcript remains available with
a Copy button if the destination changes or pasting is unavailable. A synthetic
paste request cannot confirm that the target application actually accepted it.

A blinking red microphone beside Codex means recording is active, including
when the panel is collapsed. Orange indicates preparation or transcription;
the usage ring returns when idle. Reduce Motion uses a steady microphone.

Expand the panel and use **Enable Space** for Accessibility and **Grant voice
permissions** for microphone/speech permission. OS approval must be completed
by the user. Permission checks run in the GUI process and retry while the app is
open. Use the menu's **Copy diagnostics** to inspect that process's state;
running a separate CLI permission check is not equivalent.

Dictation languages are selected manually, separately from the interface
language: Spanish, English, Italian, French, German and Portuguese. Automatic
language detection and Whisper fallback are not implemented.
Login launch defaults on for the first personal launch; disabling it from the
menu is remembered on subsequent launches.

The [audit](AUDIT.md) preserves the original findings and records their remediation
status and the remaining manual checks. Whisper remains a future integration.

## Contributing, security and license

See [CONTRIBUTING.md](CONTRIBUTING.md), [SECURITY.md](SECURITY.md) and
[THIRD_PARTY.md](THIRD_PARTY.md). Do not include account settings, credentials,
transcripts or private screenshots in issues or patches.

Licensed under [MIT](LICENSE). This independent project is not affiliated with
OpenAI, Anthropic or Apple. Product names identify external integrations.

All application source, build scripts and tests are in this repository. Apple
frameworks and downloaded speech models are proprietary platform dependencies;
Codex and Claude are external services under their own terms. MIT applies to
AgentNotch's code, not those dependencies. See [THIRD_PARTY.md](THIRD_PARTY.md).

## Product demo

An editable 34-second Remotion demo is in [demo/](demo/README.md). It illustrates
usage limits, push-to-talk and the recording indicator using sample data.
Run `npm ci` and `npm run dev` inside `demo/` to preview it. This optional video
toolchain has its own dependency licenses and is not part of the macOS build.

## Uninstall

Disable **Open at login** in the menu, then quit AgentNotch and move
`~/Applications/AgentNotch.app` to the Trash. If the Claude bridge was configured,
remove only the AgentNotch `statusLine` entry from `~/.claude/settings.json` (or
restore the relevant backup after reviewing later changes). Optional usage and
diagnostic data lives in `~/Library/Application Support/AgentNotch` and can be
moved to the Trash separately. Remove its permissions in System Settings if desired.
