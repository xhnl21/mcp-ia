"""
setup.py — Instalación y configuración de flutter-memory.
1. Crea la BD + schema + categorías + datos de ejemplo.
2. Verifica dependencias (rapidfuzz, requests).
3. (Opcional) integra bin/ al PATH del usuario.
"""
from __future__ import annotations

import os
import subprocess
import sys
from pathlib import Path

BASE = Path(__file__).resolve().parent.parent
BIN = BASE / "bin"

DEPS = ["rapidfuzz", "requests"]


def check_python() -> None:
    print(f"Python: {sys.version.split()[0]}")


def ensure_deps() -> None:
    missing = []
    for d in DEPS:
        try:
            __import__(d)
        except ImportError:
            missing.append(d)
    if missing:
        print(f"Instalando dependencias faltantes: {', '.join(missing)}")
        subprocess.run([sys.executable, "-m", "pip", "install", *missing],
                       check=True)
    else:
        print("Dependencias OK.")


def init_db() -> None:
    sys.path.insert(0, str(Path(__file__).parent))
    import db
    import manager
    conn = db.init_if_needed()
    db.add_default_categories(conn)
    conn.close()
    manager.seed_sample()
    n = len(db.get_conn().execute("SELECT * FROM soluciones").fetchall())
    print(f"Base de datos inicializada. Soluciones de ejemplo: {n}")


def setup_path(do_it: bool) -> None:
    """Agrega bin/ al PATH de usuario (persistente) si se solicita."""
    if not do_it:
        print("PATH no modificado (usa: --path para integrar bin/ al PATH).")
        return
    bin_str = str(BIN)
    user_path = os.environ.get("PATH", "")
    if bin_str.lower() in user_path.lower():
        print("bin/ ya está en el PATH.")
        return
    try:
        import winreg
        with winreg.OpenKey(winreg.HKEY_CURRENT_USER,
                            r"Environment", 0, winreg.KEY_SET_VALUE) as k:
            cur, _ = winreg.QueryValueEx(k, "Path")
            new = cur + ";" + bin_str
            winreg.SetValueEx(k, "Path", 0, winreg.REG_EXPAND_SZ, new)
        print(f"Añadido bin/ al PATH de usuario: {BIN}")
        print("Abre una terminal nueva para que surta efecto.")
    except Exception as e:
        print(f"No se pudo modificar el PATH automáticamente: {e}")
        print(f"Añádelo manualmente a tu PATH: {BIN}")


def main() -> None:
    import argparse
    p = argparse.ArgumentParser(prog="fm-setup")
    p.add_argument("--path", action="store_true",
                   help="integrar bin/ al PATH del usuario")
    args = p.parse_args()

    check_python()
    ensure_deps()
    init_db()
    if args.path:
        setup_path(True)
    else:
        setup_path(False)
    print("\nSetup completado. Prueba:  fm semilla  y  fm busca 'error'")


if __name__ == "__main__":
    main()
