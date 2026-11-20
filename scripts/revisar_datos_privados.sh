#!/bin/sh
# Lee texto por la entrada estándar y falla si encuentra datos personales que no deben
# llegar a este repositorio público: cédulas, teléfonos y correos reales.
# Los ejemplos inventados (V12345678, correos de example.com, etc.) pasan.
# Uso: git diff --cached -U0 | grep '^+' | sh scripts/revisar_datos_privados.sh
TEXTO=$(cat)
MALO=$(
  {
    # Cédula o RIF: letra + 7 a 9 dígitos, salvo secuencias de ejemplo.
    printf '%s\n' "$TEXTO" | grep -oE '\b[VEJG]-?[0-9]{7,9}\b' | grep -vE '(1234567|7654321|0000000|1111111|9999999)'
    # Teléfono con prefijo internacional o móvil venezolano.
    printf '%s\n' "$TEXTO" | grep -oE '\+[0-9]{1,3}[ -]?[0-9]{3}[ -]?[0-9]{7}\b|\b04(12|14|16|24|26)[ -]?[0-9]{7}\b' | grep -vE '1234567'
    # Correos, salvo dominios de ejemplo, remotos git y cuentas de servicio.
    printf '%s\n' "$TEXTO" | grep -oE '[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}' \
      | grep -vE '@(example\.(com|org)|x\.com|correo\.com|dominio\.com|ejemplo\.com|gitlab\.com|github\.com|users\.noreply\.github\.com|.*\.iam\.gserviceaccount\.com)$|^git@|^noreply@'
  } | sort -u
)
if [ -n "$MALO" ]; then
  echo "❌ Posibles datos personales (este repositorio es público):"
  printf '%s\n' "$MALO" | sed 's/^/   /'
  echo "👉 Cámbialos por un ejemplo inventado (V12345678, ana@example.com)."
  exit 1
fi
exit 0
