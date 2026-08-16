.PHONY: all build app install clean

SWIFTC ?= swiftc
TARGET = arm64-apple-macos11.0
APP_NAME = Show Desktop.app
DESKTOP_PATH = $(HOME)/Desktop/$(APP_NAME)

all: build app

build:
	$(SWIFTC) -O -target $(TARGET) ShowDesktop.swift -o show_desktop
	chmod +x show_desktop

app: build
	rm -rf "$(DESKTOP_PATH)"
	mkdir -p "$(DESKTOP_PATH)/Contents/MacOS"
	mkdir -p "$(DESKTOP_PATH)/Contents/Resources"
	cat << 'APPLET_EOF' > /tmp/wrapper.applescript
	on run
		do shell script "$(CURDIR)/show_desktop"
	end run
	APPLET_EOF
	osacompile -o "$(DESKTOP_PATH)" /tmp/wrapper.applescript
	plutil -replace LSUIElement -bool YES "$(DESKTOP_PATH)/Contents/Info.plist"
	cp /System/Library/CoreServices/CoreTypes.bundle/Contents/Resources/DesktopFolderIcon.icns "$(DESKTOP_PATH)/Contents/Resources/applet.icns"
	codesign --force --deep --sign - "$(DESKTOP_PATH)"
	rm -f /tmp/wrapper.applescript
	touch "$(DESKTOP_PATH)"

install: app
	mkdir -p $(HOME)/Library/LaunchAgents
	cat << 'PLIST_EOF' > $(HOME)/Library/LaunchAgents/com.local.showdesktop.plist
	<?xml version="1.0" encoding="UTF-8"?>
	<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
	<plist version="1.0">
	<dict>
		<key>Label</key>
		<string>com.local.showdesktop</string>
		<key>ProgramArguments</key>
		<array>
			<string>$(CURDIR)/show_desktop</string>
			<string>--daemon</string>
		</array>
		<key>RunAtLoad</key>
		<true/>
		<key>KeepAlive</key>
		<true/>
	</dict>
	</plist>
	PLIST_EOF
	launchctl bootstrap gui/$$(id -u) $(HOME)/Library/LaunchAgents/com.local.showdesktop.plist 2>/dev/null || launchctl load $(HOME)/Library/LaunchAgents/com.local.showdesktop.plist

clean:
	rm -f show_desktop
