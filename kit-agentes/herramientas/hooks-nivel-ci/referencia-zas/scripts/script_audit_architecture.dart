// scripts/script_audit_architecture.dart

import 'dart:convert';
import 'dart:io';

import 'package:analyzer/dart/analysis/utilities.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/token.dart';
import 'package:analyzer/dart/ast/visitor.dart';
import 'package:analyzer/source/line_info.dart';

import 'arc_accessibility.dart';
import 'arc_modules_report.dart';
import 'check_audited_screens.dart' as taps;

const String _defaultConfigPath = 'scripts/arc_config.json';
const Set<String> _baselineAllowedRules = {
  'ARC-028',
  'ARC-029',
  'ARC-025',
  'ARC-020',
  'ARC-022',
  'ARC-007',
  'ARC-008',
  'ARC-009',
  'ARC-010',
  'ARC-018',
  'ARC-019',
};

/// ARC-018: único archivo que puede leer el id del comercio de la sesión a
/// mano (define `getCurrentMerchantId()`).
const String _merchantIdSource =
    'lib/presentation/cubits/auth/handlers/login_session_handler.dart';

/// ARC-018: datos de la sesión y claves del id del comercio.
const Set<String> _sessionDataNames = {'loginData', 'sessionData'};
const Set<String> _merchantIdKeys = {'merchantId', 'merchant_id'};

/// Máximo de líneas por archivo de `lib/` (ARC-009).
const int maxFileLines = 500;

/// Máximo de imports por archivo de `lib/` (ARC-010).
const int maxFileImports = 15;

/// Clases base de estado que deben usar `SafeEmitMixin` (ARC-011).
const Set<String> _stateBaseClasses = {
  'Cubit',
  'HydratedCubit',
  'Bloc',
  'HydratedBloc',
};

/// Representa una violación individual detectada por el auditor.
class ArcViolation {
  final String rule;
  final String file;
  final int line;
  final String code;
  final String reason;

  /// Cuánto cuenta para la línea base: 1 por defecto; en ARC-009 y ARC-010,
  /// las líneas o imports de más, para que un archivo listado no pueda crecer.
  final int weight;

  const ArcViolation({
    required this.rule,
    required this.file,
    required this.line,
    required this.code,
    required this.reason,
    this.weight = 1,
  });
}

int _weightOf(Iterable<ArcViolation> violations) =>
    violations.fold(0, (sum, v) => sum + v.weight);

/// Representa una excepción temporal configurada en `scripts/arc_config.json`.
class ArcException {
  final String regla;
  final String archivo;
  final String motivo;
  final String vence;

  const ArcException({
    required this.regla,
    required this.archivo,
    required this.motivo,
    required this.vence,
  });

  factory ArcException.fromJson(Map<String, dynamic> json) {
    final regla = json['regla'];
    final archivo = json['archivo'];
    final motivo = json['motivo'];
    final vence = json['vence'];
    if (regla is! String ||
        archivo is! String ||
        motivo is! String ||
        vence is! String) {
      throw const FormatException(
        'Cada excepción debe incluir regla, archivo, motivo y vence como String.',
      );
    }
    DateTime.parse(vence);
    return ArcException(
      regla: regla,
      archivo: archivo,
      motivo: motivo,
      vence: vence,
    );
  }

  Map<String, dynamic> toJson() => {
    'regla': regla,
    'archivo': archivo,
    'motivo': motivo,
    'vence': vence,
  };
}

/// Configuración de excepciones y línea base del auditor arquitectónico.
class ArcConfig {
  final List<ArcException> excepciones;
  final Map<String, Map<String, int>> lineaBase;

  const ArcConfig({this.excepciones = const [], this.lineaBase = const {}});

  factory ArcConfig.fromJson(Map<String, dynamic> json) {
    final rawExcepciones = json['excepciones'];
    if (rawExcepciones is! List) {
      throw const FormatException('El campo "excepciones" debe ser una lista.');
    }
    final excepciones = rawExcepciones.map((item) {
      if (item is! Map<String, dynamic>) {
        throw const FormatException('Elemento inválido en "excepciones".');
      }
      return ArcException.fromJson(item);
    }).toList();

    final rawLineaBase = json['linea_base'];
    if (rawLineaBase is! Map<String, dynamic>) {
      throw const FormatException('El campo "linea_base" debe ser un objeto.');
    }
    final lineaBase = <String, Map<String, int>>{};
    for (final entry in rawLineaBase.entries) {
      final ruleMap = entry.value;
      if (ruleMap is! Map<String, dynamic>) {
        throw FormatException(
          'La línea base de ${entry.key} debe ser un mapa de archivo a conteo.',
        );
      }
      final parsedFiles = <String, int>{};
      for (final fileEntry in ruleMap.entries) {
        final count = fileEntry.value;
        if (count is! int || count < 0) {
          throw FormatException(
            'El conteo de ${fileEntry.key} en ${entry.key} debe ser un entero no negativo.',
          );
        }
        parsedFiles[fileEntry.key] = count;
      }
      lineaBase[entry.key] = parsedFiles;
    }

    return ArcConfig(excepciones: excepciones, lineaBase: lineaBase);
  }

  Map<String, dynamic> toJson() => {
    'excepciones': excepciones.map((e) => e.toJson()).toList(),
    'linea_base': lineaBase,
  };
}

/// Analiza el código fuente [source] correspondiente a la ruta [path] (`lib/...`)
/// mediante el AST de `analyzer` y devuelve las violaciones encontradas.
List<ArcViolation> auditSource(String path, String source) {
  final normalizedPath = path.replaceAll('\\', '/');
  final result = parseString(
    content: source,
    path: normalizedPath,
    throwIfDiagnostics: false,
  );
  final lines = source.split(RegExp(r'\r?\n'));
  final visitor = _ArcAstVisitor(
    filePath: normalizedPath,
    lineInfo: result.lineInfo,
    lines: lines,
    errorHelpers: _errorHelpersOf(result.unit),
  );
  result.unit.accept(visitor);
  return [
    ...visitor.violations,
    ..._auditFileSize(normalizedPath, lines, result.unit),
    ..._auditIgnores(normalizedPath, result.unit, lines),
    ..._auditTaps(normalizedPath, source, lines),
  ];
}

