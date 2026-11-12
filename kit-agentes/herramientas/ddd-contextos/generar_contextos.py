#!/usr/bin/env python3
"""Genera, por contexto, la interfaz de repositorio (domain), su implementación (infrastructure) y la clase de
casos de uso (application) con las firmas reales de un servicio gigante, y reescribe las pantallas y cubits para
que usen `XCasos` en vez del servicio. Ver README.md.

Uso, desde la raíz del proyecto:  python3 <mcp-ia>/kit-agentes/herramientas/ddd-contextos/generar_contextos.py config.json [--solo-generar] [--forzar]
"""
import collections, glob, json, os, re, shutil, subprocess, sys

AQUI = os.path.dirname(os.path.abspath(__file__))
cfg = json.load(open(sys.argv[1], encoding='utf-8'))
SOLO_GENERAR = '--solo-generar' in sys.argv
FORZAR = '--forzar' in sys.argv  # sin esto no pisa archivos que ya existen (pueden tener retoques a mano)
PAQ = cfg['paquete']; SERV = cfg['servicio']; SERV_ARCH = cfg['servicio_archivos']
SERV_IMP = cfg['servicio_import']; BARRIL = cfg.get('barril_servicio')
CTX = cfg['contextos']
DOM = cfg.get('simbolos_de_dominio', {})          # símbolo -> archivo que lo define (ya movido a domain)
M2C = {m: c for c, ms in CTX.items() for m in ms}
PK = f'package:{PAQ}/'
camel = lambda c: ''.join(w.capitalize() for w in c.split('_'))

def leer(p): return open(p, encoding='utf-8').read()
def escribir(p, t):
    os.makedirs(os.path.dirname(p), exist_ok=True); open(p, 'w', encoding='utf-8').write(t)

# 1) firmas del servicio (se deja la herramienta en tool/, no se borra)
os.makedirs('tool', exist_ok=True)
shutil.copy(os.path.join(AQUI, 'extraer_miembros.dart'), 'tool/ddd_extraer.dart')
firmas_json = cfg.get('firmas_json', 'tool/ddd_firmas.json')
subprocess.check_call(['dart', 'run', 'tool/ddd_extraer.dart', SERV, firmas_json, *SERV_ARCH])
miembros = [x for x in json.load(open(firmas_json)) if not x['static']]
por_nombre = collections.defaultdict(list)
for x in miembros: por_nombre[x['name']].append(x)

# 2) símbolos de dominio para los imports de las firmas
sym = {}
for p in glob.glob('lib/domain/**/*.dart', recursive=True) + glob.glob('lib/core/**/*.dart', recursive=True):
    if p.startswith('lib/domain/repositories'): continue
    for m in re.finditer(r'^(?:abstract |sealed |final |base )?(?:class|enum|typedef|mixin) (\w+)', leer(p), re.M):
        sym.setdefault(m.group(1), p)

def ctx_de(path):
    m = re.match(r'lib/presentation/(?:cubits|screens|routes)/([^/]+)/', path)
    return M2C.get(m.group(1)) if m else None

archivos = [os.path.join(d, f) for d, _, fs in os.walk('lib/presentation') for f in fs if f.endswith('.dart')]
ctx_archivos = collections.defaultdict(list)
for f in archivos:
    c = ctx_de(f)
    if c: ctx_archivos[c].append(f)

def miembros_usados(t):
    ids = set(re.findall(rf'{SERV}\??\s+(\w+)', t)) | {'dataService', 'casos'}
    mem = set()
    for i in ids:
        for m in re.finditer(r'\b' + i + r'\s*\??\.\s*(\w+)', t): mem.add(m.group(1))
    return mem

def imports(path, texto, extra=()):
    need = set(extra)
    for t, p in sym.items():
        if re.search(r'\b' + t + r'\b', texto) and p != path: need.add(p)
    pre = "import 'dart:typed_data';\n" if 'Uint8List' in texto else ''
    return pre + ''.join(f"import '{os.path.relpath(p, os.path.dirname(path))}';\n" for p in sorted(need))

