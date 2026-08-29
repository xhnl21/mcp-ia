"""
cleaning.py — "Lavadero de juguetes": limpiador de errores / stack traces.

Un error de Flutter/Dart suele venir cubierto de ruido: rutas de carpetas,
direcciones de memoria (0x1a2b3c), números de línea y llamadas de sistema.
Ese barro confunde al buscador. Este módulo limpia el texto y deja solo la
"pieza rota" (la excepción / el mensaje) para buscar con precisión.
"""
from __future__ import annotations

import re

# Líneas de stack trace / rutas internas que son ruido y deben descartarse.
_NOISE_LINES = (
    ".dart:",
    "package:",
    "file:///",
    "flutter_tools",
    "dart:ui",
    "dart:async",
    "dart:core",
    "dart:isolate",
    "org/dartlang",
    "java.",
    "io.flutter.",
    "android.",
    "at ",
    "./",
    "\\",
    " (",
)

# Direcciones de memoria, nums de línea al final, tokens hex.
_HEX_MEMORY = re.compile(r"0[xX][0-9a-fA-F]{2,}")
_LINE_NUM = re.compile(r":\d+:\d+\b")
_WHITESPACE = re.compile(r"\s+")
_SQUARE_BRACKETS = re.compile(r"\[[^\]]*\]")

# Reconocimiento del nombre de la excepción (primera palabra de la línea clave).
_EXC_NAME = re.compile(
    r"\b([A-Z][A-Za-z0-9_]*(?:Exception|Error|Failure|Fault|Mismatch|"
    r"NotSupported|UnsupportedError|AssertionError))\b"
)

# Mensajes "clave" que indican que esa línea describe el error real.
_KEY_WORDS = (
    "Exception", "Error:", "error:", "FAILURE:", "Execution failed",
    "Failed to", "A RenderFlex overflowed", "Null check operator",
    "has not been initialized", "No implementation found",
    "ProviderNotFound", "can't be assigned", "cannot be", "type mismatch",
    "is not a subtype", "Unhandled exception", "Every element must have",
)


def clean_error(raw: str) -> str:
    """
    Toma un stack trace / error crudo y devuelve el texto limpio y conciso.

    Estrategia:
      1. Si hay una línea que contenga una palabra clave de error y además
         un nombre de Excepción, esa línea es la "pieza rota": la usamos.
      2. Si no, tomamos la primera línea que parezca un error.
      3. Limpiamos direcciones de memoria, números de línea y espacios.
    """
    if not raw:
        return raw

    lines = raw.splitlines()
    cleaned_lines = []

    # Primero: buscar la línea clave con nombre de excepción.
    for line in lines:
        if _EXC_NAME.search(line) and any(k in line for k in _KEY_WORDS):
            cleaned_lines.append(_sanitize(line))
            break
    else:
        # Segundo: elegir la línea clave más informativa (la que tenga
        # más palabras de error, o la más larga si hay empate).
        best_line, best_score = None, -1
        for line in lines:
            if any(k in line for k in _KEY_WORDS):
                score = sum(1 for k in _KEY_WORDS if k in line)
                if score > best_score or (score == best_score and best_line
                                          and len(line) > len(best_line)):
                    best_line, best_score = line, score
        if best_line:
            cleaned_lines.append(_sanitize(best_line))

    # Si no se encontró nada clave, tomamos la primera línea no vacía
    # (suele ser la descripción del error en la salida de flutter).
    if not cleaned_lines:
        for line in lines:
            s = line.strip()
            if s and not any(n in line for n in _NOISE_LINES):
                cleaned_lines.append(_sanitize(s))
                break

    result = " ".join(cleaned_lines).strip()
    return result or _sanitize(raw)


def extract_exception_name(raw: str) -> str | None:
    """Devuelve el nombre de la excepción si se detecta, sino None."""
    m = _EXC_NAME.search(raw)
    return m.group(1) if m else None


def _sanitize(line: str) -> str:
    """Limpia números/espacios de una línea individual."""
    s = _HEX_MEMORY.sub("", line)
    s = _LINE_NUM.sub("", s)
    s = _SQUARE_BRACKETS.sub("", s)
    s = _WHITESPACE.sub(" ", s)
    return s.strip()


if __name__ == "__main__":
    import sys
    print(clean_error(" ".join(sys.argv[1:])))
