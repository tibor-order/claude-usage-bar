#!/usr/bin/env bash
# Official release: build universal → sign (Developer ID + hardened runtime) →
# notarize (Apple) → staple → package signed/notarized .dmg.
#
# Prereqs (one time): see RELEASE.md
#   - a "Developer ID Application" certificate in your login keychain
#   - a notarytool credential profile (default name: claude-usage-notary)
#
# Override via env: SIGN_ID="Developer ID Application: …"  NOTARY_PROFILE=name  VERSION=1.0.0
set -euo pipefail
cd "$(dirname "$0")"

APP="ClaudeUsageBar.app"
DMG="ClaudeUsageBar.dmg"
VOLNAME="Claude Usage"
NOTARY_PROFILE="${NOTARY_PROFILE:-claude-usage-notary}"

# 1. Resolve the Developer ID Application signing identity
SIGN_ID="${SIGN_ID:-$(security find-identity -v -p codesigning | awk -F'"' '/Developer ID Application/{print $2; exit}')}"
if [ -z "${SIGN_ID:-}" ]; then
  echo "✗ No 'Developer ID Application' identity found in keychain." >&2
  echo "  Create one first — see RELEASE.md → 'A. Create the certificate'." >&2
  exit 1
fi
echo "Signing identity: $SIGN_ID"

# 2. Build universal
./build.sh --universal

# 3. Sign the app: hardened runtime + secure timestamp (both required for notarization)
codesign --force --options runtime --timestamp --sign "$SIGN_ID" "$APP"
codesign --verify --strict --verbose=2 "$APP"

# 4. Notarize the app
ZIP="ClaudeUsageBar-notarize.zip"
/usr/bin/ditto -c -k --keepParent "$APP" "$ZIP"
echo "Submitting app to Apple notary (a few minutes)…"
xcrun notarytool submit "$ZIP" --keychain-profile "$NOTARY_PROFILE" --wait
rm -f "$ZIP"

# 5. Staple the ticket into the app (offline-trust). stapler ships with full Xcode.
if xcrun --find stapler >/dev/null 2>&1; then
  xcrun stapler staple "$APP"
else
  echo "! 'stapler' unavailable (needs full Xcode). App is notarized; Gatekeeper checks online on first launch."
fi

# 6. Package a .dmg (drag-to-Applications layout)
STAGE="$(mktemp -d)"
cp -R "$APP" "$STAGE/"
ln -s /Applications "$STAGE/Applications"
rm -f "$DMG"
hdiutil create -volname "$VOLNAME" -srcfolder "$STAGE" -ov -format UDZO "$DMG"
rm -rf "$STAGE"

# 7. Sign + notarize + staple the .dmg itself (so the downloaded file is trusted offline)
codesign --force --timestamp --sign "$SIGN_ID" "$DMG"
echo "Submitting dmg to Apple notary…"
xcrun notarytool submit "$DMG" --keychain-profile "$NOTARY_PROFILE" --wait
xcrun --find stapler >/dev/null 2>&1 && xcrun stapler staple "$DMG" || true

# 8. Verify
echo "== verification =="
codesign -dvv "$APP" 2>&1 | grep -E 'Authority|TeamIdentifier|Runtime|Timestamp' || true
spctl -a -t exec -vv "$APP" 2>&1 || true
echo
echo "✓ Done → $DMG"
echo "Publish:  gh release create v${VERSION:-1.0.0} \"$DMG\" -t \"Claude Usage ${VERSION:-1.0.0}\" -n \"Signed + notarized.\""
