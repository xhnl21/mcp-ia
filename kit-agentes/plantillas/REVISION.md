# Revisión de un lote (jefe maestro)

> La sigue el jefe maestro (Claude) después de cada `delegar` (`delegar.sh` en macOS/Linux, `delegar.bat` en Windows). Objetivo: aceptar solo lo que cumple la tarea y convertir cada error en una lección, para que el siguiente lote salga mejor.

## 1. Alarmas del lanzador

| Código de `delegar.sh` | Qué hacer |
|---|---|
| `2` sin sesión | Pedir al usuario que inicie sesión en el agente. No es un error del agente. |
| `3` hizo commits | Rechazar el lote. Deshacer con `git reset --soft <commit de partida>` y revisar los cambios igual. Registrar lección. |
| `4` terminó con error | Leer `salida.log`. Si es del agente (bucle, se detuvo), registrar lección; si es del entorno, corregirlo. |

## 2. Revisión del diff (`lotes/<lote>/cambios.txt` y `cambios.patch`)

Leer solo el diff y los archivos que toque, no el repositorio entero.

- [ ] **Alcance:** todos los archivos de `cambios.txt` están en la sección «Alcance» de la tarea.
- [ ] **Sin secretos:** `grep -nE "token|password|api[_-]?key|BEGIN .*KEY" cambios.patch` no muestra valores reales.
- [ ] **Sin inventos:** cada dato nuevo se puede comprobar con un comando (lección L-001). `grep -nE "^\+.*([0-9]+ ?%|10/10|cumple|certific)" cambios.patch` sin resultados.
- [ ] **Sin reformateo ajeno** (regla 14): el diff no cambia líneas que la tarea no pedía.
- [ ] **Sin código muerto** (regla 11, lección L-002): si el lote quita o cambia una función, ningún parámetro, callback ni campo queda solo declarado. Para cada archivo `.dart` tocado, lista los campos que solo aparecen en su declaración y en el constructor (`this.x`), es decir, que el propio archivo nunca lee:
  ```sh
  for f in $(grep '\.dart$' cambios.txt); do
    grep -E '^ *(late )?final .* [a-z][A-Za-z0-9]*;$' "$f" | grep -oE '[a-z][A-Za-z0-9]*;$' | tr -d ';' |
      while read -r n; do [ "$(grep -cw "$n" "$f")" -le 2 ] && echo "$f: $n"; done
  done
  ```
  Contar dentro del archivo, no en `lib/`: que otra pantalla lo siga pasando no significa que se use. Cada nombre listado se revisa a mano (en estados y modelos, los campos se leen desde fuera y es normal).
- [ ] **Cada tarea cumplida:** repetir su «Comprobación» y comparar con lo que dice el informe.
- [ ] **El informe dice la verdad:** las tareas marcadas «hecha» lo están; lo «no verificado» está anotado.

## 3. Verificación técnica (si el lote tocó código)

```sh
flutter analyze                                    # No issues found!
flutter test <pruebas de los archivos tocados>
```

Reglas de arquitectura de `AGENTS.md` (mientras no exista un script de auditoría):
```sh
grep -rn "setState(" lib/ --include=*.dart          # ninguno con lógica de negocio
grep -rnE "package:(provider|riverpod|flutter_riverpod|get)/" lib/   # sin resultados
grep -rn "package:flutter" lib/*/domain lib/domain 2>/dev/null       # el dominio no importa Flutter
```

## 4. Aprender del lote (obligatorio)

Por cada corrección que haga el jefe maestro:

1. **Nueva entrada en `LECCIONES_AGENTES.md`:** qué pasó, por qué está mal, qué hacer en su lugar y una comprobación con `grep` o `git` que lo detecte.
2. **Si la lección ya existía:** subir su contador «Veces».
3. **Con «Veces: 2»:** pasarla a regla en `REGLAS.md`, con su comprobación, y añadir esa comprobación a la sección 2 de este archivo.
4. **Si el error vino de un prompt ambiguo:** corregir `PLANTILLA_TAREA.md` o la forma de escribir los «Hechos verificados».
5. **Si una herramienta habría evitado el error** (un script de verificación, un linter, una librería): proponerla al usuario.

## 5. Cerrar el lote

- Corregir lo que falte y hacer los commits con la firma del usuario (`git commit -s`).
- Anotar en `lotes/<lote>/revision.md` el resultado: aceptado, corregido o rechazado, y las lecciones creadas.
