# SMMUN Register

Nuevo sistema de registro del Modelo de Naciones Unidas del Sureste Mexicano (SMMUN). El proyecto comienza con el catálogo de representaciones y el plan para trasladar la persistencia de Firestore a PostgreSQL en Supabase.

**Estado actual.** El desarrollo abre el panel del catálogo con acceso por Supabase Auth. La portada pública indica que el registro está cerrado.

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
cp .env.example .env.development.local
# Completa VITE_CATALOG_SUPABASE_PUBLISHABLE_KEY con la clave publicable de smmun-staging.
npm run dev
```

En PowerShell también puedes copiar el archivo con `Copy-Item .env.example .env.development.local`. La copia y la configuración de la clave se hacen una vez. Abre [localhost:5173](http://localhost:5173/) e ingresa con una cuenta de staging autorizada. Vite redirige al panel, reserva ese puerto y actualiza la interfaz al editar Svelte. La vista alojada requiere conexión a staging. Docker y Python solo se necesitan para trabajar con la base y las herramientas locales.

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

Configura el navegador mediante `VITE_CATALOG_PANEL_MODE`, `VITE_CATALOG_SUPABASE_URL` y `VITE_CATALOG_SUPABASE_PUBLISHABLE_KEY`. Reserva las credenciales de PostgreSQL y de Google para las funciones. Los comandos de base de datos anteriores operan sobre el stack local.

### Cargar el catálogo en Supabase local

Con Supabase local iniciado y Python 3 disponible como `python`, aplica la migración y prueba con el CSV sintético.

```sh
npm run db:migrate
npm run catalog:import -- --edition prueba --csv fixtures/catalogo.csv
npm run catalog:import -- --edition prueba --csv fixtures/catalogo.csv --apply
```

El comando sin `--apply` compara el archivo con la edición y muestra altas, cambios y ausencias. La carga conserva `disponible` en las filas existentes. Guarda los archivos exportados fuera de Git, por ejemplo en `exports/`. Consulta los [pasos de revisión](docs/operations.md#actualizar-el-catálogo) y el [plan de sincronización futura](docs/catalog-sync.md).

### Panel local del catálogo

Con Supabase local iniciado, aplica las migraciones y construye la aplicación antes de iniciar el panel.

```sh
npm run db:migrate
npm run build
npm run catalog:panel
```

Abre `http://127.0.0.1:8765/catalogo/`. El panel consulta el catálogo local y las últimas corridas, y actualiza su vista cada minuto. El servidor escucha únicamente en este equipo y está destinado al desarrollo local. Para detenerlo, pulsa Ctrl+C en la terminal.

En staging, `catalog-sync` lee Sheets y `catalog-read` atiende el panel autenticado. Consulta el [procedimiento de activación, pausa y recuperación](docs/operations.md#operar-la-sincronización-en-staging) y el [contrato de lectura](docs/catalog-read-api.md).

```sh
npm run check
npm run build
npm run preview
```

GitHub Actions ejecuta las verificaciones de tipos y compilación, levanta Supabase local y comprueba el catálogo con datos sintéticos.

## Flujo de ramas

| Rama | Uso |
| --- | --- |
| `dev` | Integra el trabajo y valida cambios con datos sintéticos. Crea las ramas de trabajo a partir de `dev`. |
| `stage` | Recibe cambios de `dev` por pull request para revisarlos antes de publicar. |
| `main` | Rama principal. Recibe cambios de `stage` por pull request. |

CI se ejecuta con cada push o pull request de estas ramas. Para una promoción, usa un merge commit para conservar el historial y espera el check `verify`. Documenta en el PR la prueba realizada y cualquier limitación.

Cada push a `dev` publica la portada estática en [GitHub Pages](https://manu2w2.github.io/smmun-register/). El panel de staging se revisa desde localhost y el backend usa el proyecto aislado `smmun-staging`. Consulta [Cómo promover cambios](docs/operations.md#promover-cambios).

## Repositorios de referencia

- [smmun-gcp](https://github.com/brunoanc/smmun-gcp) contiene la API, el worker y la infraestructura heredada.
- [smmun-frontend](https://github.com/brunoanc/smmun-frontend) contiene el sitio institucional y los formularios archivados.
