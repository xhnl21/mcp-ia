# Ejemplo: solución guardada en formato Markdown (universo híbrido)

Aunque el núcleo es SQLite, puedes conservar notas largas legibles en `knowledge/`.
El formato siguiente es el "formato optimizado" para búsqueda rápida y lectura.

---

```markdown
---
titulo: MissingPluginException: No implementation found for method
tags: [plugin, channel, test, sharedpreferences]
categoria: plataforma
fuente: manual
veces_resuelta: 0
---

## Problema

MissingPluginException: No implementation found for method getAllIcons on
channel plugins.flutter.io/shared_preferences (o cualquier plugin).

## Solución

1. `flutter clean`
2. `flutter pub get`
3. Cierra la app por completo (el hot reload NO registra plugins nativos).
4. En tests de unidad, inicializa el plugin:

```dart
SharedPreferences.setMockInitialValues({});
```

## Cuándo ocurre

- En puebas unitarias/widget tests donde se usa un plugin nativo sin mock.
- Tras agregar un plugin nuevo sin recompilar (hot reload).
```
