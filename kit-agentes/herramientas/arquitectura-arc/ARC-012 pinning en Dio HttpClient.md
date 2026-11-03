# ARC-012: todo Dio( o HttpClient( va en un archivo que aplica el pinning de certificados

> Prompt para implementar la regla de arquitectura **ARC-012** en el pre-commit de un proyecto Dart/Flutter. Origen: proyecto zas (Zas! Payments), noviembre de 2026; el código de las secciones 4 y 6 está probado contra el `lib/` de zas (analyzer 13.3.0, Flutter 3.47.7).

## 0. Cómo usar este prompt

Eres un agente de código (Claude Code, Antigravity u OpenCode) trabajando **dentro de un proyecto Dart o Flutter**. Este documento es autocontenido: trae el motivo de la regla, su definición exacta, el código completo (ya probado), las pruebas, la integración en el pre-commit, la puesta en marcha y la verificación. No necesitas ningún otro archivo.

Reglas de trabajo, en este orden:

1. **Lee primero las instrucciones del proyecto** (`AGENTS.md`, `CLAUDE.md`, `.agents/rules/*`, `README.md`). Si alguna contradice este prompt, manda la del proyecto y lo informas al final.
2. **Trabaja solo en este proyecto.** No toques otros repositorios ni el kit compartido de mcp-ia.
3. **Consulta mcp-ia antes de resolver cualquier error** (`search_solutions` con el mensaje exacto, o `python3 <mcp-ia>/kit-agentes/compartido/mcpia.py "<error>"`). Lo que resuelvas y no esté, regístralo con `add_solution` en el momento (si eres un agente delegado sin acceso, descríbelo en el informe: error, causa y solución).
4. **Nunca uses `--no-verify` ni `SKIP_PRE_COMMIT=1`**, y nunca debilites una regla, su prueba o el hook para que algo pase.
5. **No hagas `git push`.** Los commits sí, con el formato del proyecto.
6. Antes de declarar una función, clase o constante nueva, **busca si el nombre ya existe** (`grep -rn "nombre" lib scripts test`). En Dart un nombre repetido en el mismo archivo no compila, pero en archivos distintos puede ocultar al otro por imports.
7. Cada dato de tu informe debe salir de un comando que ejecutaste. Lo que no pudiste comprobar va en «No verificado».

## 0.1 ¿Aplica a este proyecto? Qué puedes omitir

**Requisito:** La app habla con un backend propio por `Dio` o `HttpClient` **y** ya tiene una clase de pinning de certificados.

**Si no se cumple:** Si no tiene pinning, **no actives la regla**: detente e informa con la guía de la sección 1 (implementarlo es otro trabajo de seguridad). Si no usa `Dio` ni `HttpClient` (solo el paquete `http`, Firebase…), ajusta `httpClients` o, si no hay clientes propios, no la actives.

**Puedes omitir, según el proyecto:**

- Si no hay servicios externos (mapas, geocodificación), omite el punto de sus huellas en la sección 8.
- Si no puedes probar en un dispositivo, no omitas el paso 4 de la sección 8: déjalo en «No verificado».
- Proyecto **sin el kit de mcp-ia**: omite la sección 7.1 y usa la 7.2.
- Proyecto **con el kit**: omite la sección 7.2.
- Proyecto **sin CI activo**: omite la sección 7.3.
- Proyecto **Dart puro** (sin Flutter): en las pruebas usa `package:test` en lugar de `flutter_test` (sección 6) y `dart test`/`dart analyze` en lugar de `flutter test`/`flutter analyze` (sección 10).
- Si el auditor de referencia **ya existe** (lo creó otro prompt ARC), omite crearlo (sección 4) y la configuración inicial (sección 5): solo agregas la regla (tabla de la sección 3).
- Si la regla **no tiene línea base** (todas salvo ARC-009, ARC-010 y ARC-018), omite todo lo relativo a `--generar-linea-base`.
- Si la regla **no aplica** al proyecto (ver arriba), omite todo lo demás: no crees el auditor solo para dejarla inactiva; informa y termina.

Todo lo que omitas, menciónalo en el informe (sección 13) con el motivo.

## 1. Contexto y motivo

El pinning de certificados hace que la app solo acepte los certificados TLS conocidos de su backend. Sin él, un proxy o una CA instalada en el teléfono (ataque de intermediario) puede leer y modificar el tráfico, incluidos tokens y datos de pago (OWASP MASVS-NETWORK-2). El riesgo típico no es no tener pinning, sino **un cliente HTTP nuevo que se crea sin él** (un `Dio()` para un servicio de mapas, para subir archivos o para auditoría) y que queda fuera de la protección sin que nadie lo note. En zas, la auditoría de seguridad encontró tres clientes así.

La regla no valida que el pinning funcione; garantiza que **cada archivo que crea un cliente HTTP también usa la clase de pinning** del proyecto, y deja la revisión de que se aplique correctamente a la persona que revisa el código.

**Requisito:** el proyecto debe tener ya una clase de pinning (en zas, `CertificatePinningConfig`, con `attach(dio)` para Dio y `createPinnedHttpClient()` para `HttpClient` de `dart:io`). Búscala antes de seguir:

````sh
grep -rnE "badCertificateCallback|CertificatePinning|SecurityContext\\\\(|allowedSHAFingerprints|IOHttpClientAdapter" lib | head
````

Si existe con otro nombre, ajusta el parámetro `pinningClass`. **Si el proyecto no tiene pinning, no actives la regla con una clase vacía ni la inventes en este trabajo**: implementar pinning es un cambio de seguridad que, mal hecho, deja la app sin conexión cuando el servidor renueva su certificado. Detente e informa al usuario con esta guía mínima para decidir:

- Obtener la huella SHA-256 del certificado del servidor: `openssl s_client -connect api.ejemplo.com:443 -servername api.ejemplo.com </dev/null 2>/dev/null | openssl x509 -outform DER | openssl dgst -sha256`.
- Fijar **al menos dos huellas** (la actual y una de respaldo: el siguiente certificado o la CA intermedia), y tener un procedimiento de rotación antes del vencimiento.
- En Dio: `IOHttpClientAdapter(createHttpClient: ...)` con un `HttpClient(context: SecurityContext(withTrustedRoots: false))` cuyo `badCertificateCallback` compare `sha256.convert(cert.der)` con las huellas; en `dart:io` directo, lo mismo sobre `HttpClient`.
- Desactivarlo solo en pruebas o en debug explícito, nunca en release.

## 2. Definición exacta

