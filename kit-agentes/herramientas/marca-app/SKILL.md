---
name: marca-app
description: Crea el ícono de una app móvil (adaptativo de Android, con capa monocroma) y un splash con video animado (nativo + video de 3-4 s con el nombre de la app y de la organización), a partir de un marca.json. Úsala cuando pidan «crea el ícono», «splash», «pantalla de carga con video», «branding», «logo de la app» o al arrancar una app Flutter nueva. Scripts reproducibles con Pillow + imageio-ffmpeg, sin servicios de pago.
---

# marca-app: ícono y splash con video

> Fuente única: `mcp-ia/kit-agentes/herramientas/marca-app/` (repo `github.com/xhnl21/mcp-ia`). En cada máquina se instala con `sh kit-agentes/enlazar_compartido.sh`, que la enlaza en `~/.claude/skills/` (Claude Code) y `~/.gemini/config/skills/` (Antigravity). Para mejorarla: edita en mcp-ia, prueba, commit y push.

Genera la marca visual de una app desde un archivo `marca.json`, con scripts reproducibles. Probado en ReelKeeper (Flutter, Android): Redmi Note 8 (Android 11, MIUI) y Pixel 9 (Android 15).

```
~/.claude/skills/marca-app/
  scripts/marca.sh            lanzador: prepara ~/.cache/marca-app/venv y genera
  scripts/generar_icono.py    ícono adaptativo + logo del splash + vista previa
  scripts/generar_video_splash.py  splash.mp4 + primer cuadro
  scripts/marca.py            símbolos (carrete, walkie, monograma, imagen) y colores
  fonts/                      Montserrat (licencia OFL: se puede incluir en apps)
  plantillas/                 flutter_launcher_icons.yaml, flutter_native_splash.yaml, splash_page.dart
  ejemplos/                   reelkeeper.marca.json (carrete), sinredtalk.marca.json (walkie), monograma.marca.json
  PROMPT.md                   este mismo pedido, para pegar en otro agente
```

## 1. Reunir los datos (preguntar lo que no esté claro)

- **Nombre de la app** y cómo partir el título en dos colores (`"titulo": [["Reel","#FFFFFF"],["Keeper","#FFC107"]]`).
- **Organización, escrita exactamente** como la quiere el usuario. Si parece un error de tipeo, pregunta una vez y respeta la respuesta (la empresa de ReelKeeper y SinRed Talk es «FurionSystem»).
- **Colores:** lee el color semilla del tema (`ColorScheme.fromSeed`, `AppColors`…) y deriva el degradado de él. No inventes una paleta que choque con la app.
- **Frase** corta (opcional) y **símbolo:**
  - `carrete`: apps de video. Gira en el splash.
  - `walkie`: walkie-talkie con ondas de radio (apps de voz o radio). En el splash las ondas salen una tras otra y la antena parpadea.
  - `monograma`: iniciales en un círculo; sirve para cualquier app.
  - `imagen`: un PNG propio del proyecto (`"ruta": "assets/logo.png"`).
- **Nunca pongas texto largo en el ícono:** a 48 px no se lee. El nombre y la organización van en el splash.

## 2. Crear `marca.json` en la raíz del proyecto

Copia `ejemplos/reelkeeper.marca.json` o `ejemplos/monograma.marca.json` y ajústalo. Solo `app` y `organizacion` son obligatorios; el resto tiene valores por defecto. `salida` (por defecto `assets/branding`) es relativa a la carpeta de `marca.json`.

## 3. Generar y REVISAR visualmente

```bash
sh ~/.claude/skills/marca-app/scripts/marca.sh marca.json icono
# abre assets/branding/icono_vista_previa.png: máscaras de MIUI, círculo, squircle y 48 px
sh ~/.claude/skills/marca-app/scripts/marca.sh marca.json cuadros 0.3,1.2,2.0,3.4
# abre assets/branding/splash_cuadro_*.png (bórralos después; no se versionan)
sh ~/.claude/skills/marca-app/scripts/marca.sh marca.json video
```

Mira las imágenes antes de integrar. Si el símbolo se corta en la máscara circular, baja `icono.escala_frente` (0,70 → 0,64).

## 4. Integrar en Flutter

1. `flutter pub add -d "flutter_launcher_icons:^0.14.4" "flutter_native_splash:^2.4.8"` (sin versión, pub puede elegir versiones viejas sin capa monocroma) y `video_player` si no está.
2. Copia `plantillas/flutter_launcher_icons.yaml` y `plantillas/flutter_native_splash.yaml` a la raíz. Pon el `minSdk` real y `color` = `colores.fondo_splash`.
3. `dart run flutter_launcher_icons` y `dart run flutter_native_splash:create`.
4. En `pubspec.yaml` → `flutter: assets:` agrega `assets/branding/splash.mp4` y `assets/branding/splash_primer_cuadro.png`.
5. Copia `plantillas/splash_page.dart` a la capa de presentación del proyecto. Ajusta `background` y `onFinished` (con go_router, `context.go('/')`), y haz que sea la ruta inicial.
6. Respeta las reglas del proyecto: en ReelKeeper, nada de `setState` en páginas (la plantilla usa `ValueListenableBuilder`).
7. Prueba de widget: en `flutter test` no hay reproductor, `initialize()` falla y el splash debe avanzar **una sola vez**.

## 5. Verificar en un dispositivo (no solo en `flutter test`)

- Captura la secuencia con `adb exec-out screencap` en un bucle. **`screenrecord` en el emulador se congela** en el splash nativo y engaña.
- Comprueba tres cosas: el splash nativo muestra el símbolo, el video arranca **sin parpadeo** y, al terminar, pasa enseguida a la pantalla principal (no a los 6 s).
- MIUI: cada paquete **nuevo** pide confirmar «Instalar vía USB» en el teléfono.
- El APK de debug de apps con bibliotecas nativas grandes puede no caber en el emulador: usa `flutter build apk --debug --split-per-abi`.

## Trampas ya resueltas (no las repitas)

| Síntoma | Causa | Ya corregido en |
|---|---|---|
| Degradado con forma de rombo | Rotar una máscara lineal deja esquinas negras | `marca.degradado` (NumPy) |
| La cinta del carrete se corta | `flutter_launcher_icons` deja visible el 98 % del frente | `escala_frente` 0,70 |
| Parpadeo al empezar el video | El símbolo aparecía gradualmente y el reproductor tarda en cargar | El video empieza opaco y la página muestra `splash_primer_cuadro.png` mientras carga |
| El splash espera 6 s | El reproductor se detiene unos ms antes de `duration` | `isCompleted` o un margen de 150 ms |
| `'_' is already declared` en la plantilla | Comodines `_` repetidos exigen Dart 3.7 | La plantilla usa `(_, __, ___)` |
| `'decodeLazy' isn't defined for ZLibDecoder` | `image` nuevo con `archive` viejo en el proyecto | `flutter pub upgrade archive` |
| Fuente con licencia dudosa | Avenir y Helvetica son de Apple | Montserrat (OFL) en `fonts/` |

## Al terminar

- Versiona `marca.json`, `assets/branding/` (sin `splash_cuadro_*.png` ni `icono_vista_previa.png`), los yaml y los recursos que generan los paquetes en `android/app/src/main/res/`.
- Documenta la paleta y cómo regenerar (en ReelKeeper: `docs/ui-datos/marca.md`).
