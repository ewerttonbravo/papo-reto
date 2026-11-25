#!/bin/bash
# Fails unless a Windows release zip (PapoReto-<version>-win-x64.zip) holds only the PapoReto folder,
# with an x64 PapoReto.exe built at <version>, the VAD and the third-party notices next to it.
set -euo pipefail

zip="${1:?usage: $0 <PapoReto-version-win-x64.zip>}"
name="$(basename "$zip" .zip)"
[[ "$name" =~ ^PapoReto-(.+)-win-x64$ ]] || { echo "$name: not PapoReto-<version>-win-x64.zip" >&2; exit 1; }
version="${BASH_REMATCH[1]}"

tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT
ditto -x -k "$zip" "$tmp"
[ "$(ls -A "$tmp")" = PapoReto ] || { echo "$name: holds $(ls -A "$tmp" | tr '\n' ' ')instead of only PapoReto" >&2; exit 1; }
app="$tmp/PapoReto"

failed=0
fail() { echo "$name: $1" >&2; failed=1; }

[[ "$(file -b "$app/PapoReto.exe" 2>&1)" == "PE32+ executable (GUI) x86-64"* ]] || fail "PapoReto.exe is not an x64 Windows app"
# The publish writes the assembly version into its deps file as "PapoReto/<version>".
grep -qF "\"PapoReto/$version\"" "$app/PapoReto.deps.json" 2>/dev/null || fail "PapoReto.deps.json is not at version $version"
for file in silero_vad.onnx THIRD_PARTY_NOTICES.md sherpa-onnx-LICENSE.txt onnxruntime-ThirdPartyNotices.txt \
  dotnet-LICENSE.txt dotnet-THIRD-PARTY-NOTICES.txt; do
  [ -s "$app/$file" ] || fail "no $file next to PapoReto.exe"
done
exit $failed
