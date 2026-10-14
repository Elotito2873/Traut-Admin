# Base de datos

Traut Admin consume las tablas existentes `profiles`, `routes`, `stops`,
`drivers`, `vehicles`, `vehicle_locations`, `trips` e `incidents`. No renombra ni
elimina objetos usados por las otras aplicaciones.

## Consultas principales

- métricas: conteos exactos filtrados por `status`/`active`;
- flota: `vehicles` con `routes`, `drivers.profiles` y `vehicle_locations`;
- rutas: `routes` con `stops` y IDs de `vehicles`;
- conductores: `drivers` con `profiles`, unidad, ruta y última ubicación;
- viajes/incidencias: relaciones de unidad, ruta, conductor y perfil;
- Realtime: `postgres_changes` sobre `public.vehicle_locations`.

`vehicle_locations` debe permanecer dentro de la publicación Realtime. En el
Dashboard actual esto se revisa en **Database → Publications/Pipelines →
supabase_realtime**. No se intenta modificar el esquema `realtime`.

## Propuestas SQL

Aplicar solo después de revisión y copiándolas a la historia canónica de
migraciones de Traut, en este orden:

1. `001_admin_rls.sql`: función `is_admin`, grants y políticas adicionales.
2. `002_audit_logs.sql`: tabla inmutable, índices y triggers administrativos.
3. `003_incident_history.sql`: `updated_at`, `resolved_at`, `resolution_notes`.
4. `004_require_admin_aal2.sql`: opcional; exige AAL2 a admins mediante policies
   restrictivas sin limitar pasajeros/conductores.
5. `005_no_signal_detection.sql`: RPC opcional para marcar activas sin señal; no
   se agenda automáticamente y nunca reactiva unidades.

La aplicación tiene fallback para el esquema original de `incidents`: podrá
cambiar `status`, pero las notas/fechas solo persisten tras la propuesta 003.

## Validación antes de producción

En un entorno de staging:

1. ejecutar las propuestas dentro de transacciones;
2. comprobar acceso con un usuario `user`, uno `driver` y uno `admin`;
3. confirmar que pasajeros siguen viendo únicamente rutas/unidades permitidas;
4. verificar INSERT/UPDATE/DELETE administrativo esperado;
5. comprobar `audit_logs` y que metadata no contiene PII sensible;
6. ejecutar Security/Performance Advisors de Supabase;
7. confirmar que `anon` no puede ejecutar funciones administrativas.
