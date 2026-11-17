# Papo Reto

Voice dictation for macOS, focused on Brazilian Portuguese (PT-BR), 100% local. Hold `Fn`, speak, release: the text appears at the cursor.

In development: for now the app only shows up in the menu bar.

## Build and run
Requires macOS 13+ and the Command Line Tools (`xcode-select --install`) or Xcode.

```sh
make test   # tests + 100% line coverage on PapoRetoCore
make app    # builds build/PapoReto.app for local use
make run    # builds and opens the app
```

## License
MIT. See [LICENSE](LICENSE).
