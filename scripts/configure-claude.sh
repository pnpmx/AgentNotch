#!/bin/zsh
set -euo pipefail

settings="$HOME/.claude/settings.json"
executable="$HOME/Applications/AgentNotch.app/Contents/MacOS/AgentNotch"

if [[ ! -x "$executable" ]]; then
  echo "Instala Agent Notch primero con scripts/install-local.sh" >&2
  exit 1
fi

mkdir -p "${settings:h}"
if [[ ! -f "$settings" ]]; then
  echo '{}' > "$settings"
fi

existing=$(jq -r '.statusLine.command // empty' "$settings")
if [[ -n "$existing" && "$existing" != *"--claude-bridge"* ]]; then
  echo "Claude ya tiene un status line; no se ha sobrescrito: $existing" >&2
  exit 2
fi

backup="${settings%.json}.agentnotch-backup.$(date +%Y%m%d-%H%M%S).json"
cp "$settings" "$backup"
temporary=$(mktemp "${settings:h}/agentnotch-settings.XXXXXX")
command="\"$executable\" --claude-bridge"
jq --arg command "$command" '.statusLine = {type:"command", command:$command, refreshInterval:30}' "$settings" > "$temporary"
mv "$temporary" "$settings"
chmod 600 "$settings"

echo "Claude Code conectado. Backup: $backup"
