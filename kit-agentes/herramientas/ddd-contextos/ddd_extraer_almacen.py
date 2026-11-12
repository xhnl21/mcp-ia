#!/usr/bin/env python3
"""Etapa B: mueve las colecciones en memoria (`List<T> _x = ...;`) de una clase a una clase almacén y deja en la clase
accesores privados con el MISMO nombre (`List<T> get _x => _almacen.x; set _x(...)`), así los métodos no cambian.
Uso: python3 tool/ddd_extraer_almacen.py <archivo_clase.dart> <Almacen> <archivo_almacen.dart> [--aplicar]"""
import re, sys
src, nombre, dest = sys.argv[1:4]
aplicar = '--aplicar' in sys.argv
t = open(src, encoding='utf-8').read()
# `  [/// doc\n]  List<T> _nombre = <inicializador>;` (el inicializador puede ocupar varias líneas)
pat = re.compile(r'((?:^  ///[^\n]*\n)*)^  (List<[\w<>?, ]+>|MisPermisos\?) (_\w+)( = (?:\[[^;]*?\]|[^;\n]*))?;\n', re.M | re.S)
campos = []
def sub(m):
    doc, tipo, priv, init = m.group(1), m.group(2), m.group(3), m.group(4) or ''
    if tipo.startswith('List<') and not init: return m.group(0)
    pub = priv[1:]
    campos.append((doc, tipo, pub, init))
    return (f"{doc}  {tipo} get {priv} => _almacen.{pub};\n  set {priv}({tipo} valor) => _almacen.{pub} = valor;\n")
nuevo = pat.sub(sub, t)
print(len(campos), 'colecciones')
if not aplicar: sys.exit(0)
nuevo = nuevo.replace("  /// Las extensiones de `datos/` no pueden", f"  /// Estado en memoria de las hojas (las colecciones). Los accesores `_x` de abajo lo exponen con los nombres de siempre.\n  final {nombre} _almacen = {nombre}();\n\n  /// Las extensiones de `datos/` no pueden", 1)
open(src, 'w', encoding='utf-8').write(nuevo)
imports = ''.join(l for l in t.split('\n') if False)
imps = [l for l in t.split('\n') if l.startswith('import ')]
cuerpo = f"/// Las colecciones en memoria de las hojas de Google Sheets, sin lógica ni red: quien lee y escribe las hojas\n/// las llena y las consulta. Existe aparte para poder probar y migrar el estado sin el servicio de datos.\nclass {nombre} {{\n"
for doc, tipo, pub, init in campos:
    cuerpo += (doc.replace('  ///', '  ///') if doc else '') + f"  {tipo} {pub}{init};\n"
cuerpo += "}\n"
open(dest, 'w', encoding='utf-8').write('\n'.join(imps) + '\n\n' + cuerpo)
