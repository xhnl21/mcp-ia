# Aviso del pre-commit: archivos `.md` con la codificación dañada

> Prompt para agregar un aviso (no bloqueante) al pre-commit de cualquier proyecto. Origen: proyecto zas (Zas! Payments), noviembre de 2026; el patrón está probado con texto dañado y con texto correcto.

## 0. Cómo usar este prompt

Eres un agente de código (Claude Code, Antigravity u OpenCode) trabajando **dentro de un proyecto Dart o Flutter**. Este documento es autocontenido: trae el motivo de la regla, su definición exacta, el código completo (ya probado), las pruebas, la integración en el pre-commit, la puesta en marcha y la verificación. No necesitas ningún otro archivo.

Reglas de trabajo, en este orden:

1. **Lee primero las instrucciones del proyecto** (`AGENTS.md`, `CLAUDE.md`, `.agents/rules/*`, `README.md`). Si alguna contradice este prompt, manda la del proyecto y lo informas al final.
2. **Trabaja solo en este proyecto.** No toques otros repositorios ni el kit compartido de mcp-ia.
3. **Consulta mcp-ia antes de resolver cualquier error** (`search_solutions` con el mensaje exacto, o `python3 <mcp-ia>/kit-agentes/compartido/mcpia.py "<error>"`). Lo que resuelvas y no esté, regístralo con `add_solution` en el momento (si eres un agente delegado sin acceso, descríbelo en el informe: error, causa y solución).
4. **Nunca uses `--no-verify` ni `SKIP_PRE_COMMIT=1`**, y nunca debilites una regla, su prueba o el hook para que algo pase.
5. **No hagas `git push`.** Los commits sí, con el formato del proyecto.
6. Antes de declarar una función, clase o constante nueva, **busca si el nombre ya existe** (`grep -rn "nombre" lib scripts test`). En Dart un nombre repetido en el mismo archivo no compila, pero en archivos distintos puede ocultar al otro por imports.
7. Cada dato de tu informe debe salir de un comando que ejecutaste. Lo que no pudiste comprobar va en «No verificado».

## 0.1 ¿Aplica a este proyecto? Qué puedes omitir

**Requisito:** ninguno: sirve en cualquier proyecto con un hook de pre-commit (Dart, Flutter, Apps Script, Python…).

**Puedes omitir, según el proyecto:**

- Proyecto **sin el kit de mcp-ia**: omite la sección 3.1 y usa la 3.2.
- Proyecto **con el kit**: omite la sección 3.2.
- Si el proyecto ya avisa o bloquea por codificación (otra herramienta, `.editorconfig` con verificación), no lo dupliques: informa y termina.
- Si no hay archivos dañados, omite la sección 5.

Todo lo que omitas, menciónalo en el informe con el motivo.

## 1. Contexto y motivo

Cuando un texto en UTF-8 se lee como Latin-1 (o Windows-1252) y se vuelve a guardar, las letras con tilde se convierten en pares raros: `é` → `Ã©`, `ó` → `Ã³` o `Ć³`, `¿` → `Ā¿`, comillas tipográficas → `â€œ`. En zas llegó así un informe de un agente («EjecuciĆ³n», «ĀæSe lograron»): se lee mal y, si se commitea, queda dañado en el historial. El aviso lo detecta al hacer commit, sin bloquear (puede haber archivos que documentan justamente estos caracteres).

## 2. Definición exacta

- **Ámbito:** archivos `*.md` del commit (staged).
- **Aviso** (no bloquea) si el archivo contiene alguna de estas secuencias: `Ã¡ Ã© Ã­ Ã³ Ãº Ã± Ã‘`, `Ć³ Ć­ Ć¡`, `Ā¿ Ā¡` o `â€`.
- **No cuenta:** texto correcto con tildes (`éxito`, `información`, `¿`).

## 3. Implementación

### 3.1 Con el kit de agentes de mcp-ia (`.githooks/pre-commit.local`)

Dentro del bucle que recorre los archivos del commit (o agrega uno si no existe; debe ir **antes** de cualquier salida temprana del tipo «no hay archivos Dart»):

````sh
for file in $STAGED_FILES; do
  [ -f "$file" ] || continue
  case "$file" in
    # Texto con la codificación dañada (UTF-8 leído como Latin-1): «Ã©», «Ć³»…
    *.md)
      if grep -qE 'Ã[¡©­³º±‘]|Ć[³­¡]|Ā[¿¡]|â€' "$file"; then
        echo "⚠️  $file parece tener la codificación dañada (Ã©, Ć³…). Guárdalo en UTF-8."
      fi
      ;;
  esac
done
````

### 3.2 Sin el kit

En el hook que use el proyecto, con la lista de archivos del commit: `git diff --cached --name-only --diff-filter=ACM`.

Guarda el hook **en UTF-8**: el patrón contiene caracteres no ASCII. Comprueba con `file .githooks/pre-commit.local` (debe decir «UTF-8 Unicode text»).

## 4. Verificación

````sh
sh -n .githooks/pre-commit.local && echo sintaxis-ok
printf 'texto Ã©xito\n' > /tmp/enc.md
grep -qE 'Ã[¡©­³º±‘]|Ć[³­¡]|Ā[¿¡]|â€' /tmp/enc.md && echo "detecta codificación dañada"
printf 'texto éxito, información, ¿sí?\n' > /tmp/enc.md
grep -qE 'Ã[¡©­³º±‘]|Ć[³­¡]|Ā[¿¡]|â€' /tmp/enc.md || echo "no confunde texto correcto"
rm /tmp/enc.md
````

Y la prueba real con el hook: crea `_probe.md` con `Ã©xito`, `git add _probe.md`, ejecuta el hook (`sh .githooks/pre-commit`): debe mostrar el aviso y terminar con `exit 0`. Después `git restore --staged _probe.md && rm _probe.md`.

## 5. Cómo se corrige un archivo dañado

- Si el daño es una sola pasada (UTF-8 leído como Latin-1): `python3 -c "import sys;p=sys.argv[1];t=open(p,encoding='utf-8').read();open(p,'w',encoding='utf-8').write(t.encode('latin-1').decode('utf-8'))" archivo.md`. Revisa el diff: si aparece un error de codificación o el resultado empeora, no era ese el caso; corrige a mano.
- Las variantes `Ć…`/`Ā…` vienen de otra codificación (por ejemplo, Latin-2): corrígelas a mano o regenera el archivo desde su fuente.

## 6. Commit e informe

- Commit: `chore(hooks): warn on .md files with broken encoding` (con `Sin-prueba: <motivo>` si el hook del proyecto lo pide para cambios de hook).
- Informe: dónde lo agregaste, salida de la verificación y de la prueba real, y «No verificado» si algo faltó.
