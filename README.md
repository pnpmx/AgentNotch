# AgentNotch

Experimental native macOS notch panel for Codex and Claude usage, with local
push-to-talk dictation using Apple's SpeechAnalyzer.

**Early prototype: known UI, keyboard, permissions and dictation defects remain.**
Read [the full audit](AUDIT.md) before using it. This is not a stable release;
passing parser tests does not mean dictation or window behavior works.

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
swift build -c release
swift run -c release AgentNotch --self-test
```

Quit any existing AgentNotch instance before updating. To install a personal,
ad-hoc signed build:

```sh
scripts/install-local.sh
open "$HOME/Applications/AgentNotch.app"
```

The installer stages its build under `.build`, installs one app in
`~/Applications`, and moves any replaced installation to the Trash. It does not
currently stop or restart a running process. Builds are not notarized.

Optionally connect Claude Code:

```sh
scripts/configure-claude.sh
```

This changes `~/.claude/settings.json`, saves a backup, and refuses to replace an
unrelated existing status line. Usage is cached locally; stale-data handling is
an open defect. Not every session or account necessarily supplies limits.

## Interaction and current limitations

Click the top strip to expand usage details. Hold Space for 280 ms in a supported
frontmost editor/terminal to start dictation, then release to transcribe and
attempt to paste. The current implementation can interfere with shortcuts or
lose release events after focus changes; test only in a disposable editor.

Languages are selected manually: Spanish, English, Italian, French, German and
Portuguese. Automatic language detection and Whisper fallback are not implemented.
Startup currently attempts to enable login launch automatically; persistence of
the disable setting is also an open defect.

The [audit](AUDIT.md) includes reproducible window-state ordering failures,
permission-diagnostic limitations, audio cleanup risks, clipboard defects and
the checks required before a stable release.

## Contributing, security and license

See [CONTRIBUTING.md](CONTRIBUTING.md), [SECURITY.md](SECURITY.md) and
[THIRD_PARTY.md](THIRD_PARTY.md). Do not include account settings, credentials,
transcripts or private screenshots in issues or patches.

Licensed under [MIT](LICENSE). This independent project is not affiliated with
OpenAI, Anthropic or Apple. Product names identify external integrations.