/// ARC-029: una pantalla con toques directos (IconButton, InkWell,
/// GestureDetector, ListTile, Switch…) los registra con `auditedCallback`
/// o `AuditableAction` (misma regla que `check_audited_screens.dart`, pero
/// sobre todo `lib/`, no solo lo del commit).
List<ArcViolation> _auditTaps(String path, String source, List<String> lines) {
  if (!path.startsWith('lib/presentation/screens/') ||
      path.endsWith('.g.dart') ||
      !taps.needsAudit(source)) {
    return const [];
  }
  return [
    ArcViolation(
      rule: 'ARC-029',
      file: path,
      line: 1,
      code: lines.isEmpty ? '' : lines.first.trim(),
      reason:
          'La pantalla tiene toques directos sin registrar en la auditoría de movimientos: envuelve el onPressed/onTap con auditedCallback(...) o usa AuditableAction. Si no lo necesita, agrega «// auditoria: exento - <motivo>».',
    ),
  ];
}

/// Funciones y métodos del archivo que reportan el error con
/// [CentralErrorHandler] (p. ej. un `_failure(e, st)`): un catch que los
/// llama cumple ARC-013.
Set<String> _errorHelpersOf(CompilationUnit unit) {
  final collector = _ErrorHelperCollector();
  unit.accept(collector);
  return collector.helpers;
}

/// Junta los métodos y funciones (de clases, extensiones, mixins o locales)
/// cuyo cuerpo usa `CentralErrorHandler`.
class _ErrorHelperCollector extends RecursiveAstVisitor<void> {
  final helpers = <String>{};

  @override
  void visitMethodDeclaration(MethodDeclaration node) {
    if (_HandlerFinder.of(node.body).usesCentralHandler) {
      helpers.add(node.name.lexeme);
    }
    super.visitMethodDeclaration(node);
  }

  @override
  void visitFunctionDeclaration(FunctionDeclaration node) {
    if (_HandlerFinder.of(node.functionExpression.body).usesCentralHandler) {
      helpers.add(node.name.lexeme);
    }
    super.visitFunctionDeclaration(node);
  }
}

/// ARC-020: nombres que delatan un dato sensible (`token`, `password`,
/// `pin`, `otp`…) o personal (teléfono y número de documento). `pin` solo
/// como palabra: no `pinned` ni `spinner`.
final _sensitiveName = RegExp(
  r'token|password|passwd|secret|otp|cvv|clave|contrase|pincode|^pin$|^pin_|pin$|phone|telefono|docnumber|dni',
);

/// Primer identificador con nombre sensible dentro de un nodo. No cuentan
/// los booleanos (`hasToken`, `isPinValid`) ni las comprobaciones que no
/// muestran el valor (`token.isEmpty`, `pin.length`, `otp.isValid`,
/// `token == null`).
class _SensitiveNameFinder extends RecursiveAstVisitor<void> {
  String? found;

  static const _safeProperties = {
    'isEmpty',
    'isNotEmpty',
    'length',
    'isValid',
    'errorMessage',
  };

  @override
  void visitSimpleIdentifier(SimpleIdentifier node) {
    final name = node.name;
    if (found == null &&
        !name.startsWith(RegExp('has|is|should')) &&
        _sensitiveName.hasMatch(name.toLowerCase()) &&
        !_onlyChecked(node)) {
      found = name;
    }
    super.visitSimpleIdentifier(node);
  }

  static bool _onlyChecked(SimpleIdentifier node) {
    final parent = node.parent;
    return switch (parent) {
      PropertyAccess(:final target, :final propertyName) =>
        target == node && _safeProperties.contains(propertyName.name),
      PrefixedIdentifier(:final prefix, :final identifier) =>
        prefix == node && _safeProperties.contains(identifier.name),
      BinaryExpression(:final leftOperand, :final rightOperand) =>
        leftOperand is NullLiteral || rightOperand is NullLiteral,
      _ => false,
    };
  }
}

/// Lo que hace un bloque con el error, leído del AST (sin confundirse con
/// el texto de cadenas o comentarios): si relanza, si usa
/// `CentralErrorHandler` y qué funciones o métodos llama.
class _HandlerFinder extends RecursiveAstVisitor<void> {
  bool rethrows = false;
  bool usesCentralHandler = false;

  /// Usa `AuditLogger` directamente (la propia infraestructura de auditoría
  /// y el arranque registran así sus errores).
  bool usesAuditLogger = false;
  final calls = <String>{};

  static _HandlerFinder of(AstNode node) {
    final finder = _HandlerFinder();
    node.accept(finder);
    return finder;
  }

  @override
  void visitRethrowExpression(RethrowExpression node) {
    rethrows = true;
    super.visitRethrowExpression(node);
  }

  @override
  void visitThrowExpression(ThrowExpression node) {
    rethrows = true;
    super.visitThrowExpression(node);
  }

  @override
  void visitSimpleIdentifier(SimpleIdentifier node) {
    if (node.name == 'CentralErrorHandler') usesCentralHandler = true;
    if (node.name == 'AuditLogger') usesAuditLogger = true;
    super.visitSimpleIdentifier(node);
  }

  @override
  void visitMethodInvocation(MethodInvocation node) {
    calls.add(node.methodName.name);
    super.visitMethodInvocation(node);
  }
}

/// ARC-025: widgets de una pantalla (`screens/<módulo>/widgets/`, también
/// `widget/` y subcarpetas como `screens/auth/two_factor/widgets/`).
final _screenWidget = RegExp(r'^lib/presentation/screens/.+/widgets?/');

/// ARC-025: estado (cubits, blocs y sus widgets) y lógica (casos de uso,
/// fachadas, GetIt) que no van en la capa de diseño.
final _stateOrLogicName = RegExp(
  r'(Cubit|Bloc|UseCase|Facade)$|^(Bloc(Builder|Listener|Consumer|Provider|Selector)|MultiBloc(Provider|Listener)|RepositoryProvider|GetIt)$',
);

/// ARC-025: `context.read<X>()`, `context.watch<X>()`, `context.select<X, Y>()`.
const Set<String> _contextLookups = {'read', 'watch', 'select'};

/// ARC-022 y ARC-024: nombres de repositorios y datasources.
final _repositoryName = RegExp(r'Repository(Impl)?$');
final _dataAccessName = RegExp(
  r'(Repository|RepositoryImpl|Datasource|DataSource)$',
);

/// ARC-021: `// ignore: regla - motivo`. El motivo va tras un guion.
final _ignoreComment = RegExp(r'^//\s*ignore(?:_for_file)?:(.*)$');
final _ignoreReason = RegExp(r'\s-\s*\S');

