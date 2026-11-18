#!/bin/bash
# Creates the self-signed "Papo Reto Dev" code signing certificate in the login keychain.
# TCC ties Microphone and Accessibility to the signature; ad-hoc changes on every build, this does not.
set -euo pipefail

NAME="Papo Reto Dev"
KEYCHAIN="$HOME/Library/Keychains/login.keychain-db"

if security find-identity -v -p codesigning | grep -qF "\"$NAME\""; then
  echo "\"$NAME\" already exists."
  exit 0
fi

tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT
cat >"$tmp/cert.cnf" <<EOF
[req]
distinguished_name = dn
x509_extensions = ext
prompt = no
[dn]
CN = $NAME
[ext]
basicConstraints = critical, CA:false
keyUsage = critical, digitalSignature
extendedKeyUsage = critical, codeSigning
EOF

# /usr/bin/openssl (LibreSSL) on purpose: security import rejects the .p12 that OpenSSL 3 writes by default.
/usr/bin/openssl req -x509 -newkey rsa:2048 -nodes -days 3650 -config "$tmp/cert.cnf" \
  -keyout "$tmp/key.pem" -out "$tmp/cert.pem" 2>/dev/null
pass=$(/usr/bin/openssl rand -hex 16)
/usr/bin/openssl pkcs12 -export -inkey "$tmp/key.pem" -in "$tmp/cert.pem" -out "$tmp/id.p12" -passout "pass:$pass"

security import "$tmp/id.p12" -k "$KEYCHAIN" -P "$pass" -T /usr/bin/codesign
echo "macOS will ask for your password to trust \"$NAME\" for code signing."
# codesign refuses an untrusted self-signed identity ("no identity found").
security add-trusted-cert -p codeSign -k "$KEYCHAIN" "$tmp/cert.pem"

security find-identity -v -p codesigning | grep -qF "\"$NAME\"" || { echo "\"$NAME\" is not a valid identity." >&2; exit 1; }
echo "Created \"$NAME\". make app now signs with it."
