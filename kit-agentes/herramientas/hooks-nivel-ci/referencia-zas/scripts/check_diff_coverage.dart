// scripts/check_diff_coverage.dart

import 'dart:io';

final RegExp _hunkHeaderPattern = RegExp(
  r'^@@ -\d+(?:,\d+)? \+(\d+)(?:,(\d+))? @@',
);
final RegExp _directivePattern = RegExp(r'^(import|export|part)\b');

bool _isEligibleLibFile(String path) {
  if (!path.startsWith('lib/') || !path.endsWith('.dart')) {
    return false;
  }
  if (path.endsWith('.g.dart') || path.endsWith('.freezed.dart')) {
    return false;
  }
  return true;
}

String? _normalizeLibPath(String rawPath) {
  final normalized = rawPath.trim().replaceAll(r'\', '/');
  if (normalized.startsWith('lib/')) {
    return normalized;
  }
  final index = normalized.lastIndexOf('/lib/');
  if (index != -1) {
    return normalized.substring(index + 1);
  }
  return null;
}

/// Cuerpo de función, método o getter: `) {`, `) async {`, `) =>`, `get x {`.
final RegExp _bodyPattern = RegExp(
  r'(\)\s*(async\*?|sync\*)?\s*(\{|=>))|(\bget\s+\w+\s*(\{|=>))',
);

/// Un archivo sin cuerpos de función (interfaz abstracta, enum simple,
/// constantes) no tiene líneas ejecutables aunque ninguna prueba lo cargue.
bool _hasExecutableBody(String source) => _bodyPattern.hasMatch(source);

bool _isCountableLineWithoutLcov(String rawLine) {
  final trimmed = rawLine.trim();
  if (trimmed.isEmpty) {
    return false;
  }
  if (trimmed.startsWith('//') ||
      trimmed.startsWith('/*') ||
      trimmed.startsWith('*')) {
    return false;
  }
  if (_directivePattern.hasMatch(trimmed)) {
    return false;
  }
  if (trimmed == '}' || trimmed == '{' || trimmed == ');') {
    return false;
  }
  return true;
}

/// Ruta lib/... → (línea → veces ejecutada). Normaliza rutas absolutas a lib/...
Map<String, Map<int, int>> parseLcov(String lcov) {
  final result = <String, Map<int, int>>{};
  String? currentFile;

  for (final rawLine in lcov.split(RegExp(r'\r?\n'))) {
    final line = rawLine.trim();
    if (line.startsWith('SF:')) {
      final path = _normalizeLibPath(line.substring(3));
      if (path != null && _isEligibleLibFile(path)) {
        currentFile = path;
        result.putIfAbsent(currentFile, () => <int, int>{});
      } else {
        currentFile = null;
      }
    } else if (line == 'end_of_record') {
      currentFile = null;
    } else if (line.startsWith('DA:') && currentFile != null) {
      final parts = line.substring(3).split(',');
      if (parts.length >= 2) {
        final lineNumber = int.tryParse(parts[0].trim());
        final count = int.tryParse(parts[1].trim());
        if (lineNumber != null && count != null) {
          final fileLines = result[currentFile]!;
          fileLines[lineNumber] = (fileLines[lineNumber] ?? 0) + count;
        }
      }
    }
  }

  return result;
}

/// Ruta lib/... → líneas agregadas o modificadas, a partir de `git diff -U0`.
Map<String, Set<int>> parseAddedLines(String diff) {
  final result = <String, Set<int>>{};
  String? currentFile;

  for (final rawLine in diff.split(RegExp(r'\r?\n'))) {
    if (rawLine.startsWith('+++ ')) {
      final target = rawLine.substring(4).trim();
      if (target == '/dev/null') {
        currentFile = null;
      } else {
        final path = target.startsWith('b/') ? target.substring(2) : target;
        if (_isEligibleLibFile(path)) {
          currentFile = path;
          result.putIfAbsent(currentFile, () => <int>{});
        } else {
          currentFile = null;
        }
      }
    } else if (currentFile != null && rawLine.startsWith('@@ ')) {
      final match = _hunkHeaderPattern.firstMatch(rawLine);
      if (match != null) {
        final start = int.parse(match.group(1)!);
        final countGroup = match.group(2);
        final count = countGroup != null ? int.parse(countGroup) : 1;
        final lines = result[currentFile]!;
        for (var i = 0; i < count; i++) {
          lines.add(start + i);
        }
      }
    }
  }

  return result;
}

class DiffCoverage {
  final int executable;
  final int covered;
  final Map<String, List<int>> uncovered;

  const DiffCoverage({
    required this.executable,
    required this.covered,
    required this.uncovered,
  });

  double get percent => executable == 0 ? 100 : (covered * 100) / executable;
}

DiffCoverage computeDiffCoverage(
  Map<String, Map<int, int>> lcov,
  Map<String, Set<int>> added, {
  String Function(String path)? readSource,
}) {
  var executable = 0;
  var covered = 0;
  final uncovered = <String, List<int>>{};

  final files = added.keys.where(_isEligibleLibFile).toList()..sort();
  for (final file in files) {
    final addedSet = added[file];
    if (addedSet == null || addedSet.isEmpty) {
      continue;
    }
    final sortedLines = addedSet.toList()..sort();
    final fileUncovered = <int>[];

    if (lcov.containsKey(file)) {
      final fileLcov = lcov[file]!;
      for (final line in sortedLines) {
        if (!fileLcov.containsKey(line)) {
          continue;
        }
        executable++;
        if (fileLcov[line]! > 0) {
          covered++;
        } else {
          fileUncovered.add(line);
        }
      }
    } else if (readSource != null) {
      final source = readSource(file);
      if (!_hasExecutableBody(source)) {
        continue;
      }
      final sourceLines = source.split(RegExp(r'\r?\n'));
      for (final line in sortedLines) {
        if (line < 1 || line > sourceLines.length) {
          continue;
        }
        if (_isCountableLineWithoutLcov(sourceLines[line - 1])) {
          executable++;
          fileUncovered.add(line);
        }
      }
    } else {
      for (final line in sortedLines) {
        executable++;
        fileUncovered.add(line);
      }
    }

    if (fileUncovered.isNotEmpty) {
      uncovered[file] = fileUncovered;
    }
  }

  return DiffCoverage(
    executable: executable,
    covered: covered,
    uncovered: uncovered,
  );
}

String _resolveDefaultBase() {
  final res = Process.runSync('git', ['merge-base', 'HEAD', 'origin/dev']);
  if (res.exitCode == 0) {
    final out = (res.stdout as String).trim();
    if (out.isNotEmpty) {
      return out;
    }
  }
  return 'origin/dev';
}

String _formatNumber(double value) {
  if (value == value.roundToDouble()) {
    return value.toInt().toString();
  }
  return value.toStringAsFixed(1);
}

void main(List<String> args) {
  String? baseRef;
  double minPercent = 80;
  String lcovPath = 'coverage/lcov.info';

  for (var i = 0; i < args.length; i++) {
    switch (args[i]) {
      case '--base':
        if (i + 1 < args.length) {
          baseRef = args[++i];
        }
      case '--min':
        if (i + 1 < args.length) {
          minPercent = double.tryParse(args[++i]) ?? minPercent;
        }
      case '--lcov':
        if (i + 1 < args.length) {
          lcovPath = args[++i];
        }
    }
  }

  final lcovFile = File(lcovPath);
  if (!lcovFile.existsSync()) {
    stderr.writeln(
      '❌ No existe $lcovPath. Ejecuta primero: flutter test --coverage',
    );
    exit(1);
  }

  final resolvedBase = baseRef ?? _resolveDefaultBase();
  final diffResult = Process.runSync('git', [
    'diff',
    '-U0',
    '$resolvedBase...HEAD',
    '--',
    'lib/',
  ]);

  final lcov = parseLcov(lcovFile.readAsStringSync());
  final added = parseAddedLines(diffResult.stdout as String);
  final coverage = computeDiffCoverage(
    lcov,
    added,
    readSource: (path) {
      final file = File(path);
      return file.existsSync() ? file.readAsStringSync() : '';
    },
  );

  if (coverage.executable == 0) {
    stdout.writeln('Sin líneas ejecutables cambiadas en lib/.');
    exit(0);
  }

  final pctText = coverage.percent.toStringAsFixed(1);
  final minText = _formatNumber(minPercent);
  stdout.writeln(
    'Cobertura de las líneas cambiadas: $pctText % '
    '(${coverage.covered} de ${coverage.executable}). Mínimo: $minText %',
  );

  if (coverage.percent < minPercent) {
    for (final entry in coverage.uncovered.entries.take(20)) {
      stdout.writeln('  ${entry.key}: ${entry.value.join(', ')}');
    }
    exit(1);
  }

  exit(0);
}
