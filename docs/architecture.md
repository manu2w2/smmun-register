# Arquitectura del nuevo registro

## Decisión registrada el 18 de noviembre de 2026

Google Sheets será la fuente para preparar el catálogo. PostgreSQL en Supabase conservará las representaciones importadas y administrará su disponibilidad. Registros y asignaciones se guardarán en tablas separadas. El panel de Finanzas se mantiene como opción.

Esta decisión resuelve la procedencia del catálogo y del indicador de disponibilidad, frente a los dos catálogos separados del sistema anterior. La [importación propuesta](data-model.md) contempla cambios repetidos sin revertir la disponibilidad operativa.

| Componente | Función | Estado |
| --- | --- | --- |
| Google Sheets | Preparar las cuatro columnas de catálogo. | Definido. |
| PostgreSQL en Supabase | Mantener catálogo, disponibilidad, registros y asignaciones. | Plataforma y separación definidas. Falta el esquema físico. |
| SvelteKit y TypeScript | Continuar con la tecnología y la identidad visual del sitio. | Portada estática y entorno de desarrollo configurados. |
| API de recepción | Validar solicitudes en servidor y guardar su aceptación con idempotencia. | Diseño pendiente. Edge Functions o FastAPI como puente son opciones. |
| Archivos y entregas | Guardar comprobantes en Storage privado y procesar correos de forma durable, si forman parte del flujo nuevo. | Storage, Queues, Cron y Resend son propuestas. |
| Panel interno | Dar a Finanzas una vista de registros y asignaciones. | En evaluación. |

## Límites de integración

- La apertura del formulario y la aceptación de solicitudes deben respetar la configuración de la edición. El servidor aplica la regla aunque la interfaz tenga un estado desactualizado.
- Si la recepción inicia entregas asíncronas, la aceptación, la idempotencia y el trabajo pendiente se confirman en una sola transacción. Correos y exportaciones siguen su propio estado y se pueden recuperar por separado.
- Storage y PostgreSQL tienen operaciones separadas. El flujo de carga necesita reconciliar fallos parciales y limpiar archivos sin registro asociado.
- El catálogo puede exponer un subconjunto de campos de lectura. Para registros, comprobantes y asignaciones internas, se proponen permisos explícitos y mínimo privilegio. Aplicar RLS a las tablas de esquemas expuestos y reservar credenciales privilegiadas al servidor. [Seguridad de la API de Supabase](https://supabase.com/docs/guides/api/securing-your-api)
- Si se conserva la compilación estática de SvelteKit, las solicitudes se envían a una API externa. El hosting y el runtime del frontend quedan por decidir. [Prerendering de SvelteKit](https://svelte.dev/docs/kit/page-options#prerender)

## Orden de implementación

1. Preparar el repositorio, las versiones, el entorno local de Supabase y las verificaciones básicas.
2. Probar el catálogo con una hoja de ejemplo y verificar importación, reimportación y permisos.
3. Definir registros, asignaciones y reglas de la edición con el flujo real de SMMUN. Conectar la recepción y, si procede, archivos y entregas.
4. Probar el recorrido público y definir el acceso del equipo interno. Decidir si el panel se construye en esta entrega.
5. Ensayar la migración histórica si entra en alcance y preparar la apertura. [Plan de migración](migration-plan.md)
