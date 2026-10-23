"""
Lecciones de los agentes delegados (Antigravity, OpenCode) compartidas entre
proyectos a través de la base de mcp-ia.

Cada lección vive en la categoría «agentes». Su clave es el ID de la lección
(L-001, J-006…), guardado en `url` como `leccion://<ID>`: al importar de nuevo
una lección cambiada se actualiza, no se duplica.

Uso:
  python3 lecciones.py importar <ruta a LECCIONES_AGENTES.md> [--proyecto NOMBRE]
  python3 lecciones.py exportar [--excluir-de <ruta a LECCIONES_AGENTES.md>]
  python3 lecciones.py listar

- importar: lee los encabezados «### <ID>. <título>» y guarda o actualiza cada
  lección en la base.
- exportar: imprime en Markdown todas las lecciones de la base. Con
  --excluir-de omite las que ya están en ese archivo (por su ID), para que
  delegar.sh no las repita en el prompt.
"""
from __future__ import annotations

import argparse
import re
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
from db import init_if_needed  # noqa: E402

CATEGORIA = "agentes"
_ENCABEZADO = re.compile(r"^###\s+([A-Z]+-\d+)\.\s+(.+?)\s*$")


def _parse(path: Path) -> list[dict]:
    """Lecciones de un LECCIONES_AGENTES.md: id, título y cuerpo."""
    lecciones, actual = [], None
    for linea in path.read_text(encoding="utf-8").splitlines():
        m = _ENCABEZADO.match(linea)
        if m:
            actual = {"id": m.group(1), "titulo": m.group(2), "cuerpo": []}
            lecciones.append(actual)
            continue
        if linea.startswith("## "):
            actual = None
            continue
        if actual is not None:
            actual["cuerpo"].append(linea)
    for l in lecciones:
        l["cuerpo"] = "\n".join(l["cuerpo"]).strip()
    return lecciones


def _categoria_id(conn) -> int:
    fila = conn.execute("SELECT id FROM categorias WHERE nombre = ?", (CATEGORIA,)).fetchone()
    if fila:
        return fila["id"]
    cur = conn.execute(
        "INSERT INTO categorias(nombre, descripcion) VALUES (?, ?)",
        (CATEGORIA, "Lecciones de los agentes delegados (Antigravity, OpenCode)"),
    )
    return cur.lastrowid


def importar(path: Path, proyecto: str) -> tuple[int, int]:
    conn = init_if_needed()
    cat = _categoria_id(conn)
    nuevas = actualizadas = 0
    for l in _parse(path):
        url = f"leccion://{l['id']}"
        titulo = f"{l['id']}. {l['titulo']}"
        fila = conn.execute("SELECT id, solucion FROM soluciones WHERE url = ?", (url,)).fetchone()
        if fila:
            if fila["solucion"] != l["cuerpo"]:
                conn.execute(
                    "UPDATE soluciones SET titulo = ?, problema = ?, solucion = ?, "
                    "actualizada_en = CURRENT_TIMESTAMP WHERE id = ?",
                    (titulo, l["titulo"], l["cuerpo"], fila["id"]),
                )
                actualizadas += 1
            continue
        conn.execute(
            "INSERT INTO soluciones(titulo, problema, solucion, categorias_id, url, fuente, hash) "
            "VALUES (?, ?, ?, ?, ?, ?, ?)",
            (titulo, l["titulo"], l["cuerpo"], cat, url, f"leccion:{proyecto}", url),
        )
        nuevas += 1
    conn.commit()
    conn.close()
    return nuevas, actualizadas


def _todas() -> list[dict]:
    conn = init_if_needed()
    # Se identifican por su ID (url leccion://ID), no por la categoría: una
    # versión anterior de sync.py perdía la categoría al importar.
    filas = conn.execute(
        "SELECT titulo, solucion, url, fuente FROM soluciones "
        "WHERE url LIKE 'leccion://%' ORDER BY url, actualizada_en DESC, id DESC"
    ).fetchall()
    conn.close()
    unicas, vistas = [], set()
    for f in filas:
        if f["url"] not in vistas:
            vistas.add(f["url"])
            unicas.append(dict(f))
    return unicas


def exportar(excluir_de: Path | None) -> str:
    excluir = {l["id"] for l in _parse(excluir_de)} if excluir_de and excluir_de.exists() else set()
    bloques = []
    for f in _todas():
        lid = f["url"].removeprefix("leccion://")
        if lid in excluir:
            continue
        origen = f["fuente"].removeprefix("leccion:")
        bloques.append(f"### {f['titulo']}\n- **Origen:** proyecto {origen}.\n{f['solucion']}")
    if not bloques:
        return ""
    return "## Lecciones comunes de otros proyectos (base mcp-ia)\n\n" + "\n\n".join(bloques) + "\n"


def main() -> None:
    p = argparse.ArgumentParser(description="Lecciones de agentes compartidas (mcp-ia).")
    sub = p.add_subparsers(dest="cmd", required=True)
    imp = sub.add_parser("importar")
    imp.add_argument("archivo", type=Path)
    imp.add_argument("--proyecto", default=None)
    exp = sub.add_parser("exportar")
    exp.add_argument("--excluir-de", type=Path, default=None)
    sub.add_parser("listar")
    a = p.parse_args()

    if a.cmd == "importar":
        proyecto = a.proyecto or a.archivo.resolve().parents[2].name
        n, u = importar(a.archivo, proyecto)
        print(f"Lecciones de {proyecto}: {n} nuevas, {u} actualizadas.")
    elif a.cmd == "exportar":
        sys.stdout.write(exportar(a.excluir_de))
    else:
        for f in _todas():
            print(f"{f['titulo']}  ({f['fuente']})")


if __name__ == "__main__":
    main()