/// ARC-021: todo `// ignore:` o `// ignore_for_file:` de `lib/` explica por
/// qué apaga el lint; sin motivo, cualquier regla estricta se apaga con una
/// línea. Los archivos generados (`*.g.dart`, `lib/l10n/`) no cuentan.
List<ArcViolation> _auditIgnores(
  String path,
  CompilationUnit unit,
  List<String> lines,
) {
  if (!path.startsWith('lib/') ||
      path.endsWith('.g.dart') ||
      path.startsWith('lib/l10n/')) {
    return const [];
  }
  final violations = <ArcViolation>[];
  void check(Token? comment) {
    for (var c = comment; c != null; c = c.next) {
      final match = _ignoreComment.firstMatch(c.lexeme);
      if (match == null || _ignoreReason.hasMatch(match.group(1) ?? '')) {
        continue;
      }
      final line = unit.lineInfo.getLocation(c.offset).lineNumber;
      violations.add(
        ArcViolation(
          rule: 'ARC-021',
          file: path,
          line: line,
          code: lines[line - 1].trim(),
          reason:
              'Un ignore del analizador lleva su motivo: // ignore: regla - motivo.',
        ),
      );
    }
  }

  Token? token = unit.beginToken;
  while (token != null) {
    check(token.precedingComments);
    if (token.isEof) break;
    token = token.next;
  }
  return violations;
}

/// ARC-009 y ARC-010: archivo de `lib/` con más de [maxFileLines] líneas o
/// más de [maxFileImports] imports. El peso es lo que sobra.
List<ArcViolation> _auditFileSize(
  String path,
  List<String> lines,
  CompilationUnit unit,
) {
  if (!path.startsWith('lib/')) return const [];
  final violations = <ArcViolation>[];
  final lineCount = lines.isNotEmpty && lines.last.isEmpty
      ? lines.length - 1
      : lines.length;
  if (lineCount > maxFileLines) {
    violations.add(
      ArcViolation(
        rule: 'ARC-009',
        file: path,
        line: maxFileLines + 1,
        code: '$lineCount líneas',
        reason:
            'El archivo supera las $maxFileLines líneas: divídelo en piezas con una responsabilidad.',
        weight: lineCount - maxFileLines,
      ),
    );
  }
  final imports = unit.directives.whereType<ImportDirective>().toList();
  if (imports.length > maxFileImports) {
    final extra = imports[maxFileImports];
    final lineInfo = unit.lineInfo;
    final line = lineInfo.getLocation(extra.offset).lineNumber;
    violations.add(
      ArcViolation(
        rule: 'ARC-010',
        file: path,
        line: line,
        code: '${imports.length} imports',
        reason:
            'El archivo supera los $maxFileImports imports: usa un barril o separa responsabilidades.',
        weight: imports.length - maxFileImports,
      ),
    );
  }
  return violations;
}

/// ARC-014: `BlocProvider<X>` o `BlocProvider.value<X>` (también `X?`).
final _globalProvider = RegExp(r'\bBlocProvider(?:\.value)?<(\w+)\??>');

/// ARC-014: cada Cubit/Bloc global de `lib/app/providers.dart` debe
/// reiniciarse en `resetSessionCubits` (`logout_helper.dart`), para que el
/// cierre de sesión no deje datos del usuario anterior.
List<ArcViolation> auditSessionReset({
  required String providersPath,
  required String providersSource,
  required String logoutSource,
}) {
  final reset = RegExp(
    r'context\.read<(\w+)>\(\)\s*\.\s*reset\(\)',
  ).allMatches(logoutSource).map((m) => m.group(1)).toSet();
  final lines = providersSource.split(RegExp(r'\r?\n'));
  final violations = <ArcViolation>[];
  final seen = <String>{};
  for (var i = 0; i < lines.length; i++) {
    for (final m in _globalProvider.allMatches(lines[i])) {
      final name = m.group(1) ?? '';
      if (reset.contains(name) || !seen.add(name)) continue;
      violations.add(
        ArcViolation(
          rule: 'ARC-014',
          file: providersPath,
          line: i + 1,
          code: lines[i].trim(),
          reason:
              '$name es global y no se reinicia al cerrar sesión: agrégalo a resetSessionCubits (logout_helper.dart).',
        ),
      );
    }
  }
  return violations;
}

/// ARC-026: un módulo con datos (interfaz, repositorio o datasource) tiene
/// interfaz en domain y repositorio en infrastructure, y además caso de uso
/// si tiene cubit o pantalla. Es lo que el reporte `--modulos` marca como
/// «falta …».
List<ArcViolation> auditModuleLayers(Iterable<String> paths) => [
  for (final gap in moduleGaps(paths))
    ArcViolation(
      rule: 'ARC-026',
      file: gap.file,
      line: 1,
      code: 'módulo ${gap.module}',
      reason:
          'Al módulo ${gap.module} le falta ${gap.missing.join(', ')} del flujo DDD (ver dart run scripts/script_audit_architecture.dart --modulos).',
    ),
];

/// Aplica las excepciones con vencimiento y la línea base (solo ARC-007 y ARC-008)
/// sobre la lista de violaciones encontradas [found].
List<ArcViolation> applyConfig(
  List<ArcViolation> found,
  ArcConfig config,
  DateTime today,
) {
  final todayDate = DateTime(today.year, today.month, today.day);
  final activeExceptions = <String>{};

  for (final exc in config.excepciones) {
    final parsed = DateTime.parse(exc.vence);
    final venceDate = DateTime(parsed.year, parsed.month, parsed.day);
    final normalizedFile = exc.archivo.replaceAll('\\', '/');
    if (todayDate.isAfter(venceDate)) {
      stdout.writeln(
        'Excepción vencida: $normalizedFile (${exc.regla}, venció ${exc.vence})',
      );
    } else {
      activeExceptions.add('${exc.regla}::$normalizedFile');
    }
  }

  final afterExceptions = found
      .where(
        (v) => !activeExceptions.contains(
          '${v.rule}::${v.file.replaceAll('\\', '/')}',
        ),
      )
      .toList();

  final baselineViolationsByRuleAndFile =
      <String, Map<String, List<ArcViolation>>>{
        for (final rule in _baselineAllowedRules) rule: {},
      };
  final finalViolations = <ArcViolation>[];

  for (final v in afterExceptions) {
    if (_baselineAllowedRules.contains(v.rule)) {
      final byFile = baselineViolationsByRuleAndFile[v.rule]!;
      byFile.putIfAbsent(v.file, () => []).add(v);
    } else {
      finalViolations.add(v);
    }
  }

  for (final rule in _baselineAllowedRules) {
    final ruleBaseline = config.lineaBase[rule] ?? const <String, int>{};
    final byFile = baselineViolationsByRuleAndFile[rule]!;
    int suppressedCount = 0;
    int suppressedFiles = 0;

    final sortedBaselineFiles = ruleBaseline.keys.toList()..sort();
    for (final file in sortedBaselineFiles) {
      final allowed = ruleBaseline[file]!;
      final actual = _weightOf(byFile[file] ?? const []);
      if (actual < allowed) {
        stdout.writeln('👉 Baja la línea base de $file ($rule) a $actual');
      }
    }

    final sortedActualFiles = byFile.keys.toList()..sort();
    for (final file in sortedActualFiles) {
      final fileViolations = byFile[file]!;
      final allowed = ruleBaseline[file];
      if (allowed != null && _weightOf(fileViolations) <= allowed) {
        suppressedCount += _weightOf(fileViolations);
        suppressedFiles += 1;
      } else {
        finalViolations.addAll(fileViolations);
      }
    }

    if (ruleBaseline.isNotEmpty || suppressedCount > 0) {
      stdout.writeln(
        'Línea base $rule: $suppressedCount pendientes en $suppressedFiles archivos',
      );
    }
  }

  return finalViolations;
}

