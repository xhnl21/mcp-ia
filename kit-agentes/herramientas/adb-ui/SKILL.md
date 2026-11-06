---
name: adb-ui
description: Prueba una app Android en un teléfono real por adb (leer la pantalla, tocar por texto, escribir, capturar) con una guardia que no toca nada si el teléfono está bloqueado o hay otra app en primer plano. Úsala cuando pidan «prueba en el teléfono», «prueba en el Redmi/Xiaomi», «prueba de UI en el dispositivo» o al verificar un cambio en un móvil conectado por USB. Incluye las trampas de MIUI (selector de archivos, instalación por USB, botón Atrás).
---

# adb-ui: probar una app en un teléfono real

> Fuente única: `mcp-ia/kit-agentes/herramientas/adb-ui/` (repo `github.com/xhnl21/mcp-ia`). Se instala en cada máquina con `sh kit-agentes/enlazar_compartido.sh`, que la enlaza en `~/.claude/skills/` y `~/.gemini/config/skills/`. Para mejorarla: edita en mcp-ia, prueba, commit y push.

Un solo archivo, solo biblioteca estándar de Python 3: `scripts/ui.py`. Probado con un Redmi Note 8 (Android 11, MIUI) y una app Flutter.

## Uso

```sh
export PKG=com.empresa.app            # paquete de la app bajo prueba
export ADB_SERIAL=170528a4            # obligatorio si hay más de un dispositivo (emulador + teléfono)
U=~/.claude/skills/adb-ui/scripts/ui.py

python3 $U estado          # encendido / bloqueado / app en primer plano
python3 $U abrir           # lanza la app
python3 $U list            # texto de cada elemento con sus coordenadas; * = clicable
python3 $U tap "Ingresar"  # toca por texto (tap "texto" 2 = la segunda coincidencia)
python3 $U xy 540 1250     # toca por coordenadas en píxeles reales
python3 $U text 'mi clave#1'   # escribe (espacios y # & ( ) ya van protegidos)
python3 $U key KEYCODE_ENTER
python3 $U swipe 540 1600 540 500 300
python3 $U shot pantalla1  # guarda UI_OUT/pantalla1.png; léelo con la herramienta Read
python3 $U --autotest      # comprueba el escapado de texto
```

## Reglas de seguridad (la guardia ya las cumple; tú también)

- **Antes de tocar nada**, `ui.py` verifica que el teléfono esté encendido, sin bloqueo y con `PKG` (o un diálogo del sistema) en primer plano. Si no, aborta sin tocar. **Nunca desbloquees el teléfono**: pídele a la persona que lo haga.
- La persona puede estar usando el teléfono (un video flotante, otra app). Si en primer plano hay otra cosa, para y avisa; no la cierres ni la uses.
- Datos de prueba, no reales: usa las credenciales demo del proyecto, nunca las de un cliente.
- **No abras ni describas imágenes personales.** Un selector de fotos abre en «Recientes» con la galería de la persona: no toques ninguna; busca el archivo de prueba por nombre o en la carpeta Descargas.

## Trampas conocidas (Xiaomi / MIUI y Flutter)

| Síntoma | Causa | Qué hacer |
|---|---|---|
| `adb install` → `INSTALL_FAILED_USER_RESTRICTED` o se cuelga sin error | MIUI exige confirmar en pantalla la instalación por USB y a veces no muestra el aviso | Activa «Instalar vía USB» en Opciones de desarrollador. Si sigue, `adb push app.apk /sdcard/Download/` y que la persona la instale desde Archivos |
| El selector de archivos no reacciona a `tap`, `xy` ni pulsación larga | El selector de MIUI (`documentsui`) ignora los toques inyectados | La persona toca el archivo (10 s). Todo lo demás de la prueba sí se automatiza |
| `key KEYCODE_BACK` saca de la app | Sin teclado abierto, Atrás cierra la actividad y vuelve al launcher | No lo uses para cerrar el teclado: toca una zona vacía o el botón ✓ del teclado |
| Un toque cae en vacío | El diseño se mueve al abrirse el teclado | Vuelve a leer con `list` o `shot` tras abrir el teclado y toca con las coordenadas nuevas |
| Las coordenadas de la captura no coinciden | La herramienta Read reduce la imagen (p. ej. 923×2000 de 1080×2340) | Multiplica por el factor que indica Read; `list` ya da píxeles reales |
| `list` muestra una pantalla que ya no existe | Un volcado viejo de uiautomator | `ui.py` borra el anterior y falla si no genera uno nuevo |
| Los campos de texto de Flutter salen sin nombre en `list` | Sin etiqueta semántica | Toca por coordenadas (`xy`) mirando la captura |
| Con varios dispositivos, adb actúa sobre el equivocado | Emulador + teléfono conectados | `ADB_SERIAL` siempre; `ui.py` aborta si falta |
| `timeout` no existe | macOS no lo trae | Lanza lo largo con `run_in_background` |

## Flujo recomendado

1. `estado`; si está bloqueado o con otra app, pregunta a la persona.
2. `abrir`, espera 3–5 s y `shot` para ver dónde cayó (puede haber un video de introducción).
3. Avanza con `list`/`tap` y confirma cada paso con `shot` antes del siguiente toque.
4. Si el paso requiere un código que llega a un correo (2FA), pídeselo a la persona.
5. Al terminar, deja la app en una pantalla estable y anota qué datos de prueba quedaron creados.
