CLT := /Library/Developer/CommandLineTools
# The Command Line Tools ship Swift Testing, but swift test cannot find it on its own.
ifeq ($(shell xcode-select -p),$(CLT))
TESTING_FLAGS := -Xswiftc -F$(CLT)/Library/Developer/Frameworks \
	-Xlinker -rpath -Xlinker $(CLT)/Library/Developer/Frameworks \
	-Xlinker -rpath -Xlinker $(CLT)/Library/Developer/usr/lib
endif

SHERPA_ARCH := $(if $(filter x86_64,$(shell uname -m)),x64,arm64)
SHERPA_LIB := vendor/sherpa-onnx/lib/.$(SHERPA_ARCH)

VAD_MODEL := vendor/silero-vad/silero_vad.onnx
# What the app loads; the cxx-api stays out.
BUNDLED_LIBS := $(addprefix vendor/sherpa-onnx/lib/,libsherpa-onnx-c-api.dylib libonnxruntime.dylib)

# One rule after the other, never two fetches at once (make -j); touch, since fetch skips files it has.
$(SHERPA_LIB): scripts/fetch-deps.sh
	scripts/fetch-deps.sh libs
	@touch $@
$(VAD_MODEL): $(SHERPA_LIB)
	scripts/fetch-deps.sh libs
	@touch $@

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

# scripts/dev-cert.sh creates it; ad-hoc otherwise, which resets the TCC permissions on every build.
DEV_CERT ?= Papo Reto Dev

.PHONY: app run
app: $(SHERPA_LIB) $(VAD_MODEL)
	swift build -c release --product PapoReto
	rm -rf build/PapoReto.app
	mkdir -p build/PapoReto.app/Contents/MacOS
	cp "$$(swift build -c release --show-bin-path)/PapoReto" build/PapoReto.app/Contents/MacOS/
	cp Resources/Info.plist build/PapoReto.app/Contents/
	mkdir -p build/PapoReto.app/Contents/Resources
	cp $(VAD_MODEL) build/PapoReto.app/Contents/Resources/
	mkdir -p build/PapoReto.app/Contents/Frameworks
	cp $(BUNDLED_LIBS) build/PapoReto.app/Contents/Frameworks/
	@# The repo's vendor/ rpath would hide a broken bundle on this Mac.
	install_name_tool -delete_rpath "$(CURDIR)/vendor/sherpa-onnx/lib" \
		-add_rpath @executable_path/../Frameworks build/PapoReto.app/Contents/MacOS/PapoReto
	@ID=$$(DEV_CERT='$(DEV_CERT)' scripts/dev-cert.sh --identity); \
	if [ -n "$$ID" ]; then echo "Signing with \"$(DEV_CERT)\" ($$ID)"; \
	else ID=-; echo "Signing ad-hoc: no \"$(DEV_CERT)\" identity, so TCC permissions reset (run scripts/dev-cert.sh)"; fi; \
	codesign --force --sign "$$ID" build/PapoReto.app/Contents/Frameworks/*.dylib && \
	codesign --force --sign "$$ID" build/PapoReto.app
	scripts/check-bundle.sh build/PapoReto.app

run: app
	open build/PapoReto.app

INSTALL_DIR ?= /Applications

# Also quits a make run instance: two event taps would paste every dictation twice.
.PHONY: install
install: app
	@# Copied aside first, so a failed copy keeps the installed app.
	rm -rf "$(INSTALL_DIR)/.PapoReto.app.tmp"
	ditto build/PapoReto.app "$(INSTALL_DIR)/.PapoReto.app.tmp"
	@# Only this user's instance: another logged-in user's cannot be signalled and does not block.
	@pkill -u "$$(id -u)" -x PapoReto && echo "Quitting the running Papo Reto"; \
	for i in $$(seq 50); do pgrep -u "$$(id -u)" -x PapoReto >/dev/null || exit 0; sleep 0.1; done; \
	echo "Papo Reto did not quit; quit it from the menu bar and run make install again"; exit 1
	rm -rf "$(INSTALL_DIR)/PapoReto.app"
	mv "$(INSTALL_DIR)/.PapoReto.app.tmp" "$(INSTALL_DIR)/PapoReto.app"
	open "$(INSTALL_DIR)/PapoReto.app"
