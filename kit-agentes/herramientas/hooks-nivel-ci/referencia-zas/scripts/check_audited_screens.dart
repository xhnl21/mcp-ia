// scripts/check_audited_screens.dart

import 'dart:io';

/// Widgets interactivos que, usados directamente en una pantalla, deben
/// registrar el toque con `auditedCallback` o `AuditableAction`. Los
/// componentes compartidos (`ButtonPrimary`, `SidebarItem`…) se registran
/// solos y no cuentan.
final RegExp interactiveWidget = RegExp(
  r'\b(IconButton|InkWell|GestureDetector|TextButton|ElevatedButton|'
  r'OutlinedButton|ListTile|Switch|Checkbox|PopupMenuButton|DropdownButton)'
  r'(\.\w+)?\s*\(',
);

/// Marcas de que el archivo registra sus toques.
final RegExp auditMarker = RegExp(
  r'\b(auditedCallback|auditedValueChanged|'
  r'AuditableAction)\s*[<(]',
);

/// Comentario que exime a un archivo, con su motivo:
/// `// auditoria: exento - <motivo>`.
final RegExp exemptMarker = RegExp(r'//\s*auditoria:\s*exento\s*-\s*\S');

/// Comprueba que las pantallas preparadas para el commit registren los
/// toques del usuario (auditoría de movimientos).
///
/// Uso:
/// ```bash
/// dart run scripts/check_audited_screens.dart
/// ```
void main() {
  final gitResult = Process.runSync('git', [
    'diff',
    '--cached',
    '--name-status',
    '--diff-filter=ACMR',
  ]);

  final missing = unauditedScreens(
    nameStatus: gitResult.stdout as String,
    read: (path) {
      final file = File(path);
      return file.existsSync() ? file.readAsStringSync() : '';
    },
  );

  if (missing.isEmpty) exit(0);

  stderr.writeln('❌ Pantallas con toques sin registrar en la auditoría:');
  for (final path in missing) {
    stderr.writeln('  - $path');
  }
  stderr.writeln(
    '👉 Envuelve el onPressed/onTap con auditedCallback(...) '
    '(lib/presentation/widgets/audit_scope.dart) o con AuditableAction. '
    'Lo que escribe el usuario nunca se registra. Si el archivo no lo '
    'necesita, agrega «// auditoria: exento - <motivo>».',
  );
  exit(1);
}

/// Devuelve las pantallas de `lib/presentation/screens/` de la salida de
/// `git diff --cached --name-status` que tienen widgets interactivos
/// directos sin registro de auditoría.
List<String> unauditedScreens({
  required String nameStatus,
  required String Function(String path) read,
}) {
  final missing = <String>[];
  for (final rawLine in nameStatus.split(RegExp(r'\r?\n'))) {
    final line = rawLine.trim();
    if (line.isEmpty) continue;
    final parts = line.split('\t');
    if (parts.length < 2) continue;
    final path = parts.last.trim();
    if (!path.startsWith('lib/presentation/screens/') ||
        !path.endsWith('.dart') ||
        path.endsWith('.g.dart')) {
      continue;
    }
    if (needsAudit(read(path))) missing.add(path);
  }
  return missing;
}

/// `true` si [source] usa widgets interactivos directos y no registra los
/// toques ni tiene la marca de exención. Ignora las líneas de comentario.
bool needsAudit(String source) {
  if (exemptMarker.hasMatch(source)) return false;
  final code = source
      .split('\n')
      .where((line) {
        final trimmed = line.trimLeft();
        return !(trimmed.startsWith('//') ||
            trimmed.startsWith('*') ||
            trimmed.startsWith('/*'));
      })
      .join('\n');
  return interactiveWidget.hasMatch(code) && !auditMarker.hasMatch(code);
}
