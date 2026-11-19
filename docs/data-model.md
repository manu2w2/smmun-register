# Modelo de datos e importación del catálogo

## Hoja maestra

El catálogo inicial se construirá a partir de una hoja de Google Sheets. La hoja tiene cuatro columnas y un encabezado. Este ejemplo utiliza datos ficticios.

| Comité | Nombre de la representación | Tipo de representación | Admite codelegación |
| --- | --- | --- | --- |
| Comité de ejemplo | País Aurora | País | Sí |
| Comité de ejemplo | Observatorio del Sur | Organización | No |

| Campo lógico en PostgreSQL | Origen | Significado |
| --- | --- | --- |
| `committee` | Comité | Comité al que pertenece la opción. |
| `representation_name` | Nombre de la representación | Etiqueta que verá el participante. |
| `representation_type` | Tipo de representación | Clasificación, por ejemplo país u organización. |
| `allows_co_delegation` | Admite codelegación | Booleano importado desde la hoja. |
| `disponible` | PostgreSQL | Booleano obligatorio con valor inicial `true` para cada fila nueva. |

`catalog.representations` añade `id` (UUID estable) y `edition` (identificador elegido al importar). El valor predeterminado de `disponible` se aplica al insertar. El esquema privado y RLS restringen el acceso desde la API. [Valores por defecto en PostgreSQL](https://www.postgresql.org/docs/17/ddl-default.html)

## Importación por CSV

1. El importador acepta los encabezados exactos `comite,nombre_delegacion,tipo_delegacion,permite_codelegacion` en cualquier orden. Recorta los campos y normaliza Unicode a NFC. Acepta `SI`, `SÍ`, `NO`, `TRUE` y `FALSE` sin distinguir mayúsculas. Los campos incompletos y booleanos inválidos se reportan con la línea del CSV.
2. La identidad inicial es edición, comité y nombre de representación, sin distinguir mayúsculas en comité y nombre según la configuración regional de PostgreSQL. Se conservan los acentos. La muestra de cuatro filas de la pestaña `catalogo` no repite esa combinación. Un tipo distinto en el mismo comité y nombre cuenta como cambio de atributo. Si un catálogo completo necesita distinguir dos filas así, habrá que acordar su identidad antes de cargarlo.
3. La vista previa devuelve conteos y detalle de altas, cambios y ausencias. Altas y ausencias simultáneas señalan posibles renombres. Un cambio de nombre que altere la identidad requiere conciliación deliberada para conservar el UUID.
4. La escritura vuelve a calcular las diferencias dentro de la transacción y serializa las importaciones por edición. Solo modifica las columnas de la hoja. La presencia de filas ausentes bloquea la escritura salvo revisión explícita. Una ausencia no altera ni elimina filas.

Consulta el [procedimiento operativo](operations.md#actualizar-el-catálogo) y el [plan de sincronización con Google Sheets](catalog-sync.md).

## Registros y asignaciones

| Entidad | Propuesta de relación | Pendiente |
| --- | --- | --- |
| Registro | Puede conservar preferencias que referencien el catálogo y motivos de revisión separados del pago. | Campos, personas por registro, preferencias, consentimiento y relación con faculty. |
| Asignación | Puede referenciar una representación del catálogo y el registro o participación al que corresponde. | Cardinalidad, capacidad, reasignación, estados e historial. |

Si una representación solo admite una asignación activa, la base deberá impedir que dos operaciones concurrentes la ocupen. En ese escenario, confirmar la asignación y actualizar la disponibilidad, si corresponde, debe ocurrir en una misma transacción. Si existen múltiples cupos, harán falta reglas adicionales para contarlos. Ambas posibilidades quedan para el diseño de asignaciones.

## Casos de verificación

- Una importación nueva crea el catálogo con disponibilidad verdadera.
- Reimportar la misma hoja mantiene el conteo y una fila que pasó a `false` conserva su valor.
- Una etiqueta igual en dos comités permanece como dos opciones distintas.
- Un valor booleano ambiguo o un duplicado se reporta antes de actualizar datos.
- Un renombre o una fila ausente se revisa sin romper referencias existentes.
