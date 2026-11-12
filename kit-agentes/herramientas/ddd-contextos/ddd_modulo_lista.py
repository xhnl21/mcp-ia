#!/usr/bin/env python3
"""Etapa C para un módulo «lista + operaciones» (checklist_iso, audit_log, cuarentena, reporte_migracion…): repositorio
(domain + infrastructure), casos de uso con nombre (Observar, ObtenerResumen, Recargar y uno por operación), locator y
reescritura mecánica del cubit. Uso: python3 tool/ddd_modulo_lista.py tool/modulos/<modulo>.json
No pisa archivos que ya existen (salvo --forzar). Detalle de la spec: ver tool/modulos/*.json."""
import json, os, re, sys
c = json.load(open(sys.argv[1], encoding='utf-8')); forzar = '--forzar' in sys.argv
M, C, E = c['modulo'], c['Clase'], c['entidad']
EP = c['entidad_archivo']
def w(p, t):
    if os.path.exists(p) and not forzar: print('  existe, no piso', p); return
    os.makedirs(os.path.dirname(p), exist_ok=True); open(p, 'w', encoding='utf-8').write(t)
def rel(a, b): return os.path.relpath(b, os.path.dirname(a))
snake = lambda n: re.sub(r'(?<!^)(?=[A-Z])', '_', n).lower()
L = c['lista']; ops = c['ops']
# domain
repo_p = f'lib/domain/repositories/{M}/{M}_repository.dart'
miembros = [f"  {L['tipo']} get {L['nombre']};"]
for o in ops:
    miembros.append(f"  {o['ret']} get {o['metodo']};" if o.get('getter') else f"  {o['ret']} {o['metodo']}({o.get('params','')});")
w(repo_p, f"""import '{rel(repo_p, EP)}';

/// Contrato de {c['etiqueta']}: lo implementa la capa de infraestructura y lo usan los casos de uso.
abstract class {C}Repository {{
  /// Emite cada vez que cambian los datos.
  Stream<void> get cambios;

{chr(10).join(miembros)}
  bool get cargando;
  String? get mensajeError;

  Future<void> recargar();
}}
""")
res = c['resumen']
res_p = f'lib/domain/entities/{M}/resumen_{M}.dart'
campos = res['campos'] + [['bool', 'cargando'], ['String?', 'error']]
w(res_p, f"""import '{rel(res_p, EP)}';

/// Lo que muestra la pantalla de {c['etiqueta']}.
class Resumen{C} {{
{chr(10).join(f'  final {t} {n};' for t, n in campos)}

  const Resumen{C}({{{', '.join(f'required this.{n}' for _, n in campos)}}});
}}
""")
# infrastructure
impl_p = f'lib/infrastructure/repositories/{M}/{M}_repository_impl.dart'
def impl_member(o):
    if o.get('getter'): return f"  @override\n  {o['ret']} get {o['metodo']} => _d.{o['servicio']};\n"
    return f"  @override\n  {o['ret']} {o['metodo']}({o.get('params','')}) =>\n      _d.{o['servicio']}({o.get('args','')});\n"
w(impl_p, f"""import '{rel(impl_p, EP)}';
import '../../../domain/repositories/{M}/{M}_repository.dart';
import '../../datasources/google_sheets/sheets_data_service.dart';

/// [{C}Repository] sobre [SheetsDataService].
class {C}RepositoryImpl implements {C}Repository {{
  final SheetsDataService _d;

  const {C}RepositoryImpl(this._d);

  @override
  Stream<void> get cambios => Stream<void>.multi((c) {{
        void escuchar() => c.add(null);
        _d.addListener(escuchar);
        c.onCancel = () => _d.removeListener(escuchar);
      }}, isBroadcast: true);

  @override
  {L['tipo']} get {L['nombre']} => _d.{L['servicio']};

{chr(10).join(impl_member(o) for o in ops)}
  @override
  bool get cargando => _d.isLoading;

  @override
  String? get mensajeError => _d.errorMessage;

  @override
  Future<void> recargar() => _d.{c['recargar']}();
}}
""")
# casos
U = f'lib/application/usecases/{M}/'
RI = f"import '../../../domain/repositories/{M}/{M}_repository.dart';\n"
def uc(archivo, cls, doc, body, extra=''):
    w(U + archivo + '.dart', f"""{extra}{RI}
/// Caso de uso: {doc}
class {cls} {{
  final {C}Repository _repo;

  const {cls}(this._repo);

{body}
}}
""")
uc(f'observar_{M}', f'Observar{C}', f'avisa cada vez que cambian los datos de {c["etiqueta"]}.', '  Stream<void> call() => _repo.cambios;')
uc(f'recargar_{M}', f'Recargar{C}', f'relee {c["etiqueta"]}.', '  Future<void> call() => _repo.recargar();')
ctor = ',\n        '.join(f'{n}: {v}' for n, v in res['ctor'].items())
uc(f'obtener_resumen_{M}', f'ObtenerResumen{C}', f'arma lo que muestra la pantalla de {c["etiqueta"]}.',
   f"""  Resumen{C} call() {{
{res.get('pre','')}    return Resumen{C}(
        {ctor},
        cargando: _repo.cargando,
        error: _repo.mensajeError);
  }}""", f"import '../../../domain/entities/{M}/resumen_{M}.dart';\n" + (f"import '{rel(U + 'x.dart', EP)}';\n" if (res.get('pre') or E in ctor) else ''))
