# Lectura autenticada del catálogo

La función `catalog-read` consulta representaciones y las últimas corridas por edición. Requiere un JWT de usuario validado mediante Supabase Auth y que el UUID del usuario esté incluido en la lista configurada. El rol `catalog_viewer` accede a las dos tablas con políticas RLS de solo lectura. La función rechaza solicitudes de escritura y sesiones anónimas.

El panel Svelte admite un modo alojado con inicio de sesión por correo y contraseña. El modo local utiliza su propio servidor y permanece separado de esta función.

## Compilación del panel alojado

Definir antes de compilar `VITE_CATALOG_PANEL_MODE=hosted`, `VITE_CATALOG_SUPABASE_URL` con la URL del proyecto y `VITE_CATALOG_SUPABASE_PUBLISHABLE_KEY` con la clave `sb_publishable_` del mismo proyecto. Las variables `VITE_` se incorporan a los archivos públicos del navegador y deben contener únicamente valores publicables. El origen del panel debe coincidir con `CATALOG_PANEL_ORIGIN` en la función. Las claves secretas y las conexiones a PostgreSQL se configuran solo en el servidor.

El panel conserva la sesión únicamente en memoria. Solicita una cuenta autorizada al abrirse, renueva su token mientras la página permanezca abierta y elimina las filas visibles al cerrar sesión o cuando la función rechaza el acceso. Para el modo local, omitir `VITE_CATALOG_PANEL_MODE` o establecer `local` y usar `npm run catalog:panel` después de compilar.

## Variables del entorno

- `CATALOG_PANEL_ORIGIN` es el origen exacto autorizado del panel, por ejemplo `https://panel.example`, sin ruta ni barra final. Para desarrollo también se admite HTTP en localhost o 127.0.0.1.
- `CATALOG_PANEL_ALLOWED_USER_IDS` contiene UUID de Supabase Auth separados por comas. La lista vacía impide el arranque.
- `CATALOG_VIEWER_DATABASE_URL` identifica la conexión privada PostgreSQL con un usuario miembro de `catalog_viewer`. Este usuario debe tener privilegios mínimos, sin superusuario ni `BYPASSRLS`, y usar una conexión cifrada apropiada al entorno.
- `SUPABASE_URL` y `SUPABASE_ANON_KEY` son las variables del entorno de Edge Functions que permiten validar el JWT en el servicio de Auth.

Cada solicitud usa el encabezado `Authorization: Bearer <JWT>`. La lectura se ejecuta en una transacción de solo lectura bajo `SET LOCAL ROLE catalog_viewer`. Se devuelven `representations` y `runs` con el mismo formato que el panel local. Las respuestas no se almacenan en caché. El origen CORS solo admite `CATALOG_PANEL_ORIGIN` y no reemplaza la autorización del usuario.

Configurar credenciales de conexión, acceso a la función, usuarios y destino por entorno. Antes de publicar, probar en staging que un usuario permitido obtiene los datos, que un token vencido o un usuario no incluido se rechaza y que el rol no puede escribir ni consultar tablas ajenas. La configuración de la lista se administra en el servidor y no depende de metadatos editables por el usuario.
