# Papo Reto

Voice dictation for macOS, focused on Brazilian Portuguese (PT-BR), 100% local. Hold `Fn`, speak, release: the text appears at the cursor.

In development: holding `Fn` for more than 300 ms records the microphone chosen in the menu bar (Microphone → System Default or a device; the choice is saved, and while that device is unplugged the system default records), and on release the transcribed text is pasted at the cursor with Cmd+V. Your previous clipboard comes back 250 ms later, except a password from a password manager, which is left out. Clipboard managers that honor `org.nspasteboard.TransientType` skip the dictation. With no text field in focus, the dictation is lost. A press while the model is still loading (hourglass icon) is transcribed once it is ready.

The first launch asks for Accessibility (to read the `Fn` key and send Cmd+V; grant it and reopen the app) and, on the first dictation, for the Microphone. Set System Settings → Keyboard → "Press 🌐 key to" → "Do Nothing", or macOS also acts on `Fn`.

## Build and run
Requires macOS 13+ and the Command Line Tools (`xcode-select --install`) or Xcode.

```sh
make test   # tests + 100% line coverage on PapoRetoCore
scripts/fetch-deps.sh model  # Parakeet TDT 0.6B v3 int8 (~670 MB, SHA-256 checked), needed by the app and the bench
make app    # builds build/PapoReto.app for local use
make run    # builds and opens the app
```

Optional, once per Mac: `scripts/dev-cert.sh` creates a free self-signed certificate, "Papo Reto Dev", in your login keychain (macOS asks for your password to trust it for code signing). `make app` then signs with it, and the Microphone and Accessibility permissions survive rebuilds. Without it, `make app` signs ad-hoc and macOS asks for them again after each build.

Without the model the menu bar shows a warning icon and the menu says how to fetch it. `make test` and `make app` download the prebuilt [sherpa-onnx](https://github.com/k2-fsa/sherpa-onnx) libs into `vendor/`, checking their SHA-256.

## Benchmark
```sh
make bench BENCH_AUDIO=<dir with WAVs>  # text, latency and RAM per file, 3 runs
```

`make bench` fails unless 2 of the 3 runs stay within the performance budget (model load, slowest file per 10 s of speech, final memory footprint).

The model is [NVIDIA Parakeet TDT 0.6B v3](https://huggingface.co/nvidia/parakeet-tdt-0.6b-v3) (CC-BY-4.0), in the int8 export by sherpa-onnx.

## License
MIT. See [LICENSE](LICENSE).
