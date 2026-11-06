// scripts/arc_modules_report.dart

/// Reporte DDD por módulo (`script_audit_architecture.dart --modulos`): qué
/// capas tiene cada módulo y cuántas violaciones DDD (ARC-022 a ARC-024)
/// acumula. No bloquea; sirve para ver qué módulo sigue el flujo
/// pantalla → cubit → caso de uso → interfaz → repositorio → datasource.
library;

/// Capas del flujo DDD y la carpeta donde vive cada una.
const Map<String, String> dddLayers = {
  'Entidad': 'lib/domain/entities/',
  'Interfaz': 'lib/domain/repositories/',
  'Caso de uso': 'lib/application/usecases/',
  'Repositorio': 'lib/infrastructure/repositories/',
  'Datasource': 'lib/infrastructure/datasources/',
  'Cubit': 'lib/presentation/cubits/',
  'Pantalla': 'lib/presentation/screens/',
};

/// Carpetas que son el mismo módulo con otro nombre en otra capa.
const Map<String, String> moduleAliases = {
  'modules_repository': 'modules',
  'products': 'product',
  'support_chat': 'support',
  'tech_support': 'support',
};

/// Reglas que cuentan como violación DDD en el reporte.
const Set<String> dddRules = {'ARC-022', 'ARC-023', 'ARC-024'};

/// Regla de la capa de diseño agnóstica (vistas y widgets de pantalla).
const String designRule = 'ARC-025';

/// Regla de accesibilidad (Semantics, tooltip y etiquetas de imágenes).
const String accessibilityRule = 'ARC-027';

/// Reglas de la auditoría: errores (ARC-028) y toques (ARC-029).
const Set<String> auditRules = {'ARC-028', 'ARC-029'};

/// Módulo y capa de [path], o `null` si no está en una carpeta de módulo.
({String module, String layer})? moduleOf(String path) {
  for (final entry in dddLayers.entries) {
    if (!path.startsWith(entry.value)) continue;
    final rest = path.substring(entry.value.length).split('/');
    if (rest.length < 2) return null; // archivo suelto en la raíz de la capa
    return (module: moduleAliases[rest.first] ?? rest.first, layer: entry.key);
  }
  return null;
}

/// Estado del módulo según sus capas: un módulo con datos (interfaz,
/// repositorio o datasource) necesita interfaz y repositorio, y además caso
/// de uso si tiene cubit o pantalla (si solo lo usa un servicio de
/// infraestructura, como `sync`, no lo necesita).
String moduleStatus(
  Map<String, int> layers,
  int violations, [
  int designViolations = 0,
  int accessibilityViolations = 0,
  int auditViolations = 0,
]) {
  final handlesData = _handlesData(layers);
  final missing = missingLayers(layers);
  final problems = [
    if (missing.isNotEmpty) 'falta ${missing.join(', ')}',
    if (violations == 1) '1 violación DDD',
    if (violations > 1) '$violations violaciones DDD',
    if (designViolations > 0) 'diseño con estado o lógica ($designViolations)',
    if (accessibilityViolations > 0)
      'accesibilidad pendiente ($accessibilityViolations)',
    if (auditViolations > 0) 'sin auditar ($auditViolations)',
  ];
  if (problems.isNotEmpty) {
    return '⚠️ ${[if (!handlesData) 'sin capa de datos', ...problems].join('; ')}';
  }
  return handlesData ? '✅ completo' : '· sin capa de datos';
}

bool _handlesData(Map<String, int> layers) =>
    ['Interfaz', 'Repositorio', 'Datasource'].any((l) => (layers[l] ?? 0) > 0);

/// Capas que le faltan a un módulo con datos: interfaz y repositorio
/// siempre, y caso de uso si tiene cubit o pantalla. Vacío si está completo
/// o si no tiene capa de datos.
List<String> missingLayers(Map<String, int> layers) {
  bool has(String layer) => (layers[layer] ?? 0) > 0;
  if (!_handlesData(layers)) return const [];
  final hasUi = has('Cubit') || has('Pantalla');
  return [
    if (!has('Interfaz')) 'Interfaz',
    if (hasUi && !has('Caso de uso')) 'Caso de uso',
    if (!has('Repositorio')) 'Repositorio',
  ];
}

/// Archivos por capa de cada módulo.
Map<String, Map<String, int>> moduleLayers(Iterable<String> paths) {
  final layers = <String, Map<String, int>>{};
  for (final path in paths) {
    final at = moduleOf(path);
    if (at == null) continue;
    final counts = layers.putIfAbsent(at.module, () => {});
    counts[at.layer] = (counts[at.layer] ?? 0) + 1;
  }
  return layers;
}

/// ARC-026: módulos a los que les falta una capa del flujo DDD, con el
/// primer archivo del módulo (para ubicar la violación).
List<({String module, List<String> missing, String file})> moduleGaps(
  Iterable<String> paths,
) {
  final sorted = paths.toList()..sort();
  final layers = moduleLayers(sorted);
  return [
    for (final entry
        in (layers.entries.toList()..sort((a, b) => a.key.compareTo(b.key))))
      if (missingLayers(entry.value) case final missing when missing.isNotEmpty)
        (
          module: entry.key,
          missing: missing,
          file: sorted.firstWhere((p) => moduleOf(p)?.module == entry.key),
        ),
  ];
}

/// Tabla Markdown con una fila por módulo (archivos por capa) y su estado.
String buildModulesReport(
  Iterable<String> paths,
  Iterable<({String file, String rule})> violations,
) {
  final layers = moduleLayers(paths);
  final dddCount = <String, int>{};
  final designCount = <String, int>{};
  final a11yCount = <String, int>{};
  final auditCount = <String, int>{};
  for (final v in violations) {
    final at = moduleOf(v.file);
    if (at == null) continue;
    if (dddRules.contains(v.rule)) {
      dddCount[at.module] = (dddCount[at.module] ?? 0) + 1;
    } else if (v.rule == designRule) {
      designCount[at.module] = (designCount[at.module] ?? 0) + 1;
    } else if (v.rule == accessibilityRule) {
      a11yCount[at.module] = (a11yCount[at.module] ?? 0) + 1;
    } else if (auditRules.contains(v.rule)) {
      auditCount[at.module] = (auditCount[at.module] ?? 0) + 1;
    }
  }

  final modules = layers.keys.toList()..sort();
  final buffer = StringBuffer()
    ..writeln(
      '| Módulo | ${dddLayers.keys.join(' | ')} | Diseño | Accesib. | '
      'Auditoría | Estado |',
    )
    ..writeln(
      '|---|${List.filled(dddLayers.length + 3, ':-:').join('|')}|---|',
    );
  for (final module in modules) {
    final counts = layers[module] ?? const {};
    final cells = dddLayers.keys.map((l) => '${counts[l] ?? '—'}');
    final design = designCount[module] ?? 0;
    final hasDesign = (counts['Pantalla'] ?? 0) > 0;
    String cell(bool applies, int n) =>
        !applies ? '—' : (n == 0 ? '✅' : '⚠️ $n');
    final a11y = a11yCount[module] ?? 0;
    final audit = auditCount[module] ?? 0;
    buffer.writeln(
      '| $module | ${cells.join(' | ')} | ${cell(hasDesign, design)} | '
      '${cell(hasDesign, a11y)} | ${cell(true, audit)} | '
      '${moduleStatus(counts, dddCount[module] ?? 0, design, a11y, audit)} |',
    );
  }
  return buffer.toString();
}