for o in ops:
    ea = f"import '{rel(U + 'x.dart', EP)}';\n" if E in o.get('params', '') else ''
    if o.get('getter'): body = f"  {o['ret']} call() => _repo.{o['metodo']};"
    else: body = f"  {o['ret']} call({o.get('params','')}) => _repo.{o['metodo']}({o.get('args','')});"
    uc(snake(o['caso']), o['caso'], o['doc'], body, ea)
campos_c = [('observar', f'Observar{C}'), ('obtenerResumen', f'ObtenerResumen{C}'), ('recargar', f'Recargar{C}')] + [(o['campo'], o['caso']) for o in ops]
archivos = [f'observar_{M}', f'recargar_{M}', f'obtener_resumen_{M}'] + [snake(o['caso']) for o in ops]
casos_p = U + f'{M}_casos.dart'
w(casos_p, ''.join(f"import '{a}.dart';\n" for a in sorted(archivos)) + f"""
/// Casos de uso de {c['etiqueta']}.
class {C}Casos {{
{chr(10).join(f'  final {t} {n};' for n, t in campos_c)}

  const {C}Casos({{
{chr(10).join(f'    required this.{n},' for n, _ in campos_c)}
  }});
}}
""")
loc_p = f'lib/config/locator/{M}_casos.dart'
w(loc_p, ''.join(f"import '../../application/usecases/{M}/{a}.dart';\n" for a in sorted(archivos + [f'{M}_casos'])) + f"""import '../../infrastructure/datasources/google_sheets/sheets_data_service.dart';
import '../../infrastructure/repositories/{M}/{M}_repository_impl.dart';

/// Casos de uso de {c['etiqueta']} armados sobre el servicio de datos.
{C}Casos {c['funcion']}(SheetsDataService datos) {{
  final repo = {C}RepositoryImpl(datos);
  return {C}Casos(
{chr(10).join(f'    {n}: {t}(repo),' for n, t in campos_c)}
  );
}}
""")
# barril
p = 'lib/config/locator/casos.dart'
s = open(p).read()
for l in (f"export '{M}_casos.dart';\n", f"export '../../application/usecases/{M}/{M}_casos.dart';\n"):
    if l not in s: s = s.rstrip('\n') + '\n' + l
open(p, 'w').write(s)
# cubit
cp = c['cubit']; s = open(cp).read()
s = s.replace("import 'package:flutter_bloc/flutter_bloc.dart';", "import 'dart:async';\n\nimport 'package:flutter_bloc/flutter_bloc.dart';", 1)
s = s.replace(c['casos_viejo_import'], f'{M}/{M}_casos.dart').replace(c['casos_viejo'], f'{C}Casos')
s = s.replace(f'  final {C}Casos casos;', f'  final {C}Casos casos;\n  StreamSubscription<void>? _suscripcion;', 1)
s = s.replace('casos.addListener(_onDataServiceChanged);', '_suscripcion = casos.observar().listen((_) => _onDataServiceChanged());')
s = s.replace('casos.removeListener(_onDataServiceChanged);', '_suscripcion?.cancel();')
s = s.replace(f"casos.{c['recargar']}()", 'casos.recargar()')
for o in ops:
    s = re.sub(rf"casos\.{o['servicio']}\b(\(?)", lambda m: f"casos.{o['campo']}()" if o.get('getter') else f"casos.{o['campo']}(", s)
a = s.index('  void _syncFromService() {'); b = s.index('\n  }\n', a) + 5
s = s[:a] + c['cubit_sync'] + s[b:]
for old, new in c.get('cubit_reemplazos', []): s = s.replace(old, new)
open(cp, 'w').write(s)
# pantallas y rutas: AuditoriaCasos(...) → locator nuevo
for p in c['usos']:
    s = open(p).read()
    s = re.sub(rf"{c['pagina']}\(casos: auditoriaCasos\(", f"{c['pagina']}(casos: {c['funcion']}(", s)
    open(p, 'w').write(s)
pg = c['pagina_archivo']; s = open(pg).read()
s = s.replace(c['casos_viejo_import'], f'{M}/{M}_casos.dart').replace(c['casos_viejo'], f'{C}Casos')
open(pg, 'w').write(s)
print('listo', M)
