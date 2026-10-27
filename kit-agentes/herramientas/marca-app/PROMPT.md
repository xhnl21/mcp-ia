# Prompt: ícono y splash con video para una app

> Para pegar en Antigravity, OpenCode u otro agente que no cargue skills de Claude Code. Completa los datos entre `< >`. En Claude Code basta con decir «crea el ícono y el splash con la skill marca-app».
>
> **Primera vez en una máquina:** clona `https://github.com/xhnl21/mcp-ia` y ejecuta `sh kit-agentes/herramientas/instalar.sh marca-app`. Eso deja la herramienta en `~/.claude/skills/marca-app/` (un enlace: `git pull` de mcp-ia la actualiza).

---

Crea el ícono y el splash con video de esta app usando las herramientas de `~/.claude/skills/marca-app/`. Lee primero `~/.claude/skills/marca-app/SKILL.md` y síguelo paso a paso.

**Datos de la marca:**
- App: `<Nombre de la app>`. Título del splash en dos colores: `<"Parte1" blanco, "Parte2" color de acento>`.
- Organización (escríbela exactamente así): `<FurionSytem>`.
- Frase corta del splash (opcional): `<Tus videos, a tu ritmo>`.
- Símbolo: `<carrete | monograma con las iniciales "XX" | imagen en assets/logo.png>`.
- Colores: deriva el degradado del color semilla del tema del proyecto. Fondo del splash: `<#081830 o un tono oscuro de la paleta>`.

**Pasos:**
1. Crea `marca.json` en la raíz del proyecto, a partir de `~/.claude/skills/marca-app/ejemplos/`.
2. Ejecuta `sh ~/.claude/skills/marca-app/scripts/marca.sh marca.json icono` y revisa `assets/branding/icono_vista_previa.png`. Después ejecuta `… cuadros 0.3,1.2,2.0,3.4`, revisa los PNG y, si todo está bien, `… video`.
3. Integra en Flutter con las plantillas de `~/.claude/skills/marca-app/plantillas/`:
   - `flutter_launcher_icons` ^0.14.4 y `flutter_native_splash` ^2.4.8 como dev_dependencies;
   - `dart run flutter_launcher_icons` y `dart run flutter_native_splash:create`;
   - los assets `splash.mp4` y `splash_primer_cuadro.png` en `pubspec.yaml`;
   - `SplashPage` como ruta inicial, que al terminar va a la pantalla principal.
4. Respeta las reglas del proyecto (`AGENTS.md`). Agrega una prueba de widget: si el video falla, el splash avanza una sola vez.
5. Comprobación (pega la salida en el informe):
   ```sh
   flutter analyze
   flutter test
   flutter build apk --debug --split-per-abi
   ```

**No hagas:**
- texto largo dentro del ícono;
- fuentes que no estén en `~/.claude/skills/marca-app/fonts/`;
- fundidos de entrada en el primer segundo del video;
- `setState` en páginas si el proyecto lo prohíbe;
- inventar los colores de la marca sin mirar el tema del proyecto.
