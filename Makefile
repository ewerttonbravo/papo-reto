CLT := /Library/Developer/CommandLineTools
# As Command Line Tools trazem o Swift Testing, mas o swift test não o encontra sozinho.
ifeq ($(shell xcode-select -p),$(CLT))
TESTING_FLAGS := -Xswiftc -F$(CLT)/Library/Developer/Frameworks \
	-Xlinker -rpath -Xlinker $(CLT)/Library/Developer/Frameworks \
	-Xlinker -rpath -Xlinker $(CLT)/Library/Developer/usr/lib
endif

.PHONY: test
test:
ifdef FILTER
	swift test $(TESTING_FLAGS) --filter $(FILTER)
else
	swift test $(TESTING_FLAGS) --enable-code-coverage
	@BIN=$$(swift build --show-bin-path); \
	xcrun llvm-cov report "$$BIN/PapoRetoPackageTests.xctest/Contents/MacOS/PapoRetoPackageTests" \
		-instr-profile "$$BIN/codecov/default.profdata" Sources/PapoRetoCore \
	| awk '/^TOTAL/ { ok = 1; print "Cobertura de linha do PapoRetoCore: " $$10; \
		if ($$10 != "100.00%") { print "Gate: o Core precisa de 100% de linha."; exit 1 } } \
		END { if (!ok) { print "Gate: relatório de cobertura não encontrado."; exit 1 } }'
endif
