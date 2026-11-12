# ddd-contextos: desacoplar pantallas de un servicio gigante hacia DDD

Para proyectos Flutter donde cubits y pantallas hablan directo con una clase enorme (en `estilo_neutral`: `SheetsDataService`, ~8000 líneas, 120 archivos). Genera por **contexto** (un grupo de módulos de presentación) la cadena que exigen las reglas ARC-001 y ARC-022 a ARC-026:

```
pantalla/cubit → XCasos (application) → XRepository (domain) → XRepositoryImpl (infrastructure) → servicio
```

Los casos son **pasarelas** con los mismos nombres de miembros que ya usaba cada archivo: desacoplan la presentación, pero la lógica sigue donde estaba. Mover la lógica a casos de uso con nombre propio es un paso aparte (ver `docs/migracion-ddd.md` de `estilo_neutral`).

## Uso

1. Copia `config.ejemplo.json` a `tool/ddd_contextos.json` del proyecto y ajústalo (paquete, clase del servicio y sus archivos, contextos = carpetas de `presentation/cubits|screens|routes`).
2. Desde la raíz del proyecto: `python3 <mcp-ia>/kit-agentes/herramientas/ddd-contextos/generar_contextos.py tool/ddd_contextos.json`.
   - `--solo-generar` crea domain/application/infrastructure/locator sin tocar la presentación.
   - Copia `extraer_miembros.dart` a `tool/ddd_extraer.dart` y deja las firmas en `tool/ddd_firmas.json` (**no se borran**: sirven para regenerar).
3. `dart fix --apply --code=unused_import`, `flutter analyze`, `flutter test`, y regenerar la línea base ARC.

Requiere `analyzer` entre las dependencias del proyecto (lo trae el auditor ARC).

## Lo que no hace (se arregla a mano; salió así en estilo_neutral)

- Tipos y constantes estáticas que viven dentro del servicio (enum, excepciones, mensajes): moverlos a `domain` y declararlos en `simbolos_de_dominio`.
- Un widget compartido entre contextos (selector de fotos): una interfaz común que implementen ambos `XCasos`.
- Pasar un `XCasos` a una pantalla de otro contexto no compila: fusionar los contextos o armar el otro con `otroCasos(ServiceLocator().servicio)`.
- Barriles (`casos.dart`) para no subir los imports (ARC-010) y regenerar la línea base: el `dart format` del hook infla ARC-009 en archivos heredados.
- Referencia: mcp-ia, solución «[estilo_neutral] Desacoplar pantallas de un servicio gigante (SheetsDataService) hacia DDD…».

## Etapa A: partir el servicio gigante en archivos `part` (hecha en estilo_neutral)

1. `dart run tool/ddd_partir_servicio.dart <archivo.dart> <Clase> <carpeta/datos> --conservar=<miembros que sobrescriben las pruebas> [--aplicar]` (sin `--aplicar` imprime el plan por secciones `// ====`).
2. `python3 tool/ddd_calificar_estaticos.py <Clase>` (repetir hasta que no queden `unqualified_reference_to_static_member`).
3. `python3 tool/ddd_importar_extensiones.py <Clase> <ruta/clase.dart> <paquete>`: las extensiones solo se ven donde se importa la librería.
4. `notifyListeners()` en las extensiones: cambiar por un `_notificar()` de la clase (es `@protected`). Un helper de test que devuelva `dynamic` no ve extensiones: tiparlo.
5. `flutter analyze`, `flutter test`, regenerar la línea base.

## Etapa B (mitad): sacar el estado en memoria a un almacén

`python3 tool/ddd_extraer_almacen.py <clase.dart> <Almacen> <almacen.dart> [--aplicar]` mueve las `List<T> _x = …;` a una clase almacén y deja accesores privados `_x` con el mismo nombre (los métodos no cambian). Faltan los flags escalares y el gateway de red.

## Etapa C para «catálogos simples»: `ddd_catalogo_simple.py`

Genera, para un módulo con lista + activos + en uso + agregar/editar/estado/borrar, el repositorio (domain+infrastructure), los casos de uso con nombre, el locator y reescribe cubit y pantalla (la regla de duplicados sale de la pantalla a un caso `Existe…`). Config por módulo en `catalogos/*.json` (ejemplos: `tipos_documento`, `codigos_telefono`). Patrón completo hecho a mano: `metodos_pago` y `tasas` de estilo_neutral.
