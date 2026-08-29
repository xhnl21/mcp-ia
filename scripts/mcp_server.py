"""
mcp_server.py — Servidor MCP (Model Context Protocol) multiplataforma en Python puro.

Recibe comandos JSON-RPC por stdin y responde por stdout.
Se comunica usando codificación UTF-8 para garantizar portabilidad en Windows, Mac y Linux.
"""
from __future__ import annotations

import sys
import json
import os
import traceback

def log(msg: str) -> None:
    """Envía logs a stderr para no contaminar stdout (que es solo para JSON-RPC)."""
    sys.stderr.write(f"[mcp-ia] {msg}\n")
    sys.stderr.flush()

# Añadir el directorio de scripts al path de importación
SCRIPTS_DIR = os.path.dirname(os.path.abspath(__file__))
if SCRIPTS_DIR not in sys.path:
    sys.path.insert(0, SCRIPTS_DIR)

try:
    import search
    import manager
except Exception as e:
    log(f"Error al importar módulos: {e}")
    traceback.print_exc(file=sys.stderr)
    sys.exit(1)

# Configurar stdin/stdout a UTF-8 de forma explícita para evitar problemas de codificación (Unicode) en Windows
if hasattr(sys.stdin, "reconfigure"):
    sys.stdin.reconfigure(encoding="utf-8")
if hasattr(sys.stdout, "reconfigure"):
    sys.stdout.reconfigure(encoding="utf-8")

def handle_search_solutions(args: dict) -> dict:
    query = args.get("query")
    category = args.get("category")
    tag = args.get("tag")
    if not query:
        return {"content": [{"type": "text", "text": "Error: El parámetro 'query' es requerido."}], "isError": True}
    
    # search.py realiza la búsqueda con FTS5, fuzzy matching y prioridad por frecuencia
    results = search.search(query, limit=5, category=category, tag=tag)
    if not results:
        return {"content": [{"type": "text", "text": "No se encontraron soluciones locales para esta búsqueda en la base de datos de conocimiento."}]}
    
    out = []
    for r in results:
        out.append(f"=== [Relevancia: {r['score']:.2f}] #{r['id']} — {r['titulo']}")
        out.append(f"Problema: {r['problema']}")
        out.append(f"Solución: {r['solucion']}")
        if r['url']:
            out.append(f"Referencia/URL: {r['url']}")
        out.append(f"Estadísticas: Usos={r['veces_usada']}, Resueltas={r['veces_resuelta']}, Búsquedas={r['veces_buscada']}")
        out.append("-" * 40)
    
    return {"content": [{"type": "text", "text": "\n".join(out)}]}

def handle_add_solution(args: dict) -> dict:
    title = args.get("title")
    problem = args.get("problem")
    solution = args.get("solution")
    category = args.get("category")
    tags = args.get("tags", [])
    url = args.get("url")
    
    if not title or not problem or not solution:
        return {"content": [{"type": "text", "text": "Error: 'title', 'problem' y 'solution' son parámetros obligatorios."}], "isError": True}
    
    sid = manager.add_solution(
        titulo=title, problema=problem, solucion=solution,
        categoria=category, tags=tags, url=url
    )
    return {"content": [{"type": "text", "text": f"Solución añadida exitosamente con ID #{sid}."}]}

def handle_record_usage(args: dict) -> dict:
    sid = args.get("solution_id")
    resolved = args.get("resolved", True)
    if sid is None:
        return {"content": [{"type": "text", "text": "Error: 'solution_id' es un parámetro obligatorio."}], "isError": True}
    
    search.record_use(int(sid), resolved=resolved)
    return {"content": [{"type": "text", "text": f"La solución #{sid} ha sido marcada como usada (resuelta={resolved})."}]}

def handle_get_report(args: dict) -> dict:
    rep = manager.report()
    return {"content": [{"type": "text", "text": rep}]}

