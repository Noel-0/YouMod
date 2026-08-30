#!/bin/sh
set -eu

dylib=${1:?usage: validate-jailed-dylib.sh YouMod.dylib}
test -s "$dylib"

file "$dylib" | grep -q 'Mach-O'
lipo -archs "$dylib" | tr ' ' '\n' | grep -qx arm64

dependencies=$(otool -L "$dylib" | tail -n +2 | awk '{print $1}')
printf '%s\n' "$dependencies" | grep -qx '@rpath/YouMod.dylib'
printf '%s\n' "$dependencies" | grep -qx '@rpath/CydiaSubstrate.framework/CydiaSubstrate'

bad_dependencies=$(printf '%s\n' "$dependencies" | grep '^/' | grep -Ev '^/usr/lib/|^/System/Library/' || true)
test -z "$bad_dependencies" || {
  echo "Jailed dylib contains unsupported absolute dependencies:" >&2
  echo "$bad_dependencies" >&2
  exit 1
}
