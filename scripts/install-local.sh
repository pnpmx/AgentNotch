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

if [[ -e "$target_app" ]]; then
  mv "$target_app" "$trash_root/AgentNotch-replaced-$stamp"
fi
mv "$staged_app" "$target_app"
echo "$target_app"
