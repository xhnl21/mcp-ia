#!/usr/bin/env python3
"""Califica con `Clase.` las referencias a miembros estáticos que el analizador marca en las extensiones
(`unqualified_reference_to_static_member_of_extended_type`). Uso: python3 tool/ddd_calificar_estaticos.py Clase"""
import re, subprocess, sys, collections
clase = sys.argv[1]
out = subprocess.run(['flutter', 'analyze'], capture_output=True, text=True).stdout
por = collections.defaultdict(list)
for l in out.splitlines():
    if 'unqualified_reference_to_static_member_of_extended_type' not in l: continue
    m = re.search(r'• (\S+?):(\d+):(\d+) •', l)
    if m: por[m.group(1)].append((int(m.group(2)), int(m.group(3))))
for f, pos in por.items():
    L = open(f, encoding='utf-8').read().split('\n')
    for ln, col in sorted(set(pos), reverse=True):
        s = L[ln - 1]; L[ln - 1] = s[:col - 1] + clase + '.' + s[col - 1:]
    open(f, 'w', encoding='utf-8').write('\n'.join(L))
    print(f, len(set(pos)))
