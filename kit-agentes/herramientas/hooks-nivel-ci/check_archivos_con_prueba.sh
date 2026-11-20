#!/bin/sh
# Cada archivo de código nuevo lo tiene que importar alguna prueba, o explicar por qué no en su propio código con
# «// sin-prueba: <motivo>» (por ejemplo, una pantalla o una escena que solo dibuja y se prueba de otra forma).
# Sin esto, el código nuevo sin pruebas recién aparece en el pre-push, cuando la cobertura total baja del mínimo.
#
#   Dart/Flutter (hay pubspec.yaml): lib/**.dart, buscado en test/ e integration_test/ («package:app/x/y.dart» o relativo).
#   TypeScript:                      src/**.ts (salvo .d.ts), buscado en los *.spec.ts y *.test.ts del proyecto.
#   Se saltan los generados (*.g.dart, *.freezed.dart, *.mocks.dart, lib/l10n/, «GENERATED CODE»).
#
# Uso: sh scripts/check_archivos_con_prueba.sh <archivos>   (el pre-commit le pasa los agregados:
#      sh scripts/check_archivos_con_prueba.sh $(git diff --cached --name-only --diff-filter=A))
# Copia canónica: mcp-ia/kit-agentes/herramientas/hooks-nivel-ci/check_archivos_con_prueba.sh (prueba: test_check_archivos_con_prueba.sh).
cd "$(git rev-parse --show-toplevel 2>/dev/null || dirname "$0")" || exit 1
FALTAN=""
# ¿Alguna prueba importa este módulo? «game/Golpe» aparece en '../../src/game/Golpe', '@/game/Golpe' e import('…');
# «a/b.dart», en 'package:app/a/b.dart'. Usa DONDE e INCLUIR del archivo que se revisa.
probado() {
  PATRON="[:/@]$(printf '%s' "$1" | sed 's/[.[\*^$]/\\&/g')['\"]"
  # shellcheck disable=SC2086
  grep -rqE $INCLUIR --exclude-dir=node_modules --exclude-dir=build "$PATRON" $DONDE 2>/dev/null
}
for f in "$@"; do
  case "$f" in
    *.g.dart|*.freezed.dart|*.mocks.dart|*.gr.dart|lib/l10n/*|*.d.ts) continue ;;
    lib/*.dart) [ -f pubspec.yaml ] || continue; MODULO=${f#lib/}; DONDE="test integration_test"; INCLUIR='--include=*_test.dart' ;;
    src/*.ts) MODULO=${f#src/}; MODULO=${MODULO%.ts}; DONDE="."; INCLUIR='--include=*.spec.ts --include=*.test.ts' ;;
    *) continue ;;
  esac
  [ -f "$f" ] || continue
  grep -qE 'sin-prueba:|GENERATED CODE' "$f" && continue
  probado "$MODULO" && continue
  # Dart: también vale si lo prueban por un archivo de lib/ que lo reexporta («export 'b.dart';») o del que es «part».
  if [ "$DONDE" != "." ]; then
    BASE=$(basename "$f" | sed 's/[.[\*^$]/\\&/g')
    for e in $(grep -rlE "^(export|part) '([^']*/)?${BASE}'" lib 2>/dev/null); do probado "${e#lib/}" && continue 2; done
  fi
  FALTAN="$FALTAN $f"
done
[ -z "$FALTAN" ] && exit 0
echo "❌ Archivos nuevos sin ninguna prueba que los importe:"
for f in $FALTAN; do echo "   $f"; done
echo "   Agrega su prueba, o escribe en el archivo «// sin-prueba: <motivo>» si no se puede probar con pruebas unitarias."
exit 1
