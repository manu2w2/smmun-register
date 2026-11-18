# Contrato de API preliminar

Este documento describe las operaciones que podrían necesitar el frontend y el equipo interno. Los nombres de rutas, formatos y códigos HTTP se fijarán cuando se definan los registros, las asignaciones y el runtime.

| Operación | Entrada y salida previstas | Decisión pendiente |
| --- | --- | --- |
| Consultar catálogo | Devuelve las representaciones del comité, su tipo y compatibilidad con codelegación. | Filtros, edición, campos públicos y cómo afecta la disponibilidad a la lista mostrada. |
| Presentar un registro | Recibe la solicitud, las preferencias y el comprobante si aplica. Devuelve una confirmación de recepción persistida o errores que el participante pueda corregir. | Campos, formatos, errores, folio y manejo de cargas. |
| Revisar un registro | Una sesión autorizada consulta el registro y su estado. | Roles, campos visibles y acciones de Finanzas. |
| Consultar asignaciones | Una sesión autorizada revisa las asignaciones vinculadas a registros. | Cardinalidad, visibilidad, edición y forma de comunicar el resultado. |

## Comportamientos propuestos

- Validar en servidor la pertenencia de cada representación a su comité y las restricciones de codelegación vigentes para la edición.
- En un reintento, una misma clave y un mismo contenido recuperan la recepción original. La misma clave con contenido distinto produce un conflicto claro. El contrato debe indicar cómo continuar en cada caso.
- Confirmar la recepción después de la persistencia duradera. Comunicar los estados del pago y la asignación por separado.
- Autorizar por operación y por rol. Los comprobantes se entregan mediante un acceso temporal tras verificar permisos.
- Diseñar pruebas de solicitudes concurrentes, respuesta perdida después de confirmar la transacción y acceso público a datos internos.
