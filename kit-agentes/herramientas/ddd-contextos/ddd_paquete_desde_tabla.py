#!/usr/bin/env python3
"""Genera un paquete de casos de uso con nombre desde una tabla de reenvíos al repositorio.
Cada fila: (campo, Clase, doc, tipo_de_retorno, 'parámetros', 'llamada al repositorio', [imports de entidades]).
Uso como módulo (ver la migración de notificaciones). Escribe un archivo por caso y el paquete (XCasos) con su fábrica."""
import os, re
def snake(n): return re.sub(r'(?<!^)(?=[A-Z])', '_', n).lower()
def generar(carpeta, paquete_clase, paquete_archivo, repo_clase, repo_import, filas, extension_sobre=None, extension_import=None, extension_nombre=None, doc_paquete=''):
    os.makedirs(carpeta, exist_ok=True)
    for campo, clase, doc, ret, params, llamada, imports in filas:
        imps = ''.join(f"import '../../../domain/entities/{i}.dart';\n" for i in imports)
        extra = "import '../comun/observar_cambios.dart';\n" if 'observarCambios' in llamada else ''
        cuerpo = f"  {ret} call({params}) => {llamada};"
        open(os.path.join(carpeta, snake(clase) + '.dart'), 'w', encoding='utf-8').write(
            imps + extra + f"import '../../../domain/repositories/{repo_import}';\n\n/// Caso de uso: {doc}\nclass {clase} {{\n  final {repo_clase} _repo;\n\n  const {clase}(this._repo);\n\n{cuerpo}\n}}\n")
    imports = ''.join(f"import '{snake(c)}.dart';\n" for _, c, *_ in sorted(filas, key=lambda f: snake(f[1])))
    campos = ''.join(f"  final {c} {n};\n" for n, c, *_ in filas)
    req = ''.join(f"    required this.{n},\n" for n, *_ in filas)
    fab = ''.join(f"        {n}: {c}(repo),\n" for n, c, *_ in filas)
    ext = ''
    imp_ext = ''
    if extension_sobre:
        imp_ext = f"import '{extension_import}';\n"
        ext = f"\nextension {extension_nombre}De{extension_sobre} on {extension_sobre} {{\n  /// Casos de uso de {doc_paquete}.\n  {paquete_clase} get {extension_nombre[0].lower()+extension_nombre[1:]} => {paquete_clase}.desdeRepositorio(repositorio);\n}}\n"
    open(os.path.join(carpeta, paquete_archivo + '.dart'), 'w', encoding='utf-8').write(
        f"import '../../../domain/repositories/{repo_import}';\n{imp_ext}{imports}\n" + (f"export '{extension_import}';\n" if extension_sobre else '') +
        f"\n/// Casos de uso de {doc_paquete}, sobre el repositorio de su contexto.\nclass {paquete_clase} {{\n{campos}\n  const {paquete_clase}({{\n{req}  }});\n\n  factory {paquete_clase}.desdeRepositorio({repo_clase} repo) =>\n      {paquete_clase}(\n{fab}      );\n}}\n" + ext)
