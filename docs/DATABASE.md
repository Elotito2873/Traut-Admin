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
4. `006_atomic_admin_operations.sql`: unicidad de asignación/orden y RPC
   transaccionales `assign_driver_to_vehicle`, `save_vehicle_with_assignment` y
   `reorder_route_stops`; requiere que el admin ya opere con AAL2.
5. `007_data_integrity_constraints.sql`: checks de orden, tarifa, coordenadas,
   código/placa y default UUID de `drivers` si aún no existe.
6. `008_server_trip_timestamps.sql`: `ended_at` calculado por trigger en INSERT y
   UPDATE.
7. `005_no_signal_detection.sql`: wrapper manual admin+AAL2 y worker privado
   opcional para marcar activas sin señal; no crea un schedule ni reactiva unidades.
8. `004_require_admin_aal2.sql`: aplicar al final, solo después de completar el
   enrolamiento y comprobar AAL2 de todos los administradores.

La aplicación tiene fallback para el esquema original de `incidents`: podrá
cambiar `status`, pero las notas/fechas solo persisten tras la propuesta 003.
El fallback usa primero códigos `42703`/`PGRST204`; la inspección de texto queda
solo para el rollout. Después de aplicar 003 en todos los entornos, elimina
`_incidentHistoryUnavailable` y ambas consultas fallback del repositorio.

## Preflight obligatorio

Antes de 006, inspecciona y resuelve manualmente duplicados; el SQL también
aborta la transacción si encuentra alguno:

```sql
select driver_id, count(*), array_agg(id order by id)
from public.vehicles
where driver_id is not null
group by driver_id
having count(*) > 1;

select route_id, stop_order, count(*), array_agg(id order by id)
from public.stops
group by route_id, stop_order
having count(*) > 1;
```

Antes de 007, revisa los datos que violarían checks:

```sql
select id from public.stops
where stop_order <= 0 or fare < 0
   or latitude not between -90 and 90
   or longitude not between -180 and 180;
select id from public.vehicles
where nullif(btrim(code), '') is null or nullif(btrim(plate), '') is null;
```

Los timestamps `updated_at`, `resolved_at` y `ended_at` usan `now()` en triggers;
Flutter ya no envía su reloj. Los triggers/RPC alimentan `audit_logs`, no la UI.

## Sin señal

`public.mark_stale_vehicles_no_signal` es el wrapper para una llamada humana:
exige administrador y JWT AAL2. Delega en
`private.mark_stale_vehicles_no_signal`, que compara
`vehicle_locations.updated_at` con `now()` del servidor y solo cambia unidades
`active`; excluye `inactive`, `maintenance` y `no_signal`. Cada cambio se audita
sin copiar filas completas.

Un job de `pg_cron` no tiene `auth.uid()` ni claim AAL2 y por eso nunca debe llamar
al wrapper público. Si se automatiza, el job debe ejecutarse como un rol de base
de datos confiable y llamar únicamente a
`private.mark_stale_vehicles_no_signal(interval '5 minutes')`. La propuesta revoca
acceso al schema y al worker para `public`, `anon` y `authenticated`; no concede
permisos nuevos a un rol de aplicación. Tampoco instala el schedule. Flutter no
usa `service_role` ni participa en esta ejecución interna.

## Grants y compatibilidad

001 añade policies con prefijo `traut_admin_` y no elimina policies de pasajero o
conductor. Sus nuevos grants son por columna, pero PostgreSQL suma privilegios:
un grant histórico a nivel tabla seguiría siendo efectivo. Revisa antes de
aplicar:

```sql
select * from information_schema.role_table_grants
where table_schema = 'public' and grantee in ('anon', 'authenticated');
select * from information_schema.column_privileges
where table_schema = 'public' and grantee in ('anon', 'authenticated');
```

No revoques permisos canónicos sin probar Traut Usuario y Traut Conductor. RLS
debe seguir habilitado en todas las tablas expuestas.

Revisa también `pg_constraint`, `pg_indexes` y `pg_attrdef` antes de 006/007. Si
el esquema canónico ya tiene una restricción equivalente con otro nombre, conserva
la canónica y omite la creación duplicada al incorporar estas propuestas.

## Validación antes de producción

En un entorno de staging:

1. ejecutar las propuestas dentro de transacciones;
2. comprobar acceso con un usuario `user`, uno `driver` y uno `admin`;
3. confirmar que pasajeros siguen viendo únicamente rutas/unidades permitidas;
4. verificar INSERT/UPDATE/DELETE administrativo esperado;
5. comprobar `audit_logs` y que metadata no contiene PII sensible;
6. ejecutar Security/Performance Advisors de Supabase;
7. confirmar que `anon` no puede ejecutar funciones administrativas.
8. probar los tres RPC con rollback forzado y confirmar que no queda estado
   parcial ni un mismo conductor en dos unidades.
