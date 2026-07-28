#!/usr/bin/env bash

extract_apk_cert_sha256() {
  local apksigner_output="$1"
  local digest_line
  local digest

  digest_line=$(printf '%s\n' "$apksigner_output" | awk '
    {
      normalized = tolower($0)
      marker = "certificate sha-256 digest:"
      marker_position = index(normalized, marker)
      if (index(normalized, "signer") && marker_position) {
        print substr($0, marker_position + length(marker))
        exit
      }
    }
  ')

  if [[ -z "$digest_line" ]]; then
    echo "Erreur: aucune ligne de certificat SHA-256 de signataire n'a été trouvée." >&2
    return 1
  fi

  digest=$(printf '%s' "$digest_line" \
    | tr -d '[:space:]:' \
    | tr '[:lower:]' '[:upper:]')

  if [[ ! "$digest" =~ ^[0-9A-F]{64}$ ]]; then
    echo "Erreur: l'empreinte extraite n'est pas composée de 64 caractères hexadécimaux." >&2
    return 1
  fi

  printf '%s' "$digest"
}
