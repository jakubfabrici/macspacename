# MacSpaceName — build helpers.
#
#   make build     compile a release binary (current architecture only)
#   make bundle    build a universal MacSpaceName.app into dist/ (ARCHS=arm64 for one arch)
#   make run       bundle + launch
#   make install   bundle + copy into /Applications
#   make test      run the unit tests
#   make zip       bundle + create dist/MacSpaceName-<version>.zip
#   make dmg       bundle + create dist/MacSpaceName-<version>.dmg (drag-to-Applications image)
#   make clean     remove build products

APP        := MacSpaceName
DIST       := dist
APP_DIR    := $(DIST)/$(APP).app
# Architectures of the universal binary. Each one is built with its own --triple
# (the native SwiftPM build system), then merged with lipo. Set ARCHS=arm64 for a quick single-arch build.
ARCHS      ?= arm64 x86_64
VERSION    ?= $(shell git describe --tags --abbrev=0 2>/dev/null | sed 's/^v//')
BUILD      ?= $(shell git rev-list --count HEAD 2>/dev/null)

ifeq ($(VERSION),)
VERSION := 0.0.0
endif
ifeq ($(BUILD),)
BUILD := 1
endif

.PHONY: build bundle run install uninstall test zip dmg clean

build:
	swift build -c release

test:
	swift test

bundle:
	@for arch in $(ARCHS); do \
		echo "==> Building $$arch"; \
		swift build -c release --triple $$arch-apple-macosx || exit 1; \
	done
	rm -rf "$(APP_DIR)"
	mkdir -p "$(APP_DIR)/Contents/MacOS" "$(APP_DIR)/Contents/Resources"
	@binaries=""; \
	for arch in $(ARCHS); do \
		bin="$$(swift build -c release --triple $$arch-apple-macosx --show-bin-path)/$(APP)"; \
		binaries="$$binaries $$bin"; \
	done; \
	echo "==> lipo $$binaries"; \
	lipo -create -output "$(APP_DIR)/Contents/MacOS/$(APP)" $$binaries
	sed -e 's/__VERSION__/$(VERSION)/' -e 's/__BUILD__/$(BUILD)/' Resources/Info.plist > "$(APP_DIR)/Contents/Info.plist"
	printf 'APPL????' > "$(APP_DIR)/Contents/PkgInfo"
	# Ad-hoc signature: required on Apple silicon and keeps the Accessibility grant stable.
	codesign --force --deep --sign - "$(APP_DIR)"
	@echo "Built $(APP_DIR) (version $(VERSION), build $(BUILD))"

run: bundle
	open "$(APP_DIR)"

install: bundle
	rm -rf "/Applications/$(APP).app"
	cp -R "$(APP_DIR)" "/Applications/$(APP).app"
	@echo "Installed /Applications/$(APP).app"

uninstall:
	rm -rf "/Applications/$(APP).app"

zip: bundle
	cd "$(DIST)" && rm -f "$(APP)-$(VERSION).zip" && ditto -c -k --keepParent "$(APP).app" "$(APP)-$(VERSION).zip"
	@echo "Created $(DIST)/$(APP)-$(VERSION).zip"

dmg: bundle
	rm -rf "$(DIST)/dmg-root" "$(DIST)/$(APP)-$(VERSION).dmg"
	mkdir -p "$(DIST)/dmg-root"
	cp -R "$(APP_DIR)" "$(DIST)/dmg-root/"
	ln -s /Applications "$(DIST)/dmg-root/Applications"
	hdiutil create -volname "$(APP)" -srcfolder "$(DIST)/dmg-root" -ov -format UDZO "$(DIST)/$(APP)-$(VERSION).dmg"
	rm -rf "$(DIST)/dmg-root"
	@echo "Created $(DIST)/$(APP)-$(VERSION).dmg"

clean:
	rm -rf .build "$(DIST)"
