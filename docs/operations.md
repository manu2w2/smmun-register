# Operación prevista

## Actualizar el catálogo

Preparar la hoja de cuatro columnas, identificar la edición y revisar la vista previa de la importación. Resolver duplicados, renombres y bajas antes de confirmar el lote. Comparar conteos después de aplicar los cambios. La disponibilidad existente se mantiene en PostgreSQL según el [procedimiento propuesto de importación](data-model.md).

## Revisar registros y asignaciones

Si se construye el panel, empezar con vistas de lectura para Finanzas. Se propone buscar o filtrar por edición e identificar en una misma revisión el estado de recepción, el pago y la asignación. La descarga de comprobantes requeriría un permiso propio. El alcance de la primera versión y la autorización para cambiar estados, asignar o reasignar se decidirán con quienes operen el proceso.

La transición debe dar a Finanzas una vía para revisar solicitudes y pagos. Si el equipo aún usa las hojas operativas antiguas, una exportación temporal o el panel podrían cubrir esa necesidad.

## Apertura y recuperación

- Antes de abrir, probar el catálogo, el formulario, la recepción duplicada, la revisión interna y la descarga autorizada si aplica.
- El cierre de recepción debe permitir completar el trabajo que ya se aceptó. Verificar el estado de las entregas pendientes antes de cambiar de sistema.
- Medir solicitudes recibidas, errores y antigüedad del trabajo pendiente. Usar identificadores de correlación sin incluir datos personales o URLs firmadas en logs.
- Reintentar efectos desde su estado registrado y reconciliar resultados ambiguos antes de reenviar. Verificar la recuperación de base y archivos en un entorno de prueba antes de confiar en un respaldo.
