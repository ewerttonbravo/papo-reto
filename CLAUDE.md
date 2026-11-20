# Papo Reto — CLAUDE.md

## Product
Voice dictation for macOS, focused on PT-BR, 100% local and open source (MIT). Hold `Fn`, speak, release: the text appears at the cursor. A free alternative to Wispr Flow, inspired by [Arara](https://github.com/davimatosms/Arara-voice), but native and lightweight.

MVP: menu bar (no Dock, no window), icon per state (loading / ready / recording / transcribing), menu with microphones and "Quit". Out of scope without an explicit request: Windows/Linux, cloud, model switching, history, dictionary, themes, live preview, auto-update, onboarding, configurable shortcut.

## Principles
1. **Brutally simple.** A new feature must justify its existence. When in doubt, leave it out.
2. **Light wherever possible.** The model stays resident (ADR-003); apart from that, ~0% idle CPU, no polling timer, microphone off outside recording.
3. **Local.** Audio and text never leave the machine; the only network use is the model download (ADR-002).
4. **Minimal configuration.** The only setting is the microphone.
5. **Intel first.** Reference Mac: i5-1038NG7 (4 cores, AVX-512, 16 GB, macOS 26). Measure on it before Apple Silicon.

## Two repos (ADR-007)
- `papo-reto` (this one): code, `README.md` and agent tooling (`CLAUDE.md`, `.claude/`, `scripts/`). A task PR carries no docs besides the README.
- `../papo-reto-docs`: [state](../papo-reto-docs/estado.md), [task roadmap](../papo-reto-docs/roadmap.md), [ADRs and trade-offs](../papo-reto-docs/README.md), task plans (`tasks/NN-name.md`), `notes/linkedin/` (outside git). Push straight to `main`.
- Read `../papo-reto-docs/estado.md` at the start of every session.

## Memory curation
- New ADR in `../papo-reto-docs/decisions/` when there is a choice between ≥ 2 real alternatives, something tested and discarded, or a decision by Mr. Bravo that restricts scope or direction. Format: Status/date · Context · Decision · Discarded alternatives · Accepted cost · Consequences · Evidence. ≤ ~30 lines.
- An ADR is immutable: changing a decision = new ADR "supersedes ADR-00X", and the old one becomes "superseded". Update the index and the trade-off table in `../papo-reto-docs/README.md`.
- Every accepted cost becomes a row in the trade-off table (type Design or Constraint, why, future path).
- `estado.md` is overwritten at the end of each block of work; it never becomes a log.
- When closing each task or relevant session: note in `../papo-reto-docs/notes/linkedin/NN-name.md` in the format of the README there, with verified facts only.
- Memory keeps only collaboration preferences; project facts go to the repos. Commit at each milestone, with the why.
- Say it in 1 line when recording ("Recorded ADR-009: ..."). This file ≤ 110 lines; the excess moves down to `../papo-reto-docs`.
- Automatic via `.claude/hooks/curadoria.sh`: injects the state at session start and forces the check at the end of a turn with uncommitted changes (at most once every 30 min).

## Stack
Swift 6 · AppKit · SwiftPM (no Xcode project, no SwiftUI, no third-party Swift dependencies) · Swift Testing · sherpa-onnx (C API, prebuilt libs pinned by SHA-256) · Parakeet TDT 0.6B v3 int8 (ADR-003) · Silero VAD bundled in the `.app` (ADR-020) · macOS 13+ · per-architecture release (ADR-006).

## Architecture
| Target | Contents | May import |
|---|---|---|
| `PapoRetoCore` | Pure logic: state machine, `Fn` gesture (injected clock), silence discarding, SHA-256 verification, final text, ports (protocols) | Foundation only |
| `PapoReto` | App + thin adapters: `StatusMenu`, `FnKeyMonitor` (CGEventTap), `AudioRecorder` (AVAudioEngine), `AudioDevices` (Core Audio), `ModelStore` (download), `Paster` | anything + Core |
| `PapoRetoSherpa` | `Transcriber` (sherpa), shared by the app and the bench; `SpeechDetector` (Silero VAD) | `CSherpaOnnx` |
| `papo-reto-bench` | CLI: text, latency and RAM per WAV, budget verdict | `PapoRetoCore`, `PapoRetoSherpa`, `CSherpaOnnx` (WAV reader) |
| `CSherpaOnnx` | module map for `vendor/sherpa-onnx/include/c-api.h` | — |

The compiler prevents the Core from importing the app. Every state transition goes through the Core state machine; no adapter changes state on its own.

## Known pitfalls
- **Model:** loads in the background when the app opens; reuse the `OfflineRecognizer` and create one stream per transcription; when the footprint after a transcription reaches 900 MB the app destroys it and loads a new one (destroy first: both at once peak at ~2.4 GB), since it keeps the RAM of the longest audio it saw (app: 28.5 s → 1,005 MB); `num_threads` = `hw.physicalcpu`. Files in `~/Library/Application Support/PapoReto/Models/parakeet-tdt-0.6b-v3-int8/`; the app downloads missing or truncated files (`ModelStore`, manifest in the Core) and the bench gets them from `scripts/fetch-deps.sh model` (same SHA-256 pins, kept in both). The launch checks sizes only: CryptoKit/CommonCrypto skip the Intel SHA instructions, so hashing the encoder takes 2.3-2.6 s (openssl: ~1 s); the SHA-256 runs after each download and on Retry (a same-size corrupt file would fail again). An `Fn` press before a load finishes records normally and transcribes when the model is ready. Recording stops by itself at 2 min (sound + transcribes it whole). After each load the app calls `malloc_zone_pressure_relief(nil, 0)` (609-692 → 450 MB); not in `Transcriber`, where it pushed the bench to 899 MB (ADR-012).
- **Audio:** the engine runs only while recording. The microphone is selected with `kAudioOutputUnitProperty_CurrentDevice` and persisted by UID, falling back to the default if the device disappears. Convert to 16 kHz mono Float32 in memory, never on disk. Recorded audio < 0.4 s skips the model (it makes words up: 0.35 s → "It was"); longer audio goes to the model only if the Silero VAD finds speech (noise → "Yeah."). The detector is created per dictation (~50 ms, no RAM at rest) and stops at the first speech; without it (`swift run`) everything is transcribed. Sounds: Bottle once the dictation is confirmed (Fn held past 300 ms, or hands-free begins), Pop on every stop to transcribe (the 2 min limit too), cancels silent. The microphone records the start sound: in the T13 spike Bottle was the only system sound that kept the first word (Tink, Pop, Purr turned "Crie" into "Tem um").
- **Fn:** CGEventTap on `flagsChanged` + `keyDown` (`.maskSecondaryFn`). Start recording on keydown and discard if it was a short tap. Fn+key cancels: the Core decides from `keyPressed(isEscape:)` (recording means Fn is held; arrows and F-keys carry `.maskSecondaryFn` without Fn); with standard F-keys on, Fn+F1 arrives as a media key (NX_SYSDEFINED). Time Fn from `NSEvent.timestamp`: handling runs late after a cold microphone start, and the raw CGEvent unit differs on Apple Silicon. Double tap = second press < 400 ms after the tap's release. Re-enable after `tapDisabledByTimeout`. Tell the user: "Press 🌐 key to" ("Pressionar tecla 🌐 para") → "Do Nothing" ("Não fazer nada").
- **Paste:** save the whole pasteboard, write with `org.nspasteboard.TransientType`, send Cmd+V via CGEvent and restore after ~250 ms.
- **Permissions:** TCC ties the permission to the signature. Ad-hoc resets on every build, so development uses the self-signed certificate "Papo Reto Dev" (ADR-006). A record from another signature stays on in the list while tccd denies it without asking, so an untrusted launch runs `tccutil reset Accessibility` on our bundle, then prompts; `FnKeyMonitor` never prompts. Granting posts `com.apple.accessibility.api` once, ~5 ms before tccd records it: the app retries the tap then and 1 s later, and on each menu opening.
- **WAV:** the sherpa reader rejects `WAVE_FORMAT_EXTENSIBLE` (what `afconvert` writes); convert reference audio with `ffmpeg -ac 1 -ar 16000 -c:a pcm_s16le`.
- **Language:** v3 detects the language on its own and was trained with more European Portuguese; watch for short phrases coming out in Spanish.

## Performance budget (measure on the reference Mac)
| Metric | Target |
|---|---|
| Physical footprint with the model, idle after a transcription | < 900 MB (T01: 460 MB after load, 889 MB after ≤ 28 s clips; longer audio keeps it higher, 103 s → 1.9 GB, so the app recreates the recognizer at 900 MB) |
| Idle CPU | ~0% |
| Release `Fn` → text pasted, 10 s of speech | < 1.5 s (sherpa measured: 0.8 s) |
| Model load at launch | < 5 s, in the background, without freezing the menu bar |
| `.app` per architecture, without the model | < 45 MB |

## Process (ADR-008)
- **Tasks**: roadmap in `../papo-reto-docs/roadmap.md`; each task runs through the `/task` skill (next in sequence, or `/task NN`; elucidate → TDD → PR). 1 observable behavior, diff ≤ ~200 lines with tests.
- **TDD**: red → green → refactor, one cycle per behavior, test always first.
- **KISS/DRY**: the minimal solution that passes the test; abstraction only on the 2nd real use.
- Core tests: Swift Testing, pure unit tests, in-memory fakes, test name = rule (`fnHeldOver300msStartsPushToTalk`). No sleep: injected clock.
- Adapters: no wiring tests. Validation by the manual checklist in the task plan and by `make bench`.

## Gates
- `make test`: `swift test` + 100% line coverage on `PapoRetoCore` (llvm-cov), failing the build below that.
- `make bench` (task that touches audio or the model): text, latency and RAM of the reference WAVs; 3 runs, fails unless 2 stay within budget (load, slowest file, final footprint). Measure with Colima stopped: with it running the footprint jumps to 1,052-1,126 MB.
- CI (GitHub Actions, macOS): `make test`.

## Commands
`make test` · `make test FILTER=<Test>` (one test, no coverage; with the CLT, plain `swift test` cannot find Swift Testing) · `make app` (assembles the `.app` with the sherpa dylibs in `Contents/Frameworks`, swaps the `vendor/` rpath for it, signs and runs `scripts/check-bundle.sh`) · `make run` · `make install` (quits a running instance, copies to `/Applications` and opens) · `make bench` (real WAVs from `BENCH_AUDIO`, default `../papo-reto-docs/bench/audio`) · `make release` (ad-hoc zips for arm64, cross-compiled, and x86_64 in `build/release`, each through `scripts/check-release.sh`; the arm64 one is untested until run on Apple Silicon).

## Conventions
- Everything in this repo is in English: code, names, comments, UI, README, commits and PRs. `../papo-reto-docs` stays in PT-BR.
- `os.Logger` with subsystem `papo-reto`; never log the transcribed text.
- A new dependency only after discussion: each one costs RAM, size and breakage surface.
- A change that affects the budget brings the before/after measurement in the PR.
