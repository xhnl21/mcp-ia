#!/usr/bin/env python3
"""Ayudante para probar una app Android en un teléfono real por adb (solo biblioteca estándar).

    PKG=com.mi.app python3 ui.py estado | abrir | list | tap <texto> [n] | xy X Y
                                | text <texto> | key <KEYCODE> | swipe X1 Y1 X2 Y2 [ms]
                                | shot <nombre> | foco | --autotest

Entorno:
  PKG          paquete de la app bajo prueba (obligatorio para abrir/tap/xy/text/key/swipe).
  ADB_SERIAL   teléfono a usar. Si no se define y hay uno solo, lo usa; con varios (p. ej. emulador
               y teléfono) aborta y los lista, para no tocar el equivocado.
  ALLOW        paquetes extra permitidos en primer plano, separados por coma.
  UI_OUT       carpeta de las capturas (por defecto, la temporal del sistema).

Seguridad: antes de cualquier toque comprueba que el teléfono esté encendido, sin bloqueo de
pantalla y que en primer plano esté PKG (o un diálogo del sistema de la lista). Si no, aborta
sin tocar nada: nunca desbloquea el teléfono ni actúa sobre otra app.
"""
import html
import os
import re
import shlex
import shutil
import subprocess
import sys
import tempfile

PKG = os.environ.get("PKG", "")
SISTEMA = ("permissioncontroller", "documentsui", "photopicker", "mediaprovider", "inputmethod",
           "googlequicksearchbox", "packageinstaller", "securitycenter")
PERMITIDOS = SISTEMA + tuple(p for p in os.environ.get("ALLOW", "").split(",") if p)
SALIDA = os.environ.get("UI_OUT", tempfile.gettempdir())


def salir(msg, codigo=1):
    print(msg)
    sys.exit(codigo)


def buscar_adb():
    candidatos = [shutil.which("adb")]
    for base in (os.environ.get("ANDROID_HOME"), os.environ.get("ANDROID_SDK_ROOT"),
                 os.path.expanduser("~/Library/Android/sdk"), os.path.expanduser("~/Android/Sdk"),
                 os.path.join(os.environ.get("LOCALAPPDATA", ""), "Android", "Sdk")):
        if base:
            candidatos.append(os.path.join(base, "platform-tools", "adb"))
    for c in candidatos:
        if c and os.path.exists(c):
            return c
    salir("No encuentro adb. Instala platform-tools o define ANDROID_HOME.")


ADB = buscar_adb()


def serial():
    s = os.environ.get("ADB_SERIAL") or os.environ.get("ANDROID_SERIAL")
    if s:
        return s
    sal = subprocess.run([ADB, "devices"], capture_output=True, text=True).stdout.splitlines()[1:]
    disp = [l.split()[0] for l in sal if l.strip().endswith("device")]
    if len(disp) == 1:
        return disp[0]
    salir(f"Define ADB_SERIAL: hay {len(disp)} dispositivos {disp}." if disp else "No hay teléfono conectado.")


def adb(*a, **k):
    return subprocess.run([ADB, "-s", serial(), *a], capture_output=True, **k)


def sh(*a):
    return adb("shell", *a).stdout.decode(errors="ignore")


def estado():
    """(encendido, bloqueado, paquete en primer plano)."""
    despierto = "mWakefulness=Awake" in sh("dumpsys", "power")
    ventanas = sh("dumpsys", "window")
    bloqueado = "isKeyguardShowing=true" in ventanas or "mDreamingLockscreen=true" in ventanas
    m = re.search(r"mCurrentFocus=Window\{[^}]*? ([\w.]+)/", ventanas)
    return despierto, bloqueado, (m.group(1) if m else "")


def guardia():
    if not PKG:
        salir("Define PKG con el paquete de la app bajo prueba.", 2)
    despierto, bloqueado, pkg = estado()
    if not despierto or bloqueado:
        salir("ABORTADO: el teléfono está apagado o bloqueado. Pídele a la persona que lo desbloquee.", 4)
    if PKG not in pkg and not any(p in pkg for p in PERMITIDOS):
        salir(f"ABORTADO: en primer plano hay «{pkg}», no {PKG}.", 3)


def texto_adb(t):
    """`input text` no admite espacios (%s) y el shell del teléfono interpreta # & ( ) ; etc.:
    se cita entero. Un % literal no se puede escribir así."""
    return shlex.quote(t.replace(" ", "%s"))


def nodos():
    """Nodos con texto o descripción: (texto, x, y, clicable). Falla si el volcado no se generó
    (un volcado viejo daría una pantalla que ya no existe)."""
    local = os.path.join(tempfile.gettempdir(), "ui_dump.xml")
    if os.path.exists(local):
        os.remove(local)
    sh("uiautomator", "dump", "/sdcard/ui_dump.xml")
    adb("pull", "/sdcard/ui_dump.xml", local)
    if not os.path.exists(local):
        salir("No se pudo leer la pantalla (uiautomator no generó el volcado).")
    x = open(local, encoding="utf-8").read()
    salida = []
    for m in re.finditer(r"<node ([^>]*)>", x):
        t = m.group(1)

        def g(k):
            r = re.search(k + r'="([^"]*)"', t)
            return r.group(1) if r else ""

        d = html.unescape(g("content-desc") or g("text")).replace("\n", " | ")
        b = re.search(r'bounds="\[(\d+),(\d+)\]\[(\d+),(\d+)\]"', t)
        if d and b:
            x1, y1, x2, y2 = map(int, b.groups())
            salida.append((d, (x1 + x2) // 2, (y1 + y2) // 2, g("clickable") == "true"))
    return salida


def autotest():
    assert texto_adb("a b") == "a%sb"
    assert texto_adb("##x y#") == "'##x%sy#'"
    assert texto_adb("o'k") == "'o'\"'\"'k'"
    print("autotest ok")


def main(a):
    if not a:
        salir(__doc__, 0)
    c = a[0]
    if c == "--autotest":
        return autotest()
    if c == "estado":
        d, b, p = estado()
        return print(f"encendido={d} bloqueado={b} primer_plano={p}")
    if c == "foco":
        return print(estado()[2])
    if c == "list":
        for d, x, y, k in nodos():
            print(f"{'*' if k else ' '} {d[:95]} ({x},{y})")
        return
    if c == "shot":
        ruta = os.path.join(SALIDA, f"{a[1]}.png")
        open(ruta, "wb").write(adb("exec-out", "screencap", "-p").stdout)
        return print(ruta)
    guardia()
    if c == "abrir":
        return sh("monkey", "-p", PKG, "-c", "android.intent.category.LAUNCHER", "1")
    if c == "tap":
        n = int(a[2]) if len(a) > 2 else 1
        hit = [v for v in nodos() if a[1].lower() in v[0].lower()]
        if len(hit) < n:
            salir(f"NO ENCONTRADO: {a[1]}", 1)
        d, x, y, _ = hit[n - 1]
        print(f"tap {d[:60]} ({x},{y})")
        sh("input", "tap", str(x), str(y))
    elif c == "xy":
        sh("input", "tap", a[1], a[2])
    elif c == "text":
        sh("input", "text", texto_adb(a[1]))
    elif c == "key":
        sh("input", "keyevent", a[1])
    elif c == "swipe":
        sh("input", "swipe", *a[1:5], a[5] if len(a) > 5 else "400")
    else:
        salir(f"Comando desconocido: {c}", 2)


if __name__ == "__main__":
    main(sys.argv[1:])