- **Ámbito:** archivos `.dart` dentro de `lib/`.
- **Violación:** el archivo crea un cliente de `httpClients` (`Dio`, `HttpClient`) —como `Dio()`, `Dio(BaseOptions(...))`, `new Dio()` o `HttpClient(context: ...)`— y el texto del archivo **no** contiene `pinningClass`. Se reporta en cada creación.
- **Cómo lo detecta sin resolver tipos:** `Dio()` llega al AST como `MethodInvocation` sin `target` (por eso se mira `methodName`), y `new Dio()` como `InstanceCreationExpression`. Una llamada con objetivo (`client.Dio()`) no cuenta.
- **Línea base:** no. Bloquea siempre.
- **Parámetros:** `pinningClass` y `httpClients`. Si el proyecto usa el paquete `http` (`http.Client()`, `IOClient(...)`), agrega esos nombres a `httpClients` y una prueba por cada uno.
- **Límite conocido:** basta con que el nombre de la clase de pinning aparezca en el archivo (también en un comentario). Es un control de presencia, no de uso correcto; por eso la revisión humana sigue siendo necesaria en esos archivos.

Casos propios para las pruebas: los nombres que agregues a `httpClients` y la forma concreta en que el proyecto aplica el pinning (por ejemplo, `CertificatePinningConfig.attach(dio, configureAdapter: true)`).

## 3. Estado del proyecto: qué revisar antes de tocar nada

Ejecuta y anota los resultados:

````sh
# ¿Flutter o Dart puro? (cambia el comando de pruebas)
grep -nE '^\s+sdk:\s*flutter' pubspec.yaml && echo FLUTTER || echo DART

# ¿Ya existe el auditor y su configuración? (otro prompt ARC pudo crearlos)
ls scripts/script_audit_architecture.dart scripts/arc_config.json 2>&1
grep -n "ARC-0" scripts/script_audit_architecture.dart 2>/dev/null | head

# ¿Está analyzer como dependencia de desarrollo? ¿Qué versión?
grep -n "analyzer" pubspec.yaml; grep -A3 "^  analyzer:" pubspec.lock | grep version

# ¿Qué hooks usa el proyecto?
git config core.hooksPath; ls .githooks 2>/dev/null; ls .git/hooks | grep -v sample

# Línea de comando de pruebas que usa el proyecto
ls test/ | head
````

Decide según lo encontrado:

| Situación | Qué haces |
|---|---|
| No existe `scripts/script_audit_architecture.dart` | Lo creas completo (sección 4) con `activeRules = {'ARC-012'}`. |
| Existe y es el **auditor de referencia de este prompt** (tiene `activeRules` y la sección `// ARC-012`) | Solo agregas `'ARC-012'` a `activeRules` y ajustas los parámetros de la regla. No lo reescribas. |
| Existe el auditor de referencia pero **sin la sección `// ARC-012`** (lo creó una versión anterior de estos prompts, con menos reglas) | Reemplázalo por el de la sección 4 **conservando** los valores de los parámetros que ya tenía y su `activeRules` (más `'ARC-012'`). Antes, `git diff` del archivo para no perder ajustes propios; la línea base de `arc_config.json` no cambia. |
| Existe pero es **otro auditor propio** del proyecto (otra estructura) | No lo reemplaces. Porta solo la detección de la regla (la función o el método `visit...` marcado `// ARC-012`) a su estructura, con sus pruebas. Si eso no es posible sin reescribirlo, detente e informa. |
| No hay `analyzer` en `dev_dependencies` | `dart pub add --dev analyzer` (o `flutter pub add --dev analyzer`). Anota la versión resuelta: el código está probado con **analyzer 13.3.0**; con versiones < 13 cambia `node.namePart.typeName` por `node.name` (ver sección 11). |

## 4. Desarrollo: el auditor de arquitectura

Un solo script, `scripts/script_audit_architecture.dart`, recorre **todo `lib/`** (no solo los archivos del commit) con el AST de `analyzer`, sin resolver tipos (rápido y sin compilar). Falla con `exit 1` si queda alguna violación que no cubra una **excepción vigente** o la **línea base** de `scripts/arc_config.json`.

Conceptos que usa:

- **Violación** (`ArcViolation`): regla, archivo, línea, código, motivo y **peso**. El peso es 1, salvo en ARC-009/ARC-010, donde vale lo que sobra (líneas o imports de más).
- **Excepción** (`excepciones` en el JSON): regla + archivo + motivo + fecha `vence`. Mientras no venza, esa regla no cuenta en ese archivo; al vencer vuelve a bloquear y el script lo avisa.
- **Línea base** (`linea_base`, solo para las reglas de `baselineRules`): por archivo, el peso permitido. Si la suma de pesos del archivo es igual o menor, no bloquea (y si es menor, el script avisa «Baja la línea base…»). Si es mayor, o el archivo no está en la lista, bloquea. Así lo existente no frena al equipo, pero **no puede empeorar ni aparecer en archivos nuevos**.
- **Parámetros**: las constantes del principio del archivo. Ajústalas al proyecto; no las conviertas en configuración externa.

Si el archivo no existe, créalo con **este contenido exacto** (luego deja en `activeRules` solo las reglas que el proyecto adopta):

````dart
// scripts/script_audit_architecture.dart
//
// Auditor de arquitectura: recorre todo lib/ con el AST de `analyzer` y
// falla (exit 1) si encuentra una violación que no está cubierta por una
// excepción vigente ni por la línea base de scripts/arc_config.json.
//
// Uso:
//   dart run scripts/script_audit_architecture.dart
//   dart run scripts/script_audit_architecture.dart --generar-linea-base

import 'dart:convert';
import 'dart:io';

import 'package:analyzer/dart/analysis/utilities.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/token.dart';
import 'package:analyzer/dart/ast/visitor.dart';
import 'package:analyzer/source/line_info.dart';

const String _configPath = 'scripts/arc_config.json';

// ---------------------------------------------------------------------------
// Parámetros del proyecto: ajústalos antes de activar cada regla.
// ---------------------------------------------------------------------------

/// ARC-009: máximo de líneas por archivo de lib/.
const int maxFileLines = 500;

/// ARC-010: máximo de imports por archivo de lib/.
const int maxFileImports = 15;

/// ARC-011: mixin que protege emit() tras close() y clases base de estado.
const String safeEmitMixin = 'SafeEmitMixin';
const Set<String> stateBaseClasses = {
  'Cubit',
  'HydratedCubit',
  'Bloc',
  'HydratedBloc',
};

/// ARC-012: clase que aplica el pinning y clientes HTTP que la necesitan.
const String pinningClass = 'CertificatePinningConfig';
const Set<String> httpClients = {'Dio', 'HttpClient'};

