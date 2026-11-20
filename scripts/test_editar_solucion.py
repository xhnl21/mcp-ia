"""
Prueba de edit_solution y de la sincronización de una solución editada, con dos máquinas de mentira (dos bases)
y un compartido.json entre ellas. No toca la base real.
Uso: python3 scripts/test_editar_solucion.py
"""
from __future__ import annotations

import os
import sys
import tempfile

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import db  # noqa: E402
import manager  # noqa: E402

TMP = tempfile.mkdtemp()
COMPARTIDO = os.path.join(TMP, "compartido.json")


def maquina(nombre: str) -> None:
    db.DB_PATH = os.path.join(TMP, f"{nombre}.db")


def filas() -> list:
    conn = db.init_if_needed()
    r = conn.execute("SELECT id, titulo, problema, veces_usada, reemplaza FROM soluciones ORDER BY id").fetchall()
    conn.close()
    return r


def tags(sid: int) -> list[str]:
    conn = db.init_if_needed()
    r = [t["nombre"] for t in conn.execute(
        "SELECT t.nombre FROM tags t JOIN solucion_tag st ON st.tag_id = t.id WHERE st.solucion_id = ? ORDER BY 1", (sid,))]
    conn.close()
    return r


# Máquina A registra una solución con un dato que no debía estar; B la recibe al sincronizar.
maquina("a")
sid = manager.add_solution("[x] Falla", "Lista el correo de alguien", "Arreglo", categoria="runtime", tags=["uno"])
otra = manager.add_solution("[x] Otra", "Otro problema", "Otro arreglo")
manager.export_json(COMPARTIDO)
maquina("b")
assert manager.import_json(COMPARTIDO) == 2
conn = db.init_if_needed()
conn.execute("UPDATE soluciones SET veces_usada = 3 WHERE titulo = '[x] Falla'")
conn.commit()
conn.close()

# A la corrige: conserva el id y guarda el hash viejo.
maquina("a")
assert manager.edit_solution(999) == "No existe la solución #999."
assert manager.edit_solution(sid, problema="  ") != ""  # no puede quedar vacía
assert manager.edit_solution(sid, problema="Otro problema", titulo="[x] Otra", solucion="Otro arreglo").startswith("Ya hay otra")
assert manager.edit_solution(sid, categoria="no-existe").startswith("No existe la categoría")
assert manager.edit_solution(sid, problema="Lista un dato personal", tags=["dos", "tres"]) == ""
a = filas()
assert [r["id"] for r in a] == [sid, otra] and a[0]["problema"] == "Lista un dato personal" and a[0]["reemplaza"]
assert tags(sid) == ["dos", "tres"]

# B sincroniza: su copia vieja se corrige en su lugar (conserva sus usos), sin duplicarse.
manager.export_json(COMPARTIDO)
maquina("b")
assert manager.import_json(COMPARTIDO) == 1
b = filas()
assert len(b) == 2 and b[0]["problema"] == "Lista un dato personal" and b[0]["veces_usada"] == 3, [dict(r) for r in b]
assert tags(b[0]["id"]) == ["dos", "tres"]

# El archivo viejo de B (con la versión vieja) vuelve a llegar a A: no la revive.
maquina("c")
manager.add_solution("[x] Falla", "Lista el correo de alguien", "Arreglo")  # una máquina que nunca sincronizó
VIEJO = os.path.join(TMP, "viejo.json")
manager.export_json(VIEJO)
maquina("a")
assert manager.import_json(VIEJO) == 0
assert len(filas()) == 2

# Si en una máquina quedaron las dos versiones, la vieja se va y sus usos pasan a la nueva.
maquina("d")
vieja = manager.add_solution("[x] Falla", "Lista el correo de alguien", "Arreglo")
manager.add_solution("[x] Falla", "Lista un dato personal", "Arreglo")  # llegó la nueva sin su «reemplaza»
conn = db.init_if_needed()
conn.execute("UPDATE soluciones SET veces_usada = 5 WHERE id = ?", (vieja,))
conn.commit()
conn.close()
maquina("a")
manager.export_json(COMPARTIDO)
maquina("d")
manager.import_json(COMPARTIDO)
d = [dict(r) for r in filas() if r["titulo"] == "[x] Falla"]
assert [(r["problema"], r["veces_usada"]) for r in d] == [("Lista un dato personal", 5)], d

# Volver al texto anterior no lo marca como viejo de sí mismo.
maquina("a")
assert manager.edit_solution(sid, problema="Lista el correo de alguien") == ""
fila = filas()[0]
assert manager._hash(fila["titulo"] + fila["problema"] + "Arreglo") not in fila["reemplaza"].split()

print("✅ edit_solution y la sincronización de soluciones editadas funcionan")