TOOLS = [
    {
        "name": "search_solutions",
        "description": "Busca soluciones locales en la base de datos de conocimiento de Flutter/Dart. Úsala antes de recurrir a la generación por IA para ahorrar tokens.",
        "inputSchema": {
            "type": "object",
            "properties": {
                "query": {
                    "type": "string",
                    "description": "El texto del error o término a buscar (ej: MissingPluginException)."
                },
                "category": {
                    "type": "string",
                    "description": "Categoría opcional de búsqueda (ej: compilacion, runtime, widgets, estado, asincronia, red, plataforma)."
                },
                "tag": {
                    "type": "string",
                    "description": "Etiqueta/tag opcional para filtrar las soluciones."
                }
            },
            "required": ["query"]
        }
    },
    {
        "name": "add_solution",
        "description": "Agrega una nueva solución encontrada a la base de datos local de conocimiento para que la IA la recuerde en futuras consultas.",
        "inputSchema": {
            "type": "object",
            "properties": {
                "title": {
                    "type": "string",
                    "description": "Título corto y descriptivo del error o problema."
                },
                "problem": {
                    "type": "string",
                    "description": "Descripción detallada del error original o comportamiento observado."
                },
                "solution": {
                    "type": "string",
                    "description": "La solución paso a paso o código que resuelve el problema."
                },
                "category": {
                    "type": "string",
                    "description": "Categoría slug para clasificarla (ej: compilacion, runtime, widgets, estado, asincronia, red, plataforma)."
                },
                "tags": {
                    "type": "array",
                    "items": {"type": "string"},
                    "description": "Lista de etiquetas libres para búsqueda granular (ej: ['provider', 'null-safety'])."
                },
                "url": {
                    "type": "string",
                    "description": "URL de referencia opcional (Stack Overflow, GitHub, docs oficiales, etc.)."
                }
            },
            "required": ["title", "problem", "solution"]
        }
    },
    {
        "name": "record_usage",
        "description": "Marca una solución específica como usada por su ID para incrementar su relevancia y frecuencia en futuras búsquedas.",
        "inputSchema": {
            "type": "object",
            "properties": {
                "solution_id": {
                    "type": "integer",
                    "description": "El ID numérico único de la solución usada."
                },
                "resolved": {
                    "type": "boolean",
                    "description": "Si la solución resolvió el problema correctamente (por defecto es true)."
                }
            },
            "required": ["solution_id"]
        }
    },
    {
        "name": "get_report",
        "description": "Obtiene un reporte consolidado de los errores más frecuentes, patrones recurrentes y etiquetas más usadas.",
        "inputSchema": {
            "type": "object",
            "properties": {}
        }
    }
]

def main() -> None:
    log("Iniciando servidor MCP...")
    while True:
        try:
            line = sys.stdin.readline()
            if not line:
                break
            line = line.strip()
            if not line:
                continue
            
            request = json.loads(line)
            req_id = request.get("id")
            method = request.get("method")
            params = request.get("params", {})
            
            if method == "initialize":
                response = {
                    "jsonrpc": "2.0",
                    "id": req_id,
                    "result": {
                        "protocolVersion": "2024-11-05",
                        "capabilities": {
                            "tools": {}
                        },
                        "serverInfo": {
                            "name": "mcp-ia",
                            "version": "1.0.0"
                        }
                    }
                }
            elif method == "notifications/initialized":
                continue
            elif method == "tools/list":
                response = {
                    "jsonrpc": "2.0",
                    "id": req_id,
                    "result": {
                        "tools": TOOLS
                    }
                }
            elif method == "tools/call":
                tool_name = params.get("name")
                tool_args = params.get("arguments", {})
                log(f"Ejecutando herramienta {tool_name}...")
                
                if tool_name == "search_solutions":
                    res = handle_search_solutions(tool_args)
                elif tool_name == "add_solution":
                    res = handle_add_solution(tool_args)
                elif tool_name == "record_usage":
                    res = handle_record_usage(tool_args)
                elif tool_name == "get_report":
                    res = handle_get_report(tool_args)
                else:
                    res = {"content": [{"type": "text", "text": f"Error: Herramienta {tool_name} no encontrada."}], "isError": True}
                
                response = {
                    "jsonrpc": "2.0",
                    "id": req_id,
                    "result": res
                }
            else:
                response = {
                    "jsonrpc": "2.0",
                    "id": req_id,
                    "error": {
                        "code": -32601,
                        "message": f"Método {method} no soportado"
                    }
                }
            
            sys.stdout.write(json.dumps(response) + "\n")
            sys.stdout.flush()
        except Exception as e:
            log(f"Error procesando petición: {e}")
            try:
                err_response = {
                    "jsonrpc": "2.0",
                    "error": {
                        "code": -32603,
                        "message": str(e)
                    }
                }
                sys.stdout.write(json.dumps(err_response) + "\n")
                sys.stdout.flush()
            except Exception:
                pass

if __name__ == "__main__":
    main()
