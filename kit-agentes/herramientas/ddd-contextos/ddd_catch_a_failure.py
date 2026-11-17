#!/usr/bin/env python3
"""ARC-028: en cada `catch` genérico que arma un mensaje para el usuario, pasa por Failure.desde (punto central).
Transforma dentro del bloque catch: (A) `switch (e) {StateError… _ => X}` → `Failure.desde(e, defecto: X).message`;
(B) `mensajeDeError(e, prefijo: P)` → `Failure.desde(e, prefijo: P).message`; (E) `'texto: $e'` → `Failure.desde(e, prefijo: 'texto').message`.
Uso: python3 tool/ddd_catch_a_failure.py <violaciones.json> (lista [regla, archivo, línea] del auditor)."""
import json, re, sys, collections
def limites(src, linea):
    L = src.split('\n'); i = int(linea) - 1
    desde = sum(len(l) + 1 for l in L[:i])
    txt = src[desde:]
    k = txt.index('catch')
    prof = 0; fin = None
    for idx in range(k, len(txt)):
        ch = txt[idx]
        if ch == '{': prof += 1
        elif ch == '}':
            prof -= 1
            if prof == 0: fin = idx + 1; break
    return desde + k, desde + fin
def balanceado(txt, ini):
    """texto desde ini (justo después de '(') hasta el paréntesis que cierra"""
    prof = 1; i = ini
    while prof:
        c = txt[i]
        if c == '(': prof += 1
        elif c == ')': prof -= 1
        i += 1
    return txt[ini:i - 1], i
def transformar(b):
    o = b
    var = re.search(r'catch \((\w+)', b).group(1)
    # A
    b = re.sub(r"switch \(" + var + r"\) \{\s*StateError\(:final message\) => message,\s*ArgumentError\(:final message\) =>\s*(?:message\.toString\(\)|'\$message'),\s*_ =>\s*(.+?),?\s*\}",
               lambda m: f"Failure.desde({var}, defecto: {m.group(1).strip()}).message", b, flags=re.S)
    # B
    while True:
        m = re.search(r"mensajeDeError\(" + var, b)
        if not m: break
        interior, fin = balanceado(b, m.end() - len(var) - 0 + 0 - 0 + len(var))
        resto = interior[len(var):]
        pm = re.search(r"prefijo:\s*(.+)$", resto, re.S)
        pref = pm.group(1).strip().rstrip(',') if pm else "'No se pudo completar'"
        b = b[:m.start()] + f"Failure.desde({var}, prefijo: {pref}).message" + b[fin:]
    # E: 'texto: $e'
    b = re.sub(r"'([^'\n]*?):\s*\$(?:\{" + var + r"\}|" + var + r")'", lambda m: f"Failure.desde({var}, prefijo: '{m.group(1)}').message", b)
    b = re.sub(r"\b" + var + r"\.toString\(\)", f"Failure.desde({var}).message", b) if 'Logger' not in b else b
    return b if b != o else None
def main():
    viol = [v for v in json.load(open(sys.argv[1])) if v[0] == 'ARC-028']
    porArchivo = collections.defaultdict(list)
    for r, f, n in viol: porArchivo[f].append(int(n))
    tocados = 0
    for f, lineas in porArchivo.items():
        src = open(f).read(); cambios = 0
        for n in sorted(lineas, reverse=True):
            try: a, z = limites(src, n)
            except Exception: continue
            nuevo = transformar(src[a:z])
            if nuevo: src = src[:a] + nuevo + src[z:]; cambios += 1
        if cambios:
            if "failures.dart" not in src:
                from os.path import relpath, dirname
                rel = relpath('lib/core/error/failures.dart', dirname(f))
                k = src.index("import ") if "import " in src else 0
                src = src[:k] + f"import '{rel}';\n" + src[k:]
            open(f, 'w').write(src); tocados += cambios
    print('catch transformados:', tocados)
main()
