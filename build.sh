#!/usr/bin/env bash
# Build ClaudeUsageBar.app with swiftc (no Xcode project needed).
set -euo pipefail
cd "$(dirname "$0")"

APP="ClaudeUsageBar.app"
BIN="ClaudeUsageBar"

rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp Info.plist "$APP/Contents/Info.plist"

echo "Compiling…"
swiftc -O -parse-as-library \
  -framework SwiftUI -framework AppKit -framework Security \
  Sources/*.swift \
  -o "$APP/Contents/MacOS/$BIN"

# Ad-hoc sign so Keychain access + networking behave on a local build.
codesign --force --deep --sign - "$APP" >/dev/null 2>&1 || echo "(codesign skipped)"

echo "Built ./$APP"
echo "Run:  open ./$APP        (or double-click in Finder)"
