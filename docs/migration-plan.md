# Plan de migración

## Catálogo de la nueva edición

1. Preparar la hoja de cuatro columnas y acordar qué edición y pestaña son el origen.
2. Ensayar con una muestra sintética. Revisar errores y diferencias antes de escribir en el entorno de pruebas.
3. Importar y verificar que cada fila nueva inicia disponible. Reimportar después de marcar una representación como no disponible para verificar que se conserva ese estado.
4. Revisar conteos y correcciones de identidad con la persona que mantiene el catálogo. El procedimiento se detalla en [Modelo de datos](data-model.md).

## Historial de Firestore y Google Cloud Storage

El arranque de una edición nueva puede comenzar con un catálogo limpio. Lo histórico tiene un plan separado de importación si el equipo confirma que necesita consultarlo desde el sistema nuevo.

1. Inventariar ediciones, documentos, objetos, hojas operativas y registros pendientes. Acordar qué datos se conservan y cuáles permanecen en el sistema anterior.
2. Exportar en un espacio restringido con un manifiesto de origen. Cargar staging con las integraciones de correo, Sheets y demás entregas desactivadas.
3. Preservar IDs de origen y el significado histórico de los estados. Mantener separadas las listas de faculty, las solicitudes, la revisión del pago y las asignaciones. Conciliar las coincidencias ambiguas con el equipo.
4. Verificar existencia, cantidad, tamaño e integridad de los comprobantes transferidos. Conservar una relación comprobable entre cada registro y su objeto.
5. Conciliar los conteos por edición y modalidad, los resultados de pago y las asignaciones que puedan existir fuera de Firestore. Repetir la carga y comprobar que no duplica.
6. Si hay un corte de un sistema en uso, detener la recepción previa, drenar o conciliar su cola y aplicar el último lote. Si se revierte, congelar la recepción nueva y conciliar cualquier registro que PostgreSQL ya haya aceptado antes de reabrir el sistema anterior.

El importador estándar de Firestore ayuda a trasladar documentos a una tabla. El catálogo de la nueva edición y el modelo relacional requieren sus propias reglas de transformación. Los respaldos se verifican por separado para la base y para los objetos de Storage. [Migración desde Firestore](https://supabase.com/kb/guides/migrate-from-firestore-data), [respaldos de Supabase](https://supabase.com/docs/guides/platform/backups)
