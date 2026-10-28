#!/bin/bash
# Puts the notarized "Cuemodo Cyc.app" from scripts/package.sh into a DMG with
# a drag-to-Applications window, then signs, notarizes and staples the DMG
# itself, so it opens on any Mac without a Gatekeeper warning. The result is
# dist/Cuemodo-Cyc-<version>.dmg.
#
#   scripts/make-dmg.sh                       uses dist/Cuemodo Cyc.app
#   scripts/make-dmg.sh path/to/Cuemodo\ Cyc.app
#   scripts/make-dmg.sh --no-notarize         build and sign only (quick layout check)
#
# A DMG (disk image) is the usual way to hand out a Mac app: double-click it,
# then drag the app onto the Applications shortcut next to it.
#
# Needs create-dmg (brew install create-dmg) and the same Developer ID
# certificate and "notary" keychain profile as scripts/package.sh.
#
# Environment overrides:
#   SIGN_IDENTITY   certificate name (default: "Developer ID Application")
#   NOTARY_PROFILE  keychain profile for notarytool (default: notary)
set -euo pipefail

cd "$(dirname "$0")/.."

notarize=true
app="dist/Cuemodo Cyc.app"
for arg in "$@"; do
    case "$arg" in
        --no-notarize) notarize=false ;;
        *) app="$arg" ;;
    esac
done

identity="${SIGN_IDENTITY:-Developer ID Application}"
profile="${NOTARY_PROFILE:-notary}"

if [[ ! -d "$app" ]]; then
    echo "error: app not found at '$app' (run scripts/package.sh first)" >&2
    exit 1
fi
command -v create-dmg >/dev/null || {
    echo "error: create-dmg not installed (brew install create-dmg)" >&2
    exit 1
}

version=$(/usr/libexec/PlistBuddy -c "Print :CFBundleShortVersionString" "$app/Contents/Info.plist")
dmg="dist/Cuemodo-Cyc-$version.dmg"

echo "==> Building $dmg from $app"
rm -f "$dmg"
create-dmg --volname "Cuemodo Cyc" --volicon "$app/Contents/Resources/AppIcon.icns" \
    --window-size 500 300 --icon-size 96 \
    --icon "$(basename "$app")" 125 120 --app-drop-link 375 120 \
    "$dmg" "$app"

echo "==> Signing $dmg"
codesign --sign "$identity" --timestamp "$dmg"

if ! $notarize; then
    echo "==> Done (signed, not notarized): $dmg"
    exit 0
fi

echo "==> Notarizing with keychain profile \"$profile\" (takes a few minutes)"
xcrun notarytool submit "$dmg" --keychain-profile "$profile" --wait
xcrun stapler staple "$dmg"

echo "==> Checking Gatekeeper accepts it"
spctl --assess --type open --context context:primary-signature --verbose=2 "$dmg"

echo "==> Done: $dmg"
