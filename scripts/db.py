"""
db.py — Capa de acceso a la base de datos SQLite para flutter-memory.

Schema optimizado para: búsqueda rápida (FTS5), etiquetas, categorías,
índice de frecuencia y trazabilidad de fuentes. Diseñado para ALMACENAR
miles de soluciones sin degradar la velocidad de búsqueda.
"""
from __future__ import annotations

import os
import sqlite3
import time
from pathlib import Path

# Ruta de la base de datos (relativa a este módulo -> carpeta data).
BASE_DIR = Path(__file__).resolve().parent.parent
DATA_DIR = BASE_DIR / "data"
DB_PATH = os.environ.get("FM_DB", str(DATA_DIR / "flutter_memory.db"))

SCHEMA = """
CREATE TABLE IF NOT EXISTS categorias (
    id          INTEGER PRIMARY KEY AUTOINCREMENT,
    nombre      TEXT NOT NULL UNIQUE,
    descripcion TEXT,
    creada_en   TEXT NOT NULL DEFAULT (datetime('now'))
);

CREATE TABLE IF NOT EXISTS tags (
    id        INTEGER PRIMARY KEY AUTOINCREMENT,
    nombre    TEXT NOT NULL UNIQUE,
    usos      INTEGER NOT NULL DEFAULT 1
);

CREATE TABLE IF NOT EXISTS soluciones (
    id             INTEGER PRIMARY KEY AUTOINCREMENT,
    titulo         TEXT NOT NULL,
    problema       TEXT NOT NULL,
    solucion       TEXT NOT NULL,
    categorias_id  INTEGER REFERENCES categorias(id) ON DELETE SET NULL,
    url            TEXT,
    fuente         TEXT,          -- 'manual' | 'stackoverflow' | 'github' | 'flutterdocs' | 'awesome'
    lenguaje       TEXT DEFAULT 'dart',
    framework      TEXT DEFAULT 'flutter',
    veces_usada    INTEGER NOT NULL DEFAULT 0,
    veces_buscada  INTEGER NOT NULL DEFAULT 0,
    veces_resuelta INTEGER NOT NULL DEFAULT 0,
    last_used      TEXT,
    creada_en      TEXT NOT NULL DEFAULT (datetime('now')),
    actualizada_en TEXT NOT NULL DEFAULT (datetime('now')),
    hash           TEXT UNIQUE
);

CREATE TABLE IF NOT EXISTS solucion_tag (
    solucion_id INTEGER NOT NULL REFERENCES soluciones(id) ON DELETE CASCADE,
    tag_id      INTEGER NOT NULL REFERENCES tags(id) ON DELETE CASCADE,
    PRIMARY KEY (solucion_id, tag_id)
);

-- Índice de frecuencia/patrones para detección de errores recurrentes.
CREATE TABLE IF NOT EXISTS patrones_error (
    id           INTEGER PRIMARY KEY AUTOINCREMENT,
    texto_deteccion TEXT NOT NULL,       -- regex/subcadena que identifica el patrón
    etiqueta     TEXT NOT NULL,          -- nombre corto del patrón p.ej. 'MissingPluginException'
    conteo       INTEGER NOT NULL DEFAULT 0,
    solucion_id  INTEGER,
    UNIQUE (etiqueta)
);

-- Búsqueda full-text (FTS5). Permite queries rápidas tipo SQL nativa.
CREATE VIRTUAL TABLE IF NOT EXISTS soluciones_fts USING fts5(
    titulo,
    problema,
    solucion,
    content='soluciones',
    content_rowid='id'
);

CREATE TRIGGER IF NOT EXISTS soluciones_ai AFTER INSERT ON soluciones BEGIN
    INSERT INTO soluciones_fts(rowid, titulo, problema, solucion)
    VALUES (new.id, new.titulo, new.problema, new.solucion);
END;

CREATE TRIGGER IF NOT EXISTS soluciones_ad AFTER DELETE ON soluciones BEGIN
    INSERT INTO soluciones_fts(soluciones_fts, rowid, titulo, problema, solucion)
    VALUES ('delete', old.id, old.titulo, old.problema, old.solucion);
END;

CREATE TRIGGER IF NOT EXISTS soluciones_au AFTER UPDATE ON soluciones BEGIN
    INSERT INTO soluciones_fts(soluciones_fts, rowid, titulo, problema, solucion)
    VALUES ('delete', old.id, old.titulo, old.problema, old.solucion);
    INSERT INTO soluciones_fts(rowid, titulo, problema, solucion)
    VALUES (new.id, new.titulo, new.problema, new.solucion);
END;
"""


def get_conn(db_path: str | None = None) -> sqlite3.Connection:
    """Devuelve una conexión SQLite con row factory y inicializa el schema."""
    path = db_path or DB_PATH
    Path(path).parent.mkdir(parents=True, exist_ok=True)
    conn = sqlite3.connect(path)
    conn.row_factory = sqlite3.Row
    conn.execute("PRAGMA journal_mode=WAL;")
    conn.execute("PRAGMA foreign_keys=ON;")
    conn.execute("PRAGMA synchronous=NORMAL;")
    return conn


def init_db(db_path: str | None = None) -> None:
    """Crea el schema si no existe."""
    conn = get_conn(db_path)
    try:
        conn.executescript(SCHEMA)
        conn.commit()
    finally:
        conn.close()


def add_default_categories(conn: sqlite3.Connection) -> None:
    """Insertar categorías por defecto orientadas a Flutter/Dart."""
    cats = [
        ("compilacion", "Errores de compilación / build / pub get"),
        ("runtime", "Excepciones y errores en tiempo de ejecución"),
        ("widgets", "Problemas de widgets, layout y estados"),
        ("estado", "Gestión de estado (Provider, Riverpod, Bloc)"),
        ("asincronia", "Future, Stream, async/await, isolate"),
        ("red", "HTTP, Dio, WebSockets, conectividad"),
        ("persistencia", "Hive, SharedPreferences, sqflite, Drift"),
        ("dependencias", "Versionado, conflictos de paquetes, pub.dev"),
        ("plataforma", "Android, iOS, web, plugins nativos"),
        ("testing", "Problemas con test, mocks e integración"),
        ("performance", "FPS, memoria, jank, build time"),
        ("build_errors", "Errores específicos de flutter build"),
    ]
    for nombre, desc in cats:
        conn.execute(
            "INSERT OR IGNORE INTO categorias(nombre, descripcion) VALUES (?, ?)",
            (nombre, desc),
        )
    conn.commit()


def init_if_needed() -> sqlite3.Connection:
    conn = get_conn()
    init_db()
    add_default_categories(conn)
    return conn


if __name__ == "__main__":
    conn = init_if_needed()
    n = conn.execute("SELECT COUNT(*) AS c FROM soluciones").fetchone()["c"]
    print(f"Base de datos lista en {DB_PATH}. Soluciones: {n}")
    conn.close()
