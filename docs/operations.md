# Operación prevista

## Promover cambios

1. Integra el trabajo en `dev` con commits que identifiquen el cambio. Comprueba `npm run check`, `npm run build` y, si cambias la base, `npm run db:check` con Supabase local iniciado.
2. Abre un pull request de `dev` a `stage`. Revisa el check `verify`, el resultado esperado y las migraciones incluidas. Usa un merge commit para la promoción.
3. Abre un pull request de `stage` a `main` cuando el alcance esté validado. GitHub verifica el código con un stack local y la revisión en staging se incorpora cuando exista un entorno separado.

Mantén `dev` y CI con datos sintéticos. Para un staging alojado, usa credenciales y base de datos distintas de producción. Antes de configurar despliegues, identifica el proyecto de destino y la forma de revertir cada cambio.

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
