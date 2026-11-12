#!/usr/bin/env python3
"""Etapa C para un «catálogo simple» (lista + activos + en uso + agregar/editar/estado/borrar), con el patrón de
metodos_pago: repositorio (domain+infrastructure), casos de uso con nombre, locator, cubit y pantalla.
Uso: python3 tool/ddd_catalogo_simple.py <config.json>   (ver tool/catalogos/*.json)"""
import json, os, re, sys
c = json.load(open(sys.argv[1], encoding='utf-8'))
M = c['modulo']; P = c['paquete']; C = ''.join(w.capitalize() for w in M.split('_'))   # TiposDocumento
E = c['entidad']; EP = c['entidad_archivo']; S = c['singular']                           # TipoDocumento / TipoDocumento
def w(p, t): os.makedirs(os.path.dirname(p), exist_ok=True); open(p, 'w', encoding='utf-8').write(t)
def rel(a, b): return os.path.relpath(b, os.path.dirname(a))
snake = lambda n: re.sub(r'(?<!^)(?=[A-Z])', '_', n).lower()
add_p, upd_p = c['agregar_params'], c['actualizar_params']      # [(nombre, tipo)]
sig = lambda ps: '{' + ', '.join(f'required {t} {n}' for n, t in ps) + '}'
args = lambda ps: ', '.join(f'{n}: {n}' for n, _ in ps)
# domain
repo_p = f'lib/domain/repositories/{M}/{M}_repository.dart'
w(repo_p, f"""import '{rel(repo_p, EP)}';

/// Contrato de {c['etiqueta']}: lo implementa la capa de infraestructura y lo usan los casos de uso.
abstract class {C}Repository {{
  Stream<void> get cambios;
  List<{E}> get items;
  int get totalActivos;
  Set<String> get idsEnUso;
  bool get cargando;
  String? get mensajeError;

  Future<void> recargar();
  Future<void> agregar({sig(add_p)});

  /// `false` si no se pudo.
  Future<bool> actualizar({sig(upd_p)});
  Future<bool> cambiarEstado(String id);
  Future<bool> eliminar(String id);
  bool estaEnUso(String {c['en_uso_param']});
}}
""")
res_p = f'lib/domain/entities/{M}/resumen_{M}.dart'
w(res_p, f"""import '{rel(res_p, EP)}';

/// Lo que muestra la pantalla de {c['etiqueta']}.
class Resumen{C} {{
  final List<{E}> items;
  final int totalActivos;
  final Set<String> enUso;
  final bool cargando;
  final String? error;

  const Resumen{C}({{
    required this.items,
    required this.totalActivos,
    required this.enUso,
    required this.cargando,
    required this.error,
  }});
}}
""")
S_ = c['servicio']
impl_p = f'lib/infrastructure/repositories/{M}/{M}_repository_impl.dart'
w(impl_p, f"""import '{rel(impl_p, EP)}';
import '{rel(impl_p, repo_p)}';
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
  List<{E}> get items => _d.{S_['lista']};

  @override
  int get totalActivos => _d.{S_['activos']}.length;

  @override
  Set<String> get idsEnUso => _d.{S_['en_uso']};

  @override
  bool get cargando => _d.isLoading;

  @override
  String? get mensajeError => _d.errorMessage;

  @override
  Future<void> recargar() => _d.fetchAllSheets();

  @override
  Future<void> agregar({sig(add_p)}) => _d.{S_['agregar']}({args(add_p)});

  @override
  Future<bool> actualizar({sig(upd_p)}) => _d.{S_['actualizar']}({args(upd_p)});

  @override
  Future<bool> cambiarEstado(String id) => _d.{S_['estado']}(id);

  @override
  Future<bool> eliminar(String id) => _d.{S_['eliminar']}(id);

  @override
  bool estaEnUso(String {c['en_uso_param']}) => _d.{S_['es_en_uso']}({c['en_uso_param']});
}}
""")
U = f'lib/application/usecases/{M}/'
ucs = []
def uc(nombre, doc, cuerpo, extra_imp=''):
    p = U + snake(nombre) + '.dart'
    w(p, f"{extra_imp}import '{rel(p, repo_p)}';\n\n/// Caso de uso: {doc}\nclass {nombre} {{\n  final {C}Repository _repo;\n\n  const {nombre}(this._repo);\n\n{cuerpo}\n}}\n")
    ucs.append((nombre, snake(nombre)))
uc(f'Observar{C}', 'avisa cada vez que cambian los datos.', "  Stream<void> call() => _repo.cambios;")
uc(f'ObtenerResumen{C}', f"arma lo que muestra la pantalla de {c['etiqueta']}.", f"""  Resumen{C} call() => Resumen{C}(
    items: List.of(_repo.items),
    totalActivos: _repo.totalActivos,
    enUso: _repo.idsEnUso,
    cargando: _repo.cargando,
    error: _repo.mensajeError,
  );""", f"import '{rel(U+'x.dart', res_p)}';\n")
