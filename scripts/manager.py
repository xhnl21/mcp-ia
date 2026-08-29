"""
manager.py — Alta/modificación de soluciones, tags, patrones y reportes.
"""
from __future__ import annotations

import hashlib
import json
import re
from typing import Optional

from db import init_if_needed


def _hash(text: str) -> str:
    return hashlib.sha256(text.strip().encode("utf-8")).hexdigest()[:24]


def add_solution(titulo: str, problema: str, solucion: str,
                 categoria: Optional[str] = None,
                 tags: Optional[list[str]] = None,
                 url: Optional[str] = None,
                 fuente: str = "manual") -> int:
    """
    Agrega una solución. Devuelve el id creado (o existente si el hash
    coincide, es decir, si es duplicada).
    """
    conn = init_if_needed()
    h = _hash(titulo + problema + solucion)

    existing = conn.execute(
        "SELECT id FROM soluciones WHERE hash = ?", (h,)
    ).fetchone()
    if existing:
        conn.close()
        return existing["id"]

    cat_id = None
    if categoria:
        cat_id = conn.execute(
            "SELECT id FROM categorias WHERE nombre = ?", (categoria,)
        ).fetchone()
        if cat_id:
            cat_id = cat_id["id"]

    cur = conn.execute(
        """
        INSERT INTO soluciones(titulo, problema, solucion, categorias_id, url, fuente, hash)
        VALUES (?, ?, ?, ?, ?, ?, ?)
        """,
        (titulo, problema, solucion, cat_id, url, fuente, h),
    )
    sid = cur.lastrowid

    if tags:
        for t in tags:
            t = t.strip().lower()
            tag_id = conn.execute(
                "SELECT id FROM tags WHERE nombre = ?", (t,)
            ).fetchone()
            if tag_id:
                conn.execute(
                    "UPDATE tags SET usos = usos + 1 WHERE id = ?", (tag_id["id"],)
                )
                tid = tag_id["id"]
            else:
                cur2 = conn.execute("INSERT INTO tags(nombre) VALUES (?)", (t,))
                tid = cur2.lastrowid
            conn.execute(
                "INSERT OR IGNORE INTO solucion_tag(solucion_id, tag_id) VALUES (?, ?)",
                (sid, tid),
            )
    conn.commit()
    conn.close()
    return sid


def register_pattern(texto_deteccion: str, etiqueta: str,
                     solucion_id: Optional[int] = None) -> int:
    """Registra un patrón de error recurrente."""
    conn = init_if_needed()
    conn.execute(
        """
        INSERT INTO patrones_error(texto_deteccion, etiqueta, solucion_id, conteo)
        VALUES (?, ?, ?, 1)
        ON CONFLICT(etiqueta) DO UPDATE SET conteo = conteo + 1,
                                             solucion_id = COALESCE(?, solucion_id)
        """,
        (texto_deteccion, etiqueta, solucion_id, solucion_id),
    )
    conn.commit()
    conn.close()


def detect_patterns(problem_text: str) -> list[dict]:
    """
    Detecta si el texto de un error coincide con patrones conocidos.
    Usa coincidencia de subcadena simple + fuzzy para ser robusto.
    """
    conn = init_if_needed()
    pats = conn.execute("SELECT * FROM patrones_error").fetchall()
    from search import _ratio
    hits = []
    for p in pats:
        needle = p["texto_deteccion"].strip().lower()
        if needle and (needle in problem_text.lower() or _ratio(needle, problem_text) > 0.6):
            hits.append({"etiqueta": p["etiqueta"], "conteo": p["conteo"],
                         "solucion_id": p["solucion_id"]})
    conn.close()
    return hits


def report(top: int = 15) -> str:
    """Genera un reporte de errores/soluciones frecuentes."""
    conn = init_if_needed()
    out = []
    out.append("=== ERRORES / SOLUCIONES FRECUENTES ===")
    rows = conn.execute(
        """
        SELECT titulo, veces_usada, veces_resuelta, veces_buscada
        FROM soluciones
        ORDER BY (veces_usada + veces_resuelta) DESC, veces_buscada DESC
        LIMIT ?
        """, (top,)
    ).fetchall()
    for i, r in enumerate(rows, 1):
        out.append(f"{i:>2}. [{r['veces_usada']}u/{r['veces_resuelta']}r/{r['veces_buscada']}b] {r['titulo']}")

    out.append("")
    out.append("=== PATRONES DE ERROR RECURRENTES ===")
    pats = conn.execute(
        "SELECT etiqueta, conteo FROM patrones_error ORDER BY conteo DESC LIMIT ?",
        (top,),
    ).fetchall()
    for p in pats:
        out.append(f"   {p['conteo']:>4}x  {p['etiqueta']}")

    out.append("")
    out.append("=== TAGS MÁS UTILIZADOS ===")
    tags = conn.execute(
        "SELECT nombre, usos FROM tags ORDER BY usos DESC LIMIT ?", (top,)
    ).fetchall()
    for t in tags:
        out.append(f"   {t['nombre']} ({t['usos']})")

    conn.close()
    return "\n".join(out)