/// ARC-013: carpeta de los datasources y manejador central de errores.
const String datasourcesDir = 'lib/infrastructure/datasources/';
const String errorHandlerClass = 'CentralErrorHandler';

/// ARC-015: llamadas que muestran un aviso al usuario dentro de un listener.
final RegExp noticeCall = RegExp(r'show\w*Dialog|showModal\w*|showSnackBar');

/// ARC-018: archivo que define el método que lee el id del comercio de la
/// sesión (el único que puede leerlo a mano), el método y las lecturas a mano
/// que se prohíben fuera de él.
const String merchantIdSourceFile =
    'lib/presentation/cubits/auth/handlers/login_session_handler.dart';
const String merchantIdGetter = 'loginCubit.getCurrentMerchantId()';
final RegExp sessionMerchantIdRead = RegExp(
  r'''(getData\(\)|loginData|sessionData)\??\[['"](merchantId|merchant_id)['"]\]''',
);

/// Reglas activas. Quita de aquí las que el proyecto no adopta.
const Set<String> activeRules = {
  'ARC-009',
  'ARC-010',
  'ARC-011',
  'ARC-012',
  'ARC-013',
  'ARC-015',
  'ARC-016',
  'ARC-017',
  'ARC-018',
};

/// Reglas que admiten línea base (las demás bloquean siempre).
const Set<String> baselineRules = {'ARC-009', 'ARC-010', 'ARC-018'};

// ---------------------------------------------------------------------------
// Modelo
// ---------------------------------------------------------------------------

/// Una violación. [weight] es cuánto cuenta para la línea base: 1 por
/// defecto; en ARC-009/ARC-010, las líneas o imports de más, para que un
/// archivo listado pueda encoger pero no crecer.
class ArcViolation {
  final String rule;
  final String file;
  final int line;
  final String code;
  final String reason;
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

/// Excepción temporal: regla + archivo + motivo + fecha de vencimiento.
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

/// Contenido de scripts/arc_config.json.
class ArcConfig {
  final List<ArcException> excepciones;
  final Map<String, Map<String, int>> lineaBase;

  const ArcConfig({this.excepciones = const [], this.lineaBase = const {}});

  factory ArcConfig.fromJson(Map<String, dynamic> json) {
    final rawExcepciones = json['excepciones'];
    final rawLineaBase = json['linea_base'];
    if (rawExcepciones is! List || rawLineaBase is! Map<String, dynamic>) {
      throw const FormatException(
        'arc_config.json necesita "excepciones" (lista) y "linea_base" (objeto).',
      );
    }
    final lineaBase = <String, Map<String, int>>{};
    for (final entry in rawLineaBase.entries) {
      final files = entry.value;
      if (files is! Map<String, dynamic>) {
        throw FormatException('linea_base.${entry.key} debe ser un objeto.');
      }
      lineaBase[entry.key] = {
        for (final f in files.entries)
          if (f.value is int && (f.value as int) >= 0)
            f.key: f.value as int
          else
            f.key: throw FormatException(
              'linea_base.${entry.key}.${f.key} debe ser un entero >= 0.',
            ),
      };
    }
    return ArcConfig(
      excepciones: [
        for (final item in rawExcepciones)
          ArcException.fromJson(item as Map<String, dynamic>),
      ],
      lineaBase: lineaBase,
    );
  }

  Map<String, dynamic> toJson() => {
    'excepciones': excepciones.map((e) => e.toJson()).toList(),
    'linea_base': lineaBase,
  };
}

int _weightOf(Iterable<ArcViolation> violations) =>
    violations.fold(0, (sum, v) => sum + v.weight);

// ---------------------------------------------------------------------------
// Detección
// ---------------------------------------------------------------------------

/// Analiza [source] (ruta [path], relativa a la raíz: `lib/...`).
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
    ..._auditMerchantIdReads(normalizedPath, lines),
  ].where((v) => activeRules.contains(v.rule)).toList();
}

/// ARC-018: el id del comercio de la sesión se lee con [merchantIdGetter],
/// que resuelve los nombres que usa el backend; leerlo a mano repite (o se
/// salta) esa lógica. Las lecturas de mensajes del backend no cuentan.
List<ArcViolation> _auditMerchantIdReads(String path, List<String> lines) {
  if (!path.startsWith('lib/') || path == merchantIdSourceFile) return const [];
  return [
    for (var i = 0; i < lines.length; i++)
      if (!lines[i].trimLeft().startsWith('//') &&
          sessionMerchantIdRead.hasMatch(lines[i]))
        ArcViolation(
          rule: 'ARC-018',
          file: path,
          line: i + 1,
          code: lines[i].trim(),
          reason:
              'Lee el id del comercio de la sesión con $merchantIdGetter, no a mano.',
        ),
  ];
}

/// ARC-009 y ARC-010: exceso de líneas o de imports. El peso es lo que sobra.
List<ArcViolation> _auditFileSize(
  String path,
  List<String> lines,
  CompilationUnit unit,
) {
  if (!path.startsWith('lib/')) return const [];
  final violations = <ArcViolation>[];
  // split deja un elemento vacío final si el archivo termina en salto de línea.
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
    violations.add(
      ArcViolation(
        rule: 'ARC-010',
        file: path,
        line: unit.lineInfo.getLocation(extra.offset).lineNumber,
        code: '${imports.length} imports',
        reason:
            'El archivo supera los $maxFileImports imports: usa un barril o separa responsabilidades.',
        weight: imports.length - maxFileImports,
      ),
    );
  }
  return violations;
}

