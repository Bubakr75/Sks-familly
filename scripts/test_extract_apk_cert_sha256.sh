#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
source "$SCRIPT_DIR/extract_apk_cert_sha256.sh"

LOWER_DIGEST=0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef
UPPER_DIGEST=${LOWER_DIGEST^^}

assert_extracts() {
  local description="$1"
  local input="$2"
  local actual

  actual=$(extract_apk_cert_sha256 "$input")
  if [[ "$actual" != "$UPPER_DIGEST" ]]; then
    echo "Échec: ${description}: résultat inattendu '${actual}'." >&2
    exit 1
  fi
}

assert_rejects() {
  local description="$1"
  local input="$2"

  if extract_apk_cert_sha256 "$input" >/dev/null 2>&1; then
    echo "Échec: ${description}: la valeur aurait dû être rejetée." >&2
    exit 1
  fi
}

assert_extracts \
  "préfixe Signer #1" \
  "Signer #1 certificate SHA-256 digest: $LOWER_DIGEST"
assert_extracts \
  "préfixe V2 Signer #1" \
  "V2 Signer #1 certificate SHA-256 digest: $LOWER_DIGEST"
assert_extracts \
  "espaces et casse variables" \
  "  v3 SiGnEr #7   CeRtIfIcAtE ShA-256 DiGeSt:  01:23:45:67:89:ab:cd:ef:01:23:45:67:89:ab:cd:ef:01:23:45:67:89:ab:cd:ef:01:23:45:67:89:ab:cd:ef  "
assert_rejects "valeur vide" "Signer #1 certificate SHA-256 digest:"
assert_rejects \
  "empreinte invalide" \
  "V2 Signer #1 certificate SHA-256 digest: XYZ123"

KNOWN_APKSIGNER_OUTPUT="V2 Signer: certificate SHA-256 digest: c92dc155674ce2bff2e717280beef2eea38fe4f5636c50c5fc782231f3227d6d"
KNOWN_EXTRACTED_DIGEST=$(extract_apk_cert_sha256 "$KNOWN_APKSIGNER_OUTPUT")

echo "Tests du parseur de certificat APK réussis."
echo "Extraction de la sortie réelle connue: $KNOWN_EXTRACTED_DIGEST"
