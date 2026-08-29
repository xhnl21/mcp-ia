# fm.ps1 — Acceso rápido al CLI flutter-memory en PowerShell.
# Añade esta carpeta bin/ a tu PATH para usar `fm` desde cualquier consola.
$FM_ROOT = Join-Path $PSScriptRoot ".."
$python = Get-Command python -ErrorAction SilentlyContinue
if (-not $python) { $python = Get-Command py -ErrorAction SilentlyContinue }
$pyProc = $python.Source
& $pyProc (Join-Path $FM_ROOT "scripts\fm.py") @args
exit $LASTEXITCODE