uc(f'Recargar{C}', 'vuelve a leer las hojas desde el servidor.', "  Future<void> call() => _repo.recargar();")
uc(f'Agregar{S}', f"registra {c['articulo_nuevo']}.", f"  Future<void> call({sig(add_p)}) => _repo.agregar({args(add_p)});")
uc(f'Actualizar{S}', 'guarda los cambios. `false` si no se pudo.', f"  Future<bool> call({sig(upd_p)}) => _repo.actualizar({args(upd_p)});")
uc(f'CambiarEstado{S}', 'activa o desactiva. `false` si no se pudo (está en uso).', "  Future<bool> call(String id) => _repo.cambiarEstado(id);")
uc(f'Eliminar{S}', 'borra uno que no esté en uso. `false` si no se pudo.', "  Future<bool> call(String id) => _repo.eliminar(id);")
uc(f'{S}EnUso', '¿lo usa algún cliente, venta o abono?', f"  bool call(String {c['en_uso_param']}) => _repo.estaEnUso({c['en_uso_param']});")
uc(f'Existe{S}', 'comprueba si ya hay uno igual (para no duplicar). `excluirId` es el que se está editando.',
   f"  bool call(String valor, {{String? excluirId}}) => _repo.items.any((x) => ({c['clave']}) == valor && x.id != excluirId);")
loc = f'lib/config/locator/{M}_casos.dart'
campos = [(n, re.sub(r'^(Observar|ObtenerResumen|Recargar|Agregar|Actualizar|CambiarEstado|Eliminar|Existe)', '', n) if False else n) for n, _ in ucs]
cam = {f'Observar{C}': 'observar', f'ObtenerResumen{C}': 'obtenerResumen', f'Recargar{C}': 'recargar', f'Agregar{S}': 'agregar',
       f'Actualizar{S}': 'actualizar', f'CambiarEstado{S}': 'cambiarEstado', f'Eliminar{S}': 'eliminar', f'{S}EnUso': 'enUso', f'Existe{S}': 'existe'}
imports = ''.join(f"import '{rel(loc, U + f + '.dart')}';\n" for _, f in ucs)
w(loc, imports + f"""import '{rel(loc, 'lib/infrastructure/datasources/google_sheets/sheets_data_service.dart')}';
import '{rel(loc, impl_p)}';

/// Casos de uso de {c['etiqueta']}, armados sobre su repositorio.
class {C}Casos {{
""" + ''.join(f"  final {n} {cam[n]};\n" for n, _ in ucs) + f"""
  const {C}Casos({{
""" + ''.join(f"    required this.{cam[n]},\n" for n, _ in ucs) + f"""  }});

  factory {C}Casos.desdeServicio(SheetsDataService datos) {{
    final repo = {C}RepositoryImpl(datos);
    return {C}Casos(
""" + ''.join(f"      {cam[n]}: {n}(repo),\n" for n, _ in ucs) + """    );
  }
}
""")
# cubit
cp = c['cubit']; t = open(cp, encoding='utf-8').read()
t = t.replace("import '../../../application/usecases/catalogos/catalogos_casos.dart';", f"import '{rel(cp, loc)}';")
t = t.replace('final CatalogosCasos casos;', f'final {C}Casos casos;\n  StreamSubscription<void>? _suscripcion;')
t = t.replace("import 'package:flutter_bloc/flutter_bloc.dart';", "import 'dart:async';\n\nimport 'package:flutter_bloc/flutter_bloc.dart';", 1)
t = re.sub(r"  void _init\(\) \{.*?\n  \}\n\n  void _onDataServiceChanged\(\) \{.*?\n  \}\n", "  void _init() {\n    _suscripcion = casos.observar().listen((_) => _syncFromService());\n    _syncFromService();\n  }\n", t, flags=re.S)
t = t.replace(f"    final currentList = List<{E}>.from(casos.{S_['lista']});\n", "    final r = casos.obtenerResumen();\n    final currentList = r.items;\n")
t = t.replace(f"casos.isLoading", "r.cargando").replace(f"casos.{S_['activos']}.length", "r.totalActivos").replace("casos.errorMessage", "r.error").replace(f"casos.{S_['en_uso']}", "r.enUso")
for a, b in ((S_['agregar'], 'agregar'), (S_['actualizar'], 'actualizar'), (S_['estado'], 'cambiarEstado'), (S_['eliminar'], 'eliminar'), (S_['es_en_uso'], 'enUso'), ('fetchAllSheets', 'recargar')):
    t = t.replace(f'casos.{a}(', f'casos.{b}(')
t = t.replace("    casos.removeListener(_onDataServiceChanged);", "    _suscripcion?.cancel();")
open(cp, 'w', encoding='utf-8').write(t)
# pantalla
pg = c['pagina']; t = open(pg, encoding='utf-8').read()
t = t.replace("import '../../../application/usecases/catalogos/catalogos_casos.dart';", f"import '{rel(pg, loc)}';\n\n// El shell y las rutas arman la pantalla con `{C}Casos.desdeServicio(...)`.\nexport '{rel(pg, loc)}';")
t = t.replace('CatalogosCasos casos', f'{C}Casos casos')
t = re.sub(c['duplicado_regex'], c['duplicado_reemplazo'], t, flags=re.S)
open(pg, 'w', encoding='utf-8').write(t)
for f in c['armado']:
    t = open(f, encoding='utf-8').read()
    t = t.replace(f"{c['pagina_clase']}(casos: catalogosCasos(widget.dataService))", f"{c['pagina_clase']}(casos: {C}Casos.desdeServicio(widget.dataService))").replace(f"{c['pagina_clase']}(casos: catalogosCasos(dataService))", f"{c['pagina_clase']}(casos: {C}Casos.desdeServicio(dataService))")
    open(f, 'w', encoding='utf-8').write(t)
print('listo', M)
