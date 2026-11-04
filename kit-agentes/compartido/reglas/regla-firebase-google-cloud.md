# Firebase y Google Cloud: acceso, permisos y notificaciones

Vale para todos los proyectos que usan Firebase (FCM, App Distribution, Remote Config…).

## Herramientas y sesión

- **Firebase:** CLI `firebase` (sesión `firebase login:list`). Con `--project <id>` en cada comando; nunca supongas el proyecto activo.
- **Google Cloud (IAM, APIs, cuentas de servicio):** `gcloud`. Si no está instalado, pídele a la persona que lo instale y que inicie sesión ella misma (`brew install --cask google-cloud-sdk`, `gcloud auth login <cuenta>`, `gcloud config set project <id>`).
- **Prohibido** sacar tokens de `~/.config/configstore/firebase-tools.json` u otros archivos de credenciales para llamar APIs a mano. Si falta una herramienta, se instala; no se rodea.

## Qué se hace sin preguntar y qué no

- **Leer** (roles, APIs habilitadas, apps, configuración): sin preguntar.
- **Cambiar** (dar o quitar roles, habilitar APIs, publicar Remote Config, crear apps, desplegar): pregunta antes, uno por uno, y di el comando exacto.
- **Nunca** generes, descargues ni pegues en el chat claves privadas de cuentas de servicio (JSON). Las genera y entrega el dueño del backend por un canal seguro. Pide solo el `client_email`.
- No pulses ni sugieras «Generate new private key» sin necesidad: cada clave nueva queda válida hasta que alguien la borre.

## El backend no puede enviar notificaciones (FCM HTTP v1)

Revisa en este orden y pide primero el error exacto (código HTTP y `error.status`):

| Respuesta de FCM | Causa | Arreglo |
|---|---|---|
| `403 PERMISSION_DENIED` (`cloudmessaging.messages.create`) | A la cuenta de servicio le falta el rol | IAM → la cuenta → **Firebase Cloud Messaging API Admin** (`roles/firebasecloudmessaging.admin`) |
| `403 SERVICE_DISABLED` | API apagada | Habilitar `fcm.googleapis.com` |
| `401 UNAUTHENTICATED` | Server Key antigua o JSON de otro proyecto | Token OAuth desde el JSON de la cuenta de servicio del mismo `project_id` |
| `404 UNREGISTERED` / `400 SENDER_ID_MISMATCH` | Token del dispositivo inválido o de otro proyecto | Revisar que la app registre su token en el backend y que use el mismo proyecto |

- **Trampa conocida:** las cuentas `firebase-adminsdk-fbsvc@<proyecto>.iam.gserviceaccount.com` de proyectos nuevos solo traen los roles de los productos activados (p. ej. App Distribution y Remote Config). **No traen FCM**: hay que agregarlo a mano.
- En el buscador de roles de IAM elige **«Firebase Cloud Messaging API Admin»**; los «Viewer» solo leen y «Service Editor» no envía por la API.
- App Distribution no tiene relación con el envío de notificaciones.
- Prueba sin backend: Firebase → Messaging → *Enviar mensaje de prueba* con el token del log de la app (teléfono físico). Comprueba la app y FCM, no el permiso de la cuenta de servicio.
