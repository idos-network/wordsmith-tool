#!/bin/bash
# Usage: ./build.sh          → build/Wordsmith.app
#        ./build.sh preview  → render the choice panel to build/preview-*.png
#        ./build.sh test     → build and run the self-test
set -euo pipefail
cd "$(dirname "$0")"
mkdir -p build

if [[ "${1:-}" == "test" ]]; then
  # -Onone keeps assert() active; main.swift is the app entry point, so the test brings its own
  swiftc -Onone -swift-version 5 Sources/Rewriter.swift Sources/DoubleTap.swift Tests/main.swift -o build/self-test
  exec build/self-test
fi

if [[ "${1:-}" == "preview" ]]; then
  # renders the choice panel to build/preview-*.png, for checking the layout without triggering it
  mkdir -p build/preview
  cp Tests/preview.swift build/preview/main.swift
  swiftc -swift-version 5 Sources/ChoicePanel.swift build/preview/main.swift -o build/preview/run
  exec build/preview/run
fi

if [[ ! -f build/AppIcon.icns ]]; then
  mkdir -p build/tools
  swiftc -swift-version 5 Tools/make-icon.swift -o build/tools/make-icon
  rm -rf build/AppIcon.iconset
  build/tools/make-icon build/AppIcon.iconset
  iconutil -c icns build/AppIcon.iconset -o build/AppIcon.icns
fi

APP=build/Wordsmith.app
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
swiftc -O -swift-version 5 -target "$(uname -m)-apple-macos13" Sources/*.swift -o "$APP/Contents/MacOS/Wordsmith"
cp build/AppIcon.icns "$APP/Contents/Resources/"
cat > "$APP/Contents/Info.plist" <<'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
  <key>CFBundleIdentifier</key><string>local.wordsmith</string>
  <key>CFBundleName</key><string>Wordsmith</string>
  <key>CFBundleExecutable</key><string>Wordsmith</string>
  <key>CFBundleIconFile</key><string>AppIcon</string>
  <key>CFBundlePackageType</key><string>APPL</string>
  <key>CFBundleShortVersionString</key><string>1.0</string>
  <key>LSMinimumSystemVersion</key><string>13.0</string>
  <key>LSUIElement</key><true/>
</dict></plist>
EOF
# Accessibility permission is tied to the signature. An ad-hoc signature changes on every build and loses it;
# a local self-signed "Profesional Local Signing" certificate (see README) keeps it across rebuilds.
IDENTITY="Profesional Local Signing"
if security find-certificate -c "$IDENTITY" >/dev/null 2>&1; then
  codesign --force --sign "$IDENTITY" "$APP"
else
  echo "warning: no '$IDENTITY' certificate, signing ad hoc; Accessibility must be granted again after each build" >&2
  codesign --force --sign - "$APP"
fi
echo "Built $APP"

if [[ "${1:-}" == "site" ]]; then
  # download page for GitHub Pages: page + zipped app + demo video → build/site
  SITE=build/site
  rm -rf "$SITE" && mkdir -p "$SITE"
  ditto -c -k --keepParent "$APP" "$SITE/Wordsmith.zip"
  cp brag-output/brag.mp4 brag-output/brag.jpg "$SITE/"
  cp build/AppIcon.iconset/icon_256x256@2x.png "$SITE/icon.png"
  VERSION="$(date -u +%Y-%m-%d)${GITHUB_SHA:+ · ${GITHUB_SHA::7}}"
  sed "s/__VERSION__/$VERSION/" site/index.html > "$SITE/index.html"
  echo "Built $SITE"
fi
