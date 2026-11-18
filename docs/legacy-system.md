# Funcionamiento del registro anterior

El análisis se basa en [smmun-gcp, commit dd3824a](https://github.com/brunoanc/smmun-gcp/commit/dd3824a2b052991d3c7dd833dac7477e9c553249) y [smmun-frontend, commit e600a4a](https://github.com/brunoanc/smmun-frontend/commit/e600a4a0581ddfc8dacd714fbef8c7ae65a2f7fe). El segundo repositorio se incorporaba al primero como submódulo.

## Registro SMMUN

1. El formulario enviaba los datos, la clave de idempotencia y el comprobante por `multipart/form-data` a FastAPI en Cloud Run.
2. La API validaba el envío, calculaba un hash del contenido y reclamaba la clave. El comprobante se guardaba en Cloud Storage privado.
3. Una transacción de Firestore confirmaba la inscripción, la idempotencia y la fila de outbox. A continuación, la API redirigía al navegador con HTTP 303.
4. El publisher enviaba las filas pendientes a Pub/Sub. Un barrido programado recuperaba publicaciones pendientes o leases vencidos.
5. El worker reclamaba la inscripción, escribía en Google Sheets, enviaba correos por Resend y registraba checkpoints. Para faculty también enviaba un aviso interno a Finanzas.

La confirmación comunicaba que se había recibido la solicitud. La validación del pago y la asignación eran procesos posteriores. Un `completed` en Firestore reflejaba los efectos técnicos del worker. [API de recepción](https://github.com/brunoanc/smmun-gcp/blob/dd3824a2b052991d3c7dd833dac7477e9c553249/api/business.py#L621), [persistencia](https://github.com/brunoanc/smmun-gcp/blob/dd3824a2b052991d3c7dd833dac7477e9c553249/api/runtime.py#L598), [worker](https://github.com/brunoanc/smmun-gcp/blob/dd3824a2b052991d3c7dd833dac7477e9c553249/worker/business.py)

## Delegaciones oficiales y preferencias

El faculty enviaba una lista de integrantes y el comprobante de la transferencia del grupo. Una vez revisado el pago, Finanzas enviaba una imagen al faculty. Cada integrante completaba después su inscripción y adjuntaba esa imagen para acompañar sus preferencias. La pertenencia se indicaba mediante nombres en texto y requería cotejo manual. Una fila de esa lista y una solicitud posterior pueden representar a una misma persona.

El frontend y el backend tenían catálogos distintos. La comparación identificó 9 comités y 212 representaciones en el frontend, frente a 11 comités y 419 representaciones en el backend. Las opciones del primero eran un subconjunto de las del segundo. La API comprobaba repeticiones y algunas restricciones de modalidad, pero no la pertenencia de cada opción al comité en todos los casos. [Formulario faculty](https://github.com/brunoanc/smmun-frontend/blob/e600a4a0581ddfc8dacd714fbef8c7ae65a2f7fe/src/routes/registro/faculty/page.old.svelte#L430), [catálogo del frontend](https://github.com/brunoanc/smmun-frontend/blob/e600a4a0581ddfc8dacd714fbef8c7ae65a2f7fe/src/lib/data/delegaciones.json), [catálogo del backend](https://github.com/brunoanc/smmun-gcp/blob/dd3824a2b052991d3c7dd833dac7477e9c553249/api/delegaciones.json)

## Operación y límites

- Firebase Hosting publicaba SvelteKit como sitio estático. Los formularios SMMUN están archivados como `page.old.svelte` en el commit revisado. La página de registro anunciaba convocatorias de 2027.
- ValladolidMUN usó otro flujo con Apps Script, folio y formulario por pasos. El servidor de Apps Script queda fuera de estos repositorios.
- Sheets recibía una copia de datos y enlaces firmados a comprobantes con vigencia de siete días. El worker podía repetir una escritura si se interrumpía justo antes de guardar su checkpoint.
- Google Sheets tenía el papel de destino operativo de solicitudes. La nueva hoja maestra es una entrada del catálogo. Son hojas con objetivos distintos.
- La evidencia disponible es código, configuración, documentación e historial de Git. El estado productivo, los volúmenes y las revisiones manuales en Sheets quedan por inventariar. [Operación heredada](https://github.com/brunoanc/smmun-gcp/blob/dd3824a2b052991d3c7dd833dac7477e9c553249/docs/operations.md), [registro del frontend](https://github.com/brunoanc/smmun-frontend/tree/e600a4a0581ddfc8dacd714fbef8c7ae65a2f7fe/src/routes/registro)
