# Papo Reto

Voice dictation for macOS, focused on Brazilian Portuguese (PT-BR), 100% local. Hold `Fn`, speak, release: the text appears at the cursor.

In development: holding `Fn` for more than 300 ms records the microphone chosen in the menu bar (Microphone → System Default or a device; the choice is saved, and while that device is unplugged the system default records), and on release the transcribed text is pasted at the cursor with Cmd+V. Your previous clipboard comes back 250 ms later, except a password from a password manager, which is left out. Clipboard managers that honor `org.nspasteboard.TransientType` skip the dictation. With no text field in focus, the dictation is lost. For longer dictation, double-tap `Fn` (second press within 400 ms of releasing the first) to record hands-free; the next `Fn` press stops and pastes. `Esc`, or any key pressed while `Fn` is held (arrows, F1-F12), cancels the recording and nothing is pasted; the `Esc` still reaches the focused app. A recording stops by itself at 2 minutes, with a sound, and is transcribed whole. After a long dictation (from ~20 s) the model reloads to give its memory back (hourglass icon for a few seconds); a press while the model is loading is transcribed once it is ready.

The first launch asks for Accessibility (to read the `Fn` key and send Cmd+V; `Fn` works as soon as you grant it) and, on the first dictation, for the Microphone. Until Accessibility is granted, the menu's "Allow Accessibility…" opens its settings. Set System Settings → Keyboard → "Press 🌐 key to" → "Do Nothing", or macOS also acts on `Fn`.

## Install
Building from source (below) is the recommended path. To use a prebuilt app, download from [Releases](https://github.com/ewerttonbravo/papo-reto/releases) the zip for your Mac: `arm64` for Apple silicon (M1 and later), `x86_64` for Intel (Apple menu → About This Mac). Unzip it and move `PapoReto.app` to Applications. Requires macOS 13+.

The app is not notarized by Apple, so macOS blocks its first launch. Open it once, then click "Open Anyway" in System Settings → Privacy & Security; or run:

```sh
xattr -dr com.apple.quarantine /Applications/PapoReto.app
```

macOS ties the permissions to the app's signature, and the prebuilt app is signed ad-hoc, so each new version counts as a new app and asks for Accessibility and the Microphone again; the app clears its old Accessibility record itself.

## Build and run
Requires macOS 13+ and the Command Line Tools (`xcode-select --install`) or Xcode.

```sh
make test   # tests + 100% line coverage on PapoRetoCore
scripts/fetch-deps.sh model  # Parakeet TDT 0.6B v3 int8 (~670 MB, SHA-256 checked) for the bench; the app downloads it itself
make install  # builds the app and installs it in /Applications, quitting and reopening a running one
make app    # builds build/PapoReto.app for local use
make release  # ad-hoc zips for arm64 and x86_64 in build/release, each checked by scripts/check-release.sh
make run    # builds and opens the app
```

Optional, once per Mac: `scripts/dev-cert.sh` creates a free self-signed certificate, "Papo Reto Dev", in your login keychain (macOS asks for your password to trust it for code signing). `make app` and `make install` then sign with it, and the Microphone and Accessibility permissions survive rebuilds. Without it, they sign ad-hoc and macOS asks for them again after each build.

On the first launch the app downloads the model (671 MB, from Hugging Face, the only network use) with the progress in the menu, and checks each file's SHA-256. At every launch it checks the file sizes and downloads again any file that is missing or truncated; an interrupted file starts over. If the download fails, the menu offers Retry. `make test` and `make app` download the prebuilt [sherpa-onnx](https://github.com/k2-fsa/sherpa-onnx) libs into `vendor/`, checking their SHA-256.

## Benchmark
```sh
make bench BENCH_AUDIO=<dir with WAVs>  # text, latency and RAM per file, 3 runs
```

`make bench` fails unless 2 of the 3 runs stay within the performance budget (model load, slowest file per 10 s of speech, final memory footprint).

The model is [NVIDIA Parakeet TDT 0.6B v3](https://huggingface.co/nvidia/parakeet-tdt-0.6b-v3) (CC-BY-4.0), in the int8 export by sherpa-onnx.

## License
MIT. See [LICENSE](LICENSE). The bundled libraries and the model keep their own licenses: see [THIRD_PARTY_NOTICES.md](Resources/THIRD_PARTY_NOTICES.md).
