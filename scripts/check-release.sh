#!/bin/bash
# Fails unless a release zip (PapoReto-<version>-<arch>.zip) holds one ad-hoc signed, self-contained PapoReto.app
# built for <arch> and at <version>, with the third-party notices; the only check the arm64 zip gets on an Intel Mac.
set -euo pipefail

zip="${1:?usage: $0 <PapoReto-version-arch.zip>}"
name="$(basename "$zip" .zip)"
[[ "$name" =~ ^PapoReto-(.+)-(x86_64|arm64)$ ]] || { echo "$name: not PapoReto-<version>-<x86_64|arm64>.zip" >&2; exit 1; }
version="${BASH_REMATCH[1]}" arch="${BASH_REMATCH[2]}"

tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT
ditto -x -k "$zip" "$tmp"
[ "$(ls -A "$tmp")" = PapoReto.app ] || { echo "$name: holds $(ls -A "$tmp" | tr '\n' ' ')instead of only PapoReto.app" >&2; exit 1; }
app="$tmp/PapoReto.app"

failed=0
fail() { echo "$name: $1" >&2; failed=1; }

plist_version=$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$app/Contents/Info.plist")
[ "$plist_version" = "$version" ] || fail "Info.plist says version $plist_version"

for image in "$app/Contents/MacOS/"* "$app/Contents/Frameworks/"*.dylib; do
  [ "$(lipo -archs "$image")" = "$arch" ] || fail "$(basename "$image") is $(lipo -archs "$image"), not $arch"
  # Captured: grep -q exiting early would SIGPIPE codesign and fail the pipeline.
  signature=$(codesign -dv "$image" 2>&1)
  grep -qx 'Signature=adhoc' <<< "$signature" || fail "$(basename "$image") is not signed ad-hoc"
done
for notice in THIRD_PARTY_NOTICES.md sherpa-onnx-LICENSE.txt onnxruntime-ThirdPartyNotices.txt; do
  [ -s "$app/Contents/Resources/$notice" ] || fail "no $notice in Contents/Resources"
done
codesign --verify --strict --deep "$app" || fail "the signature does not verify"
"$(dirname "$0")/check-bundle.sh" "$app" || fail "the bundle loads dylibs from outside it"
exit $failed
