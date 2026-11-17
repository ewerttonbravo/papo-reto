CLT := /Library/Developer/CommandLineTools
# As Command Line Tools trazem o Swift Testing, mas o swift test não o encontra sozinho.
ifeq ($(shell xcode-select -p),$(CLT))
TESTING_FLAGS := -Xswiftc -F$(CLT)/Library/Developer/Frameworks \
	-Xlinker -rpath -Xlinker $(CLT)/Library/Developer/Frameworks \
	-Xlinker -rpath -Xlinker $(CLT)/Library/Developer/usr/lib
endif

.PHONY: test
test:
	swift test $(TESTING_FLAGS) $(if $(FILTER),--filter $(FILTER))
