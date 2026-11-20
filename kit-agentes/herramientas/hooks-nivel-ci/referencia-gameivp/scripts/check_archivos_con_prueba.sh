#!/bin/sh
# Cada archivo .ts nuevo de src/ lo tiene que importar alguna prueba de tests/unit/, o explicar por qué no en su código
# con «// sin-prueba: <motivo>» (por ejemplo, una escena que solo dibuja y se prueba con Cypress).
# Sin esto, el código nuevo sin pruebas recién aparece en el pre-push, cuando la cobertura total baja del mínimo.
# Uso: sh scripts/check_archivos_con_prueba.sh src/game/Nuevo.ts ...   (el pre-commit le pasa los archivos agregados)
cd "$(dirname "$0")/.." || exit 1
FALTAN=""
for f in "$@"; do
  case "$f" in src/*.d.ts) continue ;; src/*.ts) ;; *) continue ;; esac
  [ -f "$f" ] || continue
  grep -q 'sin-prueba:' "$f" && continue
  # «game/GolpeMundo» aparece en '../../src/game/GolpeMundo', '@/game/GolpeMundo' e import('…/GolpeMundo').
  MODULO=${f#src/}; MODULO=${MODULO%.ts}
  grep -rqE "[/@]${MODULO}['\"]" tests/unit 2>/dev/null || FALTAN="$FALTAN $f"
done
[ -z "$FALTAN" ] && exit 0
echo "❌ Archivos nuevos sin ninguna prueba en tests/unit/ que los importe:"
for f in $FALTAN; do echo "   $f"; done
echo "   Agrega su prueba, o escribe en el archivo «// sin-prueba: <motivo>» si no se puede probar con vitest."
exit 1
