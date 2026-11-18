# Regla de oro: toda API que use la app tiene su contrato

**Obligatoria en todos los proyectos que consumen una API (Flutter, web, servicios) y para todos los agentes. Se suma a la regla de oro de mcp-ia.**

Un contrato guarda la forma de la respuesta de una ruta (campos y tipos, no valores) y se compara con el backend real. Sin contrato, si el backend quita un campo o cambia un tipo en una API nueva, la app se rompe en silencio y se descubre en producción.

## Qué se exige

1. **Cada ruta HTTP o evento en tiempo real (WebSocket) que la app empiece a usar lleva su contrato en el mismo MR.** No vale «lo hago después».
2. **Se graba con la respuesta real** del ambiente de pruebas, con la cuenta de contratos del proyecto (credenciales fuera del repositorio). Nunca a mano, salvo un evento que no se pueda provocar: entonces se escribe con el ejemplo de backend y se marca su origen.
3. **Lo que crea datos se deshace:** si la ruta crea, registra o modifica algo, el contrato se graba y después se borra o revoca lo creado, para no dejar basura en la cuenta de contratos.
4. **Si la ruta necesita algo que solo tiene el teléfono** (una firma, un código), se genera en el script con una llave o un dato de prueba: el contrato no se omite por eso.
5. **Un contrato nunca se relaja para que pase** (un campo que falta, un `null` nuevo, otro tipo): eso es un cambio del backend y se le reporta.
6. **Lo comprueba un control automático** antes de subir (pre-push o CI): toda ruta agregada en el MR tiene que tener su contrato. La excepción (backend todavía no publicó la ruta) va con una variable explícita y se anota en el MR.

## Agentes delegados

No graban contratos (necesitan credenciales y el backend real). Anotan en su informe cada ruta nueva con método, base (API general o la del cliente), si lleva token y el cuerpo que envía. El jefe maestro la graba antes del commit.

## Referencia

Implementación en zas: `scripts/contrato_api.py` (newman), `scripts/contratos_api/rutas.json`, `scripts/check_rutas_con_contrato.dart` (pre-push) y `docs/devops/contratos_api.md`.