void main(List<String> args) {
  final generateBaseline = args.contains('--generar-linea-base');
  final modulesReport = args.contains('--modulos');

  stdout.writeln(
    '====================================================================',
  );
  stdout.writeln(
    '🛡️  INICIANDO AUDITORÍA DE ARQUITECTURA PARANOICA (ARC-001 a ARC-029)',
  );
  stdout.writeln(
    '====================================================================\n',
  );

  final config = _loadConfig(_defaultConfigPath);

  final libDir = Directory('lib');
  if (!libDir.existsSync()) {
    stderr.writeln('❌ Error: No se encontró el directorio lib/.');
    exit(1);
  }

  final allDartFiles =
      libDir
          .listSync(recursive: true)
          .whereType<File>()
          .where(
            (file) =>
                file.path.endsWith('.dart') &&
                !file.path.endsWith('.g.dart') &&
                !file.path.endsWith('.freezed.dart'),
          )
          .toList()
        ..sort((a, b) => a.path.compareTo(b.path));

  final foundViolations = <ArcViolation>[];
  for (final file in allDartFiles) {
    final normalizedPath = file.path.replaceAll('\\', '/');
    final source = file.readAsStringSync();
    foundViolations.addAll(auditSource(normalizedPath, source));
  }
  const providersPath = 'lib/app/providers.dart';
  const logoutPath = 'lib/presentation/widgets/logout_helper.dart';
  if (File(providersPath).existsSync() && File(logoutPath).existsSync()) {
    foundViolations.addAll(
      auditSessionReset(
        providersPath: providersPath,
        providersSource: File(providersPath).readAsStringSync(),
        logoutSource: File(logoutPath).readAsStringSync(),
      ),
    );
  }

  // ARC-026: el flujo DDD de cada módulo (lo que --modulos marca «falta»).
  foundViolations.addAll(
    auditModuleLayers(allDartFiles.map((f) => f.path.replaceAll('\\', '/'))),
  );

  if (modulesReport) {
    stdout.writeln(
      buildModulesReport(
        allDartFiles.map((f) => f.path.replaceAll('\\', '/')),
        foundViolations.map((v) => (file: v.file, rule: v.rule)),
      ),
    );
    stdout.writeln(
      'Violaciones DDD: ARC-022 (presentation usa repositorios), ARC-023 '
      '(application importa infrastructure), ARC-024 (repositorio sin '
      'interfaz), incluidas las de la línea base. Diseño: usos de cubits, '
      'casos de uso o el locator en views/ y screens/*/widgets/ (ARC-025). '
      '«sin capa de datos»: sin '
      'interfaz, repositorio ni datasource propios (UI o lógica local).',
    );
    return;
  }

  if (generateBaseline) {
    _updateBaselineFile(
      configPath: _defaultConfigPath,
      config: config,
      found: foundViolations,
      today: DateTime.now(),
    );
    return;
  }

  final activeViolations = applyConfig(foundViolations, config, DateTime.now());

  for (final violation in activeViolations) {
    _reportViolation(violation);
  }

  stdout.writeln(
    '--------------------------------------------------------------------',
  );
  stdout.writeln('📊 RESUMEN DE AUDITORÍA ARQUITECTÓNICA:');
  stdout.writeln('   Total de archivos analizados: ${allDartFiles.length}');
  stdout.writeln(
    '   Total de violaciones detectadas: ${activeViolations.length}',
  );

  if (activeViolations.isEmpty) {
    stdout.writeln('\n✅ [APROBADO]: Cero violaciones detectadas.');
    exit(0);
  } else {
    stderr.writeln(
      '\n❌ [RECHAZADO]: Se encontraron ${activeViolations.length} violaciones arquitectónicas bloqueantes.',
    );
    exit(1);
  }
}

ArcConfig _loadConfig(String path) {
  final file = File(path);
  if (!file.existsSync()) {
    stderr.writeln(
      '❌ Error: No se encontró el archivo de configuración $path.',
    );
    exit(1);
  }
  try {
    final rawContent = file.readAsStringSync();
    final decoded = jsonDecode(rawContent);
    if (decoded is! Map<String, dynamic>) {
      stderr.writeln(
        '❌ Error: El archivo $path debe contener un objeto JSON en la raíz.',
      );
      exit(1);
    }
    return ArcConfig.fromJson(decoded);
  } on Object catch (e) {
    stderr.writeln('❌ Error: Configuración inválida en $path: $e');
    exit(1);
  }
}

