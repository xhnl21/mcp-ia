"""Cliente mínimo JSON-RPC para el servidor mcp-ia (stdin/stdout).

Para cuando la sesión no tiene cargadas las herramientas MCP. Uso:
  python3 <mcp-ia>/kit-agentes/compartido/mcpia.py "texto del error"   # search_solutions
  from mcpia import Cliente; Cliente().herramienta("add_solution", {...})
"""
import json, subprocess, sys
from pathlib import Path
# El servidor está en <mcp-ia>/scripts; este archivo, en <mcp-ia>/kit-agentes/compartido.
SERVER = str(Path(__file__).resolve().parents[2] / "scripts" / "mcp_server.py")

class Cliente:
    def __init__(self):
        self.p = subprocess.Popen([sys.executable, SERVER], stdin=subprocess.PIPE, stdout=subprocess.PIPE,
                                  stderr=subprocess.DEVNULL, text=True, encoding="utf-8")
        self.n = 0
        self.llamar("initialize", {"protocolVersion": "2024-11-05", "capabilities": {}, "clientInfo": {"name": "jefe-maestro", "version": "1"}})
    def llamar(self, metodo, params):
        self.n += 1
        self.p.stdin.write(json.dumps({"jsonrpc": "2.0", "id": self.n, "method": metodo, "params": params}) + "\n")
        self.p.stdin.flush()
        return json.loads(self.p.stdout.readline())
    def herramienta(self, nombre, args):
        r = self.llamar("tools/call", {"name": nombre, "arguments": args})
        return "".join(c.get("text", "") for c in r.get("result", {}).get("content", [])) or json.dumps(r)

if __name__ == "__main__":
    c = Cliente()
    for consulta in sys.argv[1:]:
        print(f"── {consulta}\n{c.herramienta('search_solutions', {'query': consulta})[:400]}\n")
