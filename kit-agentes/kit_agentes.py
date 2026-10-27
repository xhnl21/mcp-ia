#!/usr/bin/env python3
"""
Kit del jefe maestro: configura un proyecto para delegar tareas en agentes
(Antigravity `agy`, OpenCode `opencode`) con la base compartida mcp-ia.

Multiplataforma (macOS, Linux, Windows). Solo usa la biblioteca estándar.

Comandos:
  instalar   <proyecto> --prefijo XX [--carpetas "lib test docs"] [--mcp-ia RUTA]
  permisos   [<proyecto>] [--ver]          Permisos de Antigravity para el proyecto.
  mcp        [<proyecto>] [--mcp-ia RUTA]  Clona o usa mcp-ia y lo registra.
  delegar    <agy|opencode> <tarea.md> [nombre] [--solo-prompt]
  verificar  [<proyecto>]                  Revisa que todo quede bien configurado.

`instalar` copia el kit en <proyecto>/.agents/prompts/ y guarda la
configuración local en .agents/prompts/kit.json (ignorado por git).
"""
from __future__ import annotations

import argparse
import datetime as dt
import hashlib
import json
import os
import platform
import shutil
import subprocess
import sys
from pathlib import Path

AQUI = Path(__file__).resolve().parent
PLANTILLAS = AQUI / "plantillas"
REPO_MCP_IA = "https://github.com/xhnl21/mcp-ia.git"
ES_WINDOWS = platform.system() == "Windows"
AGY_SETTINGS = Path.home() / ".gemini" / "antigravity-cli" / "settings.json"
AGY_MCP = Path.home() / ".gemini" / "config" / "mcp_config.json"
# Windows corta la línea de comandos en 32.767 caracteres; los prompts grandes
# se pasan como ruta a un archivo que el agente lee.
LIMITE_PROMPT = 24000
COMANDOS_AGY = [
    "flutter test", "flutter analyze", "git status", "git diff", "git log",
    "grep", "ls", "cat", "find", "wc",
]
HERRAMIENTAS_MCP_AGY = ["mcp-ia/search_solutions"]
HOOKS_COMUNES = ["pre-commit", "pre-push", "commit-msg"]
GITIGNORE = [".agents/prompts/lotes/", ".agents/prompts/kit.json", ".mcp.json",
             ".claude/settings.local.json"]


# --------------------------------------------------------------------------- util
def raiz_git(desde: Path) -> Path:
    r = subprocess.run(["git", "rev-parse", "--show-toplevel"], cwd=desde,
                       capture_output=True, text=True)
    if r.returncode != 0:
        sys.exit(f"❌ {desde} no es un repositorio git. Ejecuta `git init` primero.")
    return Path(r.stdout.strip())


def python_cmd() -> str:
    return sys.executable or ("py" if ES_WINDOWS else "python3")


def leer_json(p: Path, defecto):
    if not p.exists():
        return defecto
    try:
        return json.loads(p.read_text(encoding="utf-8"))
    except json.JSONDecodeError as e:
        sys.exit(f"❌ {p} no es JSON válido ({e}). Corrígelo antes de seguir.")


def escribir_json(p: Path, data, respaldo: bool = False) -> None:
    p.parent.mkdir(parents=True, exist_ok=True)
    if respaldo and p.exists():
        shutil.copy2(p, f"{p}.bak-{dt.datetime.now():%Y%m%d-%H%M%S}")
    p.write_text(json.dumps(data, indent=2, ensure_ascii=False) + "\n", encoding="utf-8")


def config(proyecto: Path) -> dict:
    return leer_json(proyecto / ".agents" / "prompts" / "kit.json", {})


def mcp_ia_dir(proyecto: Path, override: str | None = None) -> Path:
    if override:
        return Path(override).expanduser().resolve()
    c = config(proyecto)
    if c.get("mcp_ia_dir"):
        return Path(c["mcp_ia_dir"])
    if os.environ.get("MCP_IA_DIR"):
        return Path(os.environ["MCP_IA_DIR"])
    return Path.home() / "mcp-ia"


