import 'package:flutter_test/flutter_test.dart';

import '../../scripts/arc_modules_report.dart';

void main() {
  group('moduleOf', () {
    test('lee el módulo de la carpeta y aplica los alias', () {
      expect(moduleOf('lib/presentation/cubits/order/order_cubit.dart'), (
        module: 'order',
        layer: 'Cubit',
      ));
      expect(
        moduleOf('lib/presentation/screens/support_chat/views/x.dart')?.module,
        'support',
      );
      expect(moduleOf('lib/domain/repositories/repositories.dart'), isNull);
      expect(moduleOf('lib/app/app.dart'), isNull);
    });
  });

  group('moduleStatus', () {
    test('completo, incompleto y sin capa de datos', () {
      const full = {'Interfaz': 1, 'Caso de uso': 1, 'Repositorio': 1};
      expect(moduleStatus(full, 0), '✅ completo');
      expect(moduleStatus({'Repositorio': 1}, 0), contains('falta Interfaz'));
      expect(moduleStatus({'Pantalla': 3}, 0), '· sin capa de datos');
      // Sin cubit ni pantalla (lo usa un servicio): no exige caso de uso.
      expect(
        moduleStatus({'Interfaz': 1, 'Repositorio': 1, 'Datasource': 1}, 0),
        '✅ completo',
      );
      expect(
        moduleStatus({'Interfaz': 1, 'Repositorio': 1, 'Cubit': 1}, 0),
        contains('falta Caso de uso'),
      );
      expect(moduleStatus({'Pantalla': 3}, 1), contains('1 violación DDD'));
      expect(moduleStatus(full, 2), contains('2 violaciones DDD'));
    });
  });

  test('buildModulesReport cuenta archivos por capa y violaciones DDD', () {
    final report = buildModulesReport(
      [
        'lib/domain/repositories/order/i_order_repository.dart',
        'lib/application/usecases/order/get_order_usecase.dart',
        'lib/infrastructure/repositories/order/order_repository_impl.dart',
        'lib/presentation/cubits/order/order_cubit.dart',
        'lib/presentation/screens/home/home_screen.dart',
      ],
      [
        (
          file: 'lib/presentation/screens/home/home_screen.dart',
          rule: 'ARC-022',
        ),
        (
          file: 'lib/presentation/screens/home/home_screen.dart',
          rule: 'ARC-019',
        ),
        (
          file: 'lib/presentation/screens/home/widgets/home_card.dart',
          rule: 'ARC-025',
        ),
        (
          file: 'lib/presentation/screens/home/home_screen.dart',
          rule: 'ARC-027',
        ),
        (
          file: 'lib/presentation/cubits/order/order_cubit.dart',
          rule: 'ARC-028',
        ),
      ],
    );

    expect(
      report,
      contains(
        '| order | — | 1 | 1 | 1 | — | 1 | — | — | — | ⚠️ 1 | ⚠️ sin auditar (1) |',
      ),
    );
    expect(report, contains('| home |'));
    expect(report, contains('1 violación DDD'));
    expect(report, contains('| ⚠️ 1 |'));
    expect(report, contains('diseño con estado o lógica (1)'));
    expect(report, contains('accesibilidad pendiente (1)'));
    expect(report, contains('sin auditar (1)'));
  });

  test('moduleGaps lista los módulos incompletos con su primer archivo', () {
    final gaps = moduleGaps([
      'lib/infrastructure/datasources/remote/catalog_remote_data_source.dart',
      'lib/presentation/screens/home/home_screen.dart',
    ]);
    expect(gaps.single.module, 'remote');
    expect(gaps.single.missing, ['Interfaz', 'Repositorio']);
    expect(
      gaps.single.file,
      'lib/infrastructure/datasources/remote/catalog_remote_data_source.dart',
    );
  });
}
