// scripts/mr_report.dart

/// Informe ejecutivo para la descripción de un merge request.
///
/// Lee los commits de la rama frente a la base (por defecto `origin/dev`),
/// los agrupa por tipo de Conventional Commits y, salvo con `--rapido`,
/// corre analyze, la auditoría ARC y la cobertura. Imprime el Markdown y lo
/// guarda en `build/mr_resumen.md` para pegarlo en GitLab.
///
/// ```sh
/// dart run scripts/mr_report.dart              # con verificación
/// dart run scripts/mr_report.dart --rapido     # solo los commits
/// dart run scripts/mr_report.dart --base origin/main
/// ```
library;

import 'dart:io';

/// Un commit de la rama: tipo, área (scope) y descripción.
typedef MrCommit = ({String hash, String type, String scope, String subject});

/// Títulos de cada tipo, en el orden del informe.
const Map<String, String> commitSections = {
  'feat': 'Funciones nuevas',
  'fix': 'Correcciones',
  'refactor': 'Refactorizaciones',
  'perf': 'Rendimiento',
  'test': 'Pruebas',
  'docs': 'Documentación',
  'ci': 'Integración y hooks',
  'build': 'Integración y hooks',
  'style': 'Estilo',
  'chore': 'Mantenimiento',
};

final _conventional = RegExp(r'^(\w+)(?:\(([^)]*)\))?!?:\s*(.+)$');

/// Convierte `git log --format=%h%x09%s` en commits. Los que no siguen
/// Conventional Commits quedan como `otros`; los merges se omiten.
List<MrCommit> parseCommits(String log) => [
  for (final line in log.split('\n'))
    if (line.contains('\t') && !line.split('\t')[1].startsWith('Merge '))
      _parse(line.split('\t').first, line.split('\t').skip(1).join('\t')),
];

MrCommit _parse(String hash, String subject) {
  final match = _conventional.firstMatch(subject.trim());
  final type = match?.group(1)?.toLowerCase() ?? '';
  return (
    hash: hash.trim(),
    type: commitSections.containsKey(type) ? type : 'otros',
    scope: match?.group(2) ?? '',
    subject: match?.group(3) ?? subject.trim(),
  );
}

/// Resultado de una verificación (`flutter analyze`, ARC, cobertura…).
typedef MrCheck = ({String name, String result});

/// Arma el informe en Markdown.
String buildReport({
  required String branch,
  required String base,
  required List<MrCommit> commits,
  required String diffStat,
  required List<MrCheck> checks,
  required String signature,
}) {
  final count = <String, int>{};
  for (final c in commits) {
    count[c.type] = (count[c.type] ?? 0) + 1;
  }
  final scopes = <String, int>{};
  for (final c in commits.where((c) => c.scope.isNotEmpty)) {
    scopes[c.scope] = (scopes[c.scope] ?? 0) + 1;
  }
  final topScopes =
      (scopes.entries.toList()..sort((a, b) => b.value.compareTo(a.value)))
          .take(5)
          .map((e) => e.key);

  String plural(int n, String one, String many) => '$n ${n == 1 ? one : many}';
  final kinds = [
    if (count['feat'] case final n?)
      plural(n, 'función nueva', 'funciones nuevas'),
    if (count['fix'] case final n?) plural(n, 'corrección', 'correcciones'),
    if (count['refactor'] case final n?)
      plural(n, 'refactorización', 'refactorizaciones'),
    if (count['test'] case final n?)
      plural(n, 'commit de pruebas', 'commits de pruebas'),
  ];

  final out = StringBuffer()
    ..writeln('## Resumen ejecutivo')
    ..writeln()
    ..writeln(
      '`$branch` → `${base.replaceFirst('origin/', '')}`: '
      '${plural(commits.length, 'commit', 'commits')}'
      '${diffStat.isEmpty ? '' : ' ($diffStat)'}.'
      '${kinds.isEmpty ? '' : ' Incluye ${_joinEs(kinds)}.'}',
    );
  if (topScopes.isNotEmpty) {
    out.writeln(
      'Áreas principales: ${topScopes.map((s) => '`$s`').join(', ')}.',
    );
  }
  out
    ..writeln()
    ..writeln('## Cambios');
  final groups = <String, List<MrCommit>>{};
  for (final c in commits) {
    final title = commitSections[c.type] ?? 'Otros';
    groups.putIfAbsent(title, () => []).add(c);
  }
  final order = [
    ...{...commitSections.values},
    'Otros',
  ];
  for (final title in order.where(groups.containsKey)) {
    out
      ..writeln()
      ..writeln('**$title**')
      ..writeln()
      ..writeln('| Área | Qué hace | Commit |')
      ..writeln('|---|---|---|');
    for (final c in groups[title] ?? const <MrCommit>[]) {
      final subject = c.subject.replaceAll('|', r'\|');
      out.writeln(
        '| ${c.scope.isEmpty ? '—' : c.scope} | $subject | ${c.hash} |',
      );
    }
  }
  out
    ..writeln()
    ..writeln('## Verificación')
    ..writeln();
  if (checks.isEmpty) {
    out.writeln('- Sin verificar (generado con `--rapido`).');
  }
  for (final check in checks) {
    out.writeln('- ${check.name}: ${check.result}');
  }
  out
    ..writeln()
    ..writeln('## Pendiente fuera de este MR')
    ..writeln()
    ..writeln('- Ninguno.')
    ..writeln()
    ..writeln(signature);
  return out.toString();
}

