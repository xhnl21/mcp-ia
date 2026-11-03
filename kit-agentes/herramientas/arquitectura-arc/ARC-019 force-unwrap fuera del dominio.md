# Prompt: bloquear en el pre-commit los force-unwrap nuevos

> **Cómo usarlo:** pegá este documento completo al agente de IA abierto en la raíz del proyecto. Sirve para cualquier lenguaje que tenga un operador para afirmar que un valor no es nulo. Se probó en Zas (Flutter/Dart) el 03/11/2026: allí es la regla ARC-019.

---

## 0. Rol y objetivo

Actúa como ingeniero de calidad del proyecto. Vas a agregar al pre-commit una regla que **bloquee los force-unwrap nuevos** en el código de la app, **sin frenar al equipo por los que ya existen**. Los que ya existen quedan anotados en una línea base: ese número solo puede bajar, a medida que se corrigen.

**Por qué:** un force-unwrap le asegura al compilador que un valor no es nulo, y el compilador no lo revisa. Si el dato llega nulo (por ejemplo, el backend no manda un campo), la app no usa un valor por defecto: tira una excepción. En Dart sale `Null check operator used on a null value`, con pantalla roja en debug y pantalla en blanco en release.

| Lenguaje | Operador que se bloquea | No confundir con |
| -------- | ----------------------- | ---------------- |
| Dart | `x!`, `x!.y`, `mapa['k']!`, `f()!`, `'${x!}'` | `!x` (negación), `!=`, `is!` |
| TypeScript | `x!`, `x!.y` (non-null assertion) | `!x`, `!=`, `!==` |
| Kotlin | `x!!` | `!x`, `!=` |
| Swift | `x!`, `try!`, `as!` | `!x`, `!=` |

Si el proyecto no usa ninguno de estos lenguajes (por ejemplo, JavaScript o Google Apps Script), **no hay operador que bloquear**: avisá a la persona y no hagas nada más.

---

## 1. Reglas estrictas

1. **Detectá con el árbol de sintaxis (AST), no con texto.** Una búsqueda con `grep` cuenta también los `!` dentro de cadenas y los `is!`. En Zas, grep daba 131 y el AST 122. Usá el analizador del lenguaje: `package:analyzer` en Dart, la API de `typescript` o `@typescript-eslint` en TypeScript, detekt o un `PsiElementVisitor` en Kotlin, SwiftSyntax o SwiftLint en Swift.
2. **No rompas el trabajo del equipo.** Los casos que ya existen van a la línea base, por archivo. La regla falla solo si aparece un archivo nuevo con casos o si un archivo sube su número.
3. **No relajes reglas que ya existen.** Si el proyecto ya prohíbe el operador en una capa (en Zas, ARC-005 en `lib/domain/`), la regla nueva cubre el resto, sin repetir lo que ya se reporta. No toques las excepciones, las líneas base de otras reglas ni las pruebas del detector para que algo pase.
4. **Nunca uses `--no-verify` ni `SKIP_*`** para hacer el commit de esta regla.
5. **Buscá antes de declarar.** En archivos grandes sin tipos, una función con el mismo nombre pisa a la anterior sin aviso. Antes de crear una función, hacé `grep -n "function nombre\|nombre("`.
6. Español, frases cortas. No escribas puntuaciones ni certificaciones («100 %», «10/10», «blindado»).

---

## 2. Pasos

### 2.1 Reconocer el proyecto

- Lenguaje, carpeta del código de la app (`lib/`, `src/`…) y si tiene capas (dominio, presentación, infraestructura).
- Qué hook de pre-commit existe (`.githooks/`, `.husky/`, `pre-commit`, `lefthook`…) y si ya corre un auditor de arquitectura o un linter.
- Si ya existe un mecanismo de línea base (un JSON de excepciones, un `baseline.xml` de detekt, un `--max-warnings`), **reutilizalo** en lugar de crear otro.

### 2.2 El detector

Agregá la regla al auditor o linter que ya corre en el pre-commit. Si no hay ninguno, creá un script chico junto a los demás scripts del proyecto.

