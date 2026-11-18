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

Los nombres técnicos de los cuatro campos importados son de trabajo. La disponibilidad se configura como valor por defecto en PostgreSQL para que aplique al insertar una fila sin ese campo. Un identificador técnico estable es una propuesta para enlazar preferencias y asignaciones sin agregar columnas a la hoja. El formato de ese identificador y la separación física de comités por edición quedan abiertos. [Valores por defecto en PostgreSQL](https://www.postgresql.org/docs/current/ddl-default.html)

## Importación propuesta

Empezar con una exportación CSV de la hoja y una importación explícita por edición. Se puede conectar la API de Sheets después si la frecuencia de cambios lo justifica.

1. Validar encabezados, campos obligatorios y valores de codelegación. Acordar el formato de origen, por ejemplo casillas booleanas o `Sí`/`No`. Reportar los valores ambiguos con número de fila.
2. Revisar duplicados y las coincidencias con el catálogo previo. Lo que identifica una fila debe incluir su comité y su edición cuando existan varias ediciones. El nombre solo no identifica una representación.
3. Mostrar altas, cambios, posibles renombres y filas ausentes antes de aplicar el lote. Con las cuatro columnas, un cambio de nombre puede parecer una fila nueva. Un renombre requiere conservar la identidad previa mediante una conciliación explícita.
4. Aplicar los cambios válidos en una transacción. Las altas reciben `disponible = true`. En filas existentes, actualizar únicamente los atributos que vienen de la hoja y conservar la disponibilidad. Una fila ausente genera un aviso para revisión.
5. Verificar conteos y repetir el lote para confirmar que mantiene la misma identidad y no crea duplicados.

La identidad definitiva de importación se fijará con una muestra del catálogo real. Conviene comprobar si dos filas pueden compartir comité y nombre y, en ese caso, distinguirlas sin confundir un cambio de tipo con un alta. [Restricciones de PostgreSQL](https://www.postgresql.org/docs/current/ddl-constraints.html)

## Registros y asignaciones

| Entidad | Propuesta de relación | Pendiente |
| --- | --- | --- |
| Registro | Puede conservar preferencias que referencien el catálogo y motivos de revisión separados del pago. | Campos, personas por registro, preferencias, consentimiento y relación con faculty. |
| Asignación | Puede referenciar una representación del catálogo y el registro o participación al que corresponde. | Cardinalidad, capacidad, reasignación, estados e historial. |

Si una representación solo admite una asignación activa, la base deberá impedir que dos operaciones concurrentes la ocupen. En ese escenario, confirmar la asignación y actualizar la disponibilidad, si corresponde, debe ocurrir en una misma transacción. Si existen múltiples cupos, harán falta reglas adicionales para contarlos. Ambas posibilidades quedan para el diseño de asignaciones.

## Casos que deberá cubrir la implementación

- Una importación nueva crea el catálogo con disponibilidad verdadera.
- Reimportar la misma hoja mantiene el conteo y una fila que pasó a `false` conserva su valor.
- Una etiqueta igual en dos comités permanece como dos opciones distintas.
- Un valor booleano ambiguo o un duplicado se reporta antes de actualizar datos.
- Un renombre o una fila ausente se revisa sin romper referencias existentes.