/// «a», «a y b», «a, b y c».
String _joinEs(List<String> items) => items.length < 2
    ? items.join()
    : '${items.sublist(0, items.length - 1).join(', ')} y ${items.last}';

/// Última línea útil de una salida (sin códigos de color).
String _lastLine(String text, Pattern match) {
  final clean = text.replaceAll(RegExp(r'\x1B\[[0-9;]*m'), '');
  return clean
      .split('\n')
      .lastWhere((l) => l.contains(match), orElse: () => '')
      .trim();
}

/// Mínimo global del pre-push (`COBERTURA_GLOBAL_MINIMA`), o 0.
int _globalMinimum() {
  final hook = File('.githooks/pre-push.local');
  final text = hook.existsSync() ? hook.readAsStringSync() : '';
  final match = RegExp(r'COBERTURA_GLOBAL_MINIMA=(\d+)').firstMatch(text);
  return int.tryParse(match?.group(1) ?? '') ?? 0;
}

String _run(String cmd, List<String> args) {
  final r = Process.runSync(cmd, args, runInShell: true);
  return '${r.stdout}\n${r.stderr}';
}

List<MrCheck> _verify() {
  final analyze = _lastLine(
    _run('flutter', ['analyze']),
    RegExp('issue|No issues'),
  );
  final arc = _lastLine(
    _run('dart', ['run', 'scripts/script_audit_architecture.dart']),
    RegExp('APROBADO|ERROR'),
  );
  final checks = <MrCheck>[
    (
      name: '`flutter analyze`',
      result: analyze.contains('No issues') ? 'sin problemas' : analyze,
    ),
    (
      name: 'Auditoría ARC',
      result: arc.contains('APROBADO') ? 'aprobada' : arc,
    ),
  ];
  if (File('coverage/lcov.info').existsSync()) {
    final diff = _lastLine(
      _run('dart', ['run', 'scripts/check_diff_coverage.dart']),
      'Cobertura de las líneas cambiadas',
    );
    final global = _lastLine(
      _run('sh', ['scripts/check_coverage.sh', '${_globalMinimum()}']),
      'Cobertura de líneas',
    );
    checks
      ..add((
        name: 'Cobertura de las líneas cambiadas',
        result: diff.replaceFirst('Cobertura de las líneas cambiadas: ', ''),
      ))
      ..add((
        name: 'Cobertura global',
        result: global.replaceFirst('Cobertura de líneas: ', ''),
      ));
  } else {
    checks.add((
      name: 'Cobertura',
      result: 'sin `coverage/lcov.info`: corre `flutter test --coverage`',
    ));
  }
  return checks;
}

void main(List<String> args) {
  final baseIndex = args.indexOf('--base');
  final base = baseIndex >= 0 && baseIndex + 1 < args.length
      ? args[baseIndex + 1]
      : 'origin/dev';
  final branch = _run('git', [
    'rev-parse',
    '--abbrev-ref',
    'HEAD',
  ]).trim().split('\n').first;
  final log =
      Process.runSync('git', ['log', '--format=%h%x09%s', '$base..HEAD']).stdout
          as String;
  final stat =
      (Process.runSync('git', ['diff', '--shortstat', '$base...HEAD']).stdout
              as String)
          .trim()
          .replaceAll(' files changed', ' archivos')
          .replaceAll(' file changed', ' archivo')
          .replaceAll(RegExp(r' insertions?\(\+\)'), ' líneas agregadas')
          .replaceAll(RegExp(r' deletions?\(-\)'), ' borradas');
  String git(String key) =>
      (Process.runSync('git', ['config', key]).stdout as String).trim();

  final report = buildReport(
    branch: branch,
    base: base,
    commits: parseCommits(log),
    diffStat: stat,
    checks: args.contains('--rapido') ? const [] : _verify(),
    signature: 'Signed-off-by: ${git('user.name')} <${git('user.email')}>',
  );
  stdout.write(report);
  File('build/mr_resumen.md')
    ..createSync(recursive: true)
    ..writeAsStringSync(report);
  stderr.writeln('\nGuardado en build/mr_resumen.md');
}