# ---------------------------------------------------------------------- instalar
def instalar(a) -> None:
    proyecto = raiz_git(Path(a.proyecto).expanduser().resolve())
    destino = proyecto / ".agents" / "prompts"
    destino.mkdir(parents=True, exist_ok=True)
    nombre = proyecto.name
    prefijo = a.prefijo.upper().rstrip("-")

    for f in ("REGLAS.md", "PLANTILLA_TAREA.md", "REVISION.md"):
        shutil.copy2(PLANTILLAS / f, destino / f)
    lecciones = destino / "LECCIONES_AGENTES.md"
    if lecciones.exists():
        print(f"  = {lecciones.name} ya existe: se conserva.")
    else:
        texto = (PLANTILLAS / "LECCIONES_AGENTES.md").read_text(encoding="utf-8")
        lecciones.write_text(texto.replace("{PREFIJO}", prefijo).replace("{PROYECTO}", nombre),
                             encoding="utf-8")
    shutil.copy2(AQUI / "kit_agentes.py", destino / "kit_agentes.py")
    for f in ("delegar.sh", "delegar.bat", "permisos_agy.sh", "permisos_agy.bat", "hooks.sh", "hooks.bat"):
        shutil.copy2(AQUI / "proyecto" / f, destino / f)
        if f.endswith(".sh"):
            os.chmod(destino / f, 0o755)

    escribir_json(destino / "kit.json", {
        "proyecto": nombre,
        "prefijo": prefijo,
        "carpetas_escritura": a.carpetas.split(),
        "mcp_ia_dir": str(mcp_ia_dir(proyecto, a.mcp_ia)),
    })

    gi = proyecto / ".gitignore"
    actual = gi.read_text(encoding="utf-8") if gi.exists() else ""
    faltan = [x for x in GITIGNORE if x not in actual]
    if faltan:
        with gi.open("a", encoding="utf-8") as f:
            f.write(("\n" if actual and not actual.endswith("\n") else "")
                    + "\n# Kit del jefe maestro: registros de lotes y configuración local\n"
                    + "\n".join(faltan) + "\n")

    seccion = (PLANTILLAS / "seccion_agents.md").read_text(encoding="utf-8").replace("{PREFIJO}", prefijo)
    for doc in ("AGENTS.md", "CLAUDE.md"):
        p = proyecto / doc
        if p.exists() and "Flujo de trabajo: jefe maestro" in p.read_text(encoding="utf-8"):
            break
    else:
        p = proyecto / "AGENTS.md"
        previo = p.read_text(encoding="utf-8") if p.exists() else f"# Instrucciones para agentes — {nombre}\n"
        p.write_text(previo.rstrip("\n") + "\n\n" + seccion, encoding="utf-8")
        claude = proyecto / "CLAUDE.md"
        if not claude.exists():
            claude.write_text("@AGENTS.md\n", encoding="utf-8")

    print(f"✓ Kit instalado en {destino}")
    print(f"  Prefijo de lecciones: {prefijo}-001…  Carpetas para el agente: {a.carpetas}")
    print("  Siguiente: `hooks` (pre-commit común), `mcp` (registrar la base) y `permisos` (Antigravity).")


# ------------------------------------------------------------------------- hooks
def fuente_hooks(proyecto: Path, override: str | None = None) -> Path:
    """Hooks comunes: los del kit si se ejecuta desde mcp-ia; si no, los de la base."""
    if (AQUI / "hooks").is_dir() and not override:
        return AQUI / "hooks"
    return mcp_ia_dir(proyecto, override) / "kit-agentes" / "hooks"


def _sha(p: Path) -> str:
    return hashlib.sha256(p.read_bytes()).hexdigest() if p.is_file() else ""


