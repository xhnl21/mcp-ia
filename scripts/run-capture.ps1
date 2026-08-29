# run-capture.ps1
# Envuelve un comando, captura su salida y detecta errores de Flutter/Dart
# para registrarlos en flutter-memory automáticamente.
#
# Uso:
#   powershell -File scripts\run-capture.ps1 -Command "flutter build apk"
#   powershell -File scripts\run-capture.ps1 -Command "dart analyze" -Search
param(
    [Parameter(Mandatory = $true)][string]$Command,
    [switch]$Search   # si se pasa, además busca solución local del error
)

$ErrorActionPreference = "Continue"
$scripts = Join-Path $PSScriptRoot "."
$learn = Join-Path $scripts "learn.py"
$fm    = Join-Path $scripts "fm.py"

Write-Host ">>> Ejecutando: $Command" -ForegroundColor Cyan
$output = & $Command 2>&1
$exitCode = $LASTEXITCODE
$output | ForEach-Object { Write-Host $_ }

# Detectar líneas de error típicas de Flutter/Dart
$errorPatterns = @(
    'Exception',
    'Error:',
    'error:',
    'FAILURE:',
    'Execution failed',
    'Can\'t be assigned',
    'No implementation found',
    "type '.*' is not a subtype"
)

$found = $output | Where-Object {
    $line = "$_"
    foreach ($p in $errorPatterns) { if ($line -match $p) { return $true } }
    return $false
}

if ($found) {
    Write-Host "`n[flutter-memory] Se detectaron posibles errores." -ForegroundColor Yellow
    $sample = ($found | Select-Object -First 1) -replace '[^\u0000-\u007F]|\[[0-9]+m|',''
    if ($Search) {
        Write-Host ">>> Buscando solución local..." -ForegroundColor Cyan
        & py $fm busca $sample 2>&1 | ForEach-Object { Write-Host $_ }
    } else {
        Write-Host ">>> Registrando patrón del error..." -ForegroundColor Cyan
        & py $learn $sample 2>&1 | ForEach-Object { Write-Host $_ }
    }
} else {
    Write-Host "`n[flutter-memory] Sin errores detectados." -ForegroundColor Green
}

exit $exitCode
