"""
fm.py — CLI principal de flutter-memory.

Uso:
    py scripts/fm.py             → muestra ayuda
    py scripts/fm.py busca "error x"          (alias: search, b, find)
    py scripts/fm.py agregar 'Título' 'Problema' 'Solución' [--tag x] [--cat y]
    py scripts/fm.py usar <id> [--no-resuelta]
    py scripts/fm.py patrones 'texto del error'
    py scripts/fm.py reporte
    py scripts/fm.py exportar [ruta.json]
    py scripts/fm.py importar ruta.json
    py scripts/fm.py importar-so "query"
    py scripts/fm.py importar-github [repo]
    py scripts/fm.py importar-awesome
    py scripts/fm.py importar-docs
    py scripts/fm.py semilla          → carga soluciones de ejemplo
"""
from __future__ import annotations

import argparse
import os
import sys

if hasattr(sys.stdout, "reconfigure"):
    sys.stdout.reconfigure(encoding="utf-8")
    sys.stderr.reconfigure(encoding="utf-8")

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

import search          # noqa: E402
import manager         # noqa: E402


def build_parser() -> argparse.ArgumentParser:
    p = argparse.ArgumentParser(prog="fm", description="Memoria local Flutter/Dart")
    sub = p.add_subparsers(dest="cmd")

    b = sub.add_parser("busca", aliases=["search", "b", "find"],
                       help="Buscar soluciones locales")
    b.add_argument("query", help="texto del error a buscar")
    b.add_argument("--n", type=int, default=8, help="número de resultados")
    b.add_argument("--cat", help="filtrar por categoría")
    b.add_argument("--tag", help="filtrar por tag")

    a = sub.add_parser("agregar", help="Agregar una solución")
    a.add_argument("titulo")
    a.add_argument("problema")
    a.add_argument("solucion")
    a.add_argument("--tag", action="append")
    a.add_argument("--cat")
    a.add_argument("--url")

    u = sub.add_parser("usar", help="Marcar una solución como usada")
    u.add_argument("id", type=int)
    u.add_argument("--no-resuelta", action="store_true")

    pa = sub.add_parser("patrones", help="Detectar patrones en un texto")
    pa.add_argument("texto")

    re_ = sub.add_parser("reporte", help="Generar reporte de frecuencia")
    re_.add_argument("--n", type=int, default=15)

    ex = sub.add_parser("exportar", help="Exportar a JSON")
    ex.add_argument("ruta", nargs="?", default=None)

    im = sub.add_parser("importar", help="Importar desde JSON")
    im.add_argument("ruta")

    io = sub.add_parser("importar-so", help="Importar de Stack Overflow")
    io.add_argument("query", nargs="?", default="flutter error")
    io.add_argument("--n", type=int, default=8)

    ig = sub.add_parser("importar-github", help="Importar de GitHub issues")
    ig.add_argument("repo", nargs="?", default="flutter/flutter")
    ig.add_argument("--n", type=int, default=8)

    iw = sub.add_parser("importar-awesome", help="Importar Awesome Flutter")
    ia = sub.add_parser("importar-docs", help="Importar Flutter docs")

    sd = sub.add_parser("semilla", help="Cargar datos de ejemplo")

    su = sub.add_parser("subir", help="Subir conocimiento al cofre compartido")
    bj = sub.add_parser("bajar", help="Bajar conocimiento del cofre compartido")
    bj.add_argument("source", nargs="?", help="ruta o URL (opcional)")

    return p


def cmd_busca(args) -> int:
    results = search.search(args.query, limit=args.n, category=args.cat, tag=args.tag)
    if not results:
        print("No se encontraron soluciones locales.")
        print("Consejo: usa `fm importar-so \"tu error\"` o `fm agregar ...` para crearla.")
        return 1
    print(f"Encontradas {len(results)} soluciones para: \"{args.query}\"\n")
    for r in results:
        print(f"=== [{r['score']:.2f}] #{r['id']} — {r['titulo']}")
        print(f"    Problema: {r['problema'][:120]}")
        print(f"    Solución: {r['solucion'][:180]}")
        if r["url"]:
            print(f"    Url: {r['url']}")
        print(f"    (úsala con: fm usar {r['id']})")
        print()
    return 0


