# MacSpaceName — build helpers.
#
#   make build     compile a release binary (current architecture only)
#   make bundle    build a universal MacSpaceName.app into dist/
#   make run       bundle + launch
#   make install   bundle + copy into /Applications
#   make test      run the unit tests
#   make zip       bundle + create dist/MacSpaceName-<version>.zip
#   make clean     remove build products

APP        := MacSpaceName
DIST       := dist
APP_DIR    := $(DIST)/$(APP).app
ARCHS      ?= --arch arm64 --arch x86_64
VERSION    ?= $(shell git describe --tags --abbrev=0 2>/dev/null | sed 's/^v//')
BUILD      ?= $(shell git rev-list --count HEAD 2>/dev/null)

ifeq ($(VERSION),)
VERSION := 0.0.0
endif
ifeq ($(BUILD),)
BUILD := 1
endif

.PHONY: build bundle run install uninstall test zip clean

build:
	swift build -c release

test:
	swift test

bundle:
	swift build -c release $(ARCHS)
	$(eval BIN_DIR := $(shell swift build -c release $(ARCHS) --show-bin-path))
	rm -rf "$(APP_DIR)"
	mkdir -p "$(APP_DIR)/Contents/MacOS" "$(APP_DIR)/Contents/Resources"
	cp "$(BIN_DIR)/$(APP)" "$(APP_DIR)/Contents/MacOS/$(APP)"
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

clean:
	rm -rf .build "$(DIST)"
