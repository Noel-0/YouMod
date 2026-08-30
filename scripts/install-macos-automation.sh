#!/bin/zsh
set -euo pipefail

repo_root=$(cd "$(dirname "$0")/.." && pwd)
bin_dir="$HOME/Library/Application Support/YouMod Builder/bin"
agent_dir="$HOME/Library/LaunchAgents"
agent_path="$agent_dir/io.github.noel-0.youmod-builder.plist"

mkdir -p "$bin_dir" "$agent_dir"
cp "$repo_root/scripts/assemble-private-ipa.sh" "$bin_dir/assemble-private-ipa.sh"
chmod 700 "$bin_dir/assemble-private-ipa.sh"

sed "s|__ASSEMBLER__|$bin_dir/assemble-private-ipa.sh|g" \
  "$repo_root/macos/io.github.noel-0.youmod-builder.plist.template" > "$agent_path"
plutil -lint "$agent_path"

launchctl bootout "gui/$(id -u)" "$agent_path" 2>/dev/null || true
launchctl bootstrap "gui/$(id -u)" "$agent_path"
launchctl enable "gui/$(id -u)/io.github.noel-0.youmod-builder"

print -- "Installed $agent_path"
print -- "Place the selected decrypted IPA at iCloud Drive/YouMod Builder/Input/base.ipa"