def export_json(path: Optional[str] = None) -> str:
    """Exporta todas las soluciones a JSON (para backup/import)."""
    conn = init_if_needed()
    rows = conn.execute("SELECT * FROM soluciones").fetchall()
    data = [dict(r) for r in rows]
    for d in data:
        tags = conn.execute(
            "SELECT t.nombre FROM tags t JOIN solucion_tag st ON st.tag_id=t.id WHERE st.solucion_id=?",
            (d["id"],),
        ).fetchall()
        d["tags"] = [t["nombre"] for t in tags]
    conn.close()
    path = path or str(__import__("pathlib").Path(__file__).resolve().parent.parent
                       / "data" / "backups" / "export.json")
    with open(path, "w", encoding="utf-8") as f:
        json.dump(data, f, ensure_ascii=False, indent=2, default=str)
    return path


def import_json(path: str) -> int:
    """Importa soluciones desde un archivo JSON exportado. Devuelve nº nuevas."""
    with open(path, "r", encoding="utf-8") as f:
        data = json.load(f)
    conn = init_if_needed()
    count = 0
    for d in data:
        h = _hash(d["titulo"] + d["problema"] + d["solucion"])
        dup = conn.execute("SELECT id FROM soluciones WHERE hash = ?", (h,)).fetchone()
        if dup:
            continue
        conn.close()
        add_solution(
            titulo=d["titulo"], problema=d["problema"], solucion=d["solucion"],
            categoria=d.get("categoria") or None,
            tags=d.get("tags"), url=d.get("url"), fuente=d.get("fuente") or "import",
        )
        conn = init_if_needed()
        count += 1
    conn.close()
    return count


def seed_sample() -> None:
    """Inserta algunas soluciones de ejemplo Flutter/Dart si la BD está vacía."""
    conn = init_if_needed()
    n = conn.execute("SELECT COUNT(*) AS c FROM soluciones").fetchone()["c"]
    conn.close()
    if n > 0:
        return
    samples = [
        {
            "titulo": "MissingPluginException: No implementation found for method",
            "problema": "MissingPluginException: No implementation found for method getAllIcons on channel plugins.flutter.io/shared_preferences",
            "solucion": "Ejecuta `flutter clean` y `flutter pub get`. Cierra y vuelve a abrir la app (no uses hot reload para registrar plugins). Si usas tests, inicializa SharedPreferences.setMockInitialValues({}) en setUp.",
            "categoria": "plataforma",
            "tags": ["plugin", "channel", "test"],
        },
        {
            "titulo": "Error: The argument type 'String?' can't be assigned to the parameter type 'String'",
            "problema": "Error: The argument type 'String?' can't be assigned to the parameter type 'String'",
            "solucion": "Haz null-safe: usa `?? ''`, `!`, o maneja el null con if/else. Ej: `text ?? ''`. Activa el análisis con `dart analyze` para localizar todos.",
            "categoria": "compilacion",
            "tags": ["null-safety", "nullable", "types"],
        },
        {
            "titulo": "ProviderNotFoundException: No Provider<X> found",
            "problema": "ProviderNotFoundException: No Provider<X> found",
            "solucion": "Asegúrate de que el Provider esté ABOVE del widget que lo consume en el árbol. Envuelve la app o la ruta con MultiProvider. Revisa que Context sea posterior al provider (usa context que desciende).",
            "categoria": "estado",
            "tags": ["provider", "context", "tree"],
        },
        {
            "titulo": "Execution failed for task ':app:compileDebugKotlin'",
            "problema": "Execution failed for task ':app:compileDebugKotlin'. Kotlin version mismatch",
            "solucion": "Sincroniza la versión de Kotlin en android/settings.gradle con la requerida por tus plugins. Aumenta la memoria del heap en gradle.properties (org.gradle.jvmargs=-Xmx4G). Usa `flutter doctor -v` para diagnosticar.",
            "categoria": "build_errors",
            "tags": ["gradle", "kotlin", "android"],
        },
        {
            "titulo": "lateInitializationError: Field '_controller' has not been initialized",
            "problema": "LateInitializationError: Field '_controller' has not been initialized",
            "solucion": "Usa `late final` solo cuando sabes que se inicializará ANTES de usarse, o usa `?` nullable con inicialización en initState. Evita acceder a controllers antes de que el widget esté montado.",
            "categoria": "runtime",
            "tags": ["controller", "late", "initstate"],
        },
    ]
    for s in samples:
        add_solution(**s)
    # Patrones de ejemplo
    register_pattern("MissingPluginException", "MissingPluginException", solucion_id=1)
    register_pattern("can't be assigned to the parameter type", "Tipo_String_null", solucion_id=2)
    register_pattern("ProviderNotFoundException", "ProviderNoEncontrado", solucion_id=3)
    register_pattern("Execution failed for task", "BuildGradleError", solucion_id=4)
    register_pattern("has not been initialized", "LateInitializationError", solucion_id=5)


if __name__ == "__main__":
    import sys
    seed_sample()
    if len(sys.argv) > 1 and sys.argv[1] == "report":
        print(report())