void _updateBaselineFile({
  required String configPath,
  required ArcConfig config,
  required List<ArcViolation> found,
  required DateTime today,
}) {
  final todayDate = DateTime(today.year, today.month, today.day);
  final activeExceptions = <String>{};
  for (final exc in config.excepciones) {
    final parsed = DateTime.parse(exc.vence);
    final venceDate = DateTime(parsed.year, parsed.month, parsed.day);
    if (!todayDate.isAfter(venceDate)) {
      activeExceptions.add(
        '${exc.regla}::${exc.archivo.replaceAll('\\', '/')}',
      );
    }
  }

  final filtered = found.where(
    (v) => !activeExceptions.contains(
      '${v.rule}::${v.file.replaceAll('\\', '/')}',
    ),
  );

  final newLineaBase = <String, Map<String, int>>{};

  for (final rule in _baselineAllowedRules) {
    final currentCounts = <String, int>{};
    for (final v in filtered.where((v) => v.rule == rule)) {
      currentCounts[v.file] = (currentCounts[v.file] ?? 0) + v.weight;
    }

    final existingForRule = config.lineaBase[rule] ?? const <String, int>{};
    final updatedForRule = <String, int>{};

    if (existingForRule.isEmpty) {
      final sortedFiles = currentCounts.keys.toList()..sort();
      for (final file in sortedFiles) {
        updatedForRule[file] = currentCounts[file]!;
      }
    } else {
      final allFiles = <String>{
        ...existingForRule.keys,
        ...currentCounts.keys,
      }.toList()..sort();

      for (final file in allFiles) {
        final existingCount = existingForRule[file];
        final currentCount = currentCounts[file] ?? 0;

        if (existingCount == null) {
          if (currentCount > 0) {
            stderr.writeln(
              'Rechazado ($rule): no se permite agregar archivo nuevo $file ($currentCount violaciones).',
            );
            exitCode = 1;
          }
        } else if (currentCount > existingCount) {
          stderr.writeln(
            'Rechazado ($rule): no se permite subir $file de $existingCount a $currentCount.',
          );
          exitCode = 1;
          updatedForRule[file] = existingCount;
        } else if (currentCount > 0) {
          updatedForRule[file] = currentCount;
        }
      }
    }

    newLineaBase[rule] = updatedForRule;
  }

  final updatedConfig = ArcConfig(
    excepciones: config.excepciones,
    lineaBase: newLineaBase,
  );
  final prettyJson = const JsonEncoder.withIndent(
    '  ',
  ).convert(updatedConfig.toJson());
  File(configPath).writeAsStringSync('$prettyJson\n');
  stdout.writeln('✅ Línea base actualizada en $configPath.');
}

class _ArcAstVisitor extends RecursiveAstVisitor<void> {
  final String filePath;
  final LineInfo lineInfo;
  final List<String> lines;
  final List<ArcViolation> violations = [];

  /// Helpers del archivo que usan CentralErrorHandler (ARC-013).
  final Set<String> errorHelpers;

  _ArcAstVisitor({
    required this.filePath,
    required this.lineInfo,
    required this.lines,
    this.errorHelpers = const {},
  });

  int _lineOf(int offset) => lineInfo.getLocation(offset).lineNumber;

  String _codeAtLine(int lineNumber) {
    if (lineNumber < 1 || lineNumber > lines.length) return '';
    return lines[lineNumber - 1].trim();
  }

  void _addViolation(String rule, int offset, String reason) {
    final line = _lineOf(offset);
    violations.add(
      ArcViolation(
        rule: rule,
        file: filePath,
        line: line,
        code: _codeAtLine(line),
        reason: reason,
      ),
    );
  }

  void _checkDirective(UriBasedDirective node) {
    final rawUri = node.uri.stringValue;
    if (rawUri == null) return;
    final resolvedUri = _resolveUri(filePath, rawUri);

    // ARC-001: Aislamiento de capas
    if (filePath.startsWith('lib/presentation/') ||
        filePath.startsWith('lib/domain/')) {
      if (resolvedUri.startsWith('lib/infrastructure/')) {
        _addViolation(
          'ARC-001',
          node.offset,
          'La capa de presentation/domain tiene estrictamente prohibido importar la capa de infrastructure.',
        );
      }
    }

    // ARC-023: el caso de uso depende de interfaces de domain, nunca de la
    // implementación (la conecta el locator).
    if (filePath.startsWith('lib/application/') &&
        resolvedUri.startsWith('lib/infrastructure/')) {
      _addViolation(
        'ARC-023',
        node.offset,
        'application no importa infrastructure: depende de la interfaz de domain y el locator conecta la implementación.',
      );
    }

    if (filePath.startsWith('lib/application/')) {
      if (resolvedUri.startsWith('lib/presentation/')) {
        _addViolation(
          'ARC-001',
          node.offset,
          'La capa de application tiene estrictamente prohibido importar la capa de presentation.',
        );
      }
    }

    // ARC-025: la capa de diseño no importa casos de uso, el locator ni
    // flutter_bloc (en views/ el import de flutter_bloc ya es ARC-003).
    if (_inDesignLayer &&
        (resolvedUri.startsWith('lib/application/usecases/') ||
            resolvedUri.startsWith('lib/config/locator/') ||
            (!filePath.contains('/views/') &&
                (rawUri == 'package:flutter_bloc/flutter_bloc.dart' ||
                    rawUri.startsWith('package:flutter_bloc/'))))) {
      _addDesignViolation(node.offset, 'importa $rawUri');
    }

    // ARC-003: Vistas agnósticas
    if (filePath.contains('/views/')) {
      if (rawUri == 'package:flutter_bloc' ||
          rawUri.startsWith('package:flutter_bloc/') ||
          rawUri.endsWith('_cubit.dart') ||
          rawUri.endsWith('_bloc.dart') ||
          resolvedUri.endsWith('_cubit.dart') ||
          resolvedUri.endsWith('_bloc.dart')) {
        _addViolation(
          'ARC-003',
          node.offset,
          'Los widgets dentro de carpetas views/ deben ser agnósticos y libres de BLoC/Cubit.',
        );
      }
    }

    // ARC-006: lib/domain/ debe ser Dart puro
    if (filePath.startsWith('lib/domain/')) {
      if (rawUri == 'package:flutter' ||
          rawUri.startsWith('package:flutter/') ||
          resolvedUri.startsWith('lib/application/') ||
          resolvedUri.startsWith('lib/presentation/') ||
          resolvedUri.startsWith('lib/infrastructure/')) {
        _addViolation(
          'ARC-006',
          node.offset,
          'La capa de domain es Dart puro: prohibido importar Flutter, application, presentation o infrastructure.',
        );
      }
    }
  }

  @override
  void visitImportDirective(ImportDirective node) {
    _checkDirective(node);
    super.visitImportDirective(node);
  }

  @override
  void visitExportDirective(ExportDirective node) {
    _checkDirective(node);
    super.visitExportDirective(node);
  }

