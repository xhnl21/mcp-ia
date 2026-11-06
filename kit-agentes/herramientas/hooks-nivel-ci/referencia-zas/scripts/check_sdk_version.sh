#!/bin/sh
# ==============================================================================
# Verifica que el Flutter que se usa sea el que fija el proyecto en .fvmrc.
#
# Uso: sh scripts/check_sdk_version.sh
# Lee la versión del Flutter que está primero en el PATH (bin/cache/
# flutter.version.json). Los hooks ponen antes .fvm/flutter_sdk/bin; si fvm
# no instaló esa versión, falla con la instrucción para instalarla.
# Sale con 0 si coincide (o si el proyecto no usa fvm) y con 1 si no.
# ==============================================================================
[ -f .fvmrc ] || exit 0
EXPECTED=$(sed -n 's/.*"flutter"[^"]*"\([^"]*\)".*/\1/p' .fvmrc)
[ -n "$EXPECTED" ] || exit 0

FLUTTER_BIN=$(command -v flutter)
if [ -z "$FLUTTER_BIN" ]; then
  echo "❌ No se encontró flutter. Instala la versión del proyecto: fvm install $EXPECTED"
  exit 1
fi
VERSION_FILE="$(dirname "$FLUTTER_BIN")/cache/flutter.version.json"
ACTUAL=$(sed -n 's/.*"frameworkVersion"[^"]*"\([^"]*\)".*/\1/p' "$VERSION_FILE" 2>/dev/null)

if [ "$ACTUAL" != "$EXPECTED" ]; then
  echo "❌ Flutter $ACTUAL no es el del proyecto ($EXPECTED en .fvmrc)."
  echo "👉 Instálalo con 'fvm install' y úsalo con 'fvm use $EXPECTED' (crea .fvm/flutter_sdk)."
  exit 1
fi
exit 0
