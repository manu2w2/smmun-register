# Reglas de negocio del registro

## Definido para el nuevo proyecto

- La hoja maestra contiene una fila por representación en un comité. Sus cuatro columnas son **Comité**, **Nombre de la representación**, **Tipo de representación** y **Admite codelegación**.
- PostgreSQL incorpora **Disponible**, un indicador propio del sistema. Al insertar una representación nueva, su valor inicial es `true`.
- Una representación puede ser un país, una organización, una persona u otra entidad que se pueda representar en un comité.
- Registros y asignaciones tendrán tablas separadas. Un registro recoge una solicitud. Una asignación recoge el resultado de la selección de representación. Los campos y la cardinalidad definitivos siguen abiertos.
- El panel de Finanzas es una opción para facilitar la revisión de registros y asignaciones. Sus permisos, vistas y operaciones están por definir.

## Reglas históricas que sirven de referencia

| Tema | Comportamiento observado |
| --- | --- |
| Modalidad | Inscripción individual o en codelegación de dos personas. |
| Delegación oficial | Grupo institucional con faculty. Independiente de la modalidad individual o en pareja. |
| Faculty | Registro de la institución y su lista de integrantes con mínimo cuatro personas. |
| Preferencias | Tres comités ordenados. La interfaz pedía tres representaciones por comité y la API permitía omitir la tercera. |
| Edad | 11 a 26 años en el formulario de delegación. La UI de faculty usaba el mismo rango para integrantes. |
| Comprobante | PDF o imagen de hasta 5 MiB. Para integrantes de una delegación oficial, la imagen provenía de Finanzas vía el faculty. |
| Recepción, pago y asignación | La recepción persistida, la revisión financiera y la asignación ocurrían en etapas distintas. |

Ver detalles y fuentes en [Sistema heredado](legacy-system.md).

## Decisiones pendientes

| Decisión | Por qué importa |
| --- | --- |
| Estructura de registros | Define los campos, las personas por solicitud, la evidencia del pago y, si el flujo continúa, cómo se enlazan integrantes y faculty. |
| Estructura de asignaciones | Define a quién se asigna, cómo se elige la representación, cuándo se confirma, si se puede reasignar y qué historial se conserva. |
| Disponibilidad | Falta decidir si `false` oculta la opción al registrar preferencias, impide asignarla, o aplica a ambas acciones. También queda abierta la gestión de cupos y liberaciones. |
| Reglas de la edición | Se deben fijar catálogo, formatos, prioridades, edades, tarifas, documentos y fechas antes de abrir el registro. |
| Panel de Finanzas | Hay que acordar qué información necesita Finanzas para revisar solicitudes y asignaciones y quién podrá aprobar pagos, descargar comprobantes o modificar asignaciones. |

Una preferencia expresa interés por una representación. La reserva de un cupo, el cierre de disponibilidad y la confirmación de la asignación son decisiones distintas que se deben acordar al diseñar el flujo.
