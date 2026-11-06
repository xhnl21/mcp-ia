// scripts/check_layer_tests.dart

import 'dart:io';

/// Resultado de la auditoría de pruebas espejo en `application` e `infrastructure`.
class LayerTestsResult {
  /// Archivos nuevos (`A`) sin prueba espejo (bloquean el commit).
  final List<String> missingNew;

  /// Archivos modificados o renombrados (`M`, `R...`) sin prueba espejo (aviso).
  final List<String> missingModified;

  const LayerTestsResult({
    required this.missingNew,
    required this.missingModified,
  });
}

/// Comprueba que los archivos preparados en `lib/application/` y
/// `lib/infrastructure/` tengan su prueba espejo en `test/`.
///
/// Uso:
/// ```bash
/// dart run scripts/check_layer_tests.dart
/// ```
void main() {
  final gitResult = Process.runSync('git', [
    'diff',
    '--cached',
    '--name-status',
    '--diff-filter=ACMR',
  ]);

  final nameStatus = gitResult.stdout as String;
  final result = checkLayerTests(
    nameStatus: nameStatus,
    exists: (path) => File(path).existsSync(),
    read: (path) {
      final file = File(path);
      return file.existsSync() ? file.readAsStringSync() : '';
    },
  );

  if (result.missingModified.isNotEmpty) {
    stdout.writeln(
      '⚠️ Archivos modificados sin prueba espejo (agrégala cuando puedas):',
    );
    for (final path in result.missingModified) {
      stdout.writeln('  - $path -> ${mirrorTestPath(path)}');
    }
  }

  if (result.missingNew.isNotEmpty) {
    stderr.writeln(
      '❌ Archivos nuevos de application/infrastructure sin prueba:',
    );
    for (final path in result.missingNew) {
      stderr.writeln('  - $path -> ${mirrorTestPath(path)}');
    }
    exit(1);
  }

  exit(0);
}

/// Devuelve la ruta de la prueba espejo para un archivo de `lib/`.
String mirrorTestPath(String libPath) {
  final relative = libPath.substring(
    'lib/'.length,
    libPath.length - '.dart'.length,
  );
  return 'test/${relative}_test.dart';
}

/// Evalúa la salida de `git diff --cached --name-status` y separa los archivos
/// de `lib/application/` y `lib/infrastructure/` sin prueba espejo en nuevos
/// (`missingNew`) y modificados/renombrados (`missingModified`).
LayerTestsResult checkLayerTests({
  required String nameStatus,
  required bool Function(String path) exists,
  required String Function(String path) read,
}) {
  final stagedTests = <String>{};
  final entries = <({String status, String path})>[];

  for (final rawLine in nameStatus.split(RegExp(r'\r?\n'))) {
    final line = rawLine.trim();
    if (line.isEmpty) continue;

    final parts = line.split('\t');
    if (parts.length < 2) continue;

    final status = parts.first.trim();
    final path = parts.last.trim();

    if (path.startsWith('test/') && path.endsWith('_test.dart')) {
      stagedTests.add(path);
    }

    entries.add((status: status, path: path));
  }

  final missingNew = <String>[];
  final missingModified = <String>[];

  for (final entry in entries) {
    final path = entry.path;
    if (!_isTargetLayerFile(path)) continue;

    final content = read(path);
    if (!_requiresUnitTest(content)) continue;

    final expectedTest = mirrorTestPath(path);
    if (exists(expectedTest) || stagedTests.contains(expectedTest)) {
      continue;
    }

    if (entry.status == 'A') {
      missingNew.add(path);
    } else if (entry.status == 'M' || entry.status.startsWith('R')) {
      missingModified.add(path);
    }
  }

  return LayerTestsResult(
    missingNew: missingNew,
    missingModified: missingModified,
  );
}

bool _isTargetLayerFile(String path) {
  final inTargetLayer =
      path.startsWith('lib/application/') ||
      path.startsWith('lib/infrastructure/');
  if (!inTargetLayer || !path.endsWith('.dart')) {
    return false;
  }
  if (path.endsWith('.g.dart') || path.endsWith('.freezed.dart')) {
    return false;
  }
  return true;
}

/// Heurística para decidir si un archivo de Dart contiene código ejecutable
/// que requiera prueba unitaria:
/// 1. Se eliminan los comentarios de línea (`//...`) y de bloque (`/*...*/`).
/// 2. Si todas las líneas restantes son directivas (`export`, `import`, `part`,
///    `library`), es un barril y no necesita prueba.
/// 3. Se busca al menos un cuerpo ejecutable de función, método o getter:
///    - una expresión flecha (`=>`), o
///    - una llave `{` que abra un cuerpo después de `)` (permitiendo `async`,
///      `async*`, `sync*` o lista de inicializadores `: ...` entre `)` y `{`), o
///    - un getter con bloque (`get <nombre> {`).
///    De este modo se ignoran interfaces abstractas sin cuerpos (incluso si
///    tienen parámetros con nombre `{...}` antes de `)`), `enum` simples y
///    archivos de solo constantes.
bool _requiresUnitTest(String source) {
  final stripped = _stripComments(source).trim();
  if (stripped.isEmpty) return false;

  final statements = stripped
      .split(RegExp(r'\r?\n'))
      .map((line) => line.trim())
      .where((line) => line.isNotEmpty)
      .toList();

  final onlyDirectives = statements.every(
    (line) =>
        line.startsWith('export ') ||
        line.startsWith('import ') ||
        line.startsWith('part ') ||
        line.startsWith('library '),
  );
  if (onlyDirectives) return false;

  if (stripped.contains('=>')) return true;

  final bodyAfterParens = RegExp(
    r'\)(\s*(async\*?|sync\*)?\s*|\s*:[^{;]+)\{',
    multiLine: true,
  );
  if (bodyAfterParens.hasMatch(stripped)) return true;

  final getterBody = RegExp(r'\bget\s+[A-Za-z_]\w*\s*(async\*?\s*)?\{');
  if (getterBody.hasMatch(stripped)) return true;

  return false;
}

String _stripComments(String source) {
  final withoutBlock = source.replaceAll(RegExp(r'/\*[\s\S]*?\*/'), '');
  return withoutBlock.replaceAll(RegExp(r'//.*$', multiLine: true), '');
}
