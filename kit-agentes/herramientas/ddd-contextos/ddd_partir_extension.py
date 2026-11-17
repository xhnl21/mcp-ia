#!/usr/bin/env python3
"""Parte un archivo `datos/<x>.dart` (extensión de SheetsDataService, parte del servicio) en varios archivos, repartiendo
sus miembros por nombre. Uso: python3 tool/ddd_partir_extension.py <archivo.dart> <spec.json>
spec: {"extension": "NucleoDatos", "archivos": {"acceso": ["setCurrentOrganizacion", ...], ...}, "resto": "lecturas"}
Los miembros que no aparecen en la spec van al archivo «resto». El archivo original queda con el archivo de nombre base."""
import json, os, re, sys
src, spec = sys.argv[1], json.load(open(sys.argv[2], encoding='utf-8'))
lines = open(src, encoding='utf-8').read().split('\n')
ext = spec['extension']
base = os.path.splitext(os.path.basename(src))[0]
d = os.path.dirname(src)
# cabecera: hasta la línea de «extension … {»
i0 = next(i for i, l in enumerate(lines) if l.startswith('extension '))
cierre = max(i for i, l in enumerate(lines) if l == '}')
cuerpo = lines[i0 + 1:cierre]
# límites de cada miembro: líneas con 2 espacios que no son comentario/anotación/cierre
inicio = [i for i, l in enumerate(cuerpo) if re.match(r'^  [A-Za-z_(]', l) and not l.startswith('  //')]
arranques = []
for i in inicio:
    a = i
    while a > 0 and re.match(r'^  (///|//|@)', cuerpo[a - 1]): a -= 1
    arranques.append(a)
bloques = []
for k, i in enumerate(inicio):
    fin = arranques[k + 1] if k + 1 < len(arranques) else len(cuerpo)
    bloques.append([arranques[k], fin, i])
def nombre(l):
    m = re.search(r'\b(?:get|set)\s+(\w+)', l) or re.search(r'(\w+)\s*(?:\(|<\w[^(]*>\s*\()', l) or re.search(r'(\w+)\s*\(', l)
    return m.group(1) if m else '?'
destino = {}
for arch, nombres in spec['archivos'].items():
    for n in nombres: destino[n] = arch
salida = {}
for a, b, i in bloques:
    n = nombre(cuerpo[i])
    arch = destino.get(n, spec.get('resto', base))
    salida.setdefault(arch, []).append('\n'.join(cuerpo[a:b]).rstrip('\n'))
titulo = {a: spec.get('titulos', {}).get(a, a.replace('_', ' ')) for a in salida}
for arch, trozos in salida.items():
    nombre_ext = ext if arch == base else ''.join(p.capitalize() for p in arch.split('_')) + 'Datos'
    ruta = os.path.join(d, arch + '.dart')
    cab = "part of '../sheets_data_service.dart';\n\n" + f"/// {titulo[arch].upper()}. Parte de [SheetsDataService] (extensión: ve los miembros privados; no se puede sobrescribir en pruebas).\n" + f"extension {nombre_ext} on SheetsDataService {{\n"
    open(ruta, 'w', encoding='utf-8').write(cab + '\n\n'.join(trozos) + '\n}\n')
    print(arch, len(trozos), 'miembros')