/// Funciones y métodos del archivo que usan [errorHandlerClass] (p. ej. un
/// `_failure(e, st)`): un catch que los llama cumple ARC-013.
Set<String> _errorHelpersOf(CompilationUnit unit) {
  final helpers = <String>{};
  void addIfHandles(Token name, AstNode body) {
    if (body.toSource().contains(errorHandlerClass)) helpers.add(name.lexeme);
  }

  for (final declaration in unit.declarations) {
    if (declaration is FunctionDeclaration) {
      addIfHandles(declaration.name, declaration.functionExpression.body);
    } else if (declaration is ClassDeclaration) {
      for (final member in declaration.body.childEntities) {
        if (member is MethodDeclaration) addIfHandles(member.name, member.body);
      }
    }
  }
  return helpers;
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

class _ArcAstVisitor extends RecursiveAstVisitor<void> {
  final String filePath;
  final LineInfo lineInfo;
  final List<String> lines;
  final Set<String> errorHelpers;
  final List<ArcViolation> violations = [];

  _ArcAstVisitor({
    required this.filePath,
    required this.lineInfo,
    required this.lines,
    this.errorHelpers = const {},
  });

  late final bool _hasPinning = lines.any((l) => l.contains(pinningClass));

  void _add(String rule, int offset, String reason) {
    final line = lineInfo.getLocation(offset).lineNumber;
    violations.add(
      ArcViolation(
        rule: rule,
        file: filePath,
        line: line,
        code: line <= lines.length ? lines[line - 1].trim() : '',
        reason: reason,
      ),
    );
  }

  // ARC-011 ------------------------------------------------------------------
  @override
  void visitClassDeclaration(ClassDeclaration node) {
    final superName = node.extendsClause?.superclass.name.lexeme;
    final mixins =
        node.withClause?.mixinTypes.map((t) => t.name.lexeme).toSet() ??
        const <String>{};
    if (filePath.startsWith('lib/') &&
        stateBaseClasses.contains(superName) &&
        !mixins.contains(safeEmitMixin)) {
      // analyzer >= 13: el nombre está en namePart.typeName (antes node.name).
      final name = node.namePart.typeName;
      _add(
        'ARC-011',
        name.offset,
        '${name.lexeme} extiende $superName sin $safeEmitMixin: un emit tras close() lanzaría StateError.',
      );
    }
    if (filePath.startsWith('lib/') && superName == 'Equatable') {
      _checkEquatableProps(node);
    }
    super.visitClassDeclaration(node);
  }

  // ARC-016 ------------------------------------------------------------------
  /// Un campo de un `Equatable` que falta en `props` no cuenta para la
  /// igualdad: si solo cambia ese campo, el estado nuevo se considera igual,
  /// el Cubit no lo emite y la pantalla no se actualiza.
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
        _add(
          'ARC-016',
          field.offset,
          '${field.lexeme} no está en props de ${node.namePart.typeName.lexeme}: un cambio solo de ese campo no se emite.',
        );
      }
    }
  }

  // ARC-017 ------------------------------------------------------------------
  @override
  void visitSimpleStringLiteral(SimpleStringLiteral node) {
    // Una clave escrita en el código se extrae del binario. Con interpolación
    // ('$key') el literal es StringInterpolation y no pasa por aquí.
    if (filePath.startsWith('lib/') &&
        RegExp(
          r'PRAGMA\s+(re)?key',
          caseSensitive: false,
        ).hasMatch(node.value)) {
      _add(
        'ARC-017',
        node.offset,
        'Clave de cifrado escrita en el código: léela del almacenamiento seguro e interpólala.',
      );
    }
    super.visitSimpleStringLiteral(node);
  }

  // ARC-015 ------------------------------------------------------------------
  /// Un listener que muestra un aviso según un campo del estado
  /// (`state.status == error`) necesita un `listenWhen` que lo compare con el
  /// anterior; si no, el aviso se repite con cualquier otra emisión mientras
  /// el campo siga igual. Los que solo preguntan el tipo (`state is XError`)
  /// reaccionan a eventos y no cuentan.
  void _checkBlocListener(String name, ArgumentList args, int offset) {
    if (!filePath.startsWith('lib/')) return;
    if (name != 'BlocListener' && name != 'BlocConsumer') return;
    // analyzer >= 13: los argumentos con nombre son NamedArgument
    // (name/argumentExpression); antes, NamedExpression (name.label/expression).
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
      _add(
        'ARC-015',
        offset,
        '$name muestra un aviso según un campo del estado sin un listenWhen que lo compare con el anterior: el aviso se repite con cualquier otra emisión.',
      );
    }
  }

  /// Si algún `if` del listener muestra un aviso y su condición compara un
  /// campo del estado (`state.status == x`, `state.message != null`).
  static bool _showsNoticeOnField(FunctionBody body, String stateName) {
    final field = RegExp('\\b$stateName\\.\\w+[\\w.?]*\\s*(==|!=)');
    final finder = _IfFinder();
    body.accept(finder);
    return finder.ifs.any(
      (i) =>
          field.hasMatch(i.expression.toSource()) &&
          noticeCall.hasMatch(i.thenStatement.toSource()),
    );
  }

  // ARC-012 ------------------------------------------------------------------
  void _checkHttpClient(String typeName, int offset) {
    if (!filePath.startsWith('lib/') || _hasPinning) return;
    if (!httpClients.contains(typeName)) return;
    _add(
      'ARC-012',
      offset,
      'Cliente HTTP ($typeName) sin pinning: aplica $pinningClass (OWASP MASVS-NETWORK-2).',
    );
  }

  @override
  void visitInstanceCreationExpression(InstanceCreationExpression node) {
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
  void visitMethodInvocation(MethodInvocation node) {
    // Sin resolución de tipos, `Dio()` se lee como una llamada, no como `new`.
    if (node.target == null) {
      _checkHttpClient(node.methodName.name, node.methodName.offset);
      _checkBlocListener(node.methodName.name, node.argumentList, node.offset);
    }
    super.visitMethodInvocation(node);
  }

  // ARC-013 ------------------------------------------------------------------
  @override
  void visitCatchClause(CatchClause node) {
    if (filePath.startsWith(datasourcesDir)) {
      final body = node.body.toSource();
      final handled =
          body.contains(errorHandlerClass) ||
          body.contains('rethrow') ||
          RegExp(r'\bthrow\b').hasMatch(body) ||
          errorHelpers.any((name) => body.contains('$name('));
      if (!handled) {
        _add(
          'ARC-013',
          node.offset,
          'El catch del datasource no pasa por $errorHandlerClass ni relanza: el error no se audita y el usuario puede ver el texto técnico.',
        );
      }
    }
    super.visitCatchClause(node);
  }
}

// ---------------------------------------------------------------------------
// Excepciones y línea base
// ---------------------------------------------------------------------------

Set<String> _activeExceptionKeys(ArcConfig config, DateTime today) {
  final todayDate = DateTime(today.year, today.month, today.day);
  final keys = <String>{};
  for (final exc in config.excepciones) {
    final parsed = DateTime.parse(exc.vence);
    final vence = DateTime(parsed.year, parsed.month, parsed.day);
    if (todayDate.isAfter(vence)) {
      stdout.writeln(
        'Excepción vencida: ${exc.archivo} (${exc.regla}, venció ${exc.vence})',
      );
    } else {
      keys.add('${exc.regla}::${exc.archivo}');
    }
  }
  return keys;
}

