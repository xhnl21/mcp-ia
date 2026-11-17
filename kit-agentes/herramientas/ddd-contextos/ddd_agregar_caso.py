#!/usr/bin/env python3
"""Agrega un caso de uso con nombre a un «paquete» (XCasos) ya generado: crea su archivo y lo registra en el
constructor y en la fábrica del paquete. Se usa como módulo desde otros scripts de migración.
    from ddd_agregar_caso import agregar
    agregar(paquete='lib/application/usecases/usuarios/usuarios_casos.dart', repo_tipo='OrganizacionesRepository',
            repo_import="import '../../../domain/repositories/organizaciones/organizaciones_repository.dart';\\n",
            campo='organizaciones', clase='ListarOrganizaciones', doc='…', cuerpo='  List<Organizacion> call() => _repo.organizaciones;',
            extra_import="import '../../../domain/entities/organizaciones/organizacion.dart';\\n")
Sin estado: si el campo ya existe en el paquete, no hace nada."""
import os, re

def snake(n): return re.sub(r'(?<!^)(?=[A-Z])', '_', n).lower()

def agregar(paquete, repo_tipo, repo_import, campo, clase, doc, cuerpo, extra_import='', sin_repo=False):
    s = open(paquete, encoding='utf-8').read()
    if re.search(rf"^\s+final {clase} {campo};", s, re.M):
        return False
    carpeta = os.path.dirname(paquete)
    archivo = snake(clase)
    ctor = f"  const {clase}();\n\n" if sin_repo else f"  final {repo_tipo} _repo;\n\n  const {clase}(this._repo);\n\n"
    # los imports de otro directorio se ajustan: el caso vive junto al paquete
    open(os.path.join(carpeta, archivo + '.dart'), 'w', encoding='utf-8').write(
        extra_import + ('' if sin_repo else repo_import) + f"\n/// Caso de uso: {doc}\nclass {clase} {{\n{ctor}{cuerpo}\n}}\n")
    # imports del paquete
    s = re.sub(r"^(import '[^']+';\n)(?!import)", lambda m: m.group(1), s, count=0, flags=re.M)
    primer = re.search(r"^import '", s, re.M)
    s = s[:primer.start()] + f"import '{archivo}.dart';\n" + s[primer.start():]
    # campo y constructor
    s = re.sub(r"(\n  const \w+\(\{)", lambda m: f"\n  final {clase} {campo};\n" + m.group(1), s, count=1)
    s = re.sub(r"(const \w+\(\{\n)", lambda m: m.group(1) + f"    required this.{campo},\n", s, count=1)
    # fábrica: «    XCasos(\n        a: A(repo),» o «      XCasos(\n …»
    fab = re.search(r"factory \w+\.\w+\([^)]*\) =>\s*\w+\(\n", s) or re.search(r"return \w+\(\n", s)
    if fab:
        nuevo = f"        {campo}: {'const ' + clase + '()' if sin_repo else clase + '(repo)'},\n"
        s = s[:fab.end()] + nuevo + s[fab.end():]
    open(paquete, 'w', encoding='utf-8').write(s)
    return True
