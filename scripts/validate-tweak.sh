#!/bin/sh
set -eu

package=${1:?usage: validate-tweak.sh package.deb}
test -s "$package"
package_dir=$(cd "$(dirname "$package")" && pwd)
package="$package_dir/$(basename "$package")"

tmp=$(mktemp -d "${TMPDIR:-/tmp}/youmod-validate.XXXXXX")
trap 'rm -rf "$tmp"' EXIT INT TERM

(
  cd "$tmp"
  ar -x "$package"
  data_archive=$(find . -maxdepth 1 -type f -name 'data.tar.*' -print -quit)
  test -n "$data_archive"
  tar -xf "$data_archive"
)

dylib=$(find "$tmp" -type f -name 'YouMod.dylib' -print -quit)
test -n "$dylib" || {
  echo "YouMod.dylib is missing from $package" >&2
  exit 1
}

file "$dylib" | grep -q 'Mach-O'
lipo -archs "$dylib" | tr ' ' '\n' | grep -qx 'arm64'
echo "$dylib"