def hooks(a) -> None:
    """Instala o actualiza los hooks comunes; con --compartir devuelve las mejoras a mcp-ia."""
    proyecto = raiz_git(Path(a.proyecto or ".").expanduser().resolve())
    fuente = fuente_hooks(proyecto, a.mcp_ia)
    if not fuente.is_dir():
        sys.exit(f"❌ No encuentro los hooks comunes en {fuente}. Ejecuta `mcp` o pasa --mcp-ia.")
    base = fuente.parent.parent
    if a.actualizar and (base / ".git").exists():
        subprocess.run(["git", "-C", str(base), "pull", "--ff-only", "-q"], check=False)
    destino = proyecto / ".githooks"
    registro_p = destino / "kit_hooks.json"
    registro = leer_json(registro_p, {})
    pendientes = []
    for f in HOOKS_COMUNES:
        src, dst = fuente / f, destino / f
        h_src, h_dst, h_reg = _sha(src), _sha(dst), registro.get(f, "")
        if a.compartir:
            if not h_dst or h_dst == h_src:
                print(f"  = {f}: sin cambios que compartir.")
            elif h_reg and h_src != h_reg and not a.forzar:
                pendientes.append(f)
                print(f"  ✗ {f}: el kit también cambió desde que lo instalaste. Integra a mano "
                      f"(diff {dst} {src}) o usa --forzar.")
            else:
                print(f"  ↑ {f}: se comparte con el kit." + (" (--ver: no se copia)" if a.ver else ""))
                if not a.ver:
                    shutil.copy2(dst, src)
                    registro[f] = h_dst
            continue
        if h_dst == h_src:
            print(f"  = {f}: al día.")
            registro[f] = h_src
        elif not h_dst or h_dst == h_reg or a.forzar:
            print(f"  ↓ {f}: " + ("se instala." if not h_dst else "se actualiza desde el kit.")
                  + (" (--ver: no se copia)" if a.ver else ""))
            if not a.ver:
                destino.mkdir(exist_ok=True)
                if h_dst and h_dst != h_reg:
                    shutil.copy2(dst, f"{dst}.bak-{dt.datetime.now():%Y%m%d-%H%M%S}")
                shutil.copy2(src, dst)
                os.chmod(dst, 0o755)
                registro[f] = h_src
        else:
            pendientes.append(f)
            print(f"  ✗ {f}: el proyecto tiene cambios propios. Compártelos con --compartir "
                  "o reemplázalos con --forzar (guarda copia .bak).")
    if a.ver:
        return
    escribir_json(registro_p, registro)
    if a.compartir:
        print(f"\nSiguiente: revisa `git -C {base} diff`, haz commit y push de mcp-ia; los demás "
              "proyectos reciben la mejora con `hooks --actualizar`.")
        return
    subprocess.run(["git", "-C", str(proyecto), "config", "core.hooksPath", ".githooks"], check=False)
    ga = proyecto / ".gitattributes"
    actual = ga.read_text(encoding="utf-8") if ga.exists() else ""
    if ".githooks/** text eol=lf" not in actual:
        with ga.open("a", encoding="utf-8") as fh:
            fh.write(("\n" if actual and not actual.endswith("\n") else "")
                     + "# Hooks del kit: siempre con saltos LF (Git Bash en Windows)\n.githooks/** text eol=lf\n")
    print(f"✓ Hooks en {destino} (core.hooksPath = .githooks).")
    print("  Reglas propias del proyecto: .githooks/pre-commit.local, pre-push.local y obligatorio.sh.")
    if pendientes:
        print(f"  Pendientes: {', '.join(pendientes)}.")


# ---------------------------------------------------------------------- permisos
def permisos(a) -> None:
    proyecto = raiz_git(Path(a.proyecto or ".").expanduser().resolve())
    c = config(proyecto)
    carpetas = c.get("carpetas_escritura") or ["lib", "test", "docs"]
    if not AGY_SETTINGS.exists():
        sys.exit(f"❌ No existe {AGY_SETTINGS}. Abre Antigravity una vez para que lo cree.")
    data = leer_json(AGY_SETTINGS, {})
    ws = data.setdefault("trustedWorkspaces", [])
    allow = data.setdefault("permissions", {}).setdefault("allow", [])
    raiz = proyecto.as_posix()
    nuevas = [] if raiz in ws else [("trustedWorkspaces", raiz)]
    reglas = [f"write_file({raiz}/{x})" for x in carpetas] + [f"command({x})" for x in COMANDOS_AGY] + [f"mcp({m})" for m in HERRAMIENTAS_MCP_AGY]
    nuevas += [("permissions.allow", r) for r in reglas if r not in allow]
    print(f"Proyecto: {raiz}")
    if not nuevas:
        print("✓ Antigravity ya tiene todos los permisos de este proyecto.")
        return
    for donde, valor in nuevas:
        print(f"  + {donde}: {valor}")
    if a.ver:
        print(f"(--ver) No se cambió nada. Sin --ver se agregan {len(nuevas)} entradas.")
        return
    for donde, valor in nuevas:
        (ws if donde == "trustedWorkspaces" else allow).append(valor)
    escribir_json(AGY_SETTINGS, data, respaldo=True)
    print(f"✓ Se agregaron {len(nuevas)} entradas (copia de seguridad junto a {AGY_SETTINGS.name}).")


