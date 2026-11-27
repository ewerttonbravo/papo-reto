#!/bin/bash
# Fails unless a Windows release zip (PapoReto-<version>-win-x64.zip) holds only the PapoReto folder,
# with an x64 PapoReto.exe built at <version>, the libs it transcribes with, the VAD, the third-party notices and the tray icons.
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

# The app and the native libs it loads to transcribe; /usr/bin/file, since newer ones word PE types differently.
for image in PapoReto.exe sherpa-onnx-c-api.dll onnxruntime.dll; do
  kind=$(/usr/bin/file -b "$app/$image" 2>&1) || true
  [[ "$kind" == PE32+* && "$kind" == *x86-64* ]] || fail "$image is not x64 Windows code ($kind)"
done
# The publish writes the assembly version into its deps file as "PapoReto/<version>".
grep -qF "\"PapoReto/$version\"" "$app/PapoReto.deps.json" 2>/dev/null || fail "PapoReto.deps.json is not at version $version"
for file in sherpa-onnx.dll NAudio.Core.dll NAudio.Wasapi.dll silero_vad.onnx \
  THIRD_PARTY_NOTICES.md sherpa-onnx-LICENSE.txt onnxruntime-ThirdPartyNotices.txt dotnet-LICENSE.txt dotnet-THIRD-PARTY-NOTICES.txt; do
  [ -s "$app/$file" ] || fail "no $file next to PapoReto.exe"
done
# The tray's profile in both inks (W12); /usr/bin/file names the format.
for state in ready listening thinking; do
  for ink in white black; do
    icon="tray-$state-$ink.ico"
    [[ "$(/usr/bin/file -b "$app/$icon" 2>&1)" == "MS Windows icon resource"* ]] || fail "$icon is not a Windows icon next to PapoReto.exe"
  done
done
exit $failed