  /// ARC-012: el archivo configura el pinning de certificados.
  late final bool _hasPinning = lines.any(
    (line) => line.contains('CertificatePinningConfig'),
  );

  void _checkHttpClient(String typeName, int offset) {
    if (!filePath.startsWith('lib/') || _hasPinning) return;
    if (typeName != 'Dio' && typeName != 'HttpClient') return;
    _addViolation(
      'ARC-012',
      offset,
      'Cliente HTTP ($typeName) sin pinning: aplica CertificatePinningConfig (OWASP MASVS-NETWORK-2).',
    );
  }

  /// ARC-015: un listener que muestra un diálogo o SnackBar según un campo
  /// del estado (`state.status == error`) debe tener un `listenWhen` que lo
  /// compare con el estado anterior; si no, el aviso se repite con cualquier
  /// otra emisión mientras el campo siga igual. Los listeners que solo
  /// preguntan el tipo (`state is XError`) reaccionan a eventos y no cuentan.
  void _checkBlocListener(String name, ArgumentList args, int offset) {
    if (name != 'BlocListener' && name != 'BlocConsumer') return;
    Expression? arg(String key) {
      for (final a in args.arguments.whereType<NamedArgument>()) {
        if (a.name.lexeme == key) return a.argumentExpression;
      }
      return null;
    }

    final listener = arg('listener');
    if (listener is! FunctionExpression) return;
    final params = listener.parameters?.parameters ?? const [];
    final stateName = params.length > 1 ? params[1].name?.lexeme ?? '' : '';
    if (stateName.isEmpty || !_showsNoticeOnField(listener.body, stateName)) {
      return;
    }
    final listenWhen = arg('listenWhen');
    final whenParams = listenWhen is FunctionExpression
        ? listenWhen.parameters?.parameters ?? const <FormalParameter>[]
        : const <FormalParameter>[];
    final previous = whenParams.isNotEmpty
        ? whenParams.first.name?.lexeme ?? ''
        : '';
    final usesPrevious =
        listenWhen is FunctionExpression &&
        previous.isNotEmpty &&
        !previous.startsWith('_') &&
        RegExp('\\b$previous\\b').hasMatch(listenWhen.body.toSource());
    if (!usesPrevious) {
      _addViolation(
        'ARC-015',
        offset,
        '$name muestra un aviso según un campo del estado sin un listenWhen que lo compare con el anterior: el aviso se repite con cualquier otra emisión.',
      );
    }
  }

  /// Si algún `if` del listener muestra un aviso y su condición compara un
  /// campo del estado (`state.status == x`, `state.message != null`).
  static bool _showsNoticeOnField(FunctionBody body, String stateName) {
    final notice = RegExp(r'show\w*Dialog|showModal\w*|showSnackBar');
    final field = RegExp('\\b$stateName\\.\\w+[\\w.?]*\\s*(==|!=)');
    final finder = _IfFinder();
    body.accept(finder);
    return finder.ifs.any(
      (i) =>
          field.hasMatch(i.expression.toSource()) &&
          notice.hasMatch(i.thenStatement.toSource()),
    );
  }

  @override
  void visitInstanceCreationExpression(InstanceCreationExpression node) {
    _checkAccessibility(node);
    _checkBlocListener(
      node.constructorName.type.name.lexeme,
      node.argumentList,
      node.offset,
    );
    _checkHttpClient(
      node.constructorName.type.name.lexeme,
      node.constructorName.offset,
    );
    super.visitInstanceCreationExpression(node);
  }

  @override
  void visitClassDeclaration(ClassDeclaration node) {
    final superName = node.extendsClause?.superclass.name.lexeme;
    final mixins =
        node.withClause?.mixinTypes.map((t) => t.name.lexeme).toSet() ??
        const <String>{};
    if (filePath.startsWith('lib/') &&
        _stateBaseClasses.contains(superName) &&
        !mixins.contains('SafeEmitMixin')) {
      _addViolation(
        'ARC-011',
        node.namePart.typeName.offset,
        '${node.namePart.typeName.lexeme} extiende $superName sin SafeEmitMixin: un emit tras close() lanzaría StateError.',
      );
    }
    if (filePath.startsWith('lib/') && superName == 'Equatable') {
      _checkEquatableProps(node);
    }
    _checkRepositoryContract(node);
    super.visitClassDeclaration(node);
  }

  /// ARC-024: una clase `…Repository` o `…RepositoryImpl` de
  /// `lib/infrastructure/repositories/` implementa una interfaz de domain;
  /// si no, el caso de uso no tiene contra qué programar y no se puede
  /// cambiar la implementación ni simularla en las pruebas.
  void _checkRepositoryContract(ClassDeclaration node) {
    final name = node.namePart.typeName.lexeme;
    if (!filePath.startsWith('lib/infrastructure/repositories/') ||
        node.abstractKeyword != null ||
        name.startsWith('_') ||
        !_repositoryName.hasMatch(name) ||
        node.implementsClause != null) {
      return;
    }
    _addViolation(
      'ARC-024',
      node.namePart.typeName.offset,
      '$name no implementa una interfaz de domain (lib/domain/repositories/): el caso de uso debe depender de la interfaz.',
    );
  }

  /// ARC-022: presentation no usa repositorios ni datasources (ni como
  /// tipo, ni con `locator<XRepository>()`, ni creándolos): va por un caso
  /// de uso registrado en el locator.
  /// ARC-025: vistas (`views/`) y widgets de pantalla
  /// (`screens/<módulo>/widgets/`) son diseño: reciben datos y callbacks.
  late final bool _inDesignLayer =
      filePath.startsWith('lib/presentation/') &&
      (filePath.contains('/views/') || _screenWidget.hasMatch(filePath));

  void _addDesignViolation(int offset, String what) => _addViolation(
    'ARC-025',
    offset,
    'La vista o el widget de diseño $what: recibe datos y callbacks por constructor y deja el cubit, los casos de uso y el locator a la pantalla coordinadora.',
  );

  @override
  void visitSimpleIdentifier(SimpleIdentifier node) {
    if (_inDesignLayer && node.name == 'locator') {
      _addDesignViolation(node.offset, 'usa el locator');
    }
    super.visitSimpleIdentifier(node);
  }

  @override
  void visitNamedType(NamedType node) {
    final name = node.name.lexeme;
    if (_inDesignLayer && _stateOrLogicName.hasMatch(name)) {
      _addDesignViolation(node.offset, 'usa $name');
    }
    if (filePath.startsWith('lib/presentation/') &&
        _dataAccessName.hasMatch(name)) {
      _addViolation(
        'ARC-022',
        node.offset,
        'presentation usa $name: pide un caso de uso al locator en lugar del repositorio o el datasource.',
      );
    }
    super.visitNamedType(node);
  }

