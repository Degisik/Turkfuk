#!/usr/bin/env bash
# Turkfuk.app paketini uretir. Xcode gerekmez; CommandLineTools yeter.
#   ./build.sh            -> yerel mimari (hizli)
#   ./build.sh universal  -> arm64 + x86_64 evrensel ikili
set -euo pipefail
cd "$(dirname "$0")"

APP="dist/Turkfuk.app"
MACOS_MIN="13.0"
SDK="$(xcrun --show-sdk-path)"
SRC=(Sources/Turkfuk/*.swift)
FRAMEWORKS=(-framework AppKit -framework ApplicationServices -framework ServiceManagement -framework Carbon)
VERSION="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' Resources/Info.plist)"

rm -rf "$APP" .buildtmp
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources" .buildtmp

derle() {  # $1 = mimari, $2 = cikti
  swiftc -O -swift-version 5 \
    -target "$1-apple-macosx$MACOS_MIN" -sdk "$SDK" \
    "${FRAMEWORKS[@]}" "${SRC[@]}" -o "$2"
}

if [ "${1:-}" = "universal" ]; then
  echo "==> derleniyor: arm64"
  derle arm64 .buildtmp/Turkfuk-arm64
  echo "==> derleniyor: x86_64"
  if derle x86_64 .buildtmp/Turkfuk-x86_64 2>/dev/null; then
    lipo -create -output "$APP/Contents/MacOS/Turkfuk" \
      .buildtmp/Turkfuk-arm64 .buildtmp/Turkfuk-x86_64
    echo "==> evrensel ikili olusturuldu"
  else
    echo "   x86_64 derlenemedi, yalnizca arm64 paketleniyor"
    cp .buildtmp/Turkfuk-arm64 "$APP/Contents/MacOS/Turkfuk"
  fi
else
  echo "==> derleniyor: $(uname -m)"
  derle "$(uname -m)" "$APP/Contents/MacOS/Turkfuk"
fi

cp Resources/Info.plist "$APP/Contents/Info.plist"
printf 'APPL????' > "$APP/Contents/PkgInfo"
rm -rf .buildtmp

echo "==> imzalaniyor (ad-hoc)"
codesign --force --sign - "$APP"

echo
echo "hazir: $APP  (surum $VERSION)"
lipo -archs "$APP/Contents/MacOS/Turkfuk" | sed 's/^/mimari: /'
