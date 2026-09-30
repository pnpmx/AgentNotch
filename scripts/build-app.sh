#!/bin/zsh
set -euo pipefail

project_dir="${0:A:h:h}"
configuration="${1:-release}"
build_dir="$project_dir/.build/arm64-apple-macosx/$configuration"
bundle_root="$project_dir/.build/app-bundle"
app_dir="$bundle_root/AgentNotch.bundle-staging"

cd "$project_dir"
swift build -c "$configuration" --arch arm64

mkdir -p "$app_dir/Contents/MacOS" "$app_dir/Contents/Resources"
cp "$build_dir/AgentNotch" "$app_dir/Contents/MacOS/AgentNotch"
cp "$project_dir/Resources/Info.plist" "$app_dir/Contents/Info.plist"
cp "$project_dir/Resources/AppIcon.icns" "$app_dir/Contents/Resources/AppIcon.icns"
chmod +x "$app_dir/Contents/MacOS/AgentNotch"
codesign --force --deep --sign - \
  --requirements '=designated => identifier "dev.agentnotch.mac"' \
  "$app_dir"

echo "$app_dir"
