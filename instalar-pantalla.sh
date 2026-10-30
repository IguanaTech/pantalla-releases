#!/usr/bin/env bash
# ============================================================================
#  Instala la ÚLTIMA versión publicada de PantallaPremios, por usuario, sin root.
#
#    curl -fsSL https://github.com/IguanaTech/pantalla-releases/releases/latest/download/instalar-pantalla.sh | bash
#    curl -fsSL …/instalar-pantalla.sh | bash -s -- --sin-arranque
#
#  Se corre con la cuenta que va a mostrar la pantalla (no con sudo). Baja el
#  manifiesto firmado (`ultima.json` + `ultima.json.firma`), verifica la firma con las
#  mismas llaves que el actualizador de la pantalla (app/actualizador/llaves.js), baja el
#  tar.gz que el manifiesto fija, compara su sha256 y corre su `instalar.sh`. Las
#  opciones pasan tal cual a ese instalador (`--sin-arranque`).
#
#  Pide: bash, curl, tar, sha256sum, base64 y openssl (verifica la firma Ed25519).
# ============================================================================
set -euo pipefail

BASE="https://github.com/IguanaTech/pantalla-releases/releases/latest/download"
PREFIJO_PAQUETE="https://github.com/IguanaTech/pantalla-releases/releases/download/"
# Las mismas que LLAVES_PUBLICAS (app/actualizador/llaves.js): `x` de la JWK, base64url.
# test/instalar-pantalla.test.js falla si se separan.
LLAVES=(
  'tZu7L8Er0ADxvZav8Q7S242LU4q1IOOeXQg5LZ3NXx4'
  'nSX6ohpYXqgBGxcsiFEGQNabYE9CBRe5_VmlNmEFm4U'
)

falla() { echo "✗ $*" >&2; exit 1; }
paso() { echo "▸ $*"; }

for argumento in "$@"; do
  case "$argumento" in
    --sin-arranque) ;;
    -h|--ayuda) sed -n '2,14p' "${BASH_SOURCE[0]:-/dev/null}" 2>/dev/null | sed 's/^# \{0,2\}//'; exit 0 ;;
    *) falla "No conozco «$argumento». Opciones: --sin-arranque" ;;
  esac
done

[ "$(id -u)" -ne 0 ] || falla "No uses sudo: la instalación es por usuario. Córrelo con la cuenta que va a mostrar la pantalla."
[ "$(uname -m)" = "x86_64" ] || falla "Sólo hay paquete para PCs de 64 bits (x86_64); esta es $(uname -m)."
for programa in curl tar sha256sum base64 openssl; do
  command -v "$programa" > /dev/null || falla "Falta «$programa». En Ubuntu: sudo apt install $programa"
done

TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

bajar() { curl -fsSL --retry 3 --connect-timeout 20 -H 'Cache-Control: no-cache' -o "$2" "$1"; }

paso "Buscando la última versión…"
bajar "$BASE/ultima.json" "$TMP/ultima.json" || falla "No pude bajar el manifiesto. ¿Hay internet?"
bajar "$BASE/ultima.json.firma" "$TMP/ultima.json.firma" || falla "No pude bajar la firma del manifiesto."

# La firma: Ed25519 sobre los bytes de ultima.json, en base64. La llave pública en DER es
# un prefijo fijo de 12 bytes + los 32 de `x`.
base64url_a_bytes() {
  local s="${1//-/+}"; s="${s//_//}"
  while [ $(( ${#s} % 4 )) -ne 0 ]; do s="$s="; done
  printf '%s' "$s" | base64 -d
}
base64 -d < "$TMP/ultima.json.firma" > "$TMP/firma.bin" 2> /dev/null || falla "La firma del manifiesto no es base64: no se instala."
FIRMADA=0
for x in "${LLAVES[@]}"; do
  { printf '\x30\x2a\x30\x05\x06\x03\x2b\x65\x70\x03\x21\x00'; base64url_a_bytes "$x"; } > "$TMP/llave.der"
  openssl pkey -pubin -inform DER -in "$TMP/llave.der" -out "$TMP/llave.pem" 2> /dev/null || continue
  if openssl pkeyutl -verify -pubin -inkey "$TMP/llave.pem" -rawin \
       -in "$TMP/ultima.json" -sigfile "$TMP/firma.bin" > /dev/null 2>&1; then
    FIRMADA=1; break
  fi
done
[ "$FIRMADA" -eq 1 ] || falla "La firma de la versión publicada no es válida: no se instala."

# El manifiesto ya está verificado; se lee con grep porque firmar.js lo escribe con un
# campo por línea. La url tiene que ser la del repo de releases y la de ESA versión.
campo() { grep -o "\"$1\": *\"[^\"]*\"" "$TMP/ultima.json" | head -1 | sed 's/.*: *"\(.*\)"/\1/'; }
VERSION="$(campo version)"
URL="$(campo url)"
SHA="$(campo sha256)"
[[ "$VERSION" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]] || falla "El manifiesto no trae una versión legible."
[ "$URL" = "${PREFIJO_PAQUETE}v${VERSION}/PantallaPremios_${VERSION}_amd64.tar.gz" ] || falla "El manifiesto apunta a un paquete inesperado: no se instala."
[[ "$SHA" =~ ^[0-9a-f]{64}$ ]] || falla "El manifiesto no trae el sha256 del paquete."

paso "Bajando PantallaPremios $VERSION…"
curl -fL --retry 3 --connect-timeout 20 --progress-bar -o "$TMP/paquete.tar.gz" "$URL" || falla "No pude bajar el paquete."
echo "$SHA  $TMP/paquete.tar.gz" | sha256sum -c --status - || falla "El paquete bajado no coincide con el publicado (sha256): no se instala."

paso "Descomprimiendo…"
mkdir "$TMP/paquete"
tar -xzf "$TMP/paquete.tar.gz" -C "$TMP/paquete"
INSTALADOR="$(ls -d "$TMP"/paquete/*/instalar.sh 2> /dev/null | head -1)"
[ -n "$INSTALADOR" ] || falla "El paquete no trae instalar.sh."

paso "Instalando…"
bash "$INSTALADOR" "$@" < /dev/null
