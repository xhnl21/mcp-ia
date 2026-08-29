"""
sync.py — Compartir el cofre de conocimiento entre compañeros.

Permite "subir" (exportar) el conocimiento local a un punto de encuentro
y "bajar" (importar) el de los demás, mezclándolo sin duplicados.

El "punto de encuentro" puede ser:
  - un directorio compartido (carpeta de Dropbox/Google Drive/Red local),
  - o una URL pública con el archivo export.json (p.ej. un Gist de GitHub).

Variable de entorno (opcional): FM_SYNC_URL  → URL del export compartido.
Por defecto usa: data/sync/compartido.json  (carpeta compartida local).
"""
from __future__ import annotations

import os
import sys
from pathlib import Path
from urllib.request import urlretrieve

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

import manager  # noqa: E402

BASE = Path(__file__).resolve().parent.parent
DEFAULT_SYNC_FILE = BASE / "data" / "sync" / "compartido.json"


def _sync_file() -> Path:
    p = os.environ.get("FM_SYNC_FILE")
    return Path(p) if p else DEFAULT_SYNC_FILE


def subir() -> str:
    """Exporta el conocimiento local al punto de encuentro."""
    dest = _sync_file()
    dest.parent.mkdir(parents=True, exist_ok=True)
    manager.export_json(str(dest))
    return str(dest)


def bajar(source: str | None = None) -> int:
    """
    Importa el conocimiento compartido a la BD local.
    - source puede ser una ruta de archivo o una URL.
    - Si es None, usa el archivo configurado (FM_SYNC_FILE o el path por defecto)
      o FM_SYNC_URL si está definida.
    Devuelve el número de soluciones NUEVAS añadidas.
    """
    src = source
    if not src:
        url = os.environ.get("FM_SYNC_URL")
        src = url if url else str(_sync_file())

    local_path: Path
    if src.startswith("http://") or src.startswith("https://"):
        tmp = BASE / "data" / "sync" / "_descargado.json"
        tmp.parent.mkdir(parents=True, exist_ok=True)
        try:
            urlretrieve(src, str(tmp))
        except Exception as e:
            print(f"No se pudo descargar {src}: {e}")
            return 0
        local_path = tmp
    else:
        local_path = Path(src)

    if not local_path.exists():
        print(f"Origen no encontrado: {local_path}")
        return 0

    n = manager.import_json(str(local_path))
    return n


if __name__ == "__main__":
    import argparse
    p = argparse.ArgumentParser(prog="fm-sync")
    sub = p.add_subparsers(dest="cmd", required=True)
    sub.add_parser("subir", help="exportar el conocimiento local")
    b = sub.add_parser("bajar", help="importar el conocimiento compartido")
    b.add_argument("source", nargs="?", help="ruta o URL (opcional)")
    a = p.parse_args()

    if a.cmd == "subir":
        print(f"Subido a: {subir()}")
    elif a.cmd == "bajar":
        n = bajar(a.source)
        print(f"Importadas {n} soluciones nuevas desde el cofre compartido.")
