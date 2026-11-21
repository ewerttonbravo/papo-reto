#!/bin/bash
# make win-bench: the C# bench on the Windows test notebook, 3 runs, text checked against the Mac bench (ADR-028).
# usage: scripts/win-bench.sh <Mac papo-reto-bench> <wav>...   env: DOTNET, WIN_HOST, WIN_KEY
set -euo pipefail
mac_bench=$1; shift
model="$HOME/Library/Application Support/PapoReto/Models/parakeet-tdt-0.6b-v3-int8"
out=build/windows/bench
bench=$out/papo-reto-bench

win() { ssh -q -o ConnectTimeout=10 -i "$WIN_KEY" "$WIN_HOST" "$@"; }
# Encoded, so no quoting goes through cmd; the console speaks CP850.
winps() {
	win "powershell -NoProfile -EncodedCommand $(printf '%s' "\$ProgressPreference='SilentlyContinue'; $1" | iconv -t UTF-16LE | base64)" \
		| iconv -f CP850 | tr -d '\r'
}

rm -rf "$out"
"$DOTNET" publish windows/PapoReto.Bench -c Release -r win-x64 --self-contained -o "$bench"
echo "== Mac reference"
"$mac_bench" "$@" | tee "$bench/mac.txt" || [ "${PIPESTATUS[0]}" -eq 3 ]  # 3 = over the Mac budget; the text still counts
mkdir "$bench/audio"
cp "$@" "$bench/audio/"
(cd "$out" && zip -qr bench.zip papo-reto-bench)

IFS='|' read -r home appdata < <(winps 'Write-Output "$env:USERPROFILE|$env:LOCALAPPDATA"') || true
# DHCP moves the notebook: arp -a | grep -i 64:32:a8, then WIN_HOST=icmsa@<ip>.
[ -n "${appdata:-}" ] || { echo "Cannot reach $WIN_HOST"; exit 1; }
remote_model="$appdata\\PapoReto\\Models\\parakeet-tdt-0.6b-v3-int8"
# The model stays on the notebook, which the next tasks reuse; only missing or resized files go over the failing disk.
sizes=$(for f in encoder.int8.onnx decoder.int8.onnx joiner.int8.onnx tokens.txt; do
	printf "@('%s',%s)," "$f" "$(stat -f %z "$model/$f")"; done)
missing=$(winps "New-Item -ItemType Directory -Force '$remote_model' | Out-Null
foreach (\$e in @(${sizes%,})) { \$p = Join-Path '$remote_model' \$e[0]
	if (-not (Test-Path \$p) -or (Get-Item \$p).Length -ne \$e[1]) { \$e[0] } }")
for f in $missing; do
	echo "== copying the model's $f"
	scp -q -i "$WIN_KEY" "$model/$f" "$WIN_HOST:${remote_model//\\//}/$f"
done

echo "== copying the bench ($(du -h "$out/bench.zip" | cut -f1))"
scp -q -i "$WIN_KEY" "$out/bench.zip" "$WIN_HOST:${home//\\//}/PapoReto-bench.zip"
wavs=$(for w in "$@"; do printf "'audio\\%s'," "$(basename "$w")"; done)
# In a variable, so PowerShell passes one argument per WAV, not "a,b,c".
winps "\$dir = '$home\\PapoReto-bench'; \$failed = 0; \$wavs = @(${wavs%,})
try {
	Expand-Archive -Force '$home\\PapoReto-bench.zip' \$dir
	Set-Location \$dir\\papo-reto-bench
	foreach (\$run in 1..3) {
		Write-Output \"== run \$run/3\"
		& .\\papo-reto-bench.exe --reference mac.txt \$wavs
		if (\$LASTEXITCODE -ne 0) { \$failed++ }
	}
} finally {
	Set-Location '$home'
	Remove-Item -Recurse -Force \$dir, '$home\\PapoReto-bench.zip' -ErrorAction SilentlyContinue
}
Write-Output \"== \$(3 - \$failed)/3 runs with the Mac's text\"
exit \$failed"
