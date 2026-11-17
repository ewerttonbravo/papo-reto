CLT := /Library/Developer/CommandLineTools
# The Command Line Tools ship Swift Testing, but swift test cannot find it on its own.
ifeq ($(shell xcode-select -p),$(CLT))
TESTING_FLAGS := -Xswiftc -F$(CLT)/Library/Developer/Frameworks \
	-Xlinker -rpath -Xlinker $(CLT)/Library/Developer/Frameworks \
	-Xlinker -rpath -Xlinker $(CLT)/Library/Developer/usr/lib
endif

SHERPA_ARCH := $(if $(filter x86_64,$(shell uname -m)),x64,arm64)
SHERPA_LIB := vendor/sherpa-onnx/lib/.$(SHERPA_ARCH)

$(SHERPA_LIB): scripts/fetch-deps.sh
	scripts/fetch-deps.sh libs

.PHONY: test
test: $(SHERPA_LIB)
ifdef FILTER
	swift test $(TESTING_FLAGS) --filter '$(FILTER)'
else
	swift test $(TESTING_FLAGS) --enable-code-coverage
	@BIN=$$(swift build --show-bin-path); \
	xcrun llvm-cov report "$$BIN/PapoRetoPackageTests.xctest/Contents/MacOS/PapoRetoPackageTests" \
		-instr-profile "$$BIN/codecov/default.profdata" Sources/PapoRetoCore \
	| awk '/^TOTAL/ { ok = 1; print "PapoRetoCore line coverage: " $$10 " (" $$9 " untested lines)"; \
		if ($$9 != 0) { print "Gate: the Core needs 100% line coverage."; exit 1 } } \
		END { if (!ok) { print "Gate: coverage report not found."; exit 1 } }'
endif

BENCH_AUDIO ?= ../papo-reto-docs/bench/audio
BENCH_PHRASE := Bom dia, pessoal. Hoje eu quero falar sobre como a inteligência artificial pode ajudar \
	pequenas empresas a vender mais, sem gastar muito com ferramentas caras.

.PHONY: bench
bench: $(SHERPA_LIB)
	swift build -c release --product papo-reto-bench
	@ls "$(BENCH_AUDIO)"/*.wav >/dev/null 2>&1 || { echo "No WAVs in BENCH_AUDIO=$(BENCH_AUDIO)"; exit 1; }
	mkdir -p build
	say -v Luciana -o build/luciana.wav --data-format=LEI16@16000 "$(BENCH_PHRASE)"
	@# Latency jumps with CPU bursts from other apps (0.8 -> 2.8 s per 10 s on the same WAVs), so the majority of 3 decides.
	@BIN="$$(swift build -c release --show-bin-path)/papo-reto-bench"; pass=0; \
	for run in 1 2 3; do \
		echo "== run $$run/3"; \
		"$$BIN" build/luciana.wav "$(BENCH_AUDIO)"/*.wav; code=$$?; \
		if [ $$code -eq 0 ]; then pass=$$((pass + 1)); elif [ $$code -ne 3 ]; then exit $$code; fi; \
	done; \
	echo "== $$pass/3 runs within budget"; [ $$pass -ge 2 ]

.PHONY: app run
app: $(SHERPA_LIB)
	swift build -c release --product PapoReto
	rm -rf build/PapoReto.app
	mkdir -p build/PapoReto.app/Contents/MacOS
	cp "$$(swift build -c release --show-bin-path)/PapoReto" build/PapoReto.app/Contents/MacOS/
	cp Resources/Info.plist build/PapoReto.app/Contents/
	codesign --force --sign - build/PapoReto.app

run: app
	open build/PapoReto.app
