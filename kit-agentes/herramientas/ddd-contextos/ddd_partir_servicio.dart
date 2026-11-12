// Parte una clase gigante en archivos `part` con extensiones, por las secciones `// ====` de su fuente.
// Uso: dart run tool/ddd_partir_servicio.dart <archivo.dart> <Clase> <carpeta_salida> [--aplicar] [--conservar=a,b,c]
//   Sin --aplicar solo imprime el plan. Se quedan en la clase: constructores, campos, miembros estáticos, los que
//   llevan @override y los de --conservar (los que sobrescriben los dobles de prueba, para que sigan siendo virtuales).
// Las extensiones ven los miembros privados (misma librería) y el `this` implícito; no pueden sobrescribirse.
import 'dart:io';

import 'package:analyzer/dart/analysis/utilities.dart';
import 'package:analyzer/dart/ast/ast.dart';

String slug(String s) {
  final t = s.toLowerCase().replaceAll(RegExp(r'[áàä]'), 'a').replaceAll(RegExp(r'[éèë]'), 'e').replaceAll(RegExp(r'[íìï]'), 'i')
      .replaceAll(RegExp(r'[óòö]'), 'o').replaceAll(RegExp(r'[úùü]'), 'u').replaceAll('ñ', 'n');
  var r = t.replaceAll(RegExp(r'\(.*'), '').replaceAll(RegExp(r'[^a-z0-9]+'), '_').replaceAll(RegExp(r'^_|_$'), '');
  r = r.replaceFirst(RegExp(r'^crud_(\d+_|de_)'), '').replaceFirst(RegExp(r'_helper$'), '');
  if (r == 'inicio') r = 'nucleo';
  final ps = r.split('_');
  var out = ps.first;
  for (final w in ps.skip(1)) { if ('${out}_$w'.length > 28) break; out = '${out}_$w'; }
  return out;
}

void main(List<String> args) {
  final archivo = args[0], clase = args[1], salida = args[2];
  final aplicar = args.contains('--aplicar');
  final conservar = args.where((a) => a.startsWith('--conservar=')).expand((a) => a.substring(12).split(',')).toSet();
  final src = File(archivo).readAsStringSync();
  final unit = parseString(content: src, throwIfDiagnostics: false).unit;
  final lineas = src.split('\n');
  final inicioLinea = <int>[0];
  for (var i = 0; i < src.length; i++) {
    if (src[i] == '\n') inicioLinea.add(i + 1);
  }
  int lineaDe(int offset) {
    var lo = 0, hi = inicioLinea.length - 1;
    while (lo < hi) {
      final mid = (lo + hi + 1) >> 1;
      if (inicioLinea[mid] <= offset) { lo = mid; } else { hi = mid - 1; }
    }
    return lo; // base 0
  }

  // Secciones: bloque `  // ====` + títulos + `  // ====`.
  final secciones = <({int linea, String titulo})>[];
  for (var i = 0; i < lineas.length; i++) {
    if (RegExp(r'^  // ={20,}').hasMatch(lineas[i])) {
      var j = i + 1; final tit = <String>[];
      while (j < lineas.length && !RegExp(r'^  // ={20,}').hasMatch(lineas[j]) && lineas[j].startsWith('  //')) {
        tit.add(lineas[j].substring(4).trim()); j++;
      }
      if (tit.isNotEmpty) { secciones.add((linea: i, titulo: tit.first)); i = j; }
    }
  }

  final cls = unit.declarations.whereType<ClassDeclaration>().firstWhere((c) => c.namePart.typeName.lexeme == clase);
  final miembros = cls.body.childEntities.whereType<ClassMember>().toList();
  bool mover(ClassMember m) {
    if (m is! MethodDeclaration) return false;
    if (m.isStatic || m.metadata.any((a) => a.name.name == 'override')) return false;
    if (conservar.contains(m.name.lexeme)) return false;
    return true;
  }

  String tituloDe(int linea) {
    var t = 'inicio';
    for (final s in secciones) { if (s.linea <= linea) t = s.titulo; }
    return t;
  }

  // Inicio real de un miembro: sube sobre comentarios `//` o `///` contiguos.
  int inicioConComentarios(ClassMember m) {
    var l = lineaDe(m.offset);
    while (l > 0 && lineas[l - 1].trimLeft().startsWith('//') && !RegExp(r'^  // ={20,}').hasMatch(lineas[l - 1])) { l--; }
    return l;
  }

  final porSeccion = <String, List<ClassMember>>{};
  for (final m in miembros.where(mover)) {
    porSeccion.putIfAbsent(tituloDe(lineaDe(m.offset)), () => []).add(m);
  }
  stdout.writeln('${miembros.length} miembros, ${miembros.where(mover).length} a mover');
  for (final e in porSeccion.entries) {
    final l = e.value.fold<int>(0, (s, m) => s + lineaDe(m.end) - inicioConComentarios(m) + 1);
    stdout.writeln('${slug(e.key).padRight(40)} ${e.value.length.toString().padLeft(4)} miembros ~$l líneas  («${e.key}»)');
  }
  if (!aplicar) return;

  // Aplicar: archivos part + recorte del original (de atrás hacia adelante).
  Directory(salida).createSync(recursive: true);
  final nombres = <String>[];
  final usados = <String, int>{};
  final recortes = <({int a, int b})>[];
  for (final e in porSeccion.entries) {
    var base = slug(e.key); if (base.isEmpty) base = 'general';
    usados[base] = (usados[base] ?? 0) + 1;
    final nombre = usados[base]! > 1 ? '${base}_${usados[base]}' : base;
    final ext = nombre.split('_').map((w) => w.isEmpty ? '' : w[0].toUpperCase() + w.substring(1)).join();
    final cuerpo = StringBuffer()
      ..writeln("part of '../${File(archivo).uri.pathSegments.last}';")
      ..writeln()
      ..writeln('/// ${e.key}. Parte de [$clase] (extensión: ve los miembros privados; no se puede sobrescribir en pruebas).')
      ..writeln('extension ${ext}Datos on $clase {');
    for (final m in e.value) {
      final a = inicioConComentarios(m), b = lineaDe(m.end);
      cuerpo.writeln(lineas.sublist(a, b + 1).join('\n'));
      cuerpo.writeln();
      recortes.add((a: a, b: b));
    }
    cuerpo.writeln('}');
    File('$salida/$nombre.dart').writeAsStringSync(cuerpo.toString());
    nombres.add(nombre);
  }
  recortes.sort((x, y) => y.a.compareTo(x.a));
  final nuevas = List<String>.of(lineas);
  for (final r in recortes) { nuevas.removeRange(r.a, r.b + 1); }
  var texto = nuevas.join('\n');
  final rel = Directory(salida).path.split('/').last;
  final partes = nombres.map((n) => "part '$rel/$n.dart';").join('\n');
  texto = texto.replaceFirst(RegExp(r"part '[^']+';\n"), '${RegExp(r"part '[^']+';\n").firstMatch(texto)?.group(0) ?? ''}$partes\n');
  File(archivo).writeAsStringSync(texto);
  stdout.writeln('aplicado: ${nombres.length} archivos en $salida');
}
