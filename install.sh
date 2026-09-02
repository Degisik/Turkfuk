#!/usr/bin/env bash
# Turkfuk kurulumu: derler, /Applications'a koyar, ayarlari sorar, baslatir.
set -euo pipefail
cd "$(dirname "$0")"

APP_ID="com.degisik.turkfuk"
HEDEF="/Applications/Turkfuk.app"

# sor "soru" varsayilan(E/H) -> 0 = evet
# Once /dev/tty, olmazsa stdin. Ikisi de yoksa varsayilana duser ama bunu
# sessizce yapmaz, ekrana yazar. TURKFUK_YES=1 ile hepsi varsayilan kabul edilir.
sor() {
  local soru="$1" var="$2" cevap="" ipucu
  ipucu=$( [ "$var" = E ] && echo 'E/h' || echo 'e/H' )

  if [ -n "${TURKFUK_YES:-}" ]; then
    echo "$soru [$ipucu] -> $var (TURKFUK_YES)"
  elif { exec 3</dev/tty; } 2>/dev/null; then
    read -r -u 3 -p "$soru [$ipucu] " cevap || cevap=""
    exec 3<&-
  elif [ -t 0 ]; then
    read -r -p "$soru [$ipucu] " cevap || cevap=""
  else
    echo "$soru [$ipucu] -> $var  (terminal yok, varsayılan kullanıldı)"
  fi

  cevap="${cevap:-$var}"
  [[ "$cevap" =~ ^[EeYy] ]]
}

echo "Turkfuk — Turkish Keylayout for US Keylayouts"
echo "============================================="
echo

# Kurulan surum varsayilan olarak evrensel olsun — install.sh'in kendisi derledigi
# icin "./build.sh universal && ./install.sh" zinciri aksi halde evrenseli eziyordu.
# Hizli yineleme icin: ./install.sh native
MIMARI="${1:-universal}"
[ "$MIMARI" = "native" ] && MIMARI=""
./build.sh "$MIMARI"
echo

if pgrep -x Turkfuk >/dev/null 2>&1; then
  echo "==> calisan surum kapatiliyor"
  pkill -x Turkfuk || true
  sleep 1
fi

echo "==> $HEDEF konumuna kuruluyor"
rm -rf "$HEDEF"
cp -R dist/Turkfuk.app "$HEDEF"

echo
if sor "Sistem açılışında otomatik başlasın mı?" E; then
  defaults write "$APP_ID" launchAtLogin -bool true
  echo "   evet — uygulama ilk açılışta kendini kaydedecek"
else
  defaults write "$APP_ID" launchAtLogin -bool false
  echo "   hayır"
fi

if sor "Menü çubuğuna simge eklensin mi?" E; then
  defaults write "$APP_ID" showMenuBarIcon -bool true
  echo "   evet — ayarlara menü çubuğundan ulaşacaksın"
else
  defaults write "$APP_ID" showMenuBarIcon -bool false
  echo "   hayır — geri açmak için: ./install.sh veya"
  echo "   defaults write $APP_ID showMenuBarIcon -bool true"
fi

# Karabiner'de ayni isi yapan eski kural varsa cakisir.
KJ="$HOME/.config/karabiner/karabiner.json"
if [ -f "$KJ" ] && python3 -c "
import json,sys
d=json.load(open('$KJ',encoding='utf-8'))
r=d['profiles'][0].get('complex_modifications',{}).get('rules',[])
sys.exit(0 if any('Türkçe uzun basım' in x.get('description','') for x in r) else 1)
" 2>/dev/null; then
  echo
  echo "UYARI: Karabiner-Elements'te aynı işi yapan bir kural açık."
  echo "       İkisi birden çalışırsa harfler çift üretilir."
  if sor "Karabiner'deki Türkçe uzun basım kuralları kaldırılsın mı?" E; then
    python3 - <<'PY'
import json, os
kj = os.path.expanduser("~/.config/karabiner/karabiner.json")
d = json.load(open(kj, encoding="utf-8"))
cm = d["profiles"][0]["complex_modifications"]
once = len(cm.get("rules", []))
cm["rules"] = [x for x in cm.get("rules", [])
               if "Türkçe uzun basım" not in x.get("description", "")]
json.dump(d, open(kj, "w", encoding="utf-8"), indent=4, ensure_ascii=False)
print(f"   {once - len(cm['rules'])} kural kaldırıldı")
PY
    echo "   geri almak için: ~/.config/karabiner/turkce-ayar.py 150"
  fi
fi

echo
echo "==> baslatiliyor"
open "$HEDEF"
sleep 2

cat <<'EOF'

Kurulum bitti.

Erişilebilirlik izni:
  Uygulama izin istemediyse ya da menü çubuğunda "izin gerekli" yazıyorsa:
  Sistem Ayarları > Gizlilik ve Güvenlik > Erişilebilirlik > Turkfuk açık olmalı.
  Bu izin olmadan tuşlar yakalanamaz.

Kullanım:
  i s g c o u  harflerinden birine basılı tut -> ı ş ğ ç ö ü
  Shift ile basılı tut                        -> İ Ş Ğ Ç Ö Ü
  ⌃⌥⌘T                                        -> aç / kapat
  Menü çubuğu simgesi                         -> eşik ve diğer ayarlar

EOF
