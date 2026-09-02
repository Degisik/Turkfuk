#!/usr/bin/env bash
# Kod imzalama icin kendinden imzali sertifika uretir ve login anahtarligina kurar.
#
# Neden: macOS erisilebilirlik iznini uygulamanin imzasina bagliyor. Ad-hoc imza
# her derlemede degistigi icin izin her seferinde dusuyor. Sabit bir sertifikayla
# imza degismez, izin bir kez verilir.
#
# NOT: Bu sertifika Apple tarafindan taninmaz. Yerelde izin kaliciligi saglar;
# baskasinin indirdigi kopyada Gatekeeper'i gecmez. Onun icin Apple Developer ID
# ve notarization gerekir.
set -euo pipefail

AD="${TURKFUK_CERT_NAME:-Turkfuk Self Signed}"
KEYCHAIN="$HOME/Library/Keychains/login.keychain-db"

if security find-identity -v -p codesigning 2>/dev/null | grep -qF "$AD"; then
  echo "sertifika zaten var: $AD"
  exit 0
fi

TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

cat > "$TMP/openssl.cnf" <<EOF
[ req ]
distinguished_name = dn
x509_extensions    = v3
prompt             = no

[ dn ]
CN = $AD

[ v3 ]
basicConstraints       = critical,CA:false
keyUsage               = critical,digitalSignature
extendedKeyUsage       = critical,codeSigning
subjectKeyIdentifier   = hash
EOF

echo "==> anahtar ve sertifika uretiliyor"
openssl req -x509 -newkey rsa:2048 -sha256 -days 3650 -nodes \
  -keyout "$TMP/key.pem" -out "$TMP/cert.pem" -config "$TMP/openssl.cnf" 2>/dev/null

# macOS'un Security cercevesi bos parolali PKCS12'yi kabul etmiyor; gecici parola
# yalnizca bu aktarim icin kullaniliyor, sonrasinda dosya siliniyor.
PAROLA="turkfuk-import"
openssl pkcs12 -export -legacy -out "$TMP/cert.p12" \
  -inkey "$TMP/key.pem" -in "$TMP/cert.pem" -name "$AD" -passout "pass:$PAROLA" 2>/dev/null \
|| openssl pkcs12 -export -out "$TMP/cert.p12" \
  -inkey "$TMP/key.pem" -in "$TMP/cert.pem" -name "$AD" -passout "pass:$PAROLA"

echo "==> anahtarliga aktariliyor"
security import "$TMP/cert.p12" -k "$KEYCHAIN" -P "$PAROLA" -A -T /usr/bin/codesign

echo "==> kod imzalama icin guveniliyor (parola sorabilir)"
security add-trusted-cert -r trustRoot -p codeSign -k "$KEYCHAIN" "$TMP/cert.pem"

echo
security find-identity -v -p codesigning | grep -F "$AD" || {
  echo "UYARI: sertifika gecerli kimlik olarak gorunmuyor."; exit 1; }
echo "hazir."
