#!/usr/bin/env bash
# Dagitilabilir .dmg uretir. Once build.sh calistirilir.
set -euo pipefail
cd "$(dirname "$0")"

VERSION="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' Resources/Info.plist)"
ETIKET="${1:-}"
AD="Turkfuk-${VERSION}${ETIKET:+-$ETIKET}"
STAGE=".buildtmp/dmg"
DMG="dist/$AD.dmg"

[ -d dist/Turkfuk.app ] || ./build.sh

echo "==> icerik hazirlaniyor"
rm -rf "$STAGE"; mkdir -p "$STAGE"
cp -R dist/Turkfuk.app "$STAGE/Turkfuk.app"
ln -s /Applications "$STAGE/Applications"

cat > "$STAGE/OKU.txt" <<'EOF'
Turkfuk — Turkish Keylayout for US Keylayouts
=============================================

KURULUM
  Turkfuk.app'i yanindaki Applications klasorune surukle.

ILK ACILIS
  Uygulama Apple tarafindan notarize edilmedi; ilk acilista macOS engelleyecek.

  macOS 15 ve ustu:
    1. Turkfuk.app'i normal ac (engellenecek)
    2. Sistem Ayarlari > Gizlilik ve Guvenlik
    3. Asagida cikan "Turkfuk yine de acilsin" dugmesine bas

  Ya da terminalden tek komutla:
    xattr -dr com.apple.quarantine /Applications/Turkfuk.app

  Bir kez yaptiktan sonra normal acilir.

ERISILEBILIRLIK IZNI
  Sistem Ayarlari > Gizlilik ve Guvenlik > Erisilebilirlik > Turkfuk
  Bu izin olmadan tuslar yakalanamaz.

KULLANIM
  i s g c o u  harflerinden birine basili tut  ->  i s g c o u
  Shift ile basili tut                         ->  I S G C O U
  Ac/kapat kisayolu (varsayilan)               ->  Control-Option-Command-T
  Ayarlar                                      ->  menu cubugu simgesi

  Kaynak kod: https://github.com/Degisik/Turkfuk
EOF

echo "==> dmg olusturuluyor"
rm -f "$DMG"
hdiutil create -volname "Turkfuk $VERSION" -srcfolder "$STAGE" \
  -ov -format UDZO -quiet "$DMG"
rm -rf "$STAGE"

echo
echo "hazir: $DMG"
ls -lh "$DMG" | awk '{print "boyut: "$5}'
shasum -a 256 "$DMG" | awk '{print "sha256: "$1}'
