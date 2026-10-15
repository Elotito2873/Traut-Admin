-- PROPUESTA: RPC transaccionales para asignaciones y reordenamiento.
-- Requiere 001_admin_rls.sql y se recomienda aplicar después de 002.
-- Los tres RPC exigen que el administrador ya tenga una sesión AAL2.
-- No ejecutar sin revisar primero las consultas de preflight de DATABASE.md.

begin;

do $$
begin
  if exists (
    select 1
    from public.vehicles
    where driver_id is not null
    group by driver_id
    having count(*) > 1
  ) then
    raise exception 'vehicles contains duplicate non-null driver_id assignments';
  end if;

  if exists (
    select 1
    from public.stops
    group by route_id, stop_order
    having count(*) > 1
  ) then
    raise exception 'stops contains duplicate route_id/stop_order pairs';
  end if;
end;
$$;

create unique index if not exists vehicles_one_driver_assignment_idx
  on public.vehicles (driver_id)
  where driver_id is not null;

create unique index if not exists stops_route_stop_order_unique_idx
  on public.stops (route_id, stop_order);

create or replace function public.assign_driver_to_vehicle(
  p_driver_id uuid,
  p_vehicle_id uuid
)
returns void
language plpgsql
security invoker
set search_path = ''
as $$
begin
  if not public.is_admin() then
    raise exception 'admin authorization required' using errcode = '42501';
  end if;
  if coalesce((select auth.jwt()) ->> 'aal', 'aal1') <> 'aal2' then
    raise exception 'aal2 authorization required' using errcode = '42501';
  end if;
  if p_driver_id is null then
    raise exception 'driver id is required' using errcode = '22023';
  end if;

  perform 1 from public.drivers where id = p_driver_id for update;
  if not found then
    raise exception 'driver not found' using errcode = 'P0002';
  end if;

  if p_vehicle_id is not null then
    perform 1 from public.vehicles where id = p_vehicle_id for update;
    if not found then
      raise exception 'vehicle not found' using errcode = 'P0002';
    end if;
  end if;

  update public.vehicles
  set driver_id = null
  where driver_id = p_driver_id
    and (p_vehicle_id is null or id <> p_vehicle_id);

  if p_vehicle_id is not null then
    update public.vehicles
    set driver_id = p_driver_id
    where id = p_vehicle_id
      and driver_id is distinct from p_driver_id;
  end if;
end;
$$;

comment on function public.assign_driver_to_vehicle(uuid, uuid) is
  'Asigna o desasigna un conductor de forma atómica; exige admin AAL2.';
revoke all on function public.assign_driver_to_vehicle(uuid, uuid)
  from public, anon;
grant execute on function public.assign_driver_to_vehicle(uuid, uuid)
  to authenticated;

create or replace function public.save_vehicle_with_assignment(
  p_vehicle_id uuid,
  p_code text,
  p_plate text,
  p_status text,
  p_route_id uuid,
  p_driver_id uuid
)
returns uuid
language plpgsql
security invoker
set search_path = ''
as $$
declare
  saved_id uuid;
  previous_driver_id uuid;