def w(path, cuerpo, extra=()):
    if os.path.exists(path) and not FORZAR:
        print(f'  ya existe, no se pisa: {path}'); return
    escribir(path, imports(path, cuerpo, extra) + '\n' + cuerpo + '\n')

clasectx = {}
for c, fs in ctx_archivos.items():
    C = camel(c); mem = set()
    for f in fs:
        t = leer(f)
        if re.search(rf'\b{SERV}\b|\bdataService\b|\bcasos\b', t): mem |= miembros_usados(t)
        for m in re.finditer(r'^(?:abstract )?class (\w+)', t, re.M): clasectx[m.group(1)] = c
    mem -= {'addListener', 'removeListener'}
    firmas = [x for n in sorted(mem) if n in por_nombre for x in por_nombre[n]]
    faltan = sorted(n for n in mem if n not in por_nombre)
    li, lm, lc = [], [], []
    pars = lambda x: x['params'] if x['params'] is not None else '()'
    args = lambda x: ', '.join(f"{p['name']}: {p['name']}" if p['named'] else p['name'] for p in x['plist'])
    for x in firmas:
        k, n, r, gen = x['kind'], x['name'], x['ret'], x.get('generics') or ''
        if k in ('getter', 'field'):
            li.append(f"  {r} get {n};"); lm.append(f"  @override\n  {r} get {n} => _d.{n};"); lc.append(f"  {r} get {n} => _r.{n};")
            if k == 'field' and not x.get('final'):
                li.append(f"  set {n}({r} valor);"); lm.append(f"  @override\n  set {n}({r} valor) => _d.{n} = valor;"); lc.append(f"  set {n}({r} valor) => _r.{n} = valor;")
        elif k == 'method':
            sig = f"{r} {n}{gen}{pars(x)}"
            li.append(f"  {sig};"); lm.append(f"  @override\n  {sig} => _d.{n}({args(x)});"); lc.append(f"  {sig} => _r.{n}({args(x)});")
    esc = "\n\n  /// Avisa cuando cambian los datos.\n  void addListener(void Function() listener);\n  void removeListener(void Function() listener);"
    pi = f'lib/domain/repositories/{c}/{c}_repository.dart'
    w(pi, f"/// Contrato de datos del contexto {c}: lo implementa la capa de infraestructura y lo usan los casos de uso.\nabstract class {C}Repository {{\n" + '\n'.join(li) + esc + "\n}\n")
    pm = f'lib/infrastructure/repositories/{c}/{c}_repository_impl.dart'
    w(pm, f"/// [{C}Repository] sobre [{SERV}] (por ahora la fuente de todos los datos).\nclass {C}RepositoryImpl implements {C}Repository {{\n  final {SERV} _d;\n\n  const {C}RepositoryImpl(this._d);\n\n" + '\n\n'.join(lm) +
      "\n\n  @override\n  void addListener(void Function() listener) => _d.addListener(listener);\n\n  @override\n  void removeListener(void Function() listener) => _d.removeListener(listener);\n}\n", extra=[pi, SERV_IMP])
    pc = f'lib/application/usecases/{c}/{c}_casos.dart'
    w(pc, f"/// Casos de uso del contexto {c}: lo que las pantallas y cubits piden, sin ver el repositorio ni la fuente.\nclass {C}Casos {{\n  final {C}Repository _r;\n\n  const {C}Casos(this._r);\n\n" + '\n'.join(lc) +
      "\n\n  void addListener(void Function() listener) => _r.addListener(listener);\n  void removeListener(void Function() listener) => _r.removeListener(listener);\n}\n", extra=[pi])
    if not os.path.exists(f'lib/config/locator/{c}_casos.dart') or FORZAR: escribir(f'lib/config/locator/{c}_casos.dart',
      f"import '../../application/usecases/{c}/{c}_casos.dart';\nimport '../../{SERV_IMP[4:]}';\nimport '../../infrastructure/repositories/{c}/{c}_repository_impl.dart';\n\n/// Casos de uso del contexto {c} armados sobre la fuente de datos.\n{C}Casos {c}Casos({SERV} datos) => {C}Casos({C}RepositoryImpl(datos));\n")
    print(f'{c}: {len(fs)} archivos, {len(firmas)} miembros', f'FALTAN {faltan}' if faltan else '')

