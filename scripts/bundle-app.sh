#!/bin/bash
# Build (unless SKIP_BUILD=1) and assemble ClaudeMenuBar.app.
# Usage: scripts/bundle-app.sh [OUTPUT_DIR]   (default: current dir)
#        SKIP_BUILD=1 scripts/bundle-app.sh DIR   (assemble from existing .build/release)
set -euo pipefail
cd "$(dirname "$0")/.."

OUT="${1:-$(pwd)}"
APP="$OUT/ClaudeMenuBar.app"

if [ -z "${SKIP_BUILD:-}" ]; then
  echo "==> swift build -c release"
  swift build -c release
fi

BIN=".build/release/ClaudeMenuBar"
[ -x "$BIN" ] || { echo "ERROR: $BIN not found (build first)" >&2; exit 1; }

rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS"
cp "$BIN" "$APP/Contents/MacOS/ClaudeMenuBar"

cat > "$APP/Contents/Info.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleName</key>            <string>ClaudeMenuBar</string>
    <key>CFBundleDisplayName</key>     <string>Claude Chats</string>
    <key>CFBundleIdentifier</key>      <string>com.adamkrampl.claudemenubar</string>
    <key>CFBundleExecutable</key>      <string>ClaudeMenuBar</string>
    <key>CFBundleVersion</key>         <string>3</string>
    <key>CFBundleShortVersionString</key> <string>1.0.3</string>
    <key>CFBundlePackageType</key>     <string>APPL</string>
    <key>LSMinimumSystemVersion</key>  <string>13.0</string>
    <key>LSUIElement</key>             <true/>
    <key>NSHighResolutionCapable</key> <true/>
    <key>NSAppleEventsUsageDescription</key>
    <string>ClaudeMenuBar controls Terminal to resume a Claude Code chat when you choose "Open in Terminal".</string>
</dict>
</plist>
PLIST

# Ad-hoc sign so a locally built bundle launches without Gatekeeper friction.
codesign --force --deep --sign - "$APP" >/dev/null 2>&1 || true

echo "==> Built $APP"
