#!/bin/zsh
# Packages the built app into a drag-to-Applications disk image.
# Usage: scripts/make-dmg.sh <path/to/AgentNotch.app> <output.dmg>
set -euo pipefail

app="$1"
output="$2"
staging="$(mktemp -d)"
trap 'rm -rf "$staging"' EXIT

cp -R "$app" "$staging/AgentNotch.app"
ln -s /Applications "$staging/Applications"
rm -f "$output"
hdiutil create -quiet -volname "AgentNotch" -srcfolder "$staging" -ov -format UDZO "$output"
echo "$output"