  /// ARC-016: un campo de un `Equatable` que falta en `props` no cuenta para
  /// la igualdad: si solo cambia ese campo, el estado nuevo se considera
  /// igual, el Cubit no lo emite y la pantalla no se actualiza.
  void _checkEquatableProps(ClassDeclaration node) {
    final fields = <Token>[];
    String? props;
    for (final member in node.body.childEntities) {
      if (member is FieldDeclaration && !member.isStatic) {
        fields.addAll(member.fields.variables.map((v) => v.name));
      } else if (member is MethodDeclaration && member.name.lexeme == 'props') {
        props = member.body.toSource();
      }
    }
    // Sin props propio (heredado de una base) no se puede comprobar aquí.
    if (props == null) return;
    for (final field in fields) {
      if (!RegExp('\\b${field.lexeme}\\b').hasMatch(props)) {
        _addViolation(
          'ARC-016',
          field.offset,
          '${field.lexeme} no está en props de ${node.namePart.typeName.lexeme}: un cambio solo de ese campo no se emite.',
        );
      }
    }
  }

  @override
  void visitMethodInvocation(MethodInvocation node) {
    _checkSensitiveLog(node);
    _checkAccessibility(node);
    final target = node.target;
    if (_inDesignLayer &&
        ((target is SimpleIdentifier &&
                target.name == 'context' &&
                _contextLookups.contains(node.methodName.name) &&
                node.typeArguments != null) ||
            (target == null &&
                _stateOrLogicName.hasMatch(node.methodName.name)))) {
      _addDesignViolation(
        node.offset,
        'usa ${target == null ? node.methodName.name : 'context.${node.methodName.name}<…>()'}',
      );
    }
    // ARC-022: sin resolución de tipos, `XRepository()` se lee como llamada.
    if (node.target == null &&
        filePath.startsWith('lib/presentation/') &&
        _dataAccessName.hasMatch(node.methodName.name)) {
      _addViolation(
        'ARC-022',
        node.offset,
        'presentation crea ${node.methodName.name}: pide un caso de uso al locator en lugar del repositorio o el datasource.',
      );
    }
    // Sin resolución de tipos, `Dio()` y `HttpClient()` se leen como llamadas.
    if (node.target == null) {
      _checkHttpClient(node.methodName.name, node.methodName.offset);
      _checkBlocListener(node.methodName.name, node.argumentList, node.offset);
    }
    if (filePath.startsWith('lib/presentation/screens/') &&
        node.methodName.name == 'setState') {
      _addViolation(
        'ARC-002',
        node.methodName.offset,
        'El uso de setState() está prohibido en pantallas reactivas gestionadas por BLoC/Cubit.',
      );
    }
    super.visitMethodInvocation(node);
  }

  @override
  void visitSimpleStringLiteral(SimpleStringLiteral node) {
    final value = node.value;
    // ARC-017: una clave escrita en el código se extrae del binario.
    if (RegExp(r'PRAGMA\s+(re)?key', caseSensitive: false).hasMatch(value)) {
      _addViolation(
        'ARC-017',
        node.offset,
        'Clave de cifrado escrita en el código: léela del almacenamiento seguro (p. ej. SecureKeyService) e interpólala.',
      );
    }
    if (value.startsWith('http://') &&
        !value.contains('www.w3.org') &&
        !value.contains('schemas.android')) {
      _addViolation(
        'ARC-004',
        node.offset,
        'Prohibido el uso de strings http:// en código fuente. Requiere TLS universal https:// (OWASP MASVS-NETWORK-1).',
      );
    }
    super.visitSimpleStringLiteral(node);
  }

  @override
  void visitPostfixExpression(PostfixExpression node) {
    if (filePath.startsWith('lib/domain/') &&
        node.operator.type == TokenType.BANG) {
      _addViolation(
        'ARC-005',
        node.operator.offset,
        'Operador force-unwrap (!) inseguro detectado en capa de Dominio. Use tipos Nullable o Result/Either.',
      );
    } else if (filePath.startsWith('lib/') &&
        node.operator.type == TokenType.BANG) {
      // ARC-019: fuera del dominio un `!` sobre un dato nulo tira
      // «Null check operator used on a null value» (pantalla roja o en blanco).
      _addViolation(
        'ARC-019',
        node.operator.offset,
        'Operador force-unwrap (!) fuera del dominio. Use ?., ??, if (x case final v?) o una variable local promovida.',
      );
    }
    super.visitPostfixExpression(node);
  }

  @override
  void visitIndexExpression(IndexExpression node) {
    final index = node.index;
    if (filePath.startsWith('lib/') &&
        filePath != _merchantIdSource &&
        index is SimpleStringLiteral &&
        _merchantIdKeys.contains(index.value) &&
        _isSessionData(node.target)) {
      _addViolation(
        'ARC-018',
        node.offset,
        'Lee el id del comercio de la sesión con loginCubit.getCurrentMerchantId(), no a mano.',
      );
    }
    super.visitIndexExpression(node);
  }

  /// ARC-020: un `Logger.*` no recibe tokens, contraseñas, PIN, OTP ni
  /// claves: quedan en el log del teléfono de los builds de desarrollo, que
  /// se copia y se comparte al depurar (Logger no imprime en release). Se
  /// miran los identificadores de los argumentos (también dentro de `${}`),
  /// no el texto fijo del mensaje.
  void _checkSensitiveLog(MethodInvocation node) {
    final target = node.target;
    if (!filePath.startsWith('lib/') ||
        target is! SimpleIdentifier ||
        target.name != 'Logger') {
      return;
    }
    final finder = _SensitiveNameFinder();
    node.argumentList.accept(finder);
    final name = finder.found;
    if (name != null) {
      _addViolation(
        'ARC-020',
        node.offset,
        'El registro incluye «$name»: no se registran tokens, contraseñas, PIN, OTP ni claves.',
      );
    }
  }

  /// `getData()`, `loginData` o `sessionData` (también `x.loginData`).
  static bool _isSessionData(Expression? target) {
    final t = target?.unParenthesized;
    return switch (t) {
      MethodInvocation() =>
        t.methodName.name == 'getData' && t.argumentList.arguments.isEmpty,
      SimpleIdentifier() => _sessionDataNames.contains(t.name),
      PrefixedIdentifier() => _sessionDataNames.contains(t.identifier.name),
      PropertyAccess() => _sessionDataNames.contains(t.propertyName.name),
      _ => false,
    };
  }

