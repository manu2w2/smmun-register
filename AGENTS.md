# Instrucciones para smmun-register

Este repositorio prepara el nuevo registro del Modelo de Naciones Unidas del Sureste Mexicano (SMMUN). El objetivo inicial es sustituir la persistencia de Firestore por PostgreSQL en Supabase. Consulta el [README](README.md) y las [reglas de negocio](docs/business-rules.md) antes de modificar un flujo.

## Alcance y decisiones

- La hoja maestra del catálogo tiene cuatro columnas: comité, nombre de la representación, tipo de representación y admite codelegación. PostgreSQL agrega y administra `disponible`. Cada fila nueva empieza en `true`.
- Mantén separados el catálogo, las solicitudes de registro y las asignaciones. El esquema de las dos últimas y el panel de Finanzas están en diseño. Documenta las decisiones nuevas y su motivo en [Arquitectura](docs/architecture.md).
- Distingue las reglas de la edición nueva de las observadas en el registro heredado. No reutilices tarifas, comités, reglas de ValladolidMUN ni textos de aceptación como si estuvieran aprobados para SMMUN.
- Conserva la semántica de la confirmación. Una solicitud recibida puede seguir pendiente de pago, procesamiento o asignación.
- Reutiliza convenciones y componentes cuando encajen. Conserva la identidad visual de SMMUN y comprueba navegación con teclado, mensajes de error, foco y comportamiento móvil cuando cambies formularios.

## Datos y entornos

- Versiona el esquema, permisos y cambios de configuración reproducibles. Verifica las instrucciones contra la versión elegida de la CLI.
- Usa datos sintéticos en desarrollo y CI. Mantén secretos, comprobantes, exportaciones y datos personales fuera de Git y de los logs.
- Mantén privado el acceso a solicitudes, asignaciones, archivos y operaciones internas. Aplica permisos mínimos y RLS donde corresponda. La ingesta pública se valida en servidor.
- No cambies producción ni ejecutes operaciones destructivas sin autorización. Verifica el proyecto de destino antes de cualquier operación remota.
- Comprueba la documentación oficial vigente al elegir una API o herramienta de Supabase o PostgreSQL.

## Verificación y comunicación

- Responde y documenta en español. Mantén los identificadores técnicos y nombres de código en inglés cuando corresponda.
- Inspecciona el estado y las instrucciones locales antes de editar. Conserva el trabajo existente y evita agregar dependencias sin una necesidad concreta.
- Revisa las diferencias y ejecuta las verificaciones pertinentes. Para cambios de datos, cubre las restricciones o riesgos afectados, como reimportación, disponibilidad, concurrencia y permisos. Informa el resultado y sus límites.
- Integra el trabajo en `dev`. Promueve a `stage` desde `dev` y a `main` desde `stage` con pull requests y el check `verify` en verde. Usa commits específicos por cambio.
- Actualiza el README cuando cambien los requisitos locales o los comandos que realmente funcionan.
