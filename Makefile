CLT := /Library/Developer/CommandLineTools
# The Command Line Tools ship Swift Testing, but swift test cannot find it on its own.
ifeq ($(shell xcode-select -p 2>/dev/null),$(CLT))
TESTING_FLAGS := -Xswiftc -F$(CLT)/Library/Developer/Frameworks \
	-Xlinker -rpath -Xlinker $(CLT)/Library/Developer/Frameworks \
	-Xlinker -rpath -Xlinker $(CLT)/Library/Developer/usr/lib
endif

NATIVE_ARCH := $(shell uname -m)
# make release builds the other one too; the libs in vendor/ follow it. Not ARCH: other tools export that name.
PAPO_ARCH ?= $(NATIVE_ARCH)
SHERPA_ARCH := $(if $(filter x86_64,$(PAPO_ARCH)),x64,arm64)
SHERPA_LIB := vendor/sherpa-onnx/lib/.$(SHERPA_ARCH)

VAD_MODEL := vendor/silero-vad/silero_vad.onnx
# Fetched last, after the sherpa-onnx LICENSE; copied by name, so a missing one fails make app.
ORT_NOTICES := vendor/notices/onnxruntime-ThirdPartyNotices.txt
NOTICES := Resources/THIRD_PARTY_NOTICES.md vendor/notices/sherpa-onnx-LICENSE.txt $(ORT_NOTICES)
# What the app loads; the cxx-api stays out.
BUNDLED_LIBS := $(addprefix vendor/sherpa-onnx/lib/,libsherpa-onnx-c-api.dylib libonnxruntime.dylib)

# One rule after the other, never two fetches at once (make -j); touch, since fetch skips files it has.
$(SHERPA_LIB): scripts/fetch-deps.sh
	PAPO_ARCH=$(PAPO_ARCH) scripts/fetch-deps.sh libs
	@touch $@
$(VAD_MODEL): $(SHERPA_LIB)
	PAPO_ARCH=$(PAPO_ARCH) scripts/fetch-deps.sh libs
	@touch $@
$(ORT_NOTICES): $(VAD_MODEL)
	PAPO_ARCH=$(PAPO_ARCH) scripts/fetch-deps.sh libs
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
SAY_BENCH_PHRASE = mkdir -p build && say -v Luciana -o build/luciana.wav --data-format=LEI16@16000 "$(BENCH_PHRASE)"

