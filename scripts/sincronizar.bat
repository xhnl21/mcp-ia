@echo off
REM ============================================================================
REM sincronizar.bat - une la base local de mcp-ia con la de las otras maquinas.
REM Mismo flujo que sincronizar.sh: fetch, importar el compartido.json de origin
REM y el de Google Drive (FM_DRIVE_ID), pull --ff-only, exportar la union y commit.
REM Despues: git push y subir compartido.json a Drive (reemplazar el archivo).
REM Los ids (#172...) son locales de cada maquina: cita las soluciones por titulo.
REM ============================================================================
setlocal
set PYTHONIOENCODING=utf-8
cd /d "%~dp0.."

set ARCHIVO=data/sync/compartido.json
set REMOTO=data/sync/_remoto.json
if "%FM_DRIVE_ID%"=="" (set DRIVE_ID=1728stc7O7fLAZ_N6FWBKsCvkapYIc1Hp) else (set DRIVE_ID=%FM_DRIVE_ID%)

for /f %%i in ('git status --porcelain -- %ARCHIVO%') do (
  echo ERROR: %ARCHIVO% tiene cambios sin commit. Haz commit o descartalos antes.
  exit /b 1
)

echo Descargando: git fetch...
git fetch -q origin || exit /b 1
for /f %%r in ('git rev-parse --abbrev-ref HEAD') do set RAMA=%%r

git cat-file -e origin/%RAMA%:%ARCHIVO% 2>nul
if not errorlevel 1 (
  git show origin/%RAMA%:%ARCHIVO% > %REMOTO%
  echo Importando el compartido.json remoto a la base local...
  py -3 scripts\sync.py bajar %REMOTO% || exit /b 1
  del %REMOTO%
)

echo Descargando la copia de Google Drive...
curl -fsSL -o %REMOTO% "https://drive.google.com/uc?export=download&id=%DRIVE_ID%"
if not errorlevel 1 (
  py -3 scripts\sync.py bajar %REMOTO%
) else (
  echo AVISO: no se pudo descargar la copia de Drive; se sigue sin ella.
)
if exist %REMOTO% del %REMOTO%

echo git pull --ff-only...
git pull -q --ff-only origin %RAMA%
if errorlevel 1 (
  echo ERROR: la rama local y origin divergieron. Resuelvelo con git pull y vuelve a ejecutar.
  exit /b 1
)

echo Exportando la union a %ARCHIVO%...
py -3 scripts\sync.py subir >nul || exit /b 1

git add %ARCHIVO%
git diff --cached --quiet -- %ARCHIVO%
if errorlevel 1 (
  git commit -q -s -m "chore(sync): compartir conocimiento" -- %ARCHIVO%
  echo Listo: commit hecho. Falta: git push
) else (
  echo Listo: sin cambios respecto de origin.
)
echo Si la copia de Drive tenia menos, sube %ARCHIVO% a Drive (reemplazar el archivo, id %DRIVE_ID%).
endlocal
