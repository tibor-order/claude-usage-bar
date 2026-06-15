#!/usr/bin/env bash
# Build ClaudeUsageBar.app with swiftc (no Xcode project needed).
#   ./build.sh              # host architecture (fast, local use)
#   ./build.sh --universal  # arm64 + x86_64 (for distribution)
set -euo pipefail
cd "$(dirname "$0")"

APP="ClaudeUsageBar.app"
BIN="ClaudeUsageBar"
MIN="13.0"
SDK="$(xcrun --show-sdk-path)"

rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp Info.plist "$APP/Contents/Info.plist"

OUT="$APP/Contents/MacOS/$BIN"
COMMON=(-O -parse-as-library -sdk "$SDK" -framework SwiftUI -framework AppKit -framework Security Sources/*.swift)

if [ "${1:-}" = "--universal" ]; then
  echo "Compiling universal (arm64 + x86_64)…"
  TMP="$(mktemp -d)"
  swiftc "${COMMON[@]}" -target "arm64-apple-macos$MIN"  -o "$TMP/arm64"
  swiftc "${COMMON[@]}" -target "x86_64-apple-macos$MIN" -o "$TMP/x86_64"
  lipo -create "$TMP/arm64" "$TMP/x86_64" -o "$OUT"
  rm -rf "$TMP"
  echo "archs: $(lipo -archs "$OUT")"
else
  echo "Compiling ($(uname -m))…"
  swiftc "${COMMON[@]}" -o "$OUT"
fi

# Ad-hoc sign for local runs; release.sh re-signs with your Developer ID.
codesign --force --deep --sign - "$APP" >/dev/null 2>&1 || echo "(ad-hoc codesign skipped)"
echo "Built ./$APP"