.PHONY: bench
bench: $(SHERPA_LIB)
	swift build -c release --product papo-reto-bench
	@ls "$(BENCH_AUDIO)"/*.wav >/dev/null 2>&1 || { echo "No WAVs in BENCH_AUDIO=$(BENCH_AUDIO)"; exit 1; }
	$(SAY_BENCH_PHRASE)
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
# A codesign identity that overrides DEV_CERT; make release passes - (ad-hoc).
SIGN ?=

.PHONY: app run
# Drawn by the app's own ProfileGlyph.swift, so the menu bar and the app icon never drift apart.
ICON := build/AppIcon.icns
ARTWORK := build/artwork
$(ARTWORK): Sources/PapoReto/ProfileGlyph.swift scripts/artwork.swift
	mkdir -p build
	swiftc -parse-as-library -O $^ -o $@
$(ICON): $(ARTWORK)
	$(ARTWORK) icns $@

# The README and social preview images, committed: run after changing the drawing.
.PHONY: showcase
showcase: $(ARTWORK)
	$(ARTWORK) showcase assets

app: $(SHERPA_LIB) $(VAD_MODEL) $(ORT_NOTICES) $(ICON)
	swift build -c release --arch $(PAPO_ARCH) --product PapoReto
	rm -rf build/PapoReto.app
	mkdir -p build/PapoReto.app/Contents/MacOS
	cp "$$(swift build -c release --arch $(PAPO_ARCH) --show-bin-path)/PapoReto" build/PapoReto.app/Contents/MacOS/
	cp Resources/Info.plist build/PapoReto.app/Contents/
	mkdir -p build/PapoReto.app/Contents/Resources
	cp $(VAD_MODEL) $(NOTICES) $(ICON) build/PapoReto.app/Contents/Resources/
	mkdir -p build/PapoReto.app/Contents/Frameworks
	cp $(BUNDLED_LIBS) build/PapoReto.app/Contents/Frameworks/
	@# The repo's vendor/ rpath would hide a broken bundle on this Mac.
	install_name_tool -delete_rpath "$(CURDIR)/vendor/sherpa-onnx/lib" \
		-add_rpath @executable_path/../Frameworks build/PapoReto.app/Contents/MacOS/PapoReto
	@ID='$(SIGN)'; if [ -z "$$ID" ]; then ID=$$(DEV_CERT='$(DEV_CERT)' scripts/dev-cert.sh --identity); \
	if [ -n "$$ID" ]; then echo "Signing with \"$(DEV_CERT)\" ($$ID)"; \
	else ID=-; echo "Signing ad-hoc: no \"$(DEV_CERT)\" identity, so TCC permissions reset (run scripts/dev-cert.sh)"; fi; fi; \
	codesign --force --sign "$$ID" build/PapoReto.app/Contents/Frameworks/*.dylib && \
	codesign --force --sign "$$ID" build/PapoReto.app
	scripts/check-bundle.sh build/PapoReto.app

run: app
	open build/PapoReto.app

VERSION := $(shell /usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' Resources/Info.plist 2>/dev/null)
OTHER_ARCH := $(if $(filter x86_64,$(NATIVE_ARCH)),arm64,x86_64)

# Ad-hoc, one zip per architecture (ADR-006); this Mac's last, so vendor/ ends with its libs, even after a failure.
# No xattrs in the zip: com.apple.provenance is this Mac's; the signature lives in the files.
.PHONY: release
release:
	@# Only the Mac zips: the win-x64 one from make win-release stays.
	rm -f build/release/PapoReto-*-x86_64.zip build/release/PapoReto-*-arm64.zip
	mkdir -p build/release
	@for arch in $(OTHER_ARCH) $(NATIVE_ARCH); do \
		zip=build/release/PapoReto-$(VERSION)-$$arch.zip; \
		$(MAKE) app PAPO_ARCH=$$arch SIGN=- && \
		ditto -c -k --norsrc --noextattr --noacl --keepParent build/PapoReto.app $$zip && \
		scripts/check-release.sh $$zip && echo "$$zip: $$(du -sh build/PapoReto.app | cut -f1) app" || \
		{ PAPO_ARCH=$(NATIVE_ARCH) scripts/fetch-deps.sh libs; exit 1; }; \
	done

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

# Windows (ADR-027). The SDK may live in ~/.dotnet, off the PATH: brew builds it from source on Intel.
DOTNET ?= $(or $(shell command -v dotnet 2>/dev/null),$(HOME)/.dotnet/dotnet)
export DOTNET_CLI_TELEMETRY_OPTOUT := 1
export DOTNET_NOLOGO := 1

.PHONY: win-test win-app
win-test:
ifdef FILTER
	$(DOTNET) test windows/PapoReto.Core.Tests --filter 'FullyQualifiedName~$(FILTER)'
else
	$(DOTNET) test windows/PapoReto.Core.Tests -p:CollectCoverage=true -p:Include='[PapoReto.Core]*' \
		-p:Threshold=100 -p:ThresholdType=line -p:CoverletOutput='$(CURDIR)/build/windows/'
	@# The tray app and the bench have no tests, but they must still compile.
	$(DOTNET) build windows/PapoReto
	$(DOTNET) build windows/PapoReto.Bench
endif

# Self-contained folder, shipped as is (W09); the version is the Mac's, from Info.plist.
# The Silero VAD goes next to the exe, from the same pin as the Mac's (ADR-020), and so do the notices,
# with the .NET runtime's from the runtime pack the publish used.
win-app: $(VAD_MODEL) $(ORT_NOTICES)
	rm -rf build/windows/PapoReto
	$(DOTNET) publish windows/PapoReto -c Release -r win-x64 --self-contained -p:Version=$(VERSION) -o build/windows/PapoReto
	cp $(VAD_MODEL) $(NOTICES) build/windows/PapoReto/
	@pack="$${NUGET_PACKAGES:-$$HOME/.nuget/packages}/microsoft.netcore.app.runtime.win-x64/$$(grep -o \
		'runtimepack.Microsoft.NETCore.App.Runtime.win-x64/[^"]*' build/windows/PapoReto/PapoReto.deps.json | head -1 | cut -d/ -f2)"; \
	cp "$$pack/LICENSE.TXT" build/windows/PapoReto/dotnet-LICENSE.txt && \
	cp "$$pack/THIRD-PARTY-NOTICES.TXT" build/windows/PapoReto/dotnet-THIRD-PARTY-NOTICES.txt

.PHONY: win-release
win-release: win-app
	mkdir -p build/release
	rm -f build/release/PapoReto-$(VERSION)-win-x64.zip
	ditto -c -k --norsrc --noextattr --noacl --keepParent build/windows/PapoReto build/release/PapoReto-$(VERSION)-win-x64.zip
	scripts/check-win-release.sh build/release/PapoReto-$(VERSION)-win-x64.zip

# On the Windows test notebook (ADR-028): reports numbers, fails only when the text differs from the Mac's.
WIN_HOST ?= icmsa@172.16.0.116
WIN_KEY ?= $(HOME)/.ssh/notebook_win_ed25519

.PHONY: win-bench
win-bench: $(SHERPA_LIB)
	swift build -c release --product papo-reto-bench
	@ls "$(BENCH_AUDIO)"/*.wav >/dev/null 2>&1 || { echo "No WAVs in BENCH_AUDIO=$(BENCH_AUDIO)"; exit 1; }
	$(SAY_BENCH_PHRASE)
	DOTNET='$(DOTNET)' WIN_HOST='$(WIN_HOST)' WIN_KEY='$(WIN_KEY)' scripts/win-bench.sh \
		"$$(swift build -c release --show-bin-path)/papo-reto-bench" build/luciana.wav "$(BENCH_AUDIO)"/*.wav