/// Quita las violaciones con excepción vigente y las que caben en la línea
/// base (suma de pesos por archivo <= permitido). Lo que queda bloquea.
List<ArcViolation> applyConfig(
  List<ArcViolation> found,
  ArcConfig config,
  DateTime today,
) {
  final excepted = _activeExceptionKeys(config, today);
  final remaining = found
      .where((v) => !excepted.contains('${v.rule}::${v.file}'))
      .toList();
  final blocking = <ArcViolation>[];
  final byRuleAndFile = <String, Map<String, List<ArcViolation>>>{};
  for (final v in remaining) {
    if (baselineRules.contains(v.rule)) {
      byRuleAndFile
          .putIfAbsent(v.rule, () => {})
          .putIfAbsent(v.file, () => [])
          .add(v);
    } else {
      blocking.add(v);
    }
  }
  for (final rule in baselineRules) {
    final allowedByFile = config.lineaBase[rule] ?? const <String, int>{};
    final byFile = byRuleAndFile[rule] ?? const {};
    for (final entry in allowedByFile.entries) {
      final actual = _weightOf(byFile[entry.key] ?? const []);
      if (actual < entry.value) {
        stdout.writeln(
          '👉 Baja la línea base de ${entry.key} ($rule) a $actual',
        );
      }
    }
    for (final entry in byFile.entries) {
      final allowed = allowedByFile[entry.key];
      if (allowed == null || _weightOf(entry.value) > allowed) {
        blocking.addAll(entry.value);
      }
    }
  }
  return blocking;
}

/// Reescribe la línea base con los pesos actuales. Nunca agrega archivos
/// nuevos ni sube un número si la línea base de esa regla ya tenía datos.
void _updateBaseline(ArcConfig config, List<ArcViolation> found) {
  final excepted = _activeExceptionKeys(config, DateTime.now());
  final newBaseline = <String, Map<String, int>>{};
  for (final rule in baselineRules) {
    final current = <String, int>{};
    for (final v in found.where(
      (v) => v.rule == rule && !excepted.contains('${v.rule}::${v.file}'),
    )) {
      current[v.file] = (current[v.file] ?? 0) + v.weight;
    }
    final existing = config.lineaBase[rule] ?? const <String, int>{};
    final updated = <String, int>{};
    for (final file in ({...existing.keys, ...current.keys}.toList()..sort())) {
      final now = current[file] ?? 0;
      final before = existing[file];
      if (existing.isEmpty) {
        updated[file] = now;
      } else if (before == null) {
        if (now > 0) stdout.writeln('Rechazado ($rule): archivo nuevo $file.');
      } else if (now > before) {
        stdout.writeln('Rechazado ($rule): $file subiría de $before a $now.');
        updated[file] = before;
      } else if (now > 0) {
        updated[file] = now;
      }
    }
    newBaseline[rule] = updated;
  }
  final json = const JsonEncoder.withIndent('  ').convert(
    ArcConfig(excepciones: config.excepciones, lineaBase: newBaseline).toJson(),
  );
  File(_configPath).writeAsStringSync('$json\n');
  stdout.writeln('✅ Línea base actualizada en $_configPath.');
}

// ---------------------------------------------------------------------------
// Programa
// ---------------------------------------------------------------------------

void main(List<String> args) {
  final configFile = File(_configPath);
  if (!configFile.existsSync()) {
    stderr.writeln('❌ No existe $_configPath.');
    exit(1);
  }
  final ArcConfig config;
  try {
    config = ArcConfig.fromJson(
      jsonDecode(configFile.readAsStringSync()) as Map<String, dynamic>,
    );
  } on Object catch (e) {
    stderr.writeln('❌ Configuración inválida en $_configPath: $e');
    exit(1);
  }

  final files =
      Directory('lib')
          .listSync(recursive: true)
          .whereType<File>()
          .where(
            (f) =>
                f.path.endsWith('.dart') &&
                !f.path.endsWith('.g.dart') &&
                !f.path.endsWith('.freezed.dart'),
          )
          .toList()
        ..sort((a, b) => a.path.compareTo(b.path));

  final found = <ArcViolation>[
    for (final f in files)
      ...auditSource(f.path.replaceAll('\\', '/'), f.readAsStringSync()),
  ];

  if (args.contains('--generar-linea-base')) {
    _updateBaseline(config, found);
    return;
  }

  final blocking = applyConfig(found, config, DateTime.now());
  for (final v in blocking) {
    stdout.writeln('🚨 VIOLACIÓN ${v.rule} DETECTADA 🚨');
    stdout.writeln('   Archivo: ${v.file}');
    stdout.writeln('   Línea ${v.line}: ${v.code}');
    if (v.weight > 1) stdout.writeln('   Exceso: ${v.weight}');
    stdout.writeln('   Razón: ${v.reason}\n');
  }
  stdout.writeln('Archivos analizados: ${files.length}');
  stdout.writeln('Total de violaciones detectadas: ${blocking.length}');
  if (blocking.isEmpty) {
    stdout.writeln('✅ [APROBADO]: Cero violaciones detectadas.');
    exit(0);
  }
  stderr.writeln('❌ [RECHAZADO]: ${blocking.length} violaciones bloqueantes.');
  exit(1);
}
````

Puntos que no debes cambiar:

- Se analiza `lib/` completo en cada ejecución: una violación en cualquier archivo bloquea, aunque no esté en el commit. Es lo que impide que la deuda vuelva por otro archivo.
- Se ignoran `*.g.dart` y `*.freezed.dart` (código generado).
- `parseString(..., throwIfDiagnostics: false)`: un archivo con errores de sintaxis no tumba el auditor; para eso ya está `flutter analyze`.

## 5. Configuración: `scripts/arc_config.json`

Si no existe, créalo así (las claves son obligatorias aunque estén vacías):

````json
{
  "excepciones": [],
  "linea_base": {
    "ARC-009": {},
    "ARC-010": {},
    "ARC-018": {}
  }
}
````

Formato de una excepción (úsalas poco, siempre con motivo concreto y fecha de vencimiento real):

````json
{
  "regla": "ARC-011",
  "archivo": "lib/ruta/al/archivo.dart",
  "motivo": "Explica por qué no se puede cumplir todavía y qué lo resolverá",
  "vence": "2027-01-31"
}
````

La línea base **no se edita a mano**: se genera con `dart run scripts/script_audit_architecture.dart --generar-linea-base` (sección 8). Una vez que una regla tiene datos, ese comando ya no agrega archivos nuevos ni sube números: solo los baja.

## 6. Pruebas del detector

El detector también se prueba, para que nadie lo debilite sin que falle el commit. Crea (o completa) `test/scripts/script_audit_architecture_test.dart`. Este es el archivo de referencia con los casos de **todas** las reglas ARC-009 a ARC-018; **conserva solo los grupos de las reglas que estén en `activeRules`** (y el grupo «línea base» si alguna de ARC-009, ARC-010 o ARC-018 está activa), y agrega los casos propios del proyecto que se indican en la sección 2.

