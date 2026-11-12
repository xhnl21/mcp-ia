#!/usr/bin/env python3
"""Agrega el import de la librería de la clase partida a los archivos donde el analizador no encuentra miembros que
ahora son extensiones (`undefined_method|getter|setter` para el tipo Clase). Uso: python3 tool/ddd_importar_extensiones.py Clase lib/ruta/clase.dart paquete"""
import os, re, subprocess, sys, collections
clase, destino, paquete = sys.argv[1:4]
out = subprocess.run(['flutter', 'analyze'], capture_output=True, text=True).stdout
archivos = set()
for l in out.splitlines():
    if f"for the type '{clase}'" in l and re.search(r'undefined_(method|getter|setter|operator)', l):
        m = re.search(r'• ((?:lib|test)/[^:]+):\d+:\d+ •', l)
        if m: archivos.add(m.group(1))
imp = re.compile(r"^[ \t]*import\s+['\"][^'\"]+['\"][^;]*;[ \t]*\n", re.M)
for f in sorted(archivos):
    t = open(f, encoding='utf-8').read()
    uri = f"package:{paquete}/{destino[4:]}" if f.startswith('test/') else os.path.relpath(destino, os.path.dirname(f))
    linea = f"import '{uri}';\n"
    if linea in t: continue
    ms = list(imp.finditer(t)); pos = ms[-1].end() if ms else 0
    open(f, 'w', encoding='utf-8').write(t[:pos] + linea + t[pos:])
print(len(archivos), 'archivos')
