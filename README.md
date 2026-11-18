# SMMUN Register

Nuevo sistema de registro del Modelo de Naciones Unidas del Sureste Mexicano (SMMUN). El proyecto comienza con el catálogo de representaciones y el plan para trasladar la persistencia de Firestore a PostgreSQL en Supabase.

**Estado actual.** Fase uno, documentación y diseño. La aplicación y el entorno local se prepararán en la fase dos.

| Componente | Alcance actual |
| --- | --- |
| Catálogo | Hoja de Google Sheets con comité, nombre de la representación, tipo de representación y admite codelegación. |
| Disponibilidad | PostgreSQL agrega el campo `disponible`. Las filas nuevas comienzan en `true`. |
| Registros y asignaciones | Cada entidad se guardará por separado. Sus campos, relaciones y reglas detalladas están por definir. |
| Finanzas | Panel interno en evaluación para consultar registros y asignaciones y, si se acuerda, revisar pagos. |

## Documentación del proyecto

- [Reglas de negocio](docs/business-rules.md) reúne lo definido para el nuevo registro y las decisiones pendientes.
- [Sistema heredado](docs/legacy-system.md) explica los formularios anteriores, sus integraciones y sus diferencias.
- [Modelo de datos e importación del catálogo](docs/data-model.md) describe la hoja maestra y los controles propuestos.
- [Arquitectura](docs/architecture.md) registra las decisiones y la ruta de implementación.
- [Contrato de API preliminar](docs/api-contract.md) describe los intercambios previstos.
- [Plan de migración](docs/migration-plan.md) separa el arranque del catálogo de una eventual importación histórica.
- [Operación](docs/operations.md) plantea cómo mantener el catálogo y revisar inscripciones.
- [AGENTS.md](AGENTS.md) reúne las instrucciones para trabajar en el proyecto.

## Desarrollo local

La base propuesta es SvelteKit con TypeScript y Supabase local con Docker. En la fase dos se fijarán las versiones de Node y Supabase CLI, la configuración del stack, las variables de ejemplo y los comandos verificados para instalar, iniciar y probar con datos sintéticos.

## Repositorios de referencia

- [smmun-gcp](https://github.com/brunoanc/smmun-gcp) contiene la API, el worker y la infraestructura heredada.
- [smmun-frontend](https://github.com/brunoanc/smmun-frontend) contiene el sitio institucional y los formularios archivados.