````dart
// test/scripts/script_audit_architecture_test.dart

import 'package:flutter_test/flutter_test.dart';

import '../../scripts/script_audit_architecture.dart'
    show
        ArcConfig,
        ArcViolation,
        applyConfig,
        auditSource,
        maxFileImports,
        maxFileLines,
        merchantIdSourceFile;

List<String> rulesOf(String path, String source) =>
    auditSource(path, source).map((v) => v.rule).toList();

void main() {
  final today = DateTime(2026, 11, 3);

  // ARC-009 ---------------------------------------------------------------
  group('ARC-009 (más de $maxFileLines líneas)', () {
    test('marca el exceso de líneas con su peso', () {
      final source = List.filled(maxFileLines + 3, '// x').join('\n');
      final v = auditSource(
        'lib/a.dart',
        source,
      ).where((v) => v.rule == 'ARC-009').single;
      expect(v.weight, 3);
    });

    test('justo en el límite, con salto final, no cuenta', () {
      final source = '${List.filled(maxFileLines, '//').join('\n')}\n';
      expect(rulesOf('lib/a.dart', source), isNot(contains('ARC-009')));
    });

    test('fuera de lib/ no aplica', () {
      final source = List.filled(maxFileLines + 3, '// x').join('\n');
      expect(rulesOf('test/a.dart', source), isNot(contains('ARC-009')));
    });
  });

  // ARC-010 ---------------------------------------------------------------
  group('ARC-010 (más de $maxFileImports imports)', () {
    String imports(int n) =>
        List.generate(n, (i) => "import 'package:app/m$i.dart';").join('\n');

    test('marca el exceso de imports con su peso', () {
      final v = auditSource(
        'lib/a.dart',
        imports(maxFileImports + 2),
      ).where((v) => v.rule == 'ARC-010').single;
      expect(v.weight, 2);
      expect(v.line, maxFileImports + 1);
    });

    test('exports y partes no cuentan como imports', () {
      final source =
          '${imports(maxFileImports)}\n'
          "export 'package:app/x.dart';\n";
      expect(rulesOf('lib/a.dart', source), isNot(contains('ARC-010')));
    });
  });

  // Línea base con pesos ----------------------------------------------------
  group('línea base', () {
    ArcViolation over(int weight, {String file = 'lib/a.dart'}) => ArcViolation(
      rule: 'ARC-009',
      file: file,
      line: 501,
      code: '',
      reason: 'r',
      weight: weight,
    );
    const config = ArcConfig(
      lineaBase: {
        'ARC-009': {'lib/a.dart': 10},
      },
    );

    test('igual o menor que lo permitido no bloquea', () {
      expect(applyConfig([over(10)], config, today), isEmpty);
      expect(applyConfig([over(4)], config, today), isEmpty);
    });

    test('un archivo listado que crece bloquea', () {
      expect(applyConfig([over(11)], config, today), hasLength(1));
    });

    test('un archivo que no está en la lista bloquea', () {
      expect(
        applyConfig([over(1, file: 'lib/b.dart')], config, today),
        hasLength(1),
      );
    });
  });

  // ARC-011 ---------------------------------------------------------------
  group('ARC-011 (SafeEmitMixin)', () {
    test('detecta Cubit, HydratedCubit y Bloc sin el mixin', () {
      for (final base in ['Cubit<S>', 'HydratedCubit<S>', 'Bloc<E, S>']) {
        expect(
          rulesOf('lib/c.dart', 'class A extends $base {}'),
          contains('ARC-011'),
          reason: base,
        );
      }
    });

    test('permite la clase con el mixin y otras clases', () {
      const source =
          'class A extends Cubit<S> with SafeEmitMixin<S> {}\n'
          'class B extends StatelessWidget {}';
      expect(rulesOf('lib/c.dart', source), isNot(contains('ARC-011')));
    });
  });

  // ARC-012 ---------------------------------------------------------------
  group('ARC-012 (pinning)', () {
    test('detecta Dio(), new Dio() y HttpClient() sin pinning', () {
      for (final code in [
        'final d = Dio();',
        'final d = new Dio();',
        'final c = HttpClient();',
      ]) {
        expect(
          rulesOf('lib/x.dart', 'void f() { $code }'),
          contains('ARC-012'),
          reason: code,
        );
      }
    });

    test('permite el cliente si el archivo aplica el pinning', () {
      const source =
          'void f() { final d = Dio(); CertificatePinningConfig.attach(d); }';
      expect(rulesOf('lib/x.dart', source), isNot(contains('ARC-012')));
    });

    test('no confunde otras llamadas ni métodos con el mismo nombre', () {
      const source = 'void f() { client.Dio(); final o = Options(); }';
      expect(rulesOf('lib/x.dart', source), isNot(contains('ARC-012')));
    });
  });

  // ARC-013 ---------------------------------------------------------------
  group('ARC-013 (errores de datasources)', () {
    const path = 'lib/infrastructure/datasources/x/x_datasource.dart';

    test('detecta el catch que devuelve el texto técnico', () {
      const source =
          "f() { try {} catch (e) { return {'message': e.toString()}; } }";
      expect(rulesOf(path, source), contains('ARC-013'));
    });

    test('permite manejador, rethrow, throw y un helper que lo use', () {
      const handled = [
        'f() { try {} catch (e, st) { return CentralErrorHandler.errorMap(e, st); } }',
        'f() { try {} catch (e) { rethrow; } }',
        'f() { try {} catch (e) { throw ServerException(e.toString()); } }',
        'class A { f() { try {} catch (e, st) { return _failure(e, st); } }\n'
            '  _failure(e, st) => CentralErrorHandler.errorMap(e, st); }',
      ];
      for (final source in handled) {
        expect(
          rulesOf(path, source),
          isNot(contains('ARC-013')),
          reason: source,
        );
      }
    });

    test('fuera de la carpeta de datasources no aplica', () {
      const source = 'f() { try {} catch (e) { print(e); } }';
      expect(
        rulesOf('lib/presentation/x.dart', source),
        isNot(contains('ARC-013')),
      );
    });
  });

  group('ARC-015 (avisos repetidos en listeners)', () {
    const path = 'lib/presentation/screens/x/x_screen.dart';
    String screen(
      String listenWhen, {
      String condition = 'state.status == S.error',
    }) =>
        '''
Widget build(BuildContext context) => BlocConsumer<C, S>(
  $listenWhen
  listener: (context, state) {
    if ($condition) {
      DialogUtils.showTemporaryDialog(context, 'Error');
    }
  },
  builder: (context, state) => const SizedBox(),
);
''';

    test('detecta un aviso según un campo sin listenWhen', () {
      expect(rulesOf(path, screen('')), contains('ARC-015'));
      expect(
        rulesOf(path, screen('', condition: 'state.message != null')),
        contains('ARC-015'),
      );
    });

    test('detecta un listenWhen que no mira el estado anterior', () {
      final source = screen('listenWhen: (_, c) => c.status == S.error,');
      expect(rulesOf(path, source), contains('ARC-015'));
    });

    test('permite un listenWhen que compara con el anterior', () {
      final source = screen('listenWhen: (p, c) => p.status != c.status,');
      expect(rulesOf(path, source), isNot(contains('ARC-015')));
    });

    test('un aviso según el tipo del estado no cuenta', () {
      final source = screen('', condition: 'state is XError');
      expect(rulesOf(path, source), isNot(contains('ARC-015')));
    });

    test('una comparación de campos fuera del if del aviso no cuenta', () {
      const source = '''
Widget build(BuildContext context) => BlocConsumer<C, S>(
  listener: (context, state) {
    if (state is XError) DialogUtils.showTemporaryDialog(context, 'Error');
    if (state.index != null) move(state.index);
  },
  builder: (context, state) => const SizedBox(),
);
''';
      expect(rulesOf(path, source), isNot(contains('ARC-015')));
    });
  });

  group('ARC-016 (Equatable: todos los campos en props)', () {
    test('detecta el campo que falta en props', () {
      const source = '''
class S extends Equatable {
  final int a;
  final String b;
  const S(this.a, this.b);
  @override
  List<Object?> get props => [a];
}''';
      final v = auditSource('lib/x.dart', source);
      expect(v.map((v) => v.rule), contains('ARC-016'));
      expect(v.firstWhere((v) => v.rule == 'ARC-016').reason, contains('b'));
    });

    test('permite todos los campos, estáticos fuera y props heredado', () {
      const source = '''
class S extends Equatable {
  static const x = 1;
  final int a;
  const S(this.a);
  @override
  List<Object?> get props => [a];
}
class T extends Equatable {
  final int a;
  const T(this.a);
}''';
      expect(rulesOf('lib/x.dart', source), isNot(contains('ARC-016')));
    });
  });

  group('ARC-017 (clave de cifrado escrita en el código)', () {
    test('detecta PRAGMA key y rekey con texto fijo', () {
      for (final sql in ["PRAGMA key = 'abc';", "pragma rekey = 'x';"]) {
        expect(
          rulesOf('lib/x.dart', 'void f(db) { db.execute("$sql"); }'),
          contains('ARC-017'),
          reason: sql,
        );
      }
    });

    test('permite la clave interpolada desde una variable', () {
      const source = r'''void f(db, k) { db.execute("PRAGMA key = '$k';"); }''';
      expect(rulesOf('lib/x.dart', source), isNot(contains('ARC-017')));
    });
  });

  group('ARC-018 (id del comercio de la sesión)', () {
    test('detecta lecturas a mano de los datos de sesión', () {
      for (final code in [
        "final id = loginData['merchantId'];",
        "final id = sessionData['merchant_id'];",
        "final id = loginCubit.getData()['merchantId'];",
      ]) {
        expect(rulesOf('lib/x.dart', code), contains('ARC-018'), reason: code);
      }
    });

    test('permite getCurrentMerchantId, mensajes del backend y el handler', () {
      const allowed = [
        'final id = loginCubit.getCurrentMerchantId();',
        "final id = rawData['merchant_id'];",
        "// loginData['merchantId'] en un comentario",
      ];
      for (final code in allowed) {
        expect(
          rulesOf('lib/x.dart', code),
          isNot(contains('ARC-018')),
          reason: code,
        );
      }
      expect(
        rulesOf(merchantIdSourceFile, "final id = loginData['merchantId'];"),
        isNot(contains('ARC-018')),
      );
    });
  });
}
````

