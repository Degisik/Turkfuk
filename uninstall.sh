#!/usr/bin/env bash
# Turkfuk'u tamamen kaldirir.
set -euo pipefail
APP_ID="com.degisik.turkfuk"
pkill -x Turkfuk 2>/dev/null || true
rm -rf /Applications/Turkfuk.app
defaults delete "$APP_ID" 2>/dev/null || true
echo "Turkfuk kaldırıldı."
echo "Erişilebilirlik listesindeki kaydı Sistem Ayarları'ndan elle silebilirsin."