**Referencia en Dart** (el `visitPostfixExpression` de un `RecursiveAstVisitor`, igual que en Zas):

```dart
@override
void visitPostfixExpression(PostfixExpression node) {
  if (node.operator.type == TokenType.BANG) {
    if (filePath.startsWith('lib/domain/')) {
      _addViolation('ARC-005', node.operator.offset, '...');  // regla previa, si existe
    } else if (filePath.startsWith('lib/')) {
      _addViolation(
        'ARC-019',
        node.operator.offset,
        'Operador force-unwrap (!) fuera del dominio. Use ?., ??, '
        'if (x case final v?) o una variable local promovida.',
      );
    }
  }
  super.visitPostfixExpression(node);
}
```

- Si el proyecto usa el auditor de referencia de este kit, agregá la regla a `activeRules` y a las reglas con línea base, como ARC-009, ARC-010 y ARC-018.
- Ponele un identificador que no choque con las reglas que ya existen (mirá cuál es el último número).
- El mensaje dice cómo se arregla, no solo qué está mal.

### 2.3 La línea base

- Guardá en la línea base el conteo por archivo de hoy: `{ "REGLA": { "ruta/archivo": N, ... } }`.
- La comprobación del pre-commit:
  - un archivo que no está en la línea base y tiene casos → **falla**;
  - un archivo que sube su número → **falla**;
  - un archivo que baja → avisa «baja la línea base de X a N» (o la regenera, si el proyecto ya lo hace así).
- Si el auditor tiene un comando para regenerar la línea base (en Zas, `--generar-linea-base`), comprobá que **nunca suba** un número que ya existe.

### 2.4 Pruebas del detector

Agregá al menos dos pruebas junto a las del auditor:

1. **Detecta:** `x!` y `json['k']!` (o sus equivalentes en el lenguaje) en dos capas distintas, con el conteo exacto.
2. **No se dispara:** en la capa que ya cubre otra regla, fuera de la carpeta de la app (por ejemplo, en `test/`), ni con `!x`, `!=`, `is!` o un `'¡Hola!'` dentro de una cadena.

### 2.5 Comprobar que bloquea de verdad

1. Agregá temporalmente `x!` (o el equivalente) en un archivo de la app que no tenga cambios.
2. Corré el auditor: tiene que fallar y nombrar la regla, el archivo y la línea.
3. Dejá el archivo exactamente como estaba. Comprobalo con `git diff --quiet <archivo>`.

### 2.6 Documentación

- En el archivo de instrucciones para agentes (`AGENTS.md`, `CLAUDE.md`…), agregá la regla a la lista de reglas obligatorias, con el operador prohibido y cómo se arregla.
- Si los comentarios de los hooks enumeran las reglas («ARC-001 a ARC-018»), actualizalos.
- Si algún documento promete «sin `!`» o da un número, corregilo con el conteo real del AST y la fecha.

### 2.7 Verificación y entrega

- Corré el auditor, el análisis estático y la suite completa de pruebas, y confirmá que pasan.
- Un solo commit con Conventional Commits: `feat(<ámbito>): <regla> blocks new force-unwraps outside <capa>`. Sin trailers de agentes. Usá la firma que pida el proyecto.
- Registrá en mcp-ia (`add_solution`) con el título `[<proyecto>] Force-unwrap sin barrera en el pre-commit`, el conteo inicial y el comando para regenerar la línea base.

---

## 3. Informe final (obligatorio)

Respondé con:

1. **Regla:** identificador, operador que bloquea y en qué carpetas.
2. **Conteo inicial:** total, archivos y reparto por capa (y, si lo medís, cuánto daba grep, para que se vea la diferencia).
3. **Archivos modificados:** con una línea por archivo.
4. **Prueba de bloqueo:** el mensaje del auditor con el `x!` temporal, y la confirmación de que el archivo quedó como estaba.
5. **Verificación:** la salida del auditor, del análisis y de la suite.
6. **Pendientes o bloqueos:** por ejemplo, un lenguaje sin analizador disponible, o un hook que no se pudo tocar.