Ejecútalo con `flutter test test/scripts/script_audit_architecture_test.dart` (proyecto Flutter) o `dart test test/scripts/script_audit_architecture_test.dart` (Dart puro; en ese caso cambia el import `flutter_test` por `package:test/test.dart` y agrega `test` a `dev_dependencies` si falta).

Si cambiaste algún parámetro (por ejemplo, `maxFileLines`), las pruebas lo leen de la constante: no escribas números fijos en ellas.

## 7. Integración en el pre-commit

### 7.1 Proyecto con el kit de agentes de mcp-ia (`.githooks/pre-commit` común + `.githooks/pre-commit.local`)

El hook común **no se edita** en el proyecto: las reglas propias van en `.githooks/pre-commit.local` (se ejecuta en el Gate 5 y recibe `STAGED_FILES`, `STAGED_DART_FILES` y `TESTS_EXTRA_FILE`). Agrega al final, antes del último `exit 0` si lo hay, **una sola vez** (si otro prompt ARC ya lo agregó, no lo dupliques):

````sh
# Auditoría de arquitectura (ARC): revisa todo lib/, no solo el staging; una
# violación en cualquier archivo bloquea el commit.
if [ -f scripts/script_audit_architecture.dart ]; then
  ARCH_OUTPUT=$(dart run scripts/script_audit_architecture.dart 2>&1)
  if [ $? -ne 0 ]; then
    echo "$ARCH_OUTPUT" | grep -A4 'VIOLACIÓN' | grep -v '^--$'
    echo "❌ ERROR ARQUITECTÓNICO: $(echo "$ARCH_OUTPUT" | grep 'Total de violaciones')"
    echo "👉 Detalle: dart run scripts/script_audit_architecture.dart"
    exit 1
  fi
fi

# Guardián: si cambian el auditor, su configuración, su prueba o los hooks,
# se ejecuta la prueba del detector aunque el commit no toque lib/.
if echo "$STAGED_FILES" | grep -Eq '^(scripts/script_audit_architecture\.dart|scripts/arc_config\.json|test/scripts/script_audit_architecture_test\.dart|\.githooks/)'; then
  echo "test/scripts/script_audit_architecture_test.dart" >> "$TESTS_EXTRA_FILE"
fi
````

Si el `pre-commit.local` tiene una salida temprana del tipo «no hay archivos Dart → `exit 0`», el bloque debe quedar **antes** de esa salida o la auditoría no correrá en commits que solo cambien el JSON o el script.

### 7.2 Proyecto sin el kit

Usa el hook que ya tenga el proyecto (`.githooks/pre-commit` con `core.hooksPath`, Husky, Lefthook, `.git/hooks/pre-commit`). Agrega el mismo bloque de auditoría (sin la parte de `TESTS_EXTRA_FILE`, y en su lugar ejecuta la prueba del detector cuando cambie el auditor). Si no hay ningún hook, crea `.githooks/pre-commit`, hazlo ejecutable (`chmod +x`) y actívalo con `git config core.hooksPath .githooks`; documenta ese paso en el README, porque `core.hooksPath` no viaja con el repositorio.

