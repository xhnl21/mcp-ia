#!/bin/sh
# Prueba de check_archivos_con_prueba.sh con un proyecto Dart y uno TypeScript de mentira.
# Uso: sh kit-agentes/herramientas/hooks-nivel-ci/test_check_archivos_con_prueba.sh
SCRIPT="$(cd "$(dirname "$0")" && pwd)/check_archivos_con_prueba.sh"
TMP=$(mktemp -d); trap 'rm -rf "$TMP"' EXIT
FALLAS=0
espera() { # espera <código> <descripción> <archivos…>
  CODIGO=$1; DESC=$2; shift 2
  sh "$SCRIPT" "$@" >/dev/null; R=$?
  if [ "$R" = "$CODIGO" ]; then echo "✓ $DESC"; else echo "✗ $DESC (salió $R, se esperaba $CODIGO)"; FALLAS=$((FALLAS + 1)); fi
}

mkdir -p "$TMP/dart/lib/core" "$TMP/dart/test/core" && cd "$TMP/dart" && git init -q .
echo 'name: app' > pubspec.yaml
echo 'class A {}' > lib/core/a.dart
echo 'class B {}' > lib/core/b.dart
printf '// sin-prueba: solo dibuja\nclass C {}\n' > lib/core/c.dart
echo 'class D {}' > lib/core/d.g.dart
echo "import 'package:app/core/a.dart';" > test/core/a_test.dart
espera 0 'Dart: importado por una prueba' lib/core/a.dart
espera 1 'Dart: sin prueba se frena' lib/core/b.dart
espera 0 'Dart: exento con sin-prueba' lib/core/c.dart
espera 0 'Dart: los generados no se revisan' lib/core/d.g.dart
espera 0 'Dart: fuera de lib/ no se revisa' test/core/a_test.dart
echo 'class E {}' > lib/core/e.dart
echo "export 'e.dart';" > lib/core/barril.dart
echo "import 'package:app/core/barril.dart';" > test/core/barril_test.dart
espera 0 'Dart: probado por el archivo que lo reexporta' lib/core/e.dart

mkdir -p "$TMP/ts/src/game" "$TMP/ts/tests/unit" && cd "$TMP/ts" && git init -q .
echo 'export const a = 1' > src/game/A.ts
echo 'export const b = 1' > src/game/B.ts
echo 'declare const c: number' > src/game/c.d.ts
echo "import { a } from '../../src/game/A'" > tests/unit/a.spec.ts
espera 0 'TS: importado por una prueba' src/game/A.ts
espera 1 'TS: sin prueba se frena' src/game/B.ts
espera 0 'TS: los .d.ts no se revisan' src/game/c.d.ts
echo "const { b } = await import('@/game/B')" > tests/unit/b.test.ts
espera 0 'TS: import dinámico con @/' src/game/B.ts

[ "$FALLAS" = 0 ] && echo "✅ Todo bien" || { echo "❌ $FALLAS fallas"; exit 1; }