  /// ARC-028: capas de cada módulo cuyos errores se auditan (los
  /// datasources tienen ARC-013; la auditoría no se audita a sí misma).
  late final bool _auditsErrors =
      (filePath.startsWith('lib/application/') ||
          filePath.startsWith('lib/infrastructure/') ||
          filePath.startsWith('lib/presentation/cubits/')) &&
      !filePath.startsWith('lib/infrastructure/audit/') &&
      !filePath.startsWith('lib/infrastructure/services/audit_') &&
      filePath != 'lib/application/utils/central_error_handler.dart';

  /// El catch vacío de application/infrastructure ya es ARC-007.
  bool _emptyCatchIsArc007(CatchClause node) =>
      node.body.statements.isEmpty &&
      (filePath.startsWith('lib/application/') ||
          filePath.startsWith('lib/infrastructure/'));

  /// ARC-027: accesibilidad de un widget de la presentación.
  void _checkAccessibility(AstNode node) {
    if (!filePath.startsWith('lib/presentation/')) return;
    final problem = accessibilityProblem(node);
    if (problem != null) _addViolation('ARC-027', node.offset, problem);
  }

  @override
  void visitCatchClause(CatchClause node) {
    if ((filePath.startsWith('lib/application/') ||
            filePath.startsWith('lib/infrastructure/')) &&
        node.body.statements.isEmpty) {
      _addViolation(
        'ARC-007',
        node.offset,
        'Prohibido bloque catch vacío en application/infrastructure; el error se pierde en silencio.',
      );
    }
    if (filePath.startsWith('lib/infrastructure/datasources/')) {
      final body = _HandlerFinder.of(node.body);
      final handled =
          body.usesCentralHandler ||
          body.rethrows ||
          body.calls.any(errorHelpers.contains);
      if (!handled) {
        _addViolation(
          'ARC-013',
          node.offset,
          'El catch del datasource no pasa por CentralErrorHandler (errorMap/handleAndLog) ni relanza: el error no se audita y el usuario puede ver el texto técnico.',
        );
      }
    } else if (_auditsErrors &&
        node.exceptionType == null &&
        !_emptyCatchIsArc007(node)) {
      // `on FormatException catch`: error esperado y nombrado (falso
      // positivo de audit_all_errors.md); el catch genérico sí se audita.
      final body = _HandlerFinder.of(node.body);
      final handled =
          body.usesCentralHandler ||
          body.usesAuditLogger ||
          body.rethrows ||
          body.calls.any(errorHelpers.contains);
      if (!handled) {
        _addViolation(
          'ARC-028',
          node.offset,
          'El catch no audita el error: pásalo por CentralErrorHandler (handleAndLog, handleAndLogAsString o errorMap, que lo registran con AuditLogger) o relánzalo.',
        );
      }
    }
    super.visitCatchClause(node);
  }

  @override
  void visitAsExpression(AsExpression node) {
    final inRelevantScope =
        filePath.startsWith('lib/infrastructure/') ||
        _isInsideFromJsonOrFromMap(node);
    if (inRelevantScope && node.expression.unParenthesized is IndexExpression) {
      final type = node.type;
      final isNullable = type.question != null;
      final isDynamic = type is NamedType && type.name.lexeme == 'dynamic';
      if (!isNullable && !isDynamic) {
        _addViolation(
          'ARC-008',
          node.offset,
          'Prohibido cast no nulo directo sobre IndexExpression en deserialización. Use cast nullable o valor por defecto.',
        );
      }
    }
    super.visitAsExpression(node);
  }

  bool _isInsideFromJsonOrFromMap(AstNode node) {
    for (
      AstNode? current = node.parent;
      current != null;
      current = current.parent
    ) {
      if (current is ConstructorDeclaration) {
        final name = current.name?.lexeme;
        if (name == 'fromJson' || name == 'fromMap') return true;
      } else if (current is MethodDeclaration) {
        final name = current.name.lexeme;
        if (name == 'fromJson' || name == 'fromMap') return true;
      } else if (current is FunctionDeclaration) {
        final name = current.name.lexeme;
        if (name == 'fromJson' || name == 'fromMap') return true;
      }
    }
    return false;
  }
}

String _resolveUri(String filePath, String rawUri) {
  if (rawUri.startsWith('package:zas/')) {
    return 'lib/${rawUri.substring('package:zas/'.length)}';
  }
  if (rawUri.startsWith('package:') || rawUri.startsWith('dart:')) {
    return rawUri;
  }

  final dirParts = filePath.split('/');
  if (dirParts.isNotEmpty) {
    dirParts.removeLast();
  }

  for (final segment in rawUri.split('/')) {
    if (segment.isEmpty || segment == '.') continue;
    if (segment == '..') {
      if (dirParts.length > 1) {
        dirParts.removeLast();
      }
    } else {
      dirParts.add(segment);
    }
  }

  final resolved = dirParts.join('/');
  // Un `../…/infrastructure/` o `../…/presentation/` cuenta como esa capa
  // aunque la profundidad no cuadre (importar la capa nunca es válido).
  if (rawUri.startsWith('../')) {
    final topLayerMatch = RegExp(
      r'^(\.\./)+(infrastructure|presentation)/(.+)$',
    ).firstMatch(rawUri);
    if (topLayerMatch != null) {
      return 'lib/${topLayerMatch.group(2)}/${topLayerMatch.group(3)}';
    }
  }
  return resolved;
}

/// Imprime el reporte de violación con formato estructurado para CI/CD.
void _reportViolation(ArcViolation v) {
  stdout.writeln('🚨 VIOLACIÓN ${v.rule} DETECTADA 🚨');
  stdout.writeln('   Archivo: ${v.file}');
  stdout.writeln('   Línea ${v.line}: ${v.code}');
  if (v.weight > 1) stdout.writeln('   Exceso: ${v.weight}');
  stdout.writeln('   Razón: ${v.reason}\n');
}

/// Junta los `if` de un bloque (también los `else if`, que son `if` anidados).
class _IfFinder extends RecursiveAstVisitor<void> {
  final ifs = <IfStatement>[];

  @override
  void visitIfStatement(IfStatement node) {
    ifs.add(node);
    super.visitIfStatement(node);
  }
}
