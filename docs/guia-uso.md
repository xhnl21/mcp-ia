# Guía práctica de flutter-memory

Ejemplos completos de uso real con Flutter/Dart.

---

## 1. Buscar un error común LOCALMENTE (sin tokens)

Muchos errores son recurrentes. Antes de preguntar a la IA, haz esto:

```powershell
fm busca "MissingPluginException"
```

Resultado (ordenado por relevancia + frecuencia):
```
=== [1.06] #1 — MissingPluginException: No implementation found for method
    Problema: MissingPluginException: No implementation found for method getAllIcons ...
    Solución: Ejecuta `flutter clean` y `flutter pub get`. ...
    (úsala con: fm usar 1)
```

Si la solución te funcionó, márcala como usada para que suba de ranking:

```powershell
fm usar 1
```

**Flujo recomendado en tu IDE:**
1. Copia el texto del error.
2. `fm busca "<copiar error>"`.
3. Si hay resultado → listo, **cero tokens**.
4. Si no → recién ahí pregunta a la IA y guarda el resultado.

---

## 2. Agregar una solución nueva (tras resolver con la IA)

Cuando la IA te dé una solución que funcionó, guárdala:

```powershell
fm agregar "TextoError" "Problema original" "La solución completa" --tag async --cat red --url https://...
```

Con comillas por cada argumento. Los `--tag` pueden repetirse:

```powershell
fm agregar "Argument type String? can't be assigned to String" `
           "null safety error" `
           "Usa `?? ''` o maneja el null" --tag null-safety --tag types
```

---

## 3. Importar soluciones desde Stack Overflow

Con internet:

```powershell
fm importar-so "flutter error MissingPluginException"
```

Importa las preguntas más relevantes como soluciones candidatas (con su URL).

También puedes importar issues cerrados de GitHub:

```powershell
fm importar-github "flutter/flutter"
fm importar-awesome     # catálogo curado de paquetes
fm importar-docs        # referencias a docs oficiales
```

---

## 4. Aprendizaje continuo automático

`learn.py` es el "capturador". Ideal para lanzarlo con un error nuevo:

```powershell
py flutter-memory\scripts\learn.py "First element must have a unique key" --auto-import
```

Comportamiento:
1. Busca primero en local → si hay solución, la muestra (sin tokens).
2. Si no hay → registra el **patrón de error** (para detectar recurrencia).
3. Con `--auto-import` además busca en Stack Overflow y guarda candidatas.

---

## 5. Reporte de errores frecuentes

```powershell
fm reporte
```

Muestra:
- Soluciones más usadas/resueltas (para saber qué te ahorra más tokens).
- Patrones de error recurrentes (para detectar problemas sistémicos).
- Tags más usados.

---

## 6. Exportar/Importar conocimiento (portabilidad y backup)

```powershell
fm exportar
fm importar "flutter-memory\data\backups\export.json"
```

---

## 7. Depuración de patrones

Si quieres que un patrón se detecte con su nombre exacto:

```powershell
# El patrón "MissingPluginException" ya está registrado con la solución #1.
# Para que learn.py lo detecte, el texto del error debe contener ese substring.
fm patrones "MissingPluginException on channel"
> Patrón: MissingPluginException (conteo 1)  solución_id: 1
```
