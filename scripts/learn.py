"""
learn.py — Aprendizaje continuo.

Cuando un usuario (o un agente de IA) se encuentra con un error NUEVO no
resuelto localmente, este script:
  1. Detecta patrones de error conocidos.
  2. Si no hay solución, sugiere buscar en Stack Overflow y guarda la
     discusión como solución candidata.
  3. Registra el patrón de error y su frecuencia.
  4. Mantiene el índice de frecuencia.

Es el "modo auto-captura" para integrar en el flujo de trabajo.
"""
from __future__ import annotations

import argparse
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

import search    # noqa: E402
import manager   # noqa: E402
import cleaning  # noqa: E402


def learn(error_text: str, auto_import: bool = False) -> None:
    """Procesa un texto de error (nuevo, sin resolver)."""
    # 0. Limpiar el error (quitar stack trace, números, rutas) para
    #    que la búsqueda sea mucho más exacta.
    original = error_text
    error_text = cleaning.clean_error(error_text)
    if error_text and error_text != original:
        print(f"Error limpiado: {error_text}")

    # 1. Buscar localmente primero.
    results = search.search(error_text, limit=3)
    if results:
        top = results[0]
        print("Se encontró una solución LOCAL (sin tokens):")
        print(f"  #{top['id']} — {top['titulo']}")
        print(f"  Uso: fm usar {top['id']}")
        print(f"  {top['solucion'][:200]}")
        return

    print("No hay solución local suficiente. Detectando patrones...")
    pats = manager.detect_patterns(error_text)
    if pats:
        for p in pats:
            print(f"  Patrón recurrente: {p['etiqueta']} (x{p['conteo']})")

    # 2. Registrar el patrón del error nuevo.
    etiqueta = _guess_label(error_text)
    manager.register_pattern(error_text[:60], etiqueta)
    print(f"Patrón registrado: {etiqueta}")

    # 3. Auto-importar solución desde Stack Overflow si se pidió.
    if auto_import:
        try:
            from importers import import_stackoverflow
            n = import_stackoverflow(error_text, max_results=3)
            if n:
                print(f"Importadas {n} soluciones candidatas desde Stack Overflow.")
                search.search(error_text, limit=3)
            else:
                print("No se pudo importar desde Stack Overflow.")
        except Exception as e:
            print(f"No se pudo importar: {e}")


def _guess_label(error_text: str) -> str:
    """Intenta extraer el nombre de la excepción como etiqueta."""
    exc = cleaning.extract_exception_name(error_text)
    if exc:
        return exc
    return (error_text.strip()[:20] or "error_generico")


def main(argv=None) -> int:
    p = argparse.ArgumentParser(prog="fm-learn")
    p.add_argument("texto", help="texto del error (nuevo o sin resolver)")
    p.add_argument("--auto-import", action="store_true",
                   help="buscar e importar de Stack Overflow si no hay solución")
    args = p.parse_args(argv)
    learn(args.texto, args.auto_import)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