# --------------------------------------------------------------------------- mcp
def mcp(a) -> None:
    proyecto = raiz_git(Path(a.proyecto or ".").expanduser().resolve())
    base = mcp_ia_dir(proyecto, a.mcp_ia)
    if not (base / "scripts" / "mcp_server.py").exists():
        print(f"▶ Clonando mcp-ia en {base}…")
        r = subprocess.run(["git", "clone", REPO_MCP_IA, str(base)])
        if r.returncode != 0:
            sys.exit("❌ No se pudo clonar mcp-ia. Revisa la conexión o la ruta con --mcp-ia.")
    if not (base / "scripts" / "lecciones.py").exists():
        shutil.copy2(AQUI / "lecciones.py", base / "scripts" / "lecciones.py")
        print("  + lecciones.py copiado en mcp-ia/scripts")

    print("▶ Instalando dependencias e inicializando la base de mcp-ia…")
    subprocess.run([python_cmd(), str(base / "scripts" / "setup.py")], cwd=base)
    # Conocimiento compartido: el del repositorio y el que trae el kit (puede ser más nuevo).
    for compartido in (base / "data" / "sync" / "compartido.json", AQUI / "compartido.json"):
        if compartido.exists():
            subprocess.run([python_cmd(), str(base / "scripts" / "sync.py"), "bajar", str(compartido)], cwd=base)

    servidor = {"command": python_cmd(), "args": [(base / "scripts" / "mcp_server.py").as_posix()]}
    # Claude Code: .mcp.json del proyecto y habilitarlo sin preguntar.
    mcpj = leer_json(proyecto / ".mcp.json", {})
    mcpj.setdefault("mcpServers", {})["mcp-ia"] = servidor
    escribir_json(proyecto / ".mcp.json", mcpj)
    sl = proyecto / ".claude" / "settings.local.json"
    s = leer_json(sl, {})
    allow = s.setdefault("permissions", {}).setdefault("allow", [])
    for r in ("Bash(sh .agents/prompts/delegar.sh:*)", "Bash(flutter analyze *)", "Bash(dart format *)"):
        if r not in allow:
            allow.append(r)
    en = s.setdefault("enabledMcpjsonServers", [])
    if "mcp-ia" not in en:
        en.append("mcp-ia")
    escribir_json(sl, s)
    # Antigravity: configuración global de MCP.
    g = leer_json(AGY_MCP, {})
    g.setdefault("mcpServers", {})["mcp-ia"] = servidor
    escribir_json(AGY_MCP, g, respaldo=AGY_MCP.exists())

    c = config(proyecto)
    if c:
        c["mcp_ia_dir"] = str(base)
        escribir_json(proyecto / ".agents" / "prompts" / "kit.json", c)
    print(f"✓ mcp-ia registrado en {proyecto / '.mcp.json'} y en {AGY_MCP}.")
    print("  Claude Code lo carga en la próxima sesión del proyecto.")


# ---------------------------------------------------------------------- delegar
def _snapshot(raiz: Path) -> dict[str, str]:
    r = subprocess.run(["git", "status", "--porcelain", "--untracked-files=all"], cwd=raiz,
                       capture_output=True, text=True)
    out = {}
    for linea in r.stdout.splitlines():
        f = linea[3:].strip().strip('"')
        if f.startswith(".agents/prompts/lotes/"):
            continue
        p = raiz / f
        out[f] = hashlib.sha1(p.read_bytes()).hexdigest() if p.is_file() else "borrado"
    return out


def _agente(nombre: str) -> str:
    exe = shutil.which(nombre)
    if not exe:
        sys.exit(f"❌ No se encontró `{nombre}` en el PATH.")
    return exe


def _ejecutar(agente: str, prompt: str, log: Path | None = None, timeout_agy: str = "30m") -> int:
    if agente == "agy":
        cmd = [_agente("agy"), "-p", prompt, "--print-timeout", os.environ.get("AGY_TIMEOUT", timeout_agy)]
        cmd += os.environ.get("AGY_FLAGS", "").split()
    elif agente == "opencode":
        cmd = [_agente("opencode"), "run"] + os.environ.get("OPENCODE_FLAGS", "").split() + [prompt]
    else:
        sys.exit("❌ Agente no soportado: usa agy u opencode.")
    if log is None:
        r = subprocess.run(cmd, capture_output=True, text=True, encoding="utf-8", errors="replace")
        return 0 if ("OK" in (r.stdout + r.stderr) and "authentication required" not in r.stdout.lower()) else 2
    with log.open("w", encoding="utf-8") as f:
        return subprocess.run(cmd, stdout=f, stderr=subprocess.STDOUT).returncode


