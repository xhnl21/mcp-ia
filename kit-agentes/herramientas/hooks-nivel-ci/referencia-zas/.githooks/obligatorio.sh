#!/bin/sh
# ==============================================================================
# Verificación obligatoria de ZAS: se ejecuta incluso con SKIP_PRE_COMMIT=1.
# Auditoría de arquitectura ARC-001 a ARC-029 (scripts/script_audit_architecture.dart).
# ==============================================================================
# Usa el SDK que fija el proyecto con fvm (.fvmrc): con otro Dart en el PATH,
# `dart run` falla con «Can't load Kernel binary: Invalid SDK hash».
[ -x .fvm/flutter_sdk/bin/dart ] && PATH="$PWD/.fvm/flutter_sdk/bin:$PATH" && export PATH
if ! dart run scripts/script_audit_architecture.dart >/dev/null 2>&1; then
  echo "❌ [PRE-COMMIT] La auditoría de arquitectura no se puede omitir y encontró violaciones."
  echo "👉 Ejecuta 'dart run scripts/script_audit_architecture.dart' para ver el detalle."
  exit 1
fi
exit 0
