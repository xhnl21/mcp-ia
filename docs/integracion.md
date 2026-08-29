# Integración con el flujo de trabajo (IDE + terminal)

## Aliases / acceso rápido

El script `bin/fm.cmd` (o `fm.ps1`) permite usar `fm` desde cualquier consola.
Recomendado: añade `flutter-memory\bin` a tu PATH (hecho por `setup.py --path`).

**En `bash`/`zsh` (si usas WSL o Git Bash):**

```bash
alias fm='python "C:/Users/user/Desktop/autoaprendizaje/flutter-memory/scripts/fm.py"'
```

## VS Code / Antigravity

### Tareas de terminal (`.vscode/tasks.json`)

Añade al proyecto:

```json
{
  "version": "2.0.0",
  "tasks": [
    {
      "label": "fm: buscar error",
      "type": "shell",
      "command": "py C:/Users/user/Desktop/autoaprendizaje/flutter-memory/scripts/fm.py busca \"${input:query}\"",
      "presentation": { "panel": "dedicated" },
      "problemMatcher": []
    },
    {
      "label": "fm: agenda solución (aprende)",
      "type": "shell",
      "command": "py C:/Users/user/Desktop/autoaprendizaje/flutter-memory/scripts/learn.py \"${input:errorText}\" --auto-import",
      "presentation": { "panel": "dedicated" },
      "problemMatcher": []
    }
  ],
  "inputs": [
    { "id": "query", "type": "promptString", "description": "Texto del error a buscar" },
    { "id": "errorText", "type": "promptString", "description": "Texto del error nuevo (para registrar/auto-importar)" }
  ]
}
```

### Shortcut de teclado para buscar el texto seleccionado

Crea un snippet o una keybinding que mande el texto seleccionado al script.
Ejemplo de keybinding (`keybindings.json`):

```json
{
  "key": "ctrl+alt+m",
  "command": "workbench.action.terminal.sendSequence",
  "args": {
    "text": "fm busca \"${selectedText}\"\u000d"
  }
}
```

Así, seleccionas el error en el editor, pulsas `Ctrl+Alt+M` y busca en local
directamente desde la terminal integrada, sin abrir la IA.

## Notificación "solución local disponible"

Como el CLI busca en local ANTES de la IA, el simple hecho de que muestre
resultados YA es la notificación. Para automatizarlo con `learn.py`, al encontrar
solución local imprimirá: *"Se encontró una solución LOCAL (sin tokens)"*.

Para notificaciones del sistema (Windows), usa:

```powershell
# Al final del script aprendes y si hay resultado
FM_RESULT=$(fm busca "error") 
if ($LASTEXITCODE -eq 0) { "$FM_RESULT" | Out-Null; Write-Host "Solución local encontrada" }
```

## Script de captura automática en el terminal (opcional)

Para registrar cada error que lanzas manualmente a la IA sin pensar, puedes
envolver tus comandos con un función que llame a `learn.py`. Ejemplo PowerShell:

```powershell
function flm($err) {
  py C:/Users/user/Desktop/autoaprendizaje/flutter-memory/scripts/learn.py $err
}
```

Uso: `flm "MissingPluginException on channel"`.

## Backup automático (tarea programada)

Crea una tarea en el Programador de tareas de Windows que ejecute:

```powershell
py C:\Users\user\Desktop\autoaprendizaje\flutter-memory\scripts\backup.py
```

con frecuencia semanal. Guarda copias `export_*.json` y `flutter_memory_*.db`
en `data\backups\`.
