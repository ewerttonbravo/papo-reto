#!/bin/bash
# Downloads the pinned sherpa-onnx libs (libs) or the Parakeet model (model), verifying SHA-256.
set -euo pipefail

SHERPA=v2.0.1
SHERPA_URL=https://github.com/k2-fsa/sherpa-onnx
MODEL_URL=https://huggingface.co/csukuangfj/sherpa-onnx-nemo-parakeet-tdt-0.6b-v3-int8/resolve/ed5d745623472f97cfc2e6c2916ee248798fc5a8
MODEL_DIR="$HOME/Library/Application Support/PapoReto/Models/parakeet-tdt-0.6b-v3-int8"
VENDOR="$(cd "$(dirname "$0")/.." && pwd)/vendor/sherpa-onnx"

# fetch <url> <sha256> <dest>: skips an existing dest; never leaves an unverified file behind.
fetch() {
  [ -f "$3" ] && return
  mkdir -p "$(dirname "$3")"
  echo "Downloading $(basename "$3")"
  curl -fL --progress-bar -o "$3.part" "$1"
  if [ "$(shasum -a 256 "$3.part" | cut -d' ' -f1)" != "$2" ]; then
    rm -f "$3.part"
    echo "SHA-256 mismatch for $1" >&2
    exit 1
  fi
  mv "$3.part" "$3"
}

case "${1:-}" in
libs)
  case "$(uname -m)" in
  x86_64) arch=x64 sha=b0107b8166c4131245380bc9b984345c4ea8637c65807f09ca5f501c72926be5 ;;
  arm64) arch=arm64 sha=ac5594ad237db56ec4a6c4b3fc48700441b33a07bb71c235f35530a52a93f2e3 ;;
  esac
  name=sherpa-onnx-$SHERPA-osx-$arch-shared-no-tts-lib
  fetch "$SHERPA_URL/releases/download/$SHERPA/$name.tar.bz2" "$sha" "$VENDOR/$name.tar.bz2"
  fetch "$SHERPA_URL/raw/$SHERPA/sherpa-onnx/c-api/c-api.h" \
    5698f38ba09ad2bdf085c56a6cbbd7741acf15e25f4ce5c7097b9702cadf437f "$VENDOR/include/c-api.h"
  [ -d "$VENDOR/lib" ] || tar -xjf "$VENDOR/$name.tar.bz2" -C "$VENDOR" --strip-components 1 "$name/lib"
  ;;
model)
  fetch "$MODEL_URL/encoder.int8.onnx" 1afbe69c1ffdabee94755f42e4daf1d93549131a3da11356bda84fcef0f2c479 "$MODEL_DIR/encoder.int8.onnx"
  fetch "$MODEL_URL/decoder.int8.onnx" 0222a86147299d4dee90edf95b6d13827edb42ad8b7c9cf0b2582f030937c0b5 "$MODEL_DIR/decoder.int8.onnx"
  fetch "$MODEL_URL/joiner.int8.onnx" cbd02f3696e9944970111fb439d9c3fd365a80374565f13f2b9c7007d253fc98 "$MODEL_DIR/joiner.int8.onnx"
  fetch "$MODEL_URL/tokens.txt" d58544679ea4bc6ac563d1f545eb7d474bd6cfa467f0a6e2c1dc1c7d37e3c35d "$MODEL_DIR/tokens.txt"
  ;;
*)
  echo "usage: $0 libs|model" >&2
  exit 2
  ;;
esac
