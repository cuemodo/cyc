#!/bin/bash
# Wraps the Swift package into "Cuemodo Cyc.app", signs it with a Developer ID
# certificate and has Apple notarize it, so it opens on any Mac without a
# Gatekeeper warning. The result is dist/Cuemodo-Cyc-<version>.zip; for a
# release, scripts/make-dmg.sh then puts the app into a DMG.
#
#   scripts/package.sh                 build, sign, notarize, staple, zip
#   scripts/package.sh --no-notarize   build and sign only (quick local check)
#
# Words used here:
# - Developer ID: the certificate Apple gives for apps shared outside the App Store.
# - Hardened runtime: a stricter mode Apple requires before it will notarize an app.
# - Notarization: Apple scans the signed app and issues a ticket; "stapling"
#   attaches that ticket to the app so Gatekeeper can check it offline.
#
# Notarization needs a stored keychain profile, created once per Apple ID (any app can reuse it) with:
#   xcrun notarytool store-credentials notary \
#       --apple-id <your Apple ID> --team-id KL8N8L33GU
# (it asks for an app-specific password from account.apple.com).
#
# Environment overrides:
#   SIGN_IDENTITY   certificate name (default: "Developer ID Application")
#   NOTARY_PROFILE  keychain profile for notarytool (default: notary, shared by all your apps)
set -euo pipefail

cd "$(dirname "$0")/.."

notarize=true
[[ "${1:-}" == "--no-notarize" ]] && notarize=false

name="Cuemodo Cyc"
executable="Cyc"
bundle_id="io.cuemodo.cyc"
identity="${SIGN_IDENTITY:-Developer ID Application}"
profile="${NOTARY_PROFILE:-notary}"
version=$(sed -n 's/.*static let version = "\(.*\)".*/\1/p' Sources/CycCore/CycInfo.swift)
build=$(git rev-list --count HEAD)

dist="dist"
app="$dist/$name.app"
zip="$dist/Cuemodo-Cyc-$version.zip"

# A notarized build is a release candidate. It must come from a committed state
# (the build number is the commit count, see Info.plist below) that is tagged
# v<version> locally, with that tag not pushed yet: the tag names exactly what
# was built, and is pushed only once Apple accepts the build. If the build
# fails, delete the local tag (git tag -d v<version>), fix and retry.
# Quick --no-notarize builds skip these checks.
if $notarize; then
    tag="v$version"
    if [[ -n "$(git status --porcelain)" ]]; then
        echo "error: uncommitted changes; commit them first (or use --no-notarize):" >&2
        git status --short >&2
        exit 1
    fi
    tagged=$(git rev-parse -q --verify "refs/tags/$tag^{commit}" || true)
    if [[ "$tagged" != "$(git rev-parse HEAD)" ]]; then
        echo "error: this commit is not tagged $tag (CycInfo.version is $version)." >&2
        if [[ -n "$tagged" ]]; then
            echo "       $tag is on another commit ($(git log -1 --format='%h %s' "$tagged"))." >&2
            echo "       If that was a failed attempt: git tag -d $tag, then tag this commit." >&2
        else
            echo "       Tag it first: git tag -a $tag -m \"$name $version\"" >&2
        fi
        here=$(git tag --points-at HEAD | tr '\n' ' ')
        [[ -n "$here" ]] && echo "       Tags on this commit: $here" >&2
        exit 1
    fi
    if ! remote_tags=$(git ls-remote --tags origin "refs/tags/$tag" 2>/dev/null); then
        echo "warning: could not reach origin to check for $tag; continuing" >&2
    elif [[ -n "$remote_tags" ]]; then
        echo "error: $tag is already on origin (released); bump CycInfo.version first" >&2
        exit 1
    fi
fi

echo "==> Building $name $version ($build), Apple silicon and Intel"
swift build -c release --arch arm64 --arch x86_64
products=$(swift build -c release --arch arm64 --arch x86_64 --show-bin-path)

echo "==> Assembling $app"
rm -rf "$app" "$zip"
mkdir -p "$app/Contents/MacOS" "$app/Contents/Resources"
cp "$products/$executable" "$app/Contents/MacOS/$executable"
# SwiftPM looks for its resource bundle in Contents/Resources first.
cp -R "$products/${executable}_${executable}.bundle" "$app/Contents/Resources/"

# The Finder and Dock icon: an .icns file built from the 1024 px PNG.
iconset=$(mktemp -d)/AppIcon.iconset
mkdir -p "$iconset"
for size in 16 32 128 256 512; do
    sips -z $size $size Sources/Cyc/Resources/AppIcon.png --out "$iconset/icon_${size}x${size}.png" >/dev/null
    sips -z $((size * 2)) $((size * 2)) Sources/Cyc/Resources/AppIcon.png --out "$iconset/icon_${size}x${size}@2x.png" >/dev/null
done
iconutil -c icns "$iconset" -o "$app/Contents/Resources/AppIcon.icns"

# NSLocalNetworkUsageDescription: macOS 15 and later ask before an app may
# receive from the local network, which is where Art-Net comes from.
cat > "$app/Contents/Info.plist" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleName</key>                  <string>$name</string>
    <key>CFBundleDisplayName</key>           <string>$name</string>
    <key>CFBundleExecutable</key>            <string>$executable</string>
    <key>CFBundleIdentifier</key>            <string>$bundle_id</string>
    <key>CFBundlePackageType</key>           <string>APPL</string>
    <key>CFBundleShortVersionString</key>    <string>$version</string>
    <key>CFBundleVersion</key>               <string>$build</string>
    <key>CFBundleIconFile</key>              <string>AppIcon</string>
    <key>LSMinimumSystemVersion</key>        <string>14.0</string>
    <key>LSApplicationCategoryType</key>     <string>public.app-category.entertainment</string>
    <key>NSHighResolutionCapable</key>       <true/>
    <key>NSHumanReadableCopyright</key>      <string>MIT License. Part of the Cuemodo family.</string>
    <key>NSLocalNetworkUsageDescription</key>
    <string>$name listens for Art-Net lighting data from your lighting desk on the local network.</string>
</dict>
</plist>
EOF

echo "==> Signing with \"$identity\" (hardened runtime)"
codesign --force --options runtime --timestamp --sign "$identity" "$app"
codesign --verify --strict --verbose=2 "$app"

if ! $notarize; then
    echo "==> Done (signed, not notarized): $app"
    exit 0
fi

echo "==> Notarizing with keychain profile \"$profile\" (takes a few minutes)"
upload="$(mktemp -d)/Cuemodo-Cyc-$version.zip"
ditto -c -k --keepParent "$app" "$upload"
xcrun notarytool submit "$upload" --keychain-profile "$profile" --wait
xcrun stapler staple "$app"

echo "==> Checking Gatekeeper accepts it"
spctl --assess --type execute --verbose=2 "$app"

ditto -c -k --keepParent "$app" "$zip"
echo "==> Done: $zip"
