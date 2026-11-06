#!/bin/sh
# ==============================================================================
# Verifica que el código generado esté al día con sus fuentes.
#
# Uso: STAGED_FILES="<rutas, una por línea>" sh scripts/check_generated_code.sh
#   - Textos (lib/l10n/*.arb o l10n.yaml en el commit): flutter gen-l10n.
#   - Base de datos drift (una fuente con «extends Table» o @DriftDatabase en
#     el commit): dart run build_runner build (tarda unos minutos).
# Regenera y falla si el resultado difiere de lo que hay en el disco: hay que
# agregar al commit los archivos regenerados.
# ==============================================================================
STALE=""

if echo "$STAGED_FILES" | grep -Eq '^(lib/l10n/.*\.arb|l10n\.yaml)$'; then
  echo "  Regenerando los textos (flutter gen-l10n)..."
  flutter gen-l10n >/dev/null 2>&1 || { echo "❌ flutter gen-l10n falló."; exit 1; }
  if ! git diff --quiet -- lib/l10n || [ -n "$(git ls-files --others --exclude-standard lib/l10n)" ]; then
    STALE="$STALE lib/l10n"
  fi
fi

DRIFT_SOURCES=""
for file in $(echo "$STAGED_FILES" | grep '\.dart$' | grep -v '\.g\.dart$'); do
  [ -f "$file" ] && grep -Eq 'extends Table|@DriftDatabase' "$file" && DRIFT_SOURCES="$DRIFT_SOURCES $file"
done
if [ -n "$DRIFT_SOURCES" ]; then
  echo "  Regenerando el código de drift (build_runner, tarda unos minutos):$DRIFT_SOURCES"
  dart run build_runner build --delete-conflicting-outputs >/dev/null 2>&1 \
    || { echo "❌ build_runner falló."; exit 1; }
  CHANGED=$(git diff --name-only -- '*.g.dart')
  [ -n "$CHANGED" ] && STALE="$STALE $CHANGED"
fi

if [ -n "$STALE" ]; then
  echo "❌ El código generado no estaba al día y se regeneró:$STALE"
  echo "👉 Revísalo y agrégalo al commit (git add)."
  exit 1
fi
exit 0
