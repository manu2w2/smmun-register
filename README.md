# SMMUN Register

Nuevo sistema de registro del Modelo de Naciones Unidas del Sureste Mexicano (SMMUN). El proyecto comienza con el catálogo de representaciones y el plan para trasladar la persistencia de Firestore a PostgreSQL en Supabase.

**Estado actual.** El repositorio contiene la documentación y la base del entorno de desarrollo. La portada indica que el registro aún está cerrado.

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

Usa Node.js **24.18.0** y npm **11.16.0**. El lockfile fija SvelteKit **3.3.1** y Supabase CLI **3.2.0**. Para levantar la base local, instala y abre [Docker Desktop en Windows](https://docs.docker.com/desktop/setup/install/windows-install/) o usa un motor Docker compatible.

```sh
npm ci
npm run dev
```

Abre `http://localhost:5173`. La portada de desarrollo se puede comprobar sin Docker.

```sh
docker info
npm run db:start
npm run db:check
npm run db:status
```

Con Docker en ejecución, Supabase inicia la API local en `http://127.0.0.1:54321`, PostgreSQL 17 en el puerto `54322` y Studio en `http://127.0.0.1:54323`. La primera ejecución descarga las imágenes del stack. Para detenerlo, usa `npm run db:stop`. [Documentación de desarrollo local](https://supabase.com/docs/guides/local-development/cli/getting-started)

En Windows, si se atasca la descarga de Edge Runtime o se reinicia el contenedor de logs, puedes trabajar en el catálogo con el arranque reducido que se probó en este equipo.

```sh
npm run db:start -- --exclude edge-runtime,vector,logflare
npm run db:check
```

Este modo mantiene PostgreSQL, Studio y la API. Para probar Edge Functions o el procesamiento de logs, usa el arranque completo.

Al integrar el cliente, copia `.env.example` a `.env.local` y toma la clave publicable de `npm run db:status`. Las variables con prefijo `PUBLIC_` pueden llegar al navegador. Reserva las credenciales privilegiadas para el servidor. Estos comandos de desarrollo operan sobre el stack local y no requieren vincular el proyecto alojado.

El archivo [`fixtures/catalogo.csv`](fixtures/catalogo.csv) contiene filas sintéticas con los cuatro encabezados observados en la hoja y valores `SI`/`NO`. Sirve para preparar la importación de la siguiente fase.

```sh
npm run check
npm run build
npm run preview
```

GitHub Actions ejecuta las verificaciones de tipos y compilación, levanta Supabase local y consulta la versión de PostgreSQL. CI usa contenedores y datos de prueba.

## Flujo de ramas

| Rama | Uso |
| --- | --- |
| `dev` | Integra el trabajo y valida cambios con datos sintéticos. Crea las ramas de trabajo a partir de `dev`. |
| `stage` | Recibe cambios de `dev` por pull request para revisarlos antes de publicar. |
| `main` | Rama principal. Recibe cambios de `stage` por pull request. |

CI se ejecuta con cada push o pull request de estas ramas. Para una promoción, usa un merge commit para conservar el historial y espera el check `verify`. Documenta en el PR la prueba realizada y cualquier limitación.

Cada push a `dev` publica la portada estática de desarrollo en [GitHub Pages](https://manu2w2.github.io/smmun-register/). Esta vista previa muestra el estado del registro y funciona sin conexión con Supabase. El hosting y el proyecto Supabase aislado de staging siguen pendientes. Consulta [Cómo promover cambios](docs/operations.md#promover-cambios).

## Repositorios de referencia

- [smmun-gcp](https://github.com/brunoanc/smmun-gcp) contiene la API, el worker y la infraestructura heredada.
- [smmun-frontend](https://github.com/brunoanc/smmun-frontend) contiene el sitio institucional y los formularios archivados.