def cmd_agregar(args) -> int:
    sid = manager.add_solution(
        titulo=args.titulo, problema=args.problema, solucion=args.solucion,
        categoria=args.cat, tags=args.tag or [], url=args.url,
    )
    print(f"Solución añadida con id {sid}.")
    return 0


def cmd_usar(args) -> int:
    search.record_use(args.id, resolved=not args.no_resuelta)
    print(f"Solución {args.id} marcada como usada.")
    return 0


def cmd_patrones(args) -> int:
    hits = manager.detect_patterns(args.texto)
    if not hits:
        print("Sin patrones conocidos para este texto.")
        return 1
    for h in hits:
        print(f"Patrón: {h['etiqueta']} (conteo {h['conteo']})  "
              f"solución_id: {h['solucion_id']}")
    return 0


def cmd_reporte(args) -> int:
    print(manager.report(top=args.n))
    return 0


def cmd_exportar(args) -> int:
    path = manager.export_json(args.ruta)
    print(f"Exportado a {path}")
    return 0


def cmd_importar(args) -> int:
    n = manager.import_json(args.ruta)
    print(f"Importadas {n} soluciones.")
    return 0


def cmd_importar_so(args) -> int:
    try:
        from importers import import_stackoverflow
    except ImportError as e:
        print(f"Falta dependencia: {e}. Ejecuta: py -m pip install requests")
        return 1
    n = import_stackoverflow(args.query, max_results=args.n)
    print(f"Importadas {n} soluciones de Stack Overflow.")
    return 0


def cmd_importar_github(args) -> int:
    try:
        from importers import import_github_issues
    except ImportError as e:
        print(f"Falta dependencia: {e}. Ejecuta: py -m pip install requests")
        return 1
    n = import_github_issues(args.repo, max_results=args.n)
    print(f"Importadas {n} soluciones de GitHub.")
    return 0


def cmd_importar_awesome(args) -> int:
    try:
        from importers import import_awesome_flutter
    except ImportError as e:
        print(f"Falta dependencia: {e}. Ejecuta: py -m pip install requests")
        return 1
    n = import_awesome_flutter()
    print(f"Importadas {n} soluciones de Awesome Flutter.")
    return 0


def cmd_importar_docs(args) -> int:
    try:
        from importers import import_flutter_docs
    except ImportError as e:
        print(f"Falta dependencia: {e}. Ejecuta: py -m pip install requests")
        return 1
    n = import_flutter_docs()
    print(f"Importadas {n} referencias de Flutter docs.")
    return 0


def cmd_semilla(args) -> int:
    manager.seed_sample()
    print("Datos de ejemplo cargados.")
    return 0


def cmd_subir(args) -> int:
    try:
        from sync import subir
        print(f"Subido a: {subir()}")
        return 0
    except ImportError as e:
        print(f"Falta dependencia: {e}")
        return 1


def cmd_bajar(args) -> int:
    try:
        from sync import bajar
        n = bajar(args.source)
        print(f"Importadas {n} soluciones nuevas desde el cofre compartido.")
        return 0
    except ImportError as e:
        print(f"Falta dependencia: {e}")
        return 1


def main(argv=None) -> int:
    parser = build_parser()
    args = parser.parse_args(argv)
    if not args.cmd:
        parser.print_help()
        return 0

    dispatch = {
        "busca": cmd_busca,
        "search": cmd_busca,
        "b": cmd_busca,
        "find": cmd_busca,
        "agregar": cmd_agregar,
        "usar": cmd_usar,
        "patrones": cmd_patrones,
        "reporte": cmd_reporte,
        "exportar": cmd_exportar,
        "importar": cmd_importar,
        "importar-so": cmd_importar_so,
        "importar-github": cmd_importar_github,
        "importar-awesome": cmd_importar_awesome,
        "importar-docs": cmd_importar_docs,
        "semilla": cmd_semilla,
        "subir": cmd_subir,
        "bajar": cmd_bajar,
    }
    return dispatch[args.cmd](args)


if __name__ == "__main__":
    raise SystemExit(main())
