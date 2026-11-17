# Papo Reto

Voice dictation for macOS, focused on Brazilian Portuguese (PT-BR), 100% local. Hold `Fn`, speak, release: the text appears at the cursor.

In development: for now the app loads the model in the background and its menu bar icon goes from loading (hourglass) to ready (mic); dictation is not wired yet.

## Build and run
Requires macOS 13+ and the Command Line Tools (`xcode-select --install`) or Xcode.

```sh
make test   # tests + 100% line coverage on PapoRetoCore
scripts/fetch-deps.sh model  # Parakeet TDT 0.6B v3 int8 (~670 MB, SHA-256 checked), needed by the app and the bench
make app    # builds build/PapoReto.app for local use
make run    # builds and opens the app
```

Without the model the menu bar shows a warning icon and the menu says how to fetch it. `make test` and `make app` download the prebuilt [sherpa-onnx](https://github.com/k2-fsa/sherpa-onnx) libs into `vendor/`, checking their SHA-256.

## Benchmark
```sh
make bench BENCH_AUDIO=<dir with WAVs>  # text, latency and RAM per file, 3 runs
```

`make bench` fails unless 2 of the 3 runs stay within the performance budget (model load, slowest file per 10 s of speech, final memory footprint).

The model is [NVIDIA Parakeet TDT 0.6B v3](https://huggingface.co/nvidia/parakeet-tdt-0.6b-v3) (CC-BY-4.0), in the int8 export by sherpa-onnx.

## License
MIT. See [LICENSE](LICENSE).