def delegar(a) -> None:
    raiz = raiz_git(Path.cwd())
    d = raiz / ".agents" / "prompts"
    tarea = Path(a.tarea).resolve()
    if not tarea.exists():
        sys.exit(f"Uso: delegar <agy|opencode> <tarea.md> [nombre]  (no existe {a.tarea})")
    c = config(raiz)

    if not a.solo_prompt:
        print(f"▶ Comprobando que {a.agente} responde…")
        if _ejecutar(a.agente, "Responde solo con la palabra: OK") != 0:
            print(f"❌ {a.agente} no responde o no tiene sesión. Inicia sesión y vuelve a lanzar.")
            sys.exit(2)

    out = d / "lotes" / f"{dt.datetime.now():%Y%m%d-%H%M}-{a.nombre}"
    out.mkdir(parents=True, exist_ok=True)
    head_antes = subprocess.run(["git", "rev-parse", "HEAD"], cwd=raiz, capture_output=True, text=True).stdout.strip()
    antes = _snapshot(raiz)

    # Lecciones: se guardan las del proyecto en mcp-ia y se traen las de otros.
    comunes = ""
    lpy = mcp_ia_dir(raiz) / "scripts" / "lecciones.py"
    if lpy.exists():
        subprocess.run([python_cmd(), str(lpy), "importar", str(d / "LECCIONES_AGENTES.md"),
                        "--proyecto", c.get("proyecto", raiz.name)], capture_output=True)
        r = subprocess.run([python_cmd(), str(lpy), "exportar", "--excluir-de", str(d / "LECCIONES_AGENTES.md")],
                           capture_output=True, text=True, encoding="utf-8")
        comunes = r.stdout.strip()
    else:
        print(f"⚠️  No se encontró mcp-ia ({lpy.parent.parent}): el lote va sin las lecciones comunes.")

    partes = [(d / "REGLAS.md").read_text(encoding="utf-8"),
              (d / "LECCIONES_AGENTES.md").read_text(encoding="utf-8")]
    if comunes:
        partes.append(comunes)
    partes.append(tarea.read_text(encoding="utf-8"))
    prompt = "\n\n".join(partes)
    (out / "prompt.md").write_text(prompt, encoding="utf-8")

    if a.solo_prompt:
        print(f"✓ Prompt armado sin lanzar el agente: {out / 'prompt.md'} ({len(prompt)} caracteres).")
        return

    if ES_WINDOWS or len(prompt) > LIMITE_PROMPT:
        rel = (out / "prompt.md").relative_to(raiz).as_posix()
        prompt = (f"Lee completo el archivo `{rel}` (en la raíz de este proyecto) y cumple sus "
                  "instrucciones al pie de la letra: reglas, lecciones y tarea. Al terminar, entrega "
                  "el informe final con el formato que pide ese archivo.")

    print(f"▶ Ejecutando el lote en {a.agente} (salida en {out / 'salida.log'})…")
    estado = _ejecutar(a.agente, prompt, out / "salida.log")
    despues = _snapshot(raiz)
    cambios = sorted(f for f, h in despues.items() if antes.get(f) != h)
    (out / "cambios.txt").write_text("\n".join(cambios) + ("\n" if cambios else ""), encoding="utf-8")
    with (out / "cambios.patch").open("w", encoding="utf-8") as patch:
        for f in cambios:
            r = subprocess.run(["git", "diff", "--", f], cwd=raiz, capture_output=True, text=True,
                               encoding="utf-8", errors="replace")
            patch.write(r.stdout)

    print(f"\n━━━━━━━━ Resumen del lote ({out}) ━━━━━━━━")
    print(f"Archivos tocados por el agente: {len(cambios)}")
    for f in cambios:
        print(f"  • {f}")
    head_despues = subprocess.run(["git", "rev-parse", "HEAD"], cwd=raiz, capture_output=True, text=True).stdout.strip()
    if head_antes != head_despues:
        print("❌ El agente hizo commits. Prohibido por REGLAS.md.")
        sys.exit(3)
    if estado != 0:
        print(f"❌ {a.agente} terminó con código {estado}. Revisa salida.log.")
        sys.exit(4)
    if "auto-denied" in (out / "salida.log").read_text(encoding="utf-8", errors="replace"):
        print(f"❌ {a.agente} se detuvo por un permiso negado. Revisa salida.log y ejecuta `permisos`.")
        sys.exit(4)
    print("✓ Lote ejecutado. Siguiente paso: revisarlo con REVISION.md.")