begin
  if not public.is_admin() then
    raise exception 'admin authorization required' using errcode = '42501';
  end if;
  if coalesce((select auth.jwt()) ->> 'aal', 'aal1') <> 'aal2' then
    raise exception 'aal2 authorization required' using errcode = '42501';
  end if;
  if nullif(btrim(p_code), '') is null or nullif(btrim(p_plate), '') is null then
    raise exception 'code and plate are required' using errcode = '22023';
  end if;
  if p_status not in ('active', 'inactive', 'maintenance', 'no_signal') then
    raise exception 'invalid vehicle status' using errcode = '22023';
  end if;
  if p_route_id is not null and not exists (
    select 1 from public.routes where id = p_route_id
  ) then
    raise exception 'route not found' using errcode = 'P0002';
  end if;
  if p_driver_id is not null then
    perform 1 from public.drivers where id = p_driver_id for update;
    if not found then
      raise exception 'driver not found' using errcode = 'P0002';
    end if;
  end if;

  if p_vehicle_id is null then
    insert into public.vehicles (code, plate, status, route_id, driver_id)
    values (
      upper(btrim(p_code)), upper(btrim(p_plate)), p_status, p_route_id, null
    )
    returning id into saved_id;
    previous_driver_id := null;
  else
    select driver_id
    into previous_driver_id
    from public.vehicles
    where id = p_vehicle_id
    for update;
    if not found then
      raise exception 'vehicle not found' using errcode = 'P0002';
    end if;
    saved_id := p_vehicle_id;
    update public.vehicles
    set code = upper(btrim(p_code)),
        plate = upper(btrim(p_plate)),
        status = p_status,
        route_id = p_route_id
    where id = saved_id
      and (code, plate, status, route_id) is distinct from (
        upper(btrim(p_code)), upper(btrim(p_plate)), p_status, p_route_id
      );
  end if;

  if previous_driver_id is distinct from p_driver_id then
    if p_driver_id is not null then
      update public.vehicles
      set driver_id = null
      where driver_id = p_driver_id and id <> saved_id;
    end if;

    update public.vehicles
    set driver_id = p_driver_id
    where id = saved_id
      and driver_id is distinct from p_driver_id;
  end if;

  return saved_id;
end;
$$;

comment on function public.save_vehicle_with_assignment(uuid, text, text, text, uuid, uuid) is
  'Crea/edita una unidad y su asignación en una sola transacción; exige admin AAL2.';
revoke all on function public.save_vehicle_with_assignment(uuid, text, text, text, uuid, uuid)
  from public, anon;
grant execute on function public.save_vehicle_with_assignment(uuid, text, text, text, uuid, uuid)
  to authenticated;

create or replace function public.reorder_route_stops(
  p_route_id uuid,
  p_stop_ids uuid[]
)
returns void
language plpgsql
security invoker
set search_path = ''
as $$
declare
  supplied_count integer := coalesce(cardinality(p_stop_ids), 0);
  route_count integer;
  temporary_base integer;
begin
  if not public.is_admin() then
    raise exception 'admin authorization required' using errcode = '42501';
  end if;
  if coalesce((select auth.jwt()) ->> 'aal', 'aal1') <> 'aal2' then
    raise exception 'aal2 authorization required' using errcode = '42501';
  end if;
  if p_route_id is null or supplied_count = 0 or array_position(p_stop_ids, null) is not null then
    raise exception 'route and stop ids are required' using errcode = '22023';
  end if;
  if (select count(distinct id) from unnest(p_stop_ids) as ids(id)) <> supplied_count then
    raise exception 'duplicate stop ids are not allowed' using errcode = '22023';
  end if;

  perform 1 from public.routes where id = p_route_id for update;
  if not found then
    raise exception 'route not found' using errcode = 'P0002';
  end if;

  perform 1
  from public.stops
  where route_id = p_route_id
  for update;

  select count(*), coalesce(max(stop_order), 0) + supplied_count
  into route_count, temporary_base
  from public.stops
  where route_id = p_route_id;

  if route_count <> supplied_count or exists (
    select 1
    from unnest(p_stop_ids) as ids(id)
    left join public.stops as stop
      on stop.id = ids.id and stop.route_id = p_route_id
    where stop.id is null
  ) then
    raise exception 'stop list must match the complete expected route' using errcode = '22023';
  end if;

  perform set_config('traut.audit_phase', 'temporary', true);
  update public.stops as stop
  set stop_order = temporary_base + ordered.position::integer
  from unnest(p_stop_ids) with ordinality as ordered(id, position)
  where stop.id = ordered.id and stop.route_id = p_route_id;

  perform set_config('traut.audit_phase', 'final', true);
  update public.stops as stop
  set stop_order = ordered.position::integer
  from unnest(p_stop_ids) with ordinality as ordered(id, position)
  where stop.id = ordered.id and stop.route_id = p_route_id;
end;
$$;

comment on function public.reorder_route_stops(uuid, uuid[]) is
  'Reordena el conjunto completo de paradas de una ruta atómicamente; exige admin AAL2.';
revoke all on function public.reorder_route_stops(uuid, uuid[])
  from public, anon;
grant execute on function public.reorder_route_stops(uuid, uuid[])
  to authenticated;

commit;
