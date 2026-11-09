// scripts/rendimiento_informe.dart
//
// Convierte el informe de integration_test/rendimiento_por_modulo_test.dart
// (build/integration_response_data.json) en Markdown: tabla por módulo,
// módulos que no se pudieron medir y cambios de la sesión.
//
//   dart run scripts/rendimiento_informe.dart [informe.json] [titulo]

import 'dart:convert';
import 'dart:io';

/// Informe en Markdown a partir de los datos de la prueba.
String informeRendimiento(Map<String, dynamic> datos, {String titulo = ''}) {
  final apertura = _mapa(datos['apertura_ms']);
  final errores = _mapa(datos['errores']);
  final sesion = datos['sesion'] is List ? datos['sesion'] as List : const [];
  String ms(Map<String, dynamic> m, String clave) {
    final valor = m[clave];
    return valor is num ? valor.toStringAsFixed(1) : '-';
  }

  final b = StringBuffer();
  if (titulo.isNotEmpty) b.writeln('## $titulo\n');
  b
    ..writeln(
      '| Módulo | Apertura | Fotogramas | Build prom / p99 / peor (ms) '
      '| Raster prom / p99 / peor (ms) | Fuera de presupuesto (build / raster) |',
    )
    ..writeln('|---|---|---|---|---|---|');
  for (final entrada in datos.entries) {
    if (const {'apertura_ms', 'errores', 'sesion'}.contains(entrada.key)) {
      continue;
    }
    final m = _mapa(entrada.value);
    if (m.isEmpty) continue;
    final abre = apertura[entrada.key];
    final textoApertura = abre is! num
        ? '-'
        : abre < 0
        ? 'no terminó'
        : '${(abre / 1000).toStringAsFixed(2)} s';
    b.writeln(
      '| ${entrada.key} | $textoApertura | ${m['frame_count'] ?? '-'} '
      '| ${ms(m, 'average_frame_build_time_millis')} / '
      '${ms(m, '99th_percentile_frame_build_time_millis')} / '
      '${ms(m, 'worst_frame_build_time_millis')} '
      '| ${ms(m, 'average_frame_rasterizer_time_millis')} / '
      '${ms(m, '99th_percentile_frame_rasterizer_time_millis')} / '
      '${ms(m, 'worst_frame_rasterizer_time_millis')} '
      '| ${m['missed_frame_build_budget_count'] ?? '-'} / '
      '${m['missed_frame_rasterizer_budget_count'] ?? '-'} |',
    );
  }
  if (errores.isNotEmpty) {
    b.writeln('\n**Sin medir:**\n');
    for (final e in errores.entries) {
      b.writeln('- ${e.key}: ${e.value}');
    }
  }
  if (sesion.isNotEmpty) {
    b.writeln('\n**Sesión:**\n');
    for (final evento in sesion.whereType<Map>()) {
      final mensaje = evento['mensaje'];
      b.writeln(
        '- ${evento['hora']}: ${evento['evento']} durante «${evento['paso']}»'
        '${mensaje == null ? '' : ' ($mensaje)'}',
      );
    }
  }
  return b.toString();
}

Map<String, dynamic> _mapa(Object? valor) =>
    valor is Map ? Map<String, dynamic>.from(valor) : const {};

void main(List<String> args) {
  final ruta = args.isNotEmpty
      ? args.first
      : 'build/integration_response_data.json';
  final archivo = File(ruta);
  if (!archivo.existsSync()) {
    stderr.writeln('No existe $ruta: corre primero la prueba de rendimiento.');
    exitCode = 1;
    return;
  }
  final datos = jsonDecode(archivo.readAsStringSync());
  if (datos is! Map<String, dynamic>) {
    stderr.writeln('$ruta no es un informe de rendimiento.');
    exitCode = 1;
    return;
  }
  stdout.write(
    informeRendimiento(datos, titulo: args.length > 1 ? args[1] : ''),
  );
}
