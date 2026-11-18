#!/bin/bash
# Creates the self-signed "Papo Reto Dev" code signing certificate in the login keychain.
# TCC ties Microphone and Accessibility to the signature; ad-hoc changes on every build, this does not.
# --identity prints the SHA-1 of the valid identity (empty if none); make app signs with it.
set -euo pipefail

NAME="${DEV_CERT:-Papo Reto Dev}"
KEYCHAIN="$HOME/Library/Keychains/login.keychain-db"

# By SHA-1 and exact name: codesign rejects an ambiguous name. Output captured, so grep never SIGPIPEs it.
identity() {
  local ids
  ids=$(security find-identity -v -p codesigning)
  awk -F'"' -v n="$NAME" '$2 == n { split($1, f, " "); print f[2]; exit }' <<<"$ids"
}

if [ "${1:-}" = --identity ]; then
  identity
  exit 0
fi

if [ -n "$(identity)" ]; then
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
  -keyout "$tmp/key.pem" -out "$tmp/cert.pem"
pass=$(/usr/bin/openssl rand -hex 16)
/usr/bin/openssl pkcs12 -export -inkey "$tmp/key.pem" -in "$tmp/cert.pem" -out "$tmp/id.p12" -passout "pass:$pass"
sha1=$(/usr/bin/openssl x509 -in "$tmp/cert.pem" -noout -fingerprint -sha1 | cut -d= -f2 | tr -d :)

security import "$tmp/id.p12" -k "$KEYCHAIN" -P "$pass" -T /usr/bin/codesign
echo "macOS will ask for your password to trust \"$NAME\" for code signing."
# codesign refuses an untrusted self-signed identity ("no identity found"). Without trust, undo the
# import: --identity cannot see an untrusted one, so a rerun would pile up duplicates.
if ! security add-trusted-cert -p codeSign -k "$KEYCHAIN" "$tmp/cert.pem"; then
  security delete-identity -Z "$sha1" "$KEYCHAIN"
  echo "Not trusted; the imported certificate was removed. Run again and allow it." >&2
  exit 1
fi

[ -n "$(identity)" ] || { echo "\"$NAME\" is not a valid identity." >&2; exit 1; }
echo "Created \"$NAME\". make app now signs with it."
