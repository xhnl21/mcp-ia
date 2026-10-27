#!/usr/bin/env python3
"""Enlaza lo compartido de mcp-ia en Claude Code y Antigravity de esta máquina.

Una sola fuente (este repo) y enlaces simbólicos desde donde cada agente busca:

  Qué                               Claude Code                         Antigravity (agy)
  herramientas/<h>/ (con SKILL.md)  ~/.claude/skills/<h>                ~/.gemini/config/skills/<h>
  compartido/reglas/*.md            ~/.claude/reglas-compartidas/ (+ @import en ~/.claude/CLAUDE.md)
                                                                        ~/.gemini/config/rules/<regla>.md

Así, una regla o una skill nueva en mcp-ia llega a todos los proyectos y a los
dos agentes con un `git pull`. Es idempotente; lo que reemplaza (si no era ya un
enlace) lo guarda como <nombre>.bak-<fecha>.

Uso:
  python3 enlazar_compartido.py          # aplica
  python3 enlazar_compartido.py --ver    # solo muestra lo que haría
  python3 enlazar_compartido.py --quitar # borra los enlaces (no toca la fuente)

En Windows los enlaces simbólicos exigen el Modo de desarrollador; si no está
activo, se copian los archivos y se avisa (habrá que volver a ejecutarlo tras
cada `git pull`).
"""
from __future__ import annotations

import argparse
import datetime
import os
import shutil
import sys
from pathlib import Path

KIT = Path(__file__).resolve().parent
HERRAMIENTAS = KIT / "herramientas"
REGLAS = KIT / "compartido" / "reglas"
INDICE = REGLAS / "INDICE.md"

HOME = Path.home()
CLAUDE = HOME / ".claude"
GEMINI_CFG = HOME / ".gemini" / "config"
IMPORT_CLAUDE = "@reglas-compartidas/INDICE.md"


def sello() -> str:
    return datetime.datetime.now().strftime("%Y%m%d-%H%M%S")


def enlaces() -> list[tuple[Path, Path]]:
    """(destino, fuente) de cada enlace a crear."""
    pares: list[tuple[Path, Path]] = []
    for h in sorted(HERRAMIENTAS.iterdir()) if HERRAMIENTAS.is_dir() else []:
        if (h / "SKILL.md").is_file():
            pares.append((CLAUDE / "skills" / h.name, h))
            pares.append((GEMINI_CFG / "skills" / h.name, h))
    if REGLAS.is_dir():
        pares.append((CLAUDE / "reglas-compartidas", REGLAS))
        for regla in sorted(REGLAS.glob("*.md")):
            if regla.name != INDICE.name:
                pares.append((GEMINI_CFG / "rules" / regla.name, regla))
    return pares


def escribir_indice(ver: bool) -> None:
    """INDICE.md importa cada regla (Claude Code sigue los @import de CLAUDE.md)."""
    reglas = [r for r in sorted(REGLAS.glob("*.md")) if r.name != INDICE.name]
    texto = (
        "# Reglas compartidas (mcp-ia)\n\n"
        "Generado por `kit-agentes/enlazar_compartido.py`: una línea `@` por regla de "
        "`compartido/reglas/`. No lo edites a mano.\n\n"
        + "".join(f"@{r.name}\n" for r in reglas)
    )
    if INDICE.exists() and INDICE.read_text(encoding="utf-8") == texto:
        return
    print(f"  {'(ver) ' if ver else ''}índice de reglas: {len(reglas)} regla(s) → {INDICE}")
    if not ver:
        INDICE.write_text(texto, encoding="utf-8")


def enlazar(destino: Path, fuente: Path, ver: bool) -> None:
    # Se compara el destino literal: un enlace que llega a la fuente a través de
    # otro enlace (p. ej. tras mover mcp-ia) se rehace para que apunte directo.
    if destino.is_symlink() and os.readlink(destino) == str(fuente):
        print(f"  = {destino}")
        return
    print(f"  {'(ver) ' if ver else ''}+ {destino} → {fuente}")
    if ver:
        return
    destino.parent.mkdir(parents=True, exist_ok=True)
    if destino.is_symlink():
        destino.unlink()
    elif destino.exists():
        respaldo = destino.with_name(f"{destino.name}.bak-{sello()}")
        destino.rename(respaldo)
        print(f"    (lo que había quedó en {respaldo.name})")
    try:
        destino.symlink_to(fuente, target_is_directory=fuente.is_dir())
    except OSError as e:
        print(f"    ⚠️  sin enlace simbólico ({e}); se copia. Repite tras cada git pull.")
        if fuente.is_dir():
            shutil.copytree(fuente, destino)
        else:
            shutil.copy2(fuente, destino)


def importar_en_claude(ver: bool) -> None:
    """Agrega `@reglas-compartidas/INDICE.md` a ~/.claude/CLAUDE.md (una vez)."""
    claude_md = CLAUDE / "CLAUDE.md"
    actual = claude_md.read_text(encoding="utf-8") if claude_md.exists() else ""
    if IMPORT_CLAUDE in actual:
        print(f"  = {claude_md} ya importa las reglas compartidas")
        return
    print(f"  {'(ver) ' if ver else ''}+ {claude_md}: agrega «{IMPORT_CLAUDE}»")
    if ver:
        return
    if claude_md.exists():
        shutil.copy2(claude_md, claude_md.with_name(f"CLAUDE.md.bak-{sello()}"))
    bloque = (
        "\n\n## Reglas compartidas (mcp-ia)\n\n"
        "Reglas de todos los proyectos, enlazadas desde mcp-ia/kit-agentes/compartido/reglas "
        "(`python3 <mcp-ia>/kit-agentes/enlazar_compartido.py`).\n\n"
        f"{IMPORT_CLAUDE}\n"
    )
    claude_md.parent.mkdir(parents=True, exist_ok=True)
    claude_md.write_text(actual.rstrip("\n") + bloque, encoding="utf-8")


def quitar() -> None:
    for destino, fuente in enlaces():
        if destino.is_symlink() and destino.resolve() == fuente.resolve():
            destino.unlink()
            print(f"  - {destino}")
    print("Enlaces quitados. La línea de ~/.claude/CLAUDE.md se deja: bórrala a mano si quieres.")


def main() -> None:
    p = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    p.add_argument("--ver", action="store_true", help="solo muestra lo que haría")
    p.add_argument("--quitar", action="store_true", help="borra los enlaces creados")
    a = p.parse_args()
    if a.quitar:
        quitar()
        return
    print(f"Fuente: {KIT}")
    if REGLAS.is_dir():
        escribir_indice(a.ver)
    for destino, fuente in enlaces():
        enlazar(destino, fuente, a.ver)
    if REGLAS.is_dir():
        importar_en_claude(a.ver)
    print("(--ver) No se cambió nada." if a.ver else "✓ Listo. Claude Code y Antigravity leen lo compartido desde mcp-ia.")


if __name__ == "__main__":
    sys.exit(main())
