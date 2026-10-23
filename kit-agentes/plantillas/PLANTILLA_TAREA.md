# Lote <N>: <título corto>

> Lo escribe el jefe maestro (Claude). `delegar.sh` antepone `REGLAS.md` y `LECCIONES_AGENTES.md`, así que aquí va solo la tarea.

## Alcance

- **Puedes modificar:** <lista exacta de archivos o directorios>.
- **No toques:** <todo lo demás que esté cerca y pueda tentar>.

## Hechos verificados por el jefe maestro

- <Cada dato con su origen: archivo y línea, o el comando que lo comprueba.>

## Tarea 1. <qué hay que conseguir>

**Pasos:**
1. <Paso concreto, con el comando a ejecutar si aplica.>

**Comprobación (pega la salida en el informe):**
```sh
<un comando por línea, sin &&, ;, |, > ni comentarios # (regla 15); lo esperado va en el texto, no en un comentario>
```

## Verificación final

```sh
git status --short
git diff --stat
<comprobaciones propias del lote: flutter analyze, flutter test <archivos>>
```

## Informe final (formato obligatorio)

```
| Tarea | Estado (hecha / parcial / no hecha) | Archivos modificados | Comprobación ejecutada y su resultado |
```

Después de la tabla:
- **No verificado:** lo que no pudiste comprobar.
- **Fuera de alcance:** archivos que convendría cambiar y no tocaste.
- **Dudas para el jefe maestro.**
