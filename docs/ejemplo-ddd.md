# 🏗️ Estructura para Aprender Nuevos Patrones (Ejemplo DDD)

El sistema de base de datos de `mcp-ia` no está limitado a almacenar simples mensajes de error. Tiene la capacidad completa de actuar como un repositorio local de **arquitectura, buenas prácticas de desarrollo y plantillas de código complejo**, como **DDD (Domain-Driven Design / Diseño Guiado por el Dominio)**.

Esta página explica cómo estructurar estas plantillas para que el Agente IA pueda "aprenderlas" y reutilizarlas con la máxima fidelidad.

---

## 📋 La Estructura del Conocimiento

Para que una plantilla de arquitectura como DDD sea fácil de buscar y asimilar por la IA, debe estructurarse en los campos de la base de datos de la siguiente manera:

* **Título (`titulo`):** Debe ser conciso e indicar claramente el patrón o la arquitectura (ej: *"Estructura Base de Arquitectura DDD"*).
* **Problema / Contexto (`problema`):** Describe la situación o la pregunta clave que disparará esta plantilla. Debe incluir palabras clave que tú o la IA usarían para solicitarla (ej: *"Cómo organizar las carpetas, capas y clases en un proyecto Flutter con arquitectura DDD"*).
* **Solución (`solucion`):** El núcleo de la plantilla. Debe contener:
  1. El diagrama del árbol de directorios.
  2. Los principios fundamentales de cada capa (Dominio, Datos, Presentación).
  3. Código de ejemplo real en Dart para cada componente.
* **Tags (`tags`):** Etiquetas clave para filtrado rápido, tales como `ddd`, `arquitectura`, `clean-architecture`, `domain-driven-design`.
* **Categoría (`categoria`):** En este caso, el slug `widgets` o `compilacion` es adecuado, o puedes omitirlo.

---

## 📝 Caso Práctico: Ejemplo de Solución DDD

A continuación se muestra el formato exacto de los datos para registrar la arquitectura DDD en la base de datos local:

### 1. Metadatos
* **Título:** `Guía de Arquitectura DDD para Proyectos en Flutter`
* **Problema:** `Cómo estructurar un proyecto Flutter usando Domain-Driven Design (DDD) y Clean Architecture`
* **Categoría:** `widgets`
* **Tags:** `ddd`, `arquitectura`, `clean-architecture`, `boilerplate`

### 2. Contenido de la Solución (Markdown)
Este texto se guarda dentro de la columna `solucion` de la base de datos:

````markdown
Estructura de capas recomendada para DDD en Flutter:

lib/
├── main.dart
└── src/
    ├── domain/                   # Capa del Dominio (Pura en Dart, sin dependencias)
    │   ├── entities/             # Objetos de negocio con identidad única
    │   ├── value_objects/        # Objetos sin identidad, definidos por sus atributos
    │   ├── failures/             # Excepciones y fallos de negocio
    │   └── repositories/         # Contratos/Interfaces de repositorios
    ├── infrastructure/           # Capa de Infraestructura (Implementaciones)
    │   ├── datasources/          # Clientes HTTP, base de datos local (Hive, SQLite)
    │   ├── models/               # Data Transfer Objects (DTOs) con toJSON/fromJSON
    │   └── repositories/         # Implementación de los repositorios del dominio
    └── presentation/             # Capa de Presentación (UI y Estado)
        ├── state/                # Gestión de estado (BLoC, Riverpod o Provider)
        ├── pages/                # Pantallas completas
        └── widgets/              # Widgets reutilizables pequeños

Ejemplo de código base:

1. Entidad (domain/entities/user.dart):
class User {
  final String id;
  final String email;
  User({required this.id, required this.email});
}

2. Interfaz de Repositorio (domain/repositories/i_user_repository.dart):
abstract class IUserRepository {
  Future<Either<Failure, User>> getUserById(String id);
}

3. Caso de Uso (domain/use_cases/get_user.dart):
class GetUser {
  final IUserRepository repository;
  GetUser(this.repository);

  Future<Either<Failure, User>> execute(String id) {
    return repository.getUserById(id);
  }
}
````

---

## 🛠️ Cómo registrar esta plantilla mediante el CLI

Para guardar esta plantilla de DDD en tu base de datos local de inmediato, ejecuta el siguiente comando en tu terminal (asegúrate de escapar las comillas dobles internas si usas PowerShell):

```powershell
fm agregar "Guia de Arquitectura DDD para Flutter" "Como estructurar un proyecto Flutter usando Domain-Driven Design DDD" "Estructura de capas recomendada en DDD: domain/ (entities, value_objects, repositories), infrastructure/ (datasources, models, repository impl), presentation/ (widgets, state). Ejemplo Entidad: class User { final String id; final String email; User({required this.id, required this.email}); }" --tag ddd --tag arquitectura --tag clean-architecture --cat widgets
```

Una vez ejecutado, la IA podrá extraer este conocimiento y replicar esta estructura exacta cada vez que le pidas crear un módulo DDD en tu código.
