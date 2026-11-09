// test/scripts/rendimiento_informe_test.dart

import 'package:flutter_test/flutter_test.dart';

import '../../scripts/rendimiento_informe.dart';

void main() {
  test('arma la tabla, los módulos sin medir y los cambios de sesión', () {
    final informe = informeRendimiento({
      'historial': {
        'frame_count': 120,
        'average_frame_build_time_millis': 0.8,
        '99th_percentile_frame_build_time_millis': 4.2,
        'worst_frame_build_time_millis': 16.9,
        'average_frame_rasterizer_time_millis': 7.0,
        '99th_percentile_frame_rasterizer_time_millis': 18.4,
        'worst_frame_rasterizer_time_millis': 25.8,
        'missed_frame_build_budget_count': 1,
        'missed_frame_rasterizer_budget_count': 4,
      },
      'soporte_tecnico': {'frame_count': 3},
      'apertura_ms': {'historial': 820, 'soporte_tecnico': -1},
      'errores': {'pagar_suscripcion': 'no encontró el menú'},
      'sesion': [
        {
          'hora': '2026-11-09T13:26:02',
          'paso': 'volver desde grupos_cajitas',
          'evento': 'cerrada',
          'mensaje': 'Tu sesión se cerró',
        },
      ],
    }, titulo: 'Redmi Note 8');

    expect(informe, startsWith('## Redmi Note 8'));
    expect(
      informe,
      contains(
        '| historial | 0.82 s | 120 | 0.8 / 4.2 / 16.9 | 7.0 / 18.4 / 25.8 | 1 / 4 |',
      ),
    );
    expect(informe, contains('| soporte_tecnico | no terminó | 3 | - / - / -'));
    expect(informe, contains('- pagar_suscripcion: no encontró el menú'));
    expect(
      informe,
      contains(
        '- 2026-11-09T13:26:02: cerrada durante «volver desde grupos_cajitas» '
        '(Tu sesión se cerró)',
      ),
    );
  });

  test('sin errores ni sesión no agrega esas secciones', () {
    final informe = informeRendimiento({
      'inicio': {'frame_count': 10},
      'apertura_ms': {'inicio': 2190},
    });

    expect(informe, contains('| inicio | 2.19 s | 10 |'));
    expect(informe, isNot(contains('Sin medir')));
    expect(informe, isNot(contains('Sesión')));
  });
}
