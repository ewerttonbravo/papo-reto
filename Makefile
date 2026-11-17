CLT := /Library/Developer/CommandLineTools
# The Command Line Tools ship Swift Testing, but swift test cannot find it on its own.
ifeq ($(shell xcode-select -p),$(CLT))
TESTING_FLAGS := -Xswiftc -F$(CLT)/Library/Developer/Frameworks \
	-Xlinker -rpath -Xlinker $(CLT)/Library/Developer/Frameworks \
	-Xlinker -rpath -Xlinker $(CLT)/Library/Developer/usr/lib
endif

SHERPA_LIB := vendor/sherpa-onnx/lib

$(SHERPA_LIB):
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

.PHONY: app run
app:
	swift build -c release --product PapoReto
	rm -rf build/PapoReto.app
	mkdir -p build/PapoReto.app/Contents/MacOS
	cp "$$(swift build -c release --show-bin-path)/PapoReto" build/PapoReto.app/Contents/MacOS/
	cp Resources/Info.plist build/PapoReto.app/Contents/
	codesign --force --sign - build/PapoReto.app

run: app
	open build/PapoReto.app
