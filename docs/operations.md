# Operación prevista

## Promover cambios

1. Integra el trabajo en `dev` con commits que identifiquen el cambio. Comprueba `npm run check`, `npm run build` y, si cambias la base, `npm run db:check` con Supabase local iniciado.
2. Abre un pull request de `dev` a `stage`. Revisa el check `verify`, el resultado esperado y las migraciones incluidas. Usa un merge commit para la promoción.
3. Abre un pull request de `stage` a `main` cuando el alcance esté validado. GitHub verifica el código con un stack local y la revisión en staging se incorpora cuando exista un entorno separado.

Mantén `dev` y CI con datos sintéticos. Para un staging alojado, usa credenciales y base de datos distintas de producción. Antes de configurar despliegues, identifica el proyecto de destino y la forma de revertir cada cambio.

## Operar la sincronización en staging

1. Comprueba el nombre `smmun-staging` y la referencia `thospiqlsgtsxzkbpkux`. Revisa las migraciones aplicadas y despliega `catalog-read` después de incorporar `catalog.panel_snapshot()`. Usa el pooler de sesión o una conexión directa con TLS y un login dedicado por función. El login del sincronizador debe heredar solo `catalog_sync`. El lector debe poder asumir `catalog_viewer`. Ambos requieren `NOSUPERUSER NOCREATEDB NOCREATEROLE NOBYPASSRLS`.
2. Configura en los secretos de Edge `CATALOG_DATABASE_URL`, `CATALOG_VIEWER_DATABASE_URL`, `CATALOG_PANEL_ORIGIN=http://localhost:5173` y `CATALOG_PANEL_ALLOWED_USER_IDS` con el UUID de la cuenta de prueba. Usa el origen exacto. Comprueba en el panel que la cuenta autorizada recibe el catálogo y que se borra al cerrar sesión.
3. Confirma la edición configurada y la pestaña sintética de staging. Con `CATALOG_MODE=preview`, invoca `catalog-sync` con POST y el encabezado privado `x-catalog-sync-secret`. Coteja los conteos con la hoja y comprueba que solo se registró la corrida. Repite en `apply`, verifica la disponibilidad de las altas y repite el lote para comprobar que todas las filas quedan iguales.
4. Verifica la cuota efectiva de Google para ese proyecto y acuerda quién revisará los avisos en el panel. En staging, habilita pg_cron y pg_net y configura en Vault `catalog_sync_url` y `catalog_sync_secret`. En la misma sesión SQL, ejecuta `SET catalog.schedule_edition = '<edición configurada en Edge>'` y el archivo [schedule-catalog-sync.sql](../supabase/operations/schedule-catalog-sync.sql). Corrobora dos disparos consecutivos de Cron, su respuesta HTTP y sus corridas `apply` completadas en el panel.
5. Para pausar, ejecuta [pause-catalog-sync.sql](../supabase/operations/pause-catalog-sync.sql). Ambos scripts actualizan el trabajo y el estado del panel en una transacción. Usa estos scripts también al reanudar. Antes de corregir la fuente, espera a que terminen las peticiones HTTP ya enviadas y comprueba que la edición no tiene una corrida en curso. Un estado `running` antiguo requiere revisar la ejecución y su bloqueo antes de continuar.
6. Con Cron pausado, corrige ausencias o concilia renombres preservando los UUID. Ejecuta un `preview`, revisa el resultado, restablece `apply` y valida una corrida manual antes de reprogramar. El aviso de atraso comienza de nuevo al reactivar. Verifica en el panel tanto el dato corregido como la última aplicación.

El panel actualiza la lectura cada minuto mientras está visible. Una lectura fallida conserva los últimos datos y su hora. Un aviso de atraso indica más de 40 minutos desde la activación o la última corrida terminada. Las corridas omitidas por concurrencia no reinician ese reloj. Revisa el trabajo de Cron y la respuesta de Edge cuando haya disparos sin una corrida asociada.

## Actualizar el catálogo

1. Descarga la pestaña del catálogo como CSV UTF-8 separado por comas. Guarda el archivo fuera de Git e identifica la edición correcta.
2. Ejecuta `npm run catalog:import -- --edition prueba --csv exports/catalogo.csv` contra Supabase local. Revisa `altas`, `cambios`, `iguales` y `ausentes`. El detalle incluye la línea del CSV donde corresponde.
3. Agrega `--apply` tras revisar el resultado. Si hay ausencias, confirma primero si son omisiones o renombres. Corrige el archivo o concilia el renombre conservando el UUID de la fila. Agrega `--allow-missing` junto con `--apply` únicamente si se acordó conservar esas filas tal cual y aplicar las demás.
4. Ejecuta la vista previa otra vez. Las filas presentes deben figurar como iguales. Las ausencias revisadas siguen apareciendo mientras falten en el origen.

La disponibilidad sigue en PostgreSQL. La ejecución manual de esta fase usa el stack local y la vista previa se ejecuta como consulta de solo lectura. Consulta el [contrato del catálogo](data-model.md).

## Revisar registros y asignaciones

Si se construye el panel, empezar con vistas de lectura para Finanzas. Se propone buscar o filtrar por edición e identificar en una misma revisión el estado de recepción, el pago y la asignación. La descarga de comprobantes requeriría un permiso propio. El alcance de la primera versión y la autorización para cambiar estados, asignar o reasignar se decidirán con quienes operen el proceso.

La transición debe dar a Finanzas una vía para revisar solicitudes y pagos. Si el equipo aún usa las hojas operativas antiguas, una exportación temporal o el panel podrían cubrir esa necesidad.

## Apertura y recuperación

- Antes de abrir, probar el catálogo, el formulario, la recepción duplicada, la revisión interna y la descarga autorizada si aplica.
- El cierre de recepción debe permitir completar el trabajo que ya se aceptó. Verificar el estado de las entregas pendientes antes de cambiar de sistema.
- Medir solicitudes recibidas, errores y antigüedad del trabajo pendiente. Usar identificadores de correlación sin incluir datos personales o URLs firmadas en logs.
- Reintentar efectos desde su estado registrado y reconciliar resultados ambiguos antes de reenviar. Verificar la recuperación de base y archivos en un entorno de prueba antes de confiar en un respaldo.
