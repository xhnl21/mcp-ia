// Extrae los miembros públicos de una clase (con sus mixins y extensiones) a JSON, con sus firmas reales.
// Uso (desde la raíz del proyecto Flutter, que tiene `analyzer` entre sus dependencias):
//   dart run tool/ddd_extraer.dart <Clase> <salida.json> <archivo.dart> [<otro.dart> ...]
// Lo copia `generar_contextos.py` a `tool/ddd_extraer.dart` del proyecto.
import 'dart:convert';
import 'dart:io';

import 'package:analyzer/dart/analysis/utilities.dart';
import 'package:analyzer/dart/ast/ast.dart';

void main(List<String> args) {
  if (args.length < 3) {
    stderr.writeln('Uso: dart run tool/ddd_extraer.dart <Clase> <salida.json> <archivo.dart>...');
    exit(2);
  }
  final clase = args[0];
  final salida = args[1];
  final out = <Map<String, dynamic>>[];

  void miembro(ClassMember m) {
    final esStatic = (m is MethodDeclaration && m.isStatic) || (m is FieldDeclaration && m.isStatic);
    if (m is MethodDeclaration) {
      final nombre = m.name.lexeme;
      if (nombre.startsWith('_') || m.isOperator) return;
      final ps = m.parameters?.parameters ?? <FormalParameter>[];
      out.add({
        'name': nombre,
        'kind': m.isGetter ? 'getter' : m.isSetter ? 'setter' : 'method',
        'static': esStatic,
        'ret': m.returnType?.toSource() ?? 'dynamic',
        'meta': m.metadata.map((a) => a.toSource()).toList(),
        'params': m.parameters?.toSource(),
        'plist': [
          for (final p in ps) {'name': p.name?.lexeme, 'named': p.isNamed, 'required': p.isRequired}
        ],
        'generics': m.typeParameters?.toSource(),
      });
    } else if (m is FieldDeclaration) {
      for (final v in m.fields.variables) {
        if (v.name.lexeme.startsWith('_')) continue;
        out.add({
          'name': v.name.lexeme,
          'kind': 'field',
          'static': esStatic,
          'ret': m.fields.type?.toSource() ?? 'dynamic',
          'final': m.fields.isFinal || m.fields.isConst,
          'meta': m.metadata.map((a) => a.toSource()).toList(),
        });
      }
    }
  }

  for (final archivo in args.skip(2)) {
    final unidad = parseString(content: File(archivo).readAsStringSync(), throwIfDiagnostics: false).unit;
    for (final d in unidad.declarations) {
      if (d is ClassDeclaration && d.namePart.typeName.lexeme == clase) {
        d.body.childEntities.whereType<ClassMember>().forEach(miembro);
      } else if (d is MixinDeclaration) {
        d.body.childEntities.whereType<ClassMember>().forEach(miembro);
      } else if (d is ExtensionDeclaration) {
        d.body.childEntities.whereType<ClassMember>().forEach(miembro);
      }
    }
  }
  File(salida).writeAsStringSync(jsonEncode(out));
  stdout.writeln('${out.length} miembros de $clase -> $salida');
}
