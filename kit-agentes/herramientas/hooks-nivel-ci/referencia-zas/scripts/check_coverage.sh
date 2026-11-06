#!/bin/sh
# ==============================================================================
# Verifica que la cobertura de líneas de coverage/lcov.info no baje del mínimo.
#
# Uso: sh scripts/check_coverage.sh [MINIMO] [LCOV]
#   MINIMO  porcentaje mínimo (por defecto 39, la cobertura medida el
#           15/10/2026). Súbelo cuando la cobertura mejore, nunca lo bajes.
#   LCOV    ruta del reporte (por defecto coverage/lcov.info).
#
# Genera el reporte antes con: flutter test --coverage
# Sale con código 1 si la cobertura es menor que el mínimo o falta el reporte.
# ==============================================================================

MIN="${1:-39}"
LCOV="${2:-coverage/lcov.info}"

if [ ! -f "$LCOV" ]; then
  echo "❌ No existe $LCOV. Ejecuta primero: flutter test --coverage"
  exit 1
fi

awk -F: -v min="$MIN" '
  /^LF:/ { found += $2 }
  /^LH:/ { hit += $2 }
  END {
    if (found == 0) { print "❌ El reporte no tiene líneas instrumentadas."; exit 1 }
    pct = hit * 100 / found
    printf "Cobertura de líneas: %.1f %% (%d de %d). Mínimo: %s %%\n", pct, hit, found, min
    if (pct + 0.0001 < min) { print "❌ La cobertura está por debajo del mínimo."; exit 1 }
    print "✅ Cobertura dentro del umbral."
  }
' "$LCOV"
