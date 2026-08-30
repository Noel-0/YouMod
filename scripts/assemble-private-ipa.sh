#!/bin/zsh
set -euo pipefail

repo=${YOUMOD_GITHUB_REPOSITORY:-Noel-0/YouMod}
icloud_root=${YOUMOD_BUILDER_ROOT:-"$HOME/Library/Mobile Documents/com~apple~CloudDocs/YouMod Builder"}
input_dir="$icloud_root/Input"
ready_dir="$icloud_root/Ready"
archive_dir="$icloud_root/Archive"
failed_dir="$icloud_root/Failed"
state_dir="$icloud_root/State"
log_file="$failed_dir/last-run.log"

mkdir -p "$input_dir" "$ready_dir" "$archive_dir" "$failed_dir" "$state_dir"
exec > >(tee -a "$log_file") 2>&1

fail() {
  print -u2 -- "ERROR: $*"
  exit 1
}

command -v gh >/dev/null || fail "GitHub CLI (gh) is required"
command -v plutil >/dev/null || fail "plutil is required"
command -v otool >/dev/null || fail "otool is required"
command -v lipo >/dev/null || fail "lipo is required"

base_ipa="$input_dir/base.ipa"
[[ -f "$base_ipa" ]] || fail "Place the explicitly selected decrypted IPA at: $base_ipa"

release_json=$(gh api "repos/$repo/releases/latest") || fail "Unable to read the latest release from $repo"
release_tag=$(printf '%s' "$release_json" | plutil -extract tag_name raw -o - - 2>/dev/null) || fail "Release has no tag"
last_tag=$(cat "$state_dir/last-release.txt" 2>/dev/null || true)
[[ "$release_tag" != "$last_tag" ]] || {
  print -- "Already assembled $release_tag"
  exit 0
}

tmp=$(mktemp -d "${TMPDIR:-/tmp}/youmod-builder.XXXXXX")
trap 'rm -rf "$tmp"' EXIT INT TERM

mkdir -p "$tmp/release"
gh release download "$release_tag" --repo "$repo" --dir "$tmp/release" --pattern '*.deb' --pattern 'provenance.json'
deb=$(find "$tmp/release" -maxdepth 1 -type f -name '*.deb' -print -quit)
[[ -n "$deb" ]] || fail "Release $release_tag has no .deb package"
[[ -f "$tmp/release/provenance.json" ]] || fail "Release $release_tag has no provenance.json"

actual_sha=$(shasum -a 256 "$deb" | awk '{print $1}')
expected_sha=$(plutil -extract package_sha256 raw -o - "$tmp/release/provenance.json" 2>/dev/null) || fail "Provenance has no package checksum"
[[ "$actual_sha" == "$expected_sha" ]] || fail "Package checksum mismatch"

mkdir "$tmp/package" "$tmp/app"
(
  cd "$tmp/package"
  ar -x "$deb"
  data_archive=$(find . -maxdepth 1 -type f -name 'data.tar.*' -print -quit)
  [[ -n "$data_archive" ]] || exit 1
  tar -xf "$data_archive"
) || fail "Unable to extract YouMod package"

new_dylib=$(find "$tmp/package" -type f -name 'YouMod.dylib' -print -quit)
[[ -n "$new_dylib" ]] || fail "YouMod.dylib is missing from the package"
file "$new_dylib" | grep -q 'Mach-O' || fail "Replacement dylib is not Mach-O"
lipo -archs "$new_dylib" | tr ' ' '\n' | grep -qx arm64 || fail "Replacement dylib has no arm64 slice"

file "$base_ipa" | grep -Eq 'Zip archive data|iOS App Zip archive data' || fail "base.ipa is not a ZIP/IPA"
ditto -x -k "$base_ipa" "$tmp/app" || fail "Unable to extract base.ipa"
app_bundle=("$tmp/app"/Payload/*.app(N))
(( ${#app_bundle} == 1 )) || fail "IPA must contain exactly one Payload/*.app"
app_bundle=${app_bundle[1]}
info_plist="$app_bundle/Info.plist"
[[ -f "$info_plist" ]] || fail "Application Info.plist is missing"
executable_name=$(plutil -extract CFBundleExecutable raw -o - "$info_plist")
main_executable="$app_bundle/$executable_name"
[[ -f "$main_executable" ]] || fail "Main executable is missing"

cryptids=$(otool -l "$main_executable" | awk '/cryptid/{print $2}')
[[ -n "$cryptids" ]] || fail "Unable to inspect executable encryption metadata"
printf '%s\n' "$cryptids" | grep -qv '^0$' && fail "The selected base IPA is still encrypted"

old_dylibs=("$app_bundle"/**/YouMod.dylib(N))
(( ${#old_dylibs} == 1 )) || fail "Expected exactly one existing YouMod.dylib; found ${#old_dylibs}"
cp -p "$new_dylib" "$old_dylibs[1]"

new_bundle=$(find "$tmp/package" -type d -name 'YouMod.bundle' -print -quit)
old_bundles=("$app_bundle"/**/YouMod.bundle(N/))
if [[ -n "$new_bundle" && ${#old_bundles} -eq 1 ]]; then
  rm -rf "$old_bundles[1]"
  cp -R "$new_bundle" "$old_bundles[1]"
elif [[ -n "$new_bundle" && ${#old_bundles} -ne 0 ]]; then
  fail "Expected zero or one existing YouMod.bundle; found ${#old_bundles}"
fi

otool -L "$main_executable" | grep -q 'YouMod.dylib' || fail "Main executable does not reference YouMod.dylib"

version=$(plutil -extract upstream_version raw -o - "$tmp/release/provenance.json")
safe_version=${version//\//-}
candidate="$ready_dir/YouMod-$safe_version.ipa"
if [[ -e "$candidate" ]]; then
  stamp=$(date -u +%Y%m%dT%H%M%SZ)
  mv "$candidate" "$archive_dir/YouMod-$safe_version-$stamp.ipa"
fi

(
  cd "$tmp/app"
  ditto -c -k --sequesterRsrc --keepParent Payload "$candidate"
)
unzip -tq "$candidate" >/dev/null || fail "Candidate IPA failed ZIP validation"
cp "$tmp/release/provenance.json" "$ready_dir/YouMod-$safe_version.provenance.json"
shasum -a 256 "$candidate" > "$ready_dir/YouMod-$safe_version.ipa.sha256"
printf '%s\n' "$release_tag" > "$state_dir/last-release.txt"

print -- "Ready for SideStore Files import: $candidate"
