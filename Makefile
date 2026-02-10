.PHONY: build build-release clean test install lint

TEST_FILES := $(wildcard tests/test_*.nim)
.PHONY: $(TEST_FILES)

# Build debug version
build:
	nim c -d:ssl -o:context7 src/context7.nim

# Build optimized release version
build-release:
	nim c -d:release -d:ssl --opt:size -o:context7 src/context7.nim && strip context7

# Clean build artifacts
clean:
	rm -f context7 src/context7
	rm -rf nimcache/ src/nimcache/

# Run tests
test: $(TEST_FILES)
$(TEST_FILES):
	nim c -r $@

# Lint the project
lint:
	nim check src/context7.nim

# Install to /usr/local/bin
install: build-release
	install -m 755 context7 /usr/local/bin/

.DEFAULT_GOAL := build
