#!/bin/zsh
set -euo pipefail

project_dir="${0:A:h:h}"
source_app="$project_dir/.build/app-bundle/AgentNotch.bundle-staging"
install_root="$HOME/Applications"
target_app="$install_root/AgentNotch.app"
staged_app="$install_root/.AgentNotch.installing.app"
trash_root="$HOME/.Trash"
stamp="$(date +%Y%m%d-%H%M%S)"

"$project_dir/scripts/build-app.sh" release >/dev/null

mkdir -p "$install_root"
mkdir -p "$trash_root"
if [[ -e "$staged_app" ]]; then
  mv "$staged_app" "$trash_root/AgentNotch-incomplete-$stamp"
fi
cp -R "$source_app" "$staged_app"
codesign --force --deep --sign - \
  --requirements '=designated => identifier "dev.agentnotch.mac"' \
  "$staged_app"
codesign --verify --deep --strict "$staged_app"

# Stop only instances whose executable is the installation being replaced.
for process_id in $(pgrep -x AgentNotch || true); do
  executable=$(ps -p "$process_id" -o comm=)
  if [[ "$executable" == "$target_app/Contents/MacOS/AgentNotch" ]]; then
    kill -TERM "$process_id"
    for attempt in {1..50}; do
      kill -0 "$process_id" 2>/dev/null || break
      sleep 0.1
    done
    if kill -0 "$process_id" 2>/dev/null; then
      echo "AgentNotch no terminó; instalación cancelada." >&2
      exit 1
    fi
  fi
done

if [[ -e "$target_app" ]]; then
  mv "$target_app" "$trash_root/AgentNotch-replaced-$stamp"
fi
mv "$staged_app" "$target_app"
if ! open -g "$target_app"; then
  sleep 1
  open -g -n "$target_app"
fi
echo "$target_app"
