import 'package:flutter_test/flutter_test.dart';

import '../../scripts/script_audit_architecture.dart'
    show
        ArcConfig,
        ArcException,
        ArcViolation,
        applyConfig,
        auditModuleLayers,
        auditSessionReset,
        auditSource,
        maxFileImports,
        maxFileLines;

/// Protege el detector de ARC-005 (force-unwrap en `lib/domain/`): si alguien
/// lo debilita, estas pruebas fallan en el pre-commit (Gate 6).
List<String> rulesOf(String path, String source) =>
    auditSource(path, source).map((v) => v.rule).toList();

void main() {
  group('ARC-005 (casos de borde del ! postfijo)', () {
    const path = 'lib/domain/entities/x.dart';

    test('detecta cualquier ! postfijo', () {
      const violations = [
        'f() { return DateTime.now().isBefore(lockedUntil!); }',
        "f() => {'created_at': createdAt!.toIso8601String()};",
        'f() { final total = items!.length; }',
        "f() { final id = json['id']!; }",
        'f() { final rate = loadRate()!; }',
        'f() { return values[0]!; }',
        r"f() { final label = 'Tasa ${rate!.value}'; }",
        'f() { final a = b!.c!.d; }',
      ];
      for (final source in violations) {
        expect(rulesOf(path, source), contains('ARC-005'), reason: source);
      }
    });

    test('no confunde negación, !=, is!, texto ni comentarios', () {
      const allowed = [
        'f() { if (!value) return false; }',
        'f() { return a != b; }',
        'f() { if (x is! String) return; }',
        'f() { final ok = !(a && b); }',
        "f() { throw ArgumentError('¡Monto inválido!'); }",
        'const msg = "Hola!";',
        "final text = 'a!=b';",
        "const block = '''valor! en comillas triples''';",
        'f() { return value; } // no usar value! aquí',
        '/// Ejemplo: valor!.metodo()\nf() {}',
        '/* valor! en un comentario de bloque */',
        'f() { final isValid = !isEmpty && !isLocked; }',
      ];
      for (final source in allowed) {
        expect(
          rulesOf(path, source),
          isNot(contains('ARC-005')),
          reason: source,
        );
      }
    });
  });

  group('ARC-001 (aislamiento de capas)', () {
    test('detecta import de package:zas/infrastructure, relativo y export', () {
      final v1 = auditSource(
        'lib/presentation/screens/a/b.dart',
        "import 'package:zas/infrastructure/models/x.dart';",
      );
      expect(v1.map((v) => v.rule), contains('ARC-001'));

      final v2 = auditSource(
        'lib/presentation/screens/a/b.dart',
        "import '../../infrastructure/x.dart';",
      );
      expect(v2.map((v) => v.rule), contains('ARC-001'));

      final v3 = auditSource(
        'lib/presentation/screens/a/b.dart',
        "export 'package:zas/infrastructure/models/x.dart';",
      );
      expect(v3.map((v) => v.rule), contains('ARC-001'));

      final v4 = auditSource(
        'lib/application/usecases/a.dart',
        "import 'package:zas/presentation/screens/x.dart';",
      );
      expect(v4.map((v) => v.rule), contains('ARC-001'));
    });

    test('permite import de lib/domain desde presentation', () {
      final v = auditSource(
        'lib/presentation/screens/a/b.dart',
        "import 'package:zas/domain/entities/x.dart';",
      );
      expect(v, isEmpty);
    });
  });

  group('ARC-002 (prohibido setState en screens)', () {
    test('detecta setState(() {}) y setState (() {}) en screens', () {
      final v1 = auditSource(
        'lib/presentation/screens/x.dart',
        'void f() { setState(() {}); }',
      );
      expect(v1.map((v) => v.rule), ['ARC-002']);

      final v2 = auditSource(
        'lib/presentation/screens/x.dart',
        'void f() { setState (() {}); }',
      );
      expect(v2.map((v) => v.rule), ['ARC-002']);
    });

    test('ignora comentarios de varias líneas y widgets fuera de screens', () {
      final vComment = auditSource(
        'lib/presentation/screens/x.dart',
        '/*\n  setState(() {});\n*/\nvoid f() {}',
      );
      expect(vComment, isEmpty);

      final vWidget = auditSource(
        'lib/presentation/widgets/x.dart',
        'void f() { setState(() {}); }',
      );
      expect(vWidget, isEmpty);
    });
  });

  group('ARC-003 (vistas agnósticas)', () {
    test('detecta flutter_bloc, _cubit.dart y _bloc.dart en views/', () {
      final v1 = auditSource(
        'lib/presentation/screens/home/views/home_view.dart',
        "import 'package:flutter_bloc/flutter_bloc.dart';",
      );
      expect(v1.map((v) => v.rule), ['ARC-003']);

      final v2 = auditSource(
        'lib/presentation/screens/home/views/home_view.dart',
        "import '../../cubits/home_cubit.dart';",
      );
      expect(v2.map((v) => v.rule), ['ARC-003']);

      final v3 = auditSource(
        'lib/presentation/screens/home/views/home_view.dart',
        "import 'package:zas/presentation/blocs/auth_bloc.dart';",
      );
      expect(v3.map((v) => v.rule), ['ARC-003']);
    });

    test('permite imports de dominio o widgets en views/', () {
      final v = auditSource(
        'lib/presentation/screens/home/views/home_view.dart',
        "import 'package:flutter/material.dart';",
      );
      expect(v, isEmpty);
    });
  });

  group('ARC-004 (prohibido http://)', () {
    test('detecta literales http:// y permite excepciones de esquemas XML', () {
      final vBad = auditSource(
        'lib/infrastructure/network/api.dart',
        "const url = 'http://api.example.com/v1';",
      );
      expect(vBad.map((v) => v.rule), ['ARC-004']);

      final vW3 = auditSource(
        'lib/infrastructure/network/xml.dart',
        "const ns = 'http://www.w3.org/2000/svg';",
      );
      expect(vW3, isEmpty);

      final vHttps = auditSource(
        'lib/infrastructure/network/api.dart',
        "const url = 'https://api.example.com/v1';",
      );
      expect(vHttps, isEmpty);
    });
  });

  group('ARC-005 (force-unwrap en AST de domain)', () {
    test('detecta x!, json[\'k\']! y f()! en lib/domain/', () {
      final v = auditSource('lib/domain/entities/x.dart', '''
void testFn(int? x, Map<String, int?> json, int? Function() f) {
  final a = x!;
  final b = json['k']!;
  final c = f()!;
}
''');
      expect(v.where((e) => e.rule == 'ARC-005').length, 3);
    });

    test(
      'permite !=, is! y texto con signos de exclamación en lib/domain/',
      () {
        final v = auditSource('lib/domain/entities/x.dart', '''
bool testFn(Object? x, Object? y) {
  if (x is! String) return false;
  const saludo = '¡Hola!';
  return x != y && saludo.isNotEmpty;
}
''');
        expect(v, isEmpty);
      },
    );
  });

  group('ARC-006 (domain Dart puro)', () {
    test('detecta package:flutter y relativo a application desde domain', () {
      final v1 = auditSource(
        'lib/domain/a/b.dart',
        "import 'package:flutter/material.dart';",
      );
      expect(v1.map((v) => v.rule), contains('ARC-006'));

      final v2 = auditSource(
        'lib/domain/a/b.dart',
        "import '../../application/x.dart';",
      );
      expect(v2.map((v) => v.rule), contains('ARC-006'));
    });

    test('permite imports internos de domain y paquetes Dart puros', () {
      final v = auditSource(
        'lib/domain/a/b.dart',
        "import 'dart:async';\nimport '../core/entity.dart';",
      );
      expect(v, isEmpty);
    });
  });

  group('ARC-007 (catch vacío en application/infrastructure)', () {
    test('detecta catch (_) {} y catch (e) {} en infrastructure', () {
      final v = auditSource('lib/infrastructure/repositories/x.dart', '''
void f() {
  try {} catch (_) {}
  try {} catch (e) {}
}
''');
      expect(v.map((e) => e.rule), ['ARC-007', 'ARC-007']);
    });

    test('permite catch con sentencias y catch vacío en presentation', () {
      final vLogged = auditSource('lib/infrastructure/repositories/x.dart', '''
void f(void Function(Object) log) {
  try {} catch (e) { log(e); }
}
''');
      expect(vLogged.map((v) => v.rule), isNot(contains('ARC-007')));
      // Solo registrarlo no lo audita: eso es ARC-028.
      expect(vLogged.map((v) => v.rule), ['ARC-028']);

      final vPresentation = auditSource(
        'lib/presentation/cubits/x.dart',
        'void f() { try {} catch (_) {} }',
      );
      expect(vPresentation.map((v) => v.rule), isNot(contains('ARC-007')));
      expect(vPresentation.map((v) => v.rule), ['ARC-028']);
    });
  });

  group('ARC-008 (cast directo sobre IndexExpression)', () {
    test(
      'detecta json[\'x\'] as String en infrastructure y en fromJson de domain',
      () {
        final vInfra = auditSource(
          'lib/infrastructure/models/x.dart',
          "String f(Map<String, dynamic> json) => json['x'] as String;",
        );
        expect(vInfra.map((v) => v.rule), ['ARC-008']);

        final vDomainFromJson = auditSource('lib/domain/entities/x.dart', '''
class Entity {
  final String x;
  Entity(this.x);
  factory Entity.fromJson(Map<String, dynamic> json) {
    return Entity(json['x'] as String);
  }
}
''');
        expect(vDomainFromJson.map((v) => v.rule), ['ARC-008']);
      },
    );

    test('permite as String?, as dynamic y ?.toString()', () {
      final vAllowed = auditSource('lib/infrastructure/models/x.dart', '''
void f(Map<String, dynamic> json) {
  final a = json['x'] as String?;
  final b = json['x'] as dynamic;
  final c = json['x']?.toString();
}
''');
      expect(vAllowed, isEmpty);
    });
  });

  group('applyConfig (excepciones y línea base)', () {
    const sampleArc002 = ArcViolation(
      rule: 'ARC-002',
      file: 'lib/presentation/screens/splash/splash_screen.dart',
      line: 10,
      code: 'setState(() {});',
      reason: 'motivo',
    );

    test('excepción vigente excluye y excepción vencida no excluye', () {
      const config = ArcConfig(
        excepciones: [
          ArcException(
            regla: 'ARC-002',
            archivo: 'lib/presentation/screens/splash/splash_screen.dart',
            motivo: 'VideoPlayerController',
            vence: '2027-12-31',
          ),
        ],
      );

      final active = applyConfig(
        [sampleArc002],
        config,
        DateTime(2026, 10, 26),
      );
      expect(active, isEmpty);

      final expired = applyConfig([sampleArc002], config, DateTime(2028, 1, 1));
      expect(expired, hasLength(1));
    });

    test('línea base igual o menor no cuenta y superada cuenta todas', () {
      const config = ArcConfig(
        lineaBase: {
          'ARC-007': {'lib/infrastructure/a.dart': 2},
        },
      );
      const v1 = ArcViolation(
        rule: 'ARC-007',
        file: 'lib/infrastructure/a.dart',
        line: 1,
        code: 'catch (_) {}',
        reason: 'r',
      );
      const v2 = ArcViolation(
        rule: 'ARC-007',
        file: 'lib/infrastructure/a.dart',
        line: 2,
        code: 'catch (_) {}',
        reason: 'r',
      );
      const v3 = ArcViolation(
        rule: 'ARC-007',
        file: 'lib/infrastructure/a.dart',
        line: 3,
        code: 'catch (_) {}',
        reason: 'r',
      );

      expect(applyConfig([v1], config, DateTime(2026, 10, 26)), isEmpty);
      expect(applyConfig([v1, v2], config, DateTime(2026, 10, 26)), isEmpty);
      expect(
        applyConfig([v1, v2, v3], config, DateTime(2026, 10, 26)),
        hasLength(3),
      );
    });

    test('ARC-001 nunca admite línea base', () {
      const config = ArcConfig(
        lineaBase: {
          'ARC-001': {'lib/presentation/a.dart': 5},
        },
      );
      const v = ArcViolation(
        rule: 'ARC-001',
        file: 'lib/presentation/a.dart',
        line: 1,
        code: "import 'package:zas/infrastructure/x.dart';",
        reason: 'r',
      );

      final result = applyConfig([v], config, DateTime(2026, 10, 26));
      expect(result, hasLength(1));
    });
  });

  group('ARC-009 y ARC-010 (tamaño e imports del archivo)', () {
    List<String> rulesOf(String path, String source) =>
        auditSource(path, source).map((v) => v.rule).toList();

    test('marca el exceso de líneas con su peso', () {
      final source = List.filled(maxFileLines + 3, '// x').join('\n');
      final v = auditSource(
        'lib/presentation/a.dart',
        source,
      ).where((v) => v.rule == 'ARC-009').single;
      expect(v.weight, 3);
      expect(
        rulesOf('lib/a.dart', List.filled(maxFileLines, '//').join('\n')),
        isNot(contains('ARC-009')),
      );
      expect(rulesOf('test/a.dart', source), isNot(contains('ARC-009')));
    });

    test('marca el exceso de imports con su peso', () {
      String imports(int n) =>
          List.generate(n, (i) => "import 'package:zas/m$i.dart';").join('\n');
      final v = auditSource(
        'lib/a.dart',
        imports(maxFileImports + 2),
      ).where((v) => v.rule == 'ARC-010').single;
      expect(v.weight, 2);
      expect(
        rulesOf('lib/a.dart', imports(maxFileImports)),
        isNot(contains('ARC-010')),
      );
    });

    test('la línea base suma pesos: un archivo listado no puede crecer', () {
      const config = ArcConfig(
        lineaBase: {
          'ARC-009': {'lib/a.dart': 10},
        },
      );
      ArcViolation over(int weight) => ArcViolation(
        rule: 'ARC-009',
        file: 'lib/a.dart',
        line: 501,
        code: '',
        reason: 'r',
        weight: weight,
      );
      final today = DateTime(2026, 11, 3);
      expect(applyConfig([over(10)], config, today), isEmpty);
      expect(applyConfig([over(11)], config, today), hasLength(1));
    });
  });

  group('ARC-011 (SafeEmitMixin)', () {
    test('detecta Cubit/HydratedCubit/Bloc sin SafeEmitMixin', () {
      for (final base in ['Cubit<S>', 'HydratedCubit<S>', 'Bloc<E, S>']) {
        final v = auditSource(
          'lib/presentation/c.dart',
          'class A extends $base {}',
        );
        expect(v.map((v) => v.rule), contains('ARC-011'), reason: base);
      }
    });

    test('permite la clase con el mixin y otras clases', () {
      final v = auditSource(
        'lib/presentation/c.dart',
        'class A extends Cubit<S> with SafeEmitMixin<S> {}\n'
            'class B extends StatelessWidget {}',
      );
      expect(v.map((v) => v.rule), isNot(contains('ARC-011')));
    });
  });

  group('ARC-012 (pinning en clientes HTTP)', () {
    test('detecta Dio() y HttpClient() sin CertificatePinningConfig', () {
      for (final code in ['final d = Dio();', 'final c = HttpClient();']) {
        final v = auditSource(
          'lib/infrastructure/x.dart',
          'void f() { $code }',
        );
        expect(v.map((v) => v.rule), contains('ARC-012'), reason: code);
      }
    });

    test('permite el cliente si el archivo aplica el pinning', () {
      final v = auditSource(
        'lib/infrastructure/x.dart',
        'void f() { final d = Dio(); CertificatePinningConfig.attach(d); }',
      );
      expect(v.map((v) => v.rule), isNot(contains('ARC-012')));
    });
  });

  group('ARC-013 (errores de datasources)', () {
    const path = 'lib/infrastructure/datasources/x/x_datasource.dart';

    test('detecta un catch que devuelve el texto técnico', () {
      final v = auditSource(
        path,
        "f() { try {} catch (e) { return {'message': e.toString()}; } }",
      );
      expect(v.map((v) => v.rule), contains('ARC-013'));
    });

    test(
      'permite CentralErrorHandler, rethrow, throw y un helper que lo use',
      () {
        const handled = [
          'f() { try {} catch (e, st) { return CentralErrorHandler.errorMap(e, st); } }',
          'f() { try {} catch (e) { rethrow; } }',
          'f() { try {} catch (e) { throw ServerException(e.toString()); } }',
          'class A { f() { try {} catch (e, st) { return _failure(e, st); } }\n'
              '  _failure(e, st) => CentralErrorHandler.errorMap(e, st); }',
        ];
        for (final source in handled) {
          final v = auditSource(path, source);
          expect(
            v.map((v) => v.rule),
            isNot(contains('ARC-013')),
            reason: source,
          );
        }
      },
    );

    test('acepta un helper de una extensión o un mixin', () {
      for (final source in [
        'extension E on A { f() { try {} catch (e, st) { return _failure(e, st); } }\n'
            '  _failure(e, st) => CentralErrorHandler.errorMap(e, st); }',
        'mixin M { f() { try {} catch (e, st) { return _failure(e, st); } }\n'
            '  _failure(e, st) => CentralErrorHandler.errorMap(e, st); }',
      ]) {
        expect(
          rulesOf(path, source),
          isNot(contains('ARC-013')),
          reason: source,
        );
      }
    });

    test('no se engaña con nombres parecidos ni con texto', () {
      for (final source in [
        // `my_failure(` contiene `_failure(` pero no es el helper.
        'class A { f() { try {} catch (e) { return my_failure(e); } }\n'
            '  _failure(e, st) => CentralErrorHandler.errorMap(e, st);\n'
            '  my_failure(e) => e.toString(); }',
        "f() { try {} catch (e) { return 'no uses CentralErrorHandler'; } }",
        "f() { try {} catch (e) { return 'throw o rethrow'; } }",
      ]) {
        expect(rulesOf(path, source), contains('ARC-013'), reason: source);
      }
    });

    test('fuera de datasources no aplica', () {
      final v = auditSource(
        'lib/presentation/x.dart',
        'f() { try {} catch (e) { print(e); } }',
      );
      expect(v.map((v) => v.rule), isNot(contains('ARC-013')));
    });
  });

  group('ARC-014 (Cubits globales se reinician al cerrar sesión)', () {
    const providers =
        '\n  BlocProvider<LoginCubit>(create: (_) => LoginCubit()),\n'
        '  BlocProvider<HomeCubit>(create: (_) => HomeCubit()),\n';

    test('detecta el Cubit global que no está en resetSessionCubits', () {
      final v = auditSessionReset(
        providersPath: 'lib/app/providers.dart',
        providersSource: providers,
        logoutSource: 'context.read<LoginCubit>().reset();',
      );
      expect(v.single.rule, 'ARC-014');
      expect(v.single.reason, contains('HomeCubit'));
      expect(v.single.line, 3);
    });

    test('también revisa BlocProvider.value y tipos nullable', () {
      final v = auditSessionReset(
        providersPath: 'lib/app/providers.dart',
        providersSource:
            'BlocProvider.value<HomeCubit>(value: home),\n'
            'BlocProvider<CartCubit?>(create: (_) => null),\n',
        logoutSource: 'context.read<HomeCubit>() .reset();',
      );
      expect(v.single.reason, contains('CartCubit'));
    });

    test('sin faltantes no hay violaciones', () {
      final v = auditSessionReset(
        providersPath: 'lib/app/providers.dart',
        providersSource: providers,
        logoutSource:
            'context.read<LoginCubit>().reset();\n'
            'context.read<HomeCubit>().reset();',
      );
      expect(v, isEmpty);
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
        "final id = cubit.loginData?['merchantId'];",
        "final id = (sessionData)['merchant_id'];",
      ]) {
        expect(rulesOf('lib/x.dart', code), contains('ARC-018'), reason: code);
      }
    });

    test('permite getCurrentMerchantId, mensajes del backend y el handler', () {
      const allowed = [
        'final id = loginCubit.getCurrentMerchantId();',
        "final id = rawData['merchant_id'];",
        "// loginData['merchantId'] en un comentario",
        "final id = 1; // loginData['merchantId'] al final de la línea",
        "/* sessionData['merchantId'] */ final id = 1;",
        "final msg = \"loginData['merchantId']\";",
        "final id = getData(x)['merchantId'];",
      ];
      for (final code in allowed) {
        expect(
          rulesOf('lib/x.dart', code),
          isNot(contains('ARC-018')),
          reason: code,
        );
      }
      expect(
        rulesOf(
          'lib/presentation/cubits/auth/handlers/login_session_handler.dart',
          "final id = loginData['merchantId'];",
        ),
        isNot(contains('ARC-018')),
      );
    });
  });

  group('ARC-019 (force-unwrap fuera de domain)', () {
    const code = '''
void testFn(int? x, Map<String, int?> json, Object? o) {
  final a = x!;
  final b = json['k']!;
  if (o is! String) return;
  final c = a != b;
}
''';

    test('detecta x! y json[\'k\']! en presentation e infrastructure', () {
      for (final path in [
        'lib/presentation/screens/x.dart',
        'lib/infrastructure/x.dart',
      ]) {
        final v = auditSource(path, code);
        expect(v.where((e) => e.rule == 'ARC-019').length, 2, reason: path);
      }
    });

    test('no duplica ARC-005 en domain ni mira fuera de lib/', () {
      expect(
        rulesOf('lib/domain/entities/x.dart', code),
        isNot(contains('ARC-019')),
      );
      expect(rulesOf('test/x_test.dart', code), isNot(contains('ARC-019')));
    });
  });

  group('ARC-020 (datos sensibles en los registros)', () {
    const path = 'lib/application/x.dart';

    test('detecta tokens, contraseñas, PIN y OTP en Logger', () {
      for (final source in [
        r"f() { Logger.info('Token: $token'); }",
        r"f() { Logger.debug('Clave ${state.password.value}'); }",
        r"f() { Logger.error('PIN', pinCode); }",
        r"f() { Logger.info('OTP: $otpCode'); }",
        r"f() { Logger.info('PIN ${user.pin}'); }",
        r"f() { Logger.info('Acceso ${getAccessToken()}'); }",
        r"f() { Logger.info('code + phone: $code + $phone'); }",
        r"f() { Logger.info('rep_phone: $repPhone'); }",
        r"f() { Logger.info('teléfono ${telefonoCliente}'); }",
        r"f() { Logger.info('doc: $merchantDocNumber'); }",
        r"f() { Logger.info('foto ${imageDni.path}'); }",
      ]) {
        expect(rulesOf(path, source), contains('ARC-020'), reason: source);
      }
    });

    test('permite texto fijo, booleanos y comprobaciones sin el valor', () {
      for (final source in [
        "f() { Logger.info('Token FCM registrado'); }",
        r"f() { Logger.info('vault=$hasVaultPassword'); }",
        r"f() { Logger.info('token=${token?.isNotEmpty == true}'); }",
        r"f() { Logger.info('largo ${pin.length}, nulo ${token == null}'); }",
        r"f() { Logger.info('OTP válido: ${otp.isValid}'); }",
        r"f() { Logger.info('fijado: $pinned, $spinner, $shipping'); }",
        r"f() { print('$token'); }",
        "f() { Logger.error('Phone code cannot be null'); }",
        r"f() { Logger.info('teléfono válido: ${phoneInput.isValid}'); }",
        r"f() { Logger.info('con teléfono: $hasPhone'); }",
      ]) {
        expect(
          rulesOf(path, source),
          isNot(contains('ARC-020')),
          reason: source,
        );
      }
    });
  });

  group('ARC-021 (ignore del analizador con motivo)', () {
    test('detecta ignore e ignore_for_file sin motivo', () {
      for (final source in [
        '// ignore_for_file: use_build_context_synchronously\nf() {}',
        'f() {\n  // ignore: unawaited_futures\n  g();\n}',
        '// ignore: a, b\nf() {}',
      ]) {
        final v = auditSource('lib/presentation/x.dart', source);
        expect(v.map((v) => v.rule), contains('ARC-021'), reason: source);
      }
      final v = auditSource(
        'lib/x.dart',
        'f() {\n  // ignore: unawaited_futures\n  g();\n}',
      );
      expect(v.singleWhere((v) => v.rule == 'ARC-021').line, 2);
    });

    test('permite el motivo, otros comentarios y archivos generados', () {
      const reasoned =
          '// ignore_for_file: deprecated_member_use - falta migrar a RadioGroup\nf() {}';
      expect(rulesOf('lib/x.dart', reasoned), isNot(contains('ARC-021')));
      expect(
        rulesOf('lib/x.dart', '// ignora esto: no es un ignore\nf() {}'),
        isNot(contains('ARC-021')),
      );
      const generated = '// ignore_for_file: type=lint\nf() {}';
      expect(rulesOf('lib/a.g.dart', generated), isNot(contains('ARC-021')));
      expect(rulesOf('lib/l10n/a.dart', generated), isNot(contains('ARC-021')));
      expect(rulesOf('test/a.dart', generated), isNot(contains('ARC-021')));
    });
  });

  group('ARC-022 (presentation va por casos de uso)', () {
    test(
      'detecta repositorios y datasources como tipo, en locator o creados',
      () {
        for (final source in [
          'class C { final IOrderRepository repo; C(this.repo); }',
          'f() { final r = locator<SecurityRepository>(); }',
          'f() => GetX(locator<IInstantDebitRepository>());',
          'f() => OrderRepositoryImpl();',
          'f() { final d = locator<SupportChatDatasource>(); }',
        ]) {
          expect(
            rulesOf('lib/presentation/cubits/x/x_cubit.dart', source),
            contains('ARC-022'),
            reason: source,
          );
        }
      },
    );

    test('permite casos de uso y aplica solo en presentation', () {
      const useCase = 'f() { final u = locator<GetOrderUseCase>(); }';
      expect(
        rulesOf('lib/presentation/screens/x/x.dart', useCase),
        isNot(contains('ARC-022')),
      );
      const repo = 'class U { final IOrderRepository repo; U(this.repo); }';
      expect(
        rulesOf('lib/application/usecases/x/x.dart', repo),
        isNot(contains('ARC-022')),
      );
    });
  });

  group('ARC-023 (application no importa infrastructure)', () {
    test('detecta import por paquete y relativo', () {
      for (final source in [
        "import 'package:zas/infrastructure/models/x_model.dart';",
        "import '../../../infrastructure/repositories/x.dart';",
      ]) {
        expect(
          rulesOf('lib/application/usecases/x/x_usecase.dart', source),
          contains('ARC-023'),
          reason: source,
        );
      }
    });

    test('permite domain y no aplica fuera de application', () {
      expect(
        rulesOf(
          'lib/application/usecases/x/x_usecase.dart',
          "import 'package:zas/domain/repositories/x.dart';",
        ),
        isNot(contains('ARC-023')),
      );
      expect(
        rulesOf(
          'lib/config/locator/x.dart',
          "import 'package:zas/infrastructure/x.dart';",
        ),
        isNot(contains('ARC-023')),
      );
    });
  });

  group('ARC-024 (repositorio implementa una interfaz de domain)', () {
    const path = 'lib/infrastructure/repositories/x/x_repository_impl.dart';

    test('detecta el repositorio sin implements', () {
      for (final source in [
        'class OrderRepository { }',
        'class OrderRepositoryImpl extends Base { }',
      ]) {
        expect(rulesOf(path, source), contains('ARC-024'), reason: source);
      }
    });

    test('permite implements, abstractas, privadas y otras clases', () {
      for (final source in [
        'class OrderRepositoryImpl implements IOrderRepository { }',
        'class A extends Base implements IOrderRepository { }',
        'abstract class BaseRepository { }',
        'class _CacheRepository { }',
        'class OrderMapper { }',
      ]) {
        expect(
          rulesOf(path, source),
          isNot(contains('ARC-024')),
          reason: source,
        );
      }
      expect(
        rulesOf('lib/domain/repositories/x.dart', 'class OrderRepository { }'),
        isNot(contains('ARC-024')),
      );
    });
  });

  group('ARC-025 (diseño agnóstico: vistas y widgets de pantalla)', () {
    const widget = 'lib/presentation/screens/users/widgets/role_selector.dart';
    const view = 'lib/presentation/screens/users/views/users_view.dart';

    test('detecta cubits, blocs, context.read, locator y casos de uso', () {
      for (final source in [
        'f(c) => BlocBuilder<UsersCubit, S>(builder: g);',
        'f(context) { context.read<UsersCubit>().save(); }',
        'f(context) => context.watch<LoginCubit>().state;',
        'class W { final UsersCubit cubit; W(this.cubit); }',
        'f() { final u = locator<GetUsersUseCase>(); }',
        'f() => GetUsersUseCase(repo);',
        "import 'package:flutter_bloc/flutter_bloc.dart';",
        "import 'package:zas/application/usecases/search/search_engine.dart';",
        "import 'package:zas/config/locator/locator.dart';",
      ]) {
        expect(rulesOf(widget, source), contains('ARC-025'), reason: source);
      }
      expect(
        rulesOf(view, 'f(context) { context.read<UsersCubit>().save(); }'),
        contains('ARC-025'),
      );
      // También `widget/` (singular) y widgets de una subcarpeta del módulo.
      for (final path in [
        'lib/presentation/screens/trade_register/widget/account_card.dart',
        'lib/presentation/screens/auth/two_factor/widgets/code_input.dart',
      ]) {
        expect(
          rulesOf(path, 'f(context) { context.read<UsersCubit>().save(); }'),
          contains('ARC-025'),
          reason: path,
        );
      }
    });

    test('permite datos, callbacks y la pantalla coordinadora', () {
      for (final source in [
        'class W { final List<String> roles; final void Function(String) onPick; W(this.roles, this.onPick); }',
        'f(context) => Theme.of(context).colorScheme;',
        'f(context) => context.read();',
        '// usa UsersCubit desde la pantalla',
      ]) {
        expect(
          rulesOf(widget, source),
          isNot(contains('ARC-025')),
          reason: source,
        );
      }
      const coordinator = 'f(context) { context.read<UsersCubit>().save(); }';
      expect(
        rulesOf(
          'lib/presentation/screens/users/users_screen.dart',
          coordinator,
        ),
        isNot(contains('ARC-025')),
      );
      expect(
        rulesOf('lib/presentation/widgets/logout_helper.dart', coordinator),
        isNot(contains('ARC-025')),
      );
    });
  });

  group('ARC-027 (accesibilidad: Semantics, tooltip y etiquetas)', () {
    const view = 'lib/presentation/screens/x/views/x_view.dart';

    test('detecta toques y botones sin nombre e imágenes sin etiqueta', () {
      for (final source in [
        'f() => GestureDetector(onTap: g, child: Text("Hola"));',
        'f() => IconButton(icon: Icon(Icons.close), onPressed: g);',
        'f() => IconButton.filled(icon: Icon(Icons.add), onPressed: g);',
        "f() => Image.asset('assets/a.png');",
        "f() => const Image.network('https://a/b.png');",
        "f() => SvgPicture.asset('assets/a.svg');",
      ]) {
        expect(rulesOf(view, source), contains('ARC-027'), reason: source);
      }
    });

    test('acepta Semantics, tooltip, etiquetas y lo decorativo', () {
      for (final source in [
        'f() => Semantics(button: true, label: "Abrir", child: GestureDetector(onTap: g));',
        'f() => GestureDetector(onTap: g, child: Semantics(label: "Abrir", child: x));',
        'f() => GestureDetector(excludeFromSemantics: true, onTap: g);',
        'f() => Semantics(child: Builder(builder: (c) => GestureDetector(onTap: g)));',
        'f() => IconButton(tooltip: "Cerrar", icon: Icon(Icons.close), onPressed: g);',
        'f() => IconButton.styleFrom(backgroundColor: c);',
        "f() => Image.asset('a.png', semanticLabel: 'Logo');",
        "f() => Image.asset('a.png', excludeFromSemantics: true);",
        "f() => SvgPicture.asset('a.svg', semanticsLabel: 'Logo');",
      ]) {
        expect(
          rulesOf(view, source),
          isNot(contains('ARC-027')),
          reason: source,
        );
      }
    });

    test('fuera de la presentación no aplica', () {
      expect(
        rulesOf(
          'lib/app/x.dart',
          'f() => IconButton(icon: Icon(Icons.close), onPressed: g);',
        ),
        isNot(contains('ARC-027')),
      );
    });
  });

  group('ARC-028 (errores auditados en todas las capas)', () {
    test('detecta un catch genérico que no audita ni relanza', () {
      for (final path in [
        'lib/application/usecases/x/x_usecase.dart',
        'lib/infrastructure/repositories/x/x_repository_impl.dart',
        'lib/infrastructure/services/x_service.dart',
        'lib/presentation/cubits/x/x_cubit.dart',
      ]) {
        const source =
            r'f() { try { g(); } catch (e) { Logger.error("$e"); } }';
        expect(rulesOf(path, source), contains('ARC-028'), reason: path);
      }
    });

    test(
      'acepta CentralErrorHandler, AuditLogger, rethrow, helper y catch tipado',
      () {
        const path = 'lib/infrastructure/repositories/x/x_repository_impl.dart';
        for (final source in [
          'f() { try { g(); } catch (e, st) { return CentralErrorHandler.handleAndLog(e, st); } }',
          'f() { try { g(); } catch (e, st) { AuditLogger.logError("x", e.toString()); } }',
          'f() { try { g(); } catch (e) { rethrow; } }',
          'h(e, st) => CentralErrorHandler.errorMap(e, st);\nf() { try { g(); } catch (e, st) { return h(e, st); } }',
          'f() { try { g(); } on FormatException catch (_) { return null; } }',
        ]) {
          expect(
            rulesOf(path, source),
            isNot(contains('ARC-028')),
            reason: source,
          );
        }
      },
    );

    test('no aplica a la propia auditoría ni a los datasources (ARC-013)', () {
      const source = r'f() { try { g(); } catch (e) { Logger.error("$e"); } }';
      for (final path in [
        'lib/infrastructure/audit/audit_logger.dart',
        'lib/infrastructure/services/audit_sync_service.dart',
        'lib/application/utils/central_error_handler.dart',
        'lib/infrastructure/datasources/x/x_datasource.dart',
        'lib/presentation/screens/x/x_screen.dart',
      ]) {
        expect(rulesOf(path, source), isNot(contains('ARC-028')), reason: path);
      }
    });
  });

  group('ARC-029 (toques registrados en la auditoría de movimientos)', () {
    const screen = 'lib/presentation/screens/x/x_screen.dart';

    test('detecta una pantalla con toques sin registrar', () {
      expect(
        rulesOf(
          screen,
          'f() => IconButton(tooltip: "a", onPressed: g, icon: i);',
        ),
        contains('ARC-029'),
      );
    });

    test('acepta auditedCallback, AuditableAction y la exención con motivo', () {
      for (final source in [
        'f(c) => IconButton(tooltip: "a", onPressed: auditedCallback(c, g), icon: i);',
        'f() => AuditableAction(child: InkWell(onTap: g));',
        '// auditoria: exento - solo muestra datos\nf() => InkWell(onTap: g);',
      ]) {
        expect(
          rulesOf(screen, source),
          isNot(contains('ARC-029')),
          reason: source,
        );
      }
      expect(
        rulesOf('lib/presentation/widgets/x.dart', 'f() => InkWell(onTap: g);'),
        isNot(contains('ARC-029')),
      );
    });
  });

  group('ARC-026 (flujo DDD completo por módulo)', () {
    test('bloquea un módulo con datos al que le falta una capa', () {
      final v = auditModuleLayers([
        'lib/domain/repositories/orders/i_orders_repository.dart',
        'lib/infrastructure/datasources/orders/orders_datasource.dart',
        'lib/presentation/cubits/orders/orders_cubit.dart',
      ]);
      expect(v.single.rule, 'ARC-026');
      expect(v.single.reason, contains('Caso de uso'));
      expect(v.single.reason, contains('Repositorio'));
      expect(v.single.file, startsWith('lib/'));
    });

    test('permite módulos completos, de solo UI y sin UI propia', () {
      final v = auditModuleLayers([
        // Completo.
        'lib/domain/repositories/orders/i_orders_repository.dart',
        'lib/application/usecases/orders/get_orders_usecase.dart',
        'lib/infrastructure/repositories/orders/orders_repository_impl.dart',
        'lib/presentation/cubits/orders/orders_cubit.dart',
        // Solo pantallas.
        'lib/presentation/screens/splash/splash_screen.dart',
        // Datos sin cubit ni pantalla (lo usa un servicio).
        'lib/domain/repositories/sync/i_sync_repository.dart',
        'lib/infrastructure/repositories/sync/sync_repository_impl.dart',
      ]);
      expect(v, isEmpty);
    });
  });
}
