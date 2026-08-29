"""
search.py — Motor de búsqueda local con fuzzy matching.

Combina:
  1. Búsqueda FTS5 (SQLite) — rápida y tolerante a palabras incompletas.
  2. Fuzzy matching (RapidFuzz si está instalado, si no difflib) — para
     errores escritos con typos o con espacios/dígitos variables.
  3. Priorización por frecuencia de uso (veces_usada + veces_resuelta)
     para que las soluciones más útiles aparezcan primero.
"""
from __future__ import annotations

import re
from difflib import SequenceMatcher
from typing import Optional

try:
    from rapidfuzz import fuzz
    HAS_RAPIDFUZZ = True
except ImportError:
    HAS_RAPIDFUZZ = False

from db import init_if_needed
import cleaning


def _normalize(text: str) -> str:
    """Normaliza texto: minúsculas, elimina puntuación, colapsa espacios."""
    text = text.lower()
    text = re.sub(r"[^\w\s]", " ", text)
    return re.sub(r"\s+", " ", text).strip()


def _tokenize(text: str) -> list[str]:
    return [t for t in _normalize(text).split() if t]


_ERR_HINTS = (
    "exception", "error", "failed", "fail", "can't", "cannot", "cant",
    "assigned", "not found", "not a", "unable", "invalid", "null", "undefined",
    "must be", "expected", "too many", "no implementation", "missing",
)


def _looks_like_error(q: str) -> bool:
    ql = q.lower()
    return any(h in ql for h in _ERR_HINTS)


def _ratio(a: str, b: str) -> float:
    if HAS_RAPIDFUZZ:
        return fuzz.token_set_ratio(a, b) / 100.0
    return SequenceMatcher(None, _normalize(a), _normalize(b)).ratio()


def _fts_query(q: str) -> str:
    """Construye una query FTS con operador AND y sufijos libres."""
    tokens = _normalize(q).split()
    return " AND ".join(f'"{t}"*' for t in tokens) if tokens else ""


def search(query: str, limit: int = 10, category: Optional[str] = None,
           tag: Optional[str] = None) -> list[dict]:
    """
    Busca soluciones. Devuelve list[dict] ya rankeadas.
    La relevancia combina FTS + fuzzy + frecuencia.
    """
    query = cleaning.clean_error(query)
    conn = init_if_needed()
    fts = _fts_query(query)
    fts_hits: dict[int, float] = {}

    if fts:
        rows = conn.execute(
            """
            SELECT s.id, bm25(soluciones_fts) AS rank
            FROM soluciones_fts
            JOIN soluciones s ON s.id = soluciones_fts.rowid
            WHERE soluciones_fts MATCH ?
            ORDER BY rank
            LIMIT 100
            """,
            (fts,),
        ).fetchall()
        for r in rows:
            # bm25 más negativo = mejor match; lo invertimos a scoring 0..1
            fts_hits[r["id"]] = 1.0 / (1.0 + abs(r["rank"]))

    # Recuperar candidatos (con filtros de categoría/tag).
    sql = """
        SELECT s.* FROM soluciones s
        {join_tag}
        WHERE {where}
        {group}
        LIMIT 500
    """
    join_tag = ""
    where = ["1=1"]
    group = ""
    params: list = []

    if category:
        where.append("s.categorias_id = (SELECT id FROM categorias WHERE nombre = ?)")
        params.append(category)
    if tag:
        join_tag = "JOIN solucion_tag st ON st.solucion_id = s.id"
        where.append("st.tag_id = (SELECT id FROM tags WHERE nombre = ?)")
        group = "GROUP BY s.id"
        params.append(tag)

    sql = sql.format(
        join_tag=join_tag,
        where=" AND ".join(where),
        group=group,
    )
    rows = conn.execute(sql, params).fetchall()

    candidates = []
    looks_error = _looks_like_error(query)
    for row in rows:
        score_fts = fts_hits.get(row["id"], 0.0)
        # Score fuzzy sobre titulo y problema.
        f1 = _ratio(query, row["titulo"])
        f2 = _ratio(query, row["problema"]) if row["problema"] else 0.0
        fuzzy = max(f1, f2)

        # Frecuencia: 0..1 normalizado respecto a soluciones más usadas.
        freq = min(1.0, (row["veces_usada"] * 2 + row["veces_resuelta"]) / 100.0)

        # Si la query parece un error, penaliza fuentes de tipo "recursos"
        # (Awesome/docs) que suelen ser ruido, y exige más fuzzy.
        source = row["fuente"] or ""
        source_penalty = 1.0
        fuzzy_threshold = 0.05
        if looks_error and source in ("awesome", "flutterdocs"):
            source_penalty = 0.15
            fuzzy_threshold = 0.5

        # Score combinado ponderado.
        score = (score_fts * 1.0 + fuzzy * 1.2 + freq * 0.4) * source_penalty

        if score > fuzzy_threshold:
            candidates.append({
                "id": row["id"],
                "titulo": row["titulo"],
                "problema": row["problema"],
                "solucion": row["solucion"],
                "url": row["url"],
                "fuente": row["fuente"],
                "categoria": category or "",
                "veces_usada": row["veces_usada"],
                "veces_resuelta": row["veces_resuelta"],
                "veces_buscada": row["veces_buscada"],
                "score": round(score, 4),
            })

    # Ordenar por score desc.
    candidates.sort(key=lambda c: c["score"], reverse=True)
    # Incrementar contador de búsquedas de los que se muestran.
    for c in candidates[:limit]:
        conn.execute(
            "UPDATE soluciones SET veces_buscada = veces_buscada + 1 WHERE id = ?",
            (c["id"],),
        )
    conn.commit()
    conn.close()
    return candidates[:limit]


def record_use(solution_id: int, resolved: bool = True) -> None:
    """Registra el uso (y resolución) de una solución."""
    conn = init_if_needed()
    conn.execute(
        """
        UPDATE soluciones
        SET veces_usada = veces_usada + 1,
            veces_resuelta = veces_resuelta + (?),
            last_used = datetime('now')
        WHERE id = ?
        """,
        (1 if resolved else 0, solution_id),
    )
    conn.commit()
    conn.close()


if __name__ == "__main__":
    import sys
    q = sys.argv[1] if len(sys.argv) > 1 else "plugin not registered"
    for r in search(q):
        print(f"[{r['score']:.2f}] {r['titulo']} (usos: {r['veces_usada']})")
        print(f"    {r['problema'][:100]}")
