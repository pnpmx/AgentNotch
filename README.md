# AgentNotch

[![CI](https://github.com/pnpmx/AgentNotch/actions/workflows/ci.yml/badge.svg)](https://github.com/pnpmx/AgentNotch/actions/workflows/ci.yml)
[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](LICENSE)

Experimental native macOS notch panel for Codex and Claude usage, with local
push-to-talk dictation using Apple's SpeechAnalyzer.

**Experimental software.** Version 0.2 addresses the defects in the initial
[audit](AUDIT.md). Behavioral regression tests cover window state, keyboard
lifecycle, voice recovery, audio conversion, clipboard restoration and request
cancellation. Physical microphone dictation and OS permission approval still
require an installed-app check on each machine.

The maintainer has confirmed dictation and the blinking recording indicator on
a MacBook Air M2. This is a personal verification, not a compatibility guarantee
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
