"""
importers.py — Importadores automáticos desde fuentes en línea.

Estos scripts usan APIs públicas. SOLO funcionan con conexión a internet;
el resto del sistema es 100% offline. Cada función devuelve el nº de
soluciones nuevas añadidas a la BD local.
"""
from __future__ import annotations

import json
import time
from urllib.parse import quote_plus

import requests

from manager import add_solution

HEADERS = {"User-Agent": "flutter-memory/1.0 (local knowledge base)"}
TIMEOUT = 15


def import_stackoverflow(query: str = "flutter error", max_results: int = 10,
                         tags: str = "flutter") -> int:
    """
    Busca preguntas de Stack Overflow en inglés relacionadas con Flutter.
    Usa la API pública (sin key para uso moderado).
    """
    url = "https://api.stackexchange.com/2.3/search/advanced"
    params = {
        "order": "desc", "sort": "relevance", "q": query,
        "tagged": tags, "site": "stackoverflow", "pagesize": max_results,
    }
    try:
        r = requests.get(url, params=params, headers=HEADERS, timeout=TIMEOUT)
        if r.status_code != 200:
            return 0
        data = r.json()
    except Exception:
        return 0

    count = 0
    for item in data.get("items", []):
        title = item.get("title", "")
        if not title:
            continue
        link = item.get("link", "")
        # 'answer_count' alto => más probabilidad de solución aceptada.
        sid = add_solution(
            titulo=title,
            problema=title,
            solucion=f"Ver discusión completa: {link}\nVotos: {item.get('score', 0)}, "
                     f"respuestas: {item.get('answer_count', 0)}",
            tags=["stackoverflow"] + [t for t in item.get("tags", []) if t.lower() in
                                      ("flutter", "dart")],
            url=link,
            fuente="stackoverflow",
        )
        if sid:
            count += 1
        time.sleep(0.3)  # ser amables con la API
    return count


def import_github_issues(repo: str = "flutter/flutter", state: str = "closed",
                         query: str = "exception", max_results: int = 10) -> int:
    """
    Importa issues cerrados de GitHub (por defecto flutter/flutter) con su
    'body' como problema y los primeros comentarios como solución.
    """
    url = f"https://api.github.com/search/issues"
    q = f"repo:{repo} state:{state} {query}"
    params = {"q": q, "per_page": max_results}
    try:
        r = requests.get(url, params=params, headers=HEADERS, timeout=TIMEOUT)
        if r.status_code != 200:
            return 0
        data = r.json()
    except Exception:
        return 0

    count = 0
    for item in data.get("items", []):
        title = item.get("title", "")
        body = (item.get("body") or "")[:800]
        html_url = item.get("html_url", "")
        # Obtener un comentario como solución sugerida.
        solution_url = f"https://api.github.com/repos/{repo}/issues/{item.get('number')}/comments"
        solution_text = "Resuelto en el issue (cerrado). Revisa el hilo para la solución."
        try:
            cr = requests.get(solution_url, headers=HEADERS, timeout=TIMEOUT)
            if cr.status_code == 200:
                comments = cr.json()
                if comments:
                    solution_text = (comments[0].get("body") or "")[:800]
        except Exception:
            pass

        sid = add_solution(
            titulo=f"{title} [{item.get('number')}]",
            problema=body,
            solucion=solution_text,
            tags=["github", repo.split("/")[-1]],
            url=html_url,
            fuente="github",
        )
        if sid:
            count += 1
        time.sleep(0.3)
    return count


def import_awesome_flutter() -> int:
    """
    Lee el índice catálogo de Awesome Flutter (raw de GitHub) y guarda
    entradas como soluciones de tipo 'recurso/referencia'.
    """
    url = ("https://raw.githubusercontent.com/Solido/awesome-flutter/"
           "master/README.md")
    try:
        r = requests.get(url, headers=HEADERS, timeout=TIMEOUT)
        if r.status_code != 200:
            return 0
        text = r.text
    except Exception:
        return 0

    # Extraer entradas tipo "- [Nombre](url) - descripción"
    import re
    entries = re.findall(r"-\s*\[([^\]]+)\]\(([^)]+)\)(?:\s*[-–—]\s*(.*))?", text)

    count = 0
    for nombre, url, desc in entries[:80]:
        if not (url.startswith("http")):
            continue
        sid = add_solution(
            titulo=f"[Awesome] {nombre}",
            problema=f"Recurso/paquete curado de Awesome Flutter.",
            solucion=f"{desc or 'Paquete/herramienta curada de Flutter.'}\nURL: {url}",
            tags=["awesome", "recurso"],
            url=url,
            fuente="awesome",
        )
        if sid:
            count += 1
    return count


def import_flutter_docs(topics: list[str] | None = None) -> int:
    """
    Referencia a la documentación oficial de Flutter. Importa páginas
    de 'docs.flutter.dev' como entradas de referencia rápida.
    """
    base = {
        "navigation": "https://docs.flutter.dev/ui/navigation",
        "state": "https://docs.flutter.dev/data-and-backend/state-mgmt/intro",
        "testing": "https://docs.flutter.dev/testing/overview",
        "deployment": "https://docs.flutter.dev/deployment",
        "platform": "https://docs.flutter.dev/platform-integration",
    }
    topics = topics or list(base.keys())
    count = 0
    for t in topics:
        if t not in base:
            continue
        sid = add_solution(
            titulo=f"[Docs] Flutter guide: {t}",
            problema=f"Referencia oficial sobre {t} en Flutter.",
            solucion=f"Ver documentación oficial: {base[t]}",
            tags=["docs", t],
            url=base[t],
            fuente="flutterdocs",
        )
        if sid:
            count += 1
    return count


def run_all() -> dict:
    """Ejecuta todos los importadores y devuelve resumen."""
    results = {}
    results["stackoverflow"] = import_stackoverflow()
    results["github"] = import_github_issues()
    results["awesome"] = import_awesome_flutter()
    results["flutterdocs"] = import_flutter_docs()
    return results


if __name__ == "__main__":
    import sys
    which = sys.argv[1] if len(sys.argv) > 1 else "all"
    if which == "stackoverflow":
        q = sys.argv[2] if len(sys.argv) > 2 else "flutter error"
        print(f"Importando SO: {import_stackoverflow(q)}")
    elif which == "github":
        repo = sys.argv[2] if len(sys.argv) > 2 else "flutter/flutter"
        print(f"Importando GitHub: {import_github_issues(repo)}")
    elif which == "awesome":
        print(f"Importando Awesome: {import_awesome_flutter()}")
    elif which == "docs":
        print(f"Importando Flutter docs: {import_flutter_docs()}")
    else:
        for k, v in run_all().items():
            print(f"{k}: {v}")
