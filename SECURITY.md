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
  Version 0.2 verifies the original process, targets that PID, preserves clipboard
  representations and restores them only if no intervening copy occurred. It
  cannot guarantee the target application accepts the synthetic paste request.
- Codex usage starts a locally installed `codex app-server`, which uses the CLI's
  existing account session and may contact its service. This is not offline usage.
- Claude usage reads a local status-line snapshot and optionally Claude Desktop's
  usage history. Connecting the bridge modifies `~/.claude/settings.json`, with
  a backup; an unrelated status-line command is preserved.
- Usage snapshots are stored under `~/Library/Application Support/AgentNotch`.
  These files, account settings, transcripts, screenshots and signing material
  must never be committed.
- Personal builds are ad-hoc signed, not Developer ID signed or notarized.
- Optional `--diagnostics` writes sanitized GUI-process state to the local
  support directory. It excludes transcripts, clipboard data and account details.
  The menu can copy the same diagnostic state on demand.

## Reporting

Use [GitHub private vulnerability reporting](https://github.com/pnpmx/AgentNotch/security/advisories/new)
for security defects. Do not put credentials, transcripts, clipboard contents or
personal screenshots in public issues. If private reporting is temporarily
unavailable, open an issue asking for a private contact without including
exploit details or sensitive data. There is no guaranteed response-time SLA.

Security fixes target the latest source on `main`; historical personal builds
are not maintained separately.

## Release checks

Review the complete staged diff and tracked files, scan for secrets, build from
a clean checkout, and test the actual installed GUI process. Do not publish
local app bundles, account caches, usage snapshots or diagnostic captures.