json.dump({'clasectx': clasectx, 'ctx_archivos': ctx_archivos}, open('tool/ddd_clases.json', 'w'))
if SOLO_GENERAR: sys.exit(0)

# 3) reescribir presentación y pruebas
def tg(path, uri):
    if uri.startswith(PK): return 'lib/' + uri[len(PK):]
    if uri.startswith(('dart:', 'package:')): return None
    return os.path.normpath(os.path.join(os.path.dirname(path), uri))
def uri_a(path, t): return PK + t[4:] if path.startswith('test/') else os.path.relpath(t, os.path.dirname(path))
imp = re.compile(r"^[ \t]*import\s+(['\"])([^'\"]+)\1[^;]*;[ \t]*\n", re.M)
def add_import(t, path, destino):
    linea = f"import '{uri_a(path, destino)}';\n"
    if linea in t: return t
    ms = list(imp.finditer(t)); pos = ms[-1].end() if ms else 0
    return t[:pos] + linea + t[pos:]
def llamadas_a_otros(t, path, propio=None):
    """`Clase(... dataService|casos: X ...)` de otro contexto -> `casos: <ctx>Casos(X)`."""
    usados = set(); res = ''; pos = 0
    for m in re.finditer(r'\b([A-Z]\w*)\(', t):
        if m.start() < pos: continue
        c = clasectx.get(m.group(1))
        if not c or c == propio: continue
        prof = 0; j = m.end() - 1
        while j < len(t):
            prof += (t[j] == '(') - (t[j] == ')')
            if prof == 0: break
            j += 1
        a = t[m.end():j]
        n = re.sub(r'\b(?:dataService|casos):\s*([\w.?!]+(?:\(\))?)', lambda x: f"casos: {c}Casos({x.group(1)})", a)
        if n != a: usados.add(c); res += t[pos:m.end()] + n; pos = j
    return res + t[pos:], usados
propios = {f for fs in ctx_archivos.values() for f in fs}
for c, fs in ctx_archivos.items():
    C = camel(c)
    for f in fs:
        t = leer(f); o = t
        if not re.search(rf'\b{SERV}\b|\bdataService\b', t): continue
        t = re.sub(rf'\b{SERV}\b(?!\.)', f'{C}Casos', t)
        t = re.sub(r'\bdataService\b', 'casos', t)
        t = imp.sub(lambda m: '' if tg(f, m.group(2)) in (SERV_IMP, BARRIL) else m.group(0), t)
        if re.search(rf'{SERV}\.', t): t = add_import(t, f, SERV_IMP)
        if re.search(rf'\b{C}Casos\b', t): t = add_import(t, f, f'lib/application/usecases/{c}/{c}_casos.dart')
        t, usados = llamadas_a_otros(t, f, propio=c)
        for u in usados: t = add_import(t, f, f'lib/config/locator/{u}_casos.dart')
        for s, p in DOM.items():
            if re.search(rf'\b{s}\b', t): t = add_import(t, f, p)
        if t != o: escribir(f, t)
otros = [os.path.join(d, f) for b in ('lib', 'test') for d, _, fs in os.walk(b) for f in fs if f.endswith('.dart')]
for f in otros:
    if f in propios or f.startswith(('lib/infrastructure', 'lib/application', 'lib/domain')): continue
    t = leer(f); o = t
    t, usados = llamadas_a_otros(t, f)
    for u in usados: t = add_import(t, f, f'lib/config/locator/{u}_casos.dart')
    for s, p in DOM.items():
        if re.search(rf'\b{s}\b', t): t = add_import(t, f, p)
    if t != o: escribir(f, t)
print('reescritura lista: corre `dart fix --apply --code=unused_import` y `flutter analyze`')
