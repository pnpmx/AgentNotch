# Security and privacy

AgentNotch is an experimental macOS application. See [AUDIT.md](AUDIT.md) before
enabling global keyboard capture or dictation. A successful build or parser test
does not establish that microphone capture, permissions or pasting work safely.

## Data flow

- Speech recognition uses Apple's on-device SpeechAnalyzer. Language assets may
  need a network download. AgentNotch has no hosted speech API or analytics.
- Accessibility is used to intercept Space and synthesize keyboard events. The
  tap receives global key events, although the application filters its behavior
  by frontmost application. Do not log raw keystrokes or transcript contents.
- Dictation temporarily writes to the system clipboard and sends Command-V.
  Current destination and clipboard preservation defects are listed in the audit.
- Codex usage starts a locally installed `codex app-server`, which uses the CLI's
  existing account session and may contact its service. This is not offline usage.
- Claude usage reads a local status-line snapshot and optionally Claude Desktop's
  usage history. Connecting the bridge modifies `~/.claude/settings.json`, with
  a backup; an unrelated status-line command is preserved.
- Usage snapshots are stored under `~/Library/Application Support/AgentNotch`.
  These files, account settings, transcripts, screenshots and signing material
  must never be committed.
- Personal builds are ad-hoc signed, not Developer ID signed or notarized.

## Reporting

No hosted private reporting channel is configured yet. Once a repository host
is selected, configure private vulnerability reporting there before requesting
security reports. Do not put credentials, transcripts, clipboard contents or
personal screenshots in public issues.

## Release checks

Review the complete staged diff and tracked files, scan for secrets, build from
a clean checkout, and test the actual installed GUI process. Do not publish
local app bundles, account caches, usage snapshots or diagnostic captures.
