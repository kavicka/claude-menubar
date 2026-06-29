#!/bin/bash
# Local / from-source install (no Homebrew). Builds this checkout, installs the
# app to /Applications, then wires the Claude Code hooks + autostart.
#
# Most users should instead:  brew install kavicka/claude-menubar/claude-menubar
set -euo pipefail
cd "$(dirname "$0")"

command -v swift >/dev/null 2>&1 || { echo "Swift not found. Run: xcode-select --install" >&2; exit 1; }
command -v jq    >/dev/null 2>&1 || { echo "jq not found. Run: brew install jq" >&2; exit 1; }

./scripts/bundle-app.sh

echo "==> Installing app to /Applications"
rm -rf "/Applications/ClaudeMenuBar.app"
cp -R "ClaudeMenuBar.app" "/Applications/ClaudeMenuBar.app"

CLAUDE_MENUBAR_APP="/Applications/ClaudeMenuBar.app" ./scripts/claude-menubar setup
