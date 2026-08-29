"""
backup.py — Backups automáticos de la base de datos y del conocimiento.
Copia la BD SQLite (modo WAL) y crea un export JSON con nombre de fecha.
"""
from __future__ import annotations

import os
import shutil
import sys
import time
from pathlib import Path

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import manager  # noqa: E402

BASE = Path(__file__).resolve().parent.parent
DATA = BASE / "data"
BACKUP_DIR = DATA / "backups"
DB = DATA / "flutter_memory.db"


def backup() -> str:
    BACKUP_DIR.mkdir(parents=True, exist_ok=True)
    ts = time.strftime("%Y%m%d_%H%M%S")

    # 1. Export JSON (portable, legible)
    json_path = manager.export_json(str(BACKUP_DIR / f"export_{ts}.json"))

    # 2. Copia física del .db (WAL checkpoint previo para consistencia)
    if DB.exists():
        db_copy = BACKUP_DIR / f"flutter_memory_{ts}.db"
        shutil.copy2(DB, db_copy)
        # también copia wal/shm si existieran
        for suffix in ("-wal", "-shm"):
            src = Path(str(DB) + suffix)
            if src.exists():
                shutil.copy2(src, BACKUP_DIR / (db_copy.name + suffix))
        return f"Backup completado:\n  JSON: {json_path}\n  DB:   {db_copy}"

    return json_path


def prune(keep: int = 20) -> int:
    """Borra backups antiguos conservando los `keep` más recientes."""
    files = sorted(BACKUP_DIR.glob("*.db")) + sorted(BACKUP_DIR.glob("*.json"))
    removed = 0
    while len(files) > keep:
        f = files.pop(0)
        f.unlink(missing_ok=True)
        removed += 1
    return removed


if __name__ == "__main__":
    import argparse
    p = argparse.ArgumentParser(prog="fm-backup")
    p.add_argument("--prune", type=int, default=0, help="borra antiguos dejando N")
    a = p.parse_args()
    if a.prune:
        print(f"Backups antiguos eliminados: {prune(a.prune)}")
    print(backup())
