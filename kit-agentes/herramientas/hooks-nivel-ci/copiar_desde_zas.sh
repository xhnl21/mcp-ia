#!/bin/sh
# Actualiza referencia-zas/ con la versión vigente de los hooks, el auditor ARC
# y sus scripts en zas. Uso: sh copiar_desde_zas.sh [ruta-de-zas]
# Después: revisar `git diff` en mcp-ia, actualizar la tabla del README si
# cambiaron las reglas, y hacer commit.
set -e
ZAS="${1:-$HOME/Documents/Proyectos/tdc-innovo/zas}"
DEST="$(cd "$(dirname "$0")" && pwd)/referencia-zas"
[ -f "$ZAS/scripts/script_audit_architecture.dart" ] || { echo "No encuentro zas en $ZAS"; exit 1; }

ARCHIVOS="
.githooks/pre-commit.local
.githooks/pre-push.local
.githooks/obligatorio.sh
.gitleaks.toml
.gitlab-ci.yml
.gitlab/merge_request_templates/default.md
docs/devops/configurar_hooks_desde_cero.md
docs/devops/git-hooks.md
scripts/script_audit_architecture.dart
scripts/arc_accessibility.dart
scripts/arc_modules_report.dart
scripts/arc_config.json
scripts/check_audited_screens.dart
scripts/check_coverage.sh
scripts/check_diff_coverage.dart
scripts/check_generated_code.sh
scripts/check_layer_tests.dart
scripts/check_sdk_version.sh
scripts/mr_report.dart
test/scripts/script_audit_architecture_test.dart
test/scripts/arc_modules_report_test.dart
"
rm -rf "$DEST"
for f in $ARCHIVOS; do
  mkdir -p "$DEST/$(dirname "$f")"
  cp "$ZAS/$f" "$DEST/$f"
done
VERSION=$(git -C "$ZAS" log -1 --format='%h %ad' --date=short)
printf 'Copiado de zas %s (%s).\n' "$VERSION" "$(git -C "$ZAS" rev-parse --abbrev-ref HEAD)" > "$DEST/VERSION.txt"
echo "✓ referencia-zas actualizada desde zas $VERSION"
