-- PROPUESTA: acceso administrativo adicional para Traut Admin.
-- Revisar e incorporar al repositorio CANÓNICO de migraciones de Traut.
-- No elimina ni hace más permisivas las políticas de pasajeros/conductores.
-- Es idempotente respecto de las políticas cuyo nombre comienza con traut_admin_.

begin;

create or replace function public.is_admin()
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (
    select 1
    from public.profiles
    where id = (select auth.uid())
      and role = 'admin'
  );
$$;

comment on function public.is_admin() is
  'Comprueba el rol del usuario autenticado sin depender de metadata editable del JWT.';

revoke all on function public.is_admin() from public, anon;
grant execute on function public.is_admin() to authenticated;

alter table public.profiles enable row level security;
alter table public.routes enable row level security;
alter table public.stops enable row level security;
alter table public.drivers enable row level security;
alter table public.vehicles enable row level security;
alter table public.vehicle_locations enable row level security;
alter table public.trips enable row level security;
alter table public.incidents enable row level security;

-- Acceso mínimo a la Data API. RLS sigue decidiendo qué filas puede usar cada
-- persona. Estos GRANT por columna no revocan permisos históricos: antes de
-- aplicar, revisar information_schema.role_table_grants y
-- information_schema.column_privileges en el repositorio canónico.
grant select (id, full_name, email, role, avatar_preset)
  on public.profiles to authenticated;
grant select (id, name, origin, destination, color, active, created_at),
  insert (name, origin, destination, color, active),
  update (name, origin, destination, color, active)
  on public.routes to authenticated;
grant select (id, route_id, name, latitude, longitude, stop_order, fare),
  insert (route_id, name, latitude, longitude, stop_order, fare),
  update (route_id, name, latitude, longitude, stop_order, fare),
  delete on public.stops to authenticated;
grant select (id, profile_id, license_number, status, created_at),
  update (license_number, status)
  on public.drivers to authenticated;
grant select (id, code, plate, status, route_id, driver_id, created_at),
  insert (code, plate, status, route_id, driver_id),
  update (code, plate, status, route_id, driver_id)
  on public.vehicles to authenticated;
grant select (vehicle_id, latitude, longitude, speed, heading, updated_at)
  on public.vehicle_locations to authenticated;
grant select (id, vehicle_id, route_id, driver_id, status, started_at, ended_at, created_at),
  update (status)
  on public.trips to authenticated;
grant select (id, vehicle_id, driver_id, type, description, status, created_at),
  update (status)
  on public.incidents to authenticated;

drop policy if exists traut_admin_select_profiles on public.profiles;
create policy traut_admin_select_profiles
on public.profiles for select to authenticated
using ((select public.is_admin()));

-- No se concede UPDATE administrativo sobre profiles: el cliente no puede cambiar roles.

drop policy if exists traut_admin_select_routes on public.routes;
create policy traut_admin_select_routes
on public.routes for select to authenticated
using ((select public.is_admin()));
drop policy if exists traut_admin_insert_routes on public.routes;
create policy traut_admin_insert_routes
on public.routes for insert to authenticated
with check ((select public.is_admin()));
drop policy if exists traut_admin_update_routes on public.routes;
create policy traut_admin_update_routes
on public.routes for update to authenticated
using ((select public.is_admin()))
with check ((select public.is_admin()));

drop policy if exists traut_admin_select_stops on public.stops;
create policy traut_admin_select_stops
on public.stops for select to authenticated
using ((select public.is_admin()));
drop policy if exists traut_admin_insert_stops on public.stops;
create policy traut_admin_insert_stops
on public.stops for insert to authenticated
with check ((select public.is_admin()));
drop policy if exists traut_admin_update_stops on public.stops;
create policy traut_admin_update_stops
on public.stops for update to authenticated
using ((select public.is_admin()))
with check ((select public.is_admin()));
drop policy if exists traut_admin_delete_stops on public.stops;
create policy traut_admin_delete_stops
on public.stops for delete to authenticated
using ((select public.is_admin()));

drop policy if exists traut_admin_select_drivers on public.drivers;
create policy traut_admin_select_drivers
on public.drivers for select to authenticated
using ((select public.is_admin()));
drop policy if exists traut_admin_update_drivers on public.drivers;
create policy traut_admin_update_drivers
on public.drivers for update to authenticated
using ((select public.is_admin()))
with check ((select public.is_admin()));

drop policy if exists traut_admin_select_vehicles on public.vehicles;
create policy traut_admin_select_vehicles
on public.vehicles for select to authenticated
using ((select public.is_admin()));
drop policy if exists traut_admin_insert_vehicles on public.vehicles;
create policy traut_admin_insert_vehicles
on public.vehicles for insert to authenticated
with check ((select public.is_admin()));
drop policy if exists traut_admin_update_vehicles on public.vehicles;
create policy traut_admin_update_vehicles
on public.vehicles for update to authenticated
using ((select public.is_admin()))
with check ((select public.is_admin()));

drop policy if exists traut_admin_select_vehicle_locations on public.vehicle_locations;
create policy traut_admin_select_vehicle_locations
on public.vehicle_locations for select to authenticated
using ((select public.is_admin()));

drop policy if exists traut_admin_select_trips on public.trips;
create policy traut_admin_select_trips
on public.trips for select to authenticated
using ((select public.is_admin()));
drop policy if exists traut_admin_update_trips on public.trips;
create policy traut_admin_update_trips
on public.trips for update to authenticated
using ((select public.is_admin()))
with check ((select public.is_admin()));

drop policy if exists traut_admin_select_incidents on public.incidents;
create policy traut_admin_select_incidents
on public.incidents for select to authenticated
using ((select public.is_admin()));
drop policy if exists traut_admin_update_incidents on public.incidents;
create policy traut_admin_update_incidents
on public.incidents for update to authenticated
using ((select public.is_admin()))
with check ((select public.is_admin()));

commit;