### 7.3 CI (opcional)

Si el proyecto tiene CI activo, agrega un job que ejecute `dart run scripts/script_audit_architecture.dart` y la prueba del detector. No reemplaza al hook.

## 8. Puesta en marcha

1. Confirma la clase de pinning (sección 1) y ajusta `pinningClass`.
2. Activa la regla (`'ARC-012'` en `activeRules`) y ejecuta el auditor. Lista cada archivo marcado.
3. Corrige **todas** las violaciones:
   - Si el cliente debe tener pinning (cualquier cliente que hable con el backend o envíe datos del usuario): aplícalo con el método del proyecto (en zas, `CertificatePinningConfig.attach(dio)` justo después de crearlo, o `CertificatePinningConfig.createPinnedHttpClient()` en lugar de `HttpClient()`).
   - Si es un servicio externo legítimo (mapas, geocodificación), fija también su huella (en zas, `allowedFingerprints: [CertificatePinningConfig.nominatimFingerprint]`).
   - Si de verdad no puede llevar pinning (por ejemplo, un cliente que solo se usa en pruebas de integración dentro de `lib/`), excepción en `arc_config.json` con motivo concreto y vencimiento, y avísalo en el informe.
4. Prueba en un dispositivo o emulador que las llamadas de esos clientes siguen funcionando (el pinning mal configurado bloquea la conexión). Si no puedes probarlo, va a «No verificado».
5. Commit propio para las correcciones (`fix(security):`), con su prueba si el proyecto lo exige, y luego el de la regla.

## 9. Documentación del proyecto

Agrega a `AGENTS.md`:

> **ARC-012:** todo `Dio(` o `HttpClient(` va en un archivo que aplica `CertificatePinningConfig` (pinning de certificados, OWASP MASVS-NETWORK-2). Un cliente nuevo sin pinning bloquea el commit.

## 10. Verificación final (todo debe cumplirse antes de entregar)

Ejecuta y copia la salida relevante en el informe:

````sh
dart run scripts/script_audit_architecture.dart          # termina en "✅ [APROBADO]"
flutter test test/scripts/script_audit_architecture_test.dart   # "All tests passed!"
flutter analyze                                          # "No issues found!"
flutter test                                             # suite completa en verde
````

Además, prueba que la regla **de verdad bloquea** (y deshaz la prueba después):

````sh
cat > lib/_arc_probe.dart <<'EOF'
import 'package:dio/dio.dart';
final probe = Dio();
EOF
dart run scripts/script_audit_architecture.dart; echo "exit=$?"   # exit=1 con ARC-012
rm lib/_arc_probe.dart
````

Lista de comprobación:

- [ ] `'ARC-012'` está en `activeRules` y sus parámetros están ajustados al proyecto.
- [ ] `scripts/arc_config.json` es válido y, si aplica, tiene la línea base generada.
- [ ] El pre-commit ejecuta la auditoría y la prueba del detector (sección 7).
- [ ] La prueba manual de bloqueo falló como se esperaba y se deshizo (`git status` limpio salvo tus cambios).
- [ ] La documentación del proyecto describe la regla (sección 9).
- [ ] Cada error que resolviste está en mcp-ia (o descrito en el informe).

## 11. Errores conocidos y cómo resolverlos

| Síntoma | Causa | Arreglo |
|---|---|---|
| `The getter 'name' isn't defined for the type 'ClassDeclaration'` | analyzer ≥ 13 movió el nombre de la clase a `ClassNamePart` | Usa `node.namePart.typeName` (ya lo hace el código de referencia). Con analyzer < 13 es al revés: usa `node.name`. |
| `The name 'NamedArgument' isn't a type` (o, al revés, `NamedExpression` sin `label`) | La API de los argumentos con nombre cambió en analyzer 13 | analyzer ≥ 13: `NamedArgument` con `name.lexeme` y `argumentExpression` (lo usa el código de referencia). analyzer < 13: `NamedExpression` con `name.label.name` y `expression`. |
| `Target of URI doesn't exist: 'package:analyzer/...'` | Falta la dependencia | `dart pub add --dev analyzer` (o `flutter pub add --dev analyzer`). |
| La prueba del detector no encuentra `auditSource`/`applyConfig` | El import relativo no apunta al script | El test vive en `test/scripts/` y el script en `scripts/`: el import es `'../../scripts/script_audit_architecture.dart'`. |
| El hook no ejecuta la auditoría en un commit que solo cambia el JSON | El bloque quedó después de la salida temprana «sin archivos Dart» | Muévelo antes (sección 7.1). |
| Un bucle de shell sobre una lista de archivos no itera en zsh | zsh no separa en palabras una variable con saltos de línea | Usa `while read -r f; do …; done < archivo` o `for f in ${(f)var}`. |
| `--generar-linea-base` agrega archivos que no esperabas | La regla tenía la línea base vacía: la primera generación toma todo lo actual | Es lo correcto la primera vez. Después, revisa siempre el diff de `arc_config.json` en el commit. |
| El auditor tarda mucho | Proyecto muy grande | Normal: es lineal en el tamaño de `lib/`. No lo limites al staging; así se pierde la garantía de la sección 4. |

## 12. Commit

- Un commit para el auditor y la regla, y uno aparte por cada corrección de código que hayas hecho para cumplirla (si el proyecto exige prueba de regresión en un `fix:`, agrégala).
- Mensaje sugerido (ajústalo al formato del proyecto): `chore(arch): ARC-012 Dio/HttpClient without certificate pinning`.
- Antes del commit, por cada causa corregida: ¿tiene su `add_solution` en mcp-ia? Si no, regístrala primero.
- Si el hook del proyecto pide `Sin-prueba: <motivo>` para cambios sin prueba (por ejemplo, solo JSON o documentación), agrégalo al mensaje con un motivo real.

## 13. Informe de entrega

Responde con:

1. Situación encontrada (sección 3) y qué camino tomaste.
2. Parámetros elegidos y por qué.
3. Resultado inicial de la regla (cuántas violaciones, en qué archivos) y qué hiciste con cada una (corregida, línea base o excepción con motivo y vencimiento).
4. Salida de los comandos de la sección 10 y de la prueba manual de bloqueo.
5. Commits creados (hash y mensaje).
6. Errores resueltos con su ID de mcp-ia (o error, causa y solución si no tienes acceso).
7. «No verificado»: lo que no pudiste comprobar.