# --------------------------------------------------------------------- verificar
def verificar(a) -> None:
    proyecto = raiz_git(Path(a.proyecto or ".").expanduser().resolve())
    d = proyecto / ".agents" / "prompts"
    ok = True

    def check(cond: bool, texto: str) -> None:
        nonlocal ok
        ok &= cond
        print(("  ✓ " if cond else "  ✗ ") + texto)

    print(f"Proyecto: {proyecto}")
    for f in ("REGLAS.md", "LECCIONES_AGENTES.md", "PLANTILLA_TAREA.md", "REVISION.md", "kit_agentes.py", "kit.json"):
        check((d / f).exists(), f".agents/prompts/{f}")
    base = mcp_ia_dir(proyecto)
    check((base / "scripts" / "mcp_server.py").exists(), f"mcp-ia en {base}")
    check((base / "scripts" / "lecciones.py").exists(), "mcp-ia/scripts/lecciones.py")
    check("mcp-ia" in leer_json(proyecto / ".mcp.json", {}).get("mcpServers", {}), ".mcp.json registra mcp-ia")
    agy = leer_json(AGY_SETTINGS, {}) if AGY_SETTINGS.exists() else {}
    check(proyecto.as_posix() in agy.get("trustedWorkspaces", []), "Antigravity confía en el proyecto")
    carpetas = config(proyecto).get("carpetas_escritura", []) if agy else []
    for x in carpetas:
        check(f"write_file({proyecto.as_posix()}/{x})" in agy.get("permissions", {}).get("allow", []),
              f"Antigravity puede escribir en {x}")
    fuente = fuente_hooks(proyecto)
    hp = subprocess.run(["git", "-C", str(proyecto), "config", "core.hooksPath"],
                        capture_output=True, text=True).stdout.strip()
    check(hp == ".githooks", "git usa .githooks (core.hooksPath)")
    for f in HOOKS_COMUNES:
        check(_sha(proyecto / ".githooks" / f) == _sha(fuente / f) != "",
              f".githooks/{f} igual al del kit (si no: `hooks --actualizar` o `hooks --compartir`)")
    for exe in ("git", "agy", "opencode"):
        check(shutil.which(exe) is not None, f"`{exe}` disponible en el PATH" + ("" if exe != "opencode" else " (opcional)"))
    print("✓ Todo listo." if ok else "Hay puntos pendientes (✗).")


# -------------------------------------------------------------------------- main
def main() -> None:
    p = argparse.ArgumentParser(description="Kit del jefe maestro para agentes delegados.")
    sub = p.add_subparsers(dest="cmd", required=True)
    i = sub.add_parser("instalar")
    i.add_argument("proyecto")
    i.add_argument("--prefijo", required=True, help="Prefijo de las lecciones del proyecto (p. ej. RK).")
    i.add_argument("--carpetas", default="lib test docs", help="Carpetas donde el agente puede escribir.")
    i.add_argument("--mcp-ia", default=None, help="Ruta de mcp-ia (por defecto ~/mcp-ia).")
    pe = sub.add_parser("permisos")
    pe.add_argument("proyecto", nargs="?")
    pe.add_argument("--ver", action="store_true")
    m = sub.add_parser("mcp")
    m.add_argument("proyecto", nargs="?")
    m.add_argument("--mcp-ia", default=None)
    de = sub.add_parser("delegar")
    de.add_argument("agente", choices=["agy", "opencode"])
    de.add_argument("tarea")
    de.add_argument("nombre", nargs="?", default="lote")
    de.add_argument("--solo-prompt", action="store_true", help="Arma el prompt sin lanzar el agente.")
    h = sub.add_parser("hooks", help="Instala/actualiza el pre-commit común o comparte sus mejoras.")
    h.add_argument("proyecto", nargs="?")
    h.add_argument("--compartir", action="store_true", help="Copia al kit las mejoras del proyecto.")
    h.add_argument("--actualizar", action="store_true", help="Hace git pull de mcp-ia antes de instalar.")
    h.add_argument("--forzar", action="store_true", help="Reemplaza aunque haya cambios propios (con copia .bak).")
    h.add_argument("--ver", action="store_true", help="Solo muestra lo que haría.")
    h.add_argument("--mcp-ia", default=None)
    v = sub.add_parser("verificar")
    v.add_argument("proyecto", nargs="?")
    a = p.parse_args()
    {"instalar": instalar, "permisos": permisos, "mcp": mcp, "delegar": delegar, "hooks": hooks,
     "verificar": verificar}[a.cmd](a)


if __name__ == "__main__":
    main()
