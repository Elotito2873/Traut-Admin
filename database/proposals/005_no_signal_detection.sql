-- PROPUESTA: operación segura para marcar unidades activas sin señal reciente.
-- Separa la llamada manual admin+AAL2 del worker interno para un scheduler de BD.
-- No crea ningún schedule y nunca reactiva unidades de forma automática.
-- Requiere 002_audit_logs.sql.

begin;

create schema if not exists private;
revoke all on schema private from public, anon, authenticated;

create or replace function private.mark_stale_vehicles_no_signal(
  stale_after interval default interval '5 minutes'
)
returns integer
language plpgsql
security definer
set search_path = ''
as $$
declare
  affected integer;
begin
  if stale_after is null or stale_after < interval '1 minute' then
    raise exception 'stale_after must be at least one minute'
      using errcode = '22023';
  end if;

  -- El trigger genérico se omite durante el cambio y se inserta un evento seguro
  -- por unidad, válido tanto para el wrapper manual como para el scheduler.
  perform set_config('traut.audit_phase', 'temporary', true);
  with changed as (
    update public.vehicles as vehicle
    set status = 'no_signal'
    where vehicle.status = 'active'
      and not exists (
        select 1
        from public.vehicle_locations as location
        where location.vehicle_id = vehicle.id
          and location.updated_at >= now() - stale_after
      )
    returning vehicle.id
  ), logged as (
    insert into public.audit_logs (
      admin_user_id,
      action,
      entity_type,
      entity_id,
      metadata
    )
    select
      (select auth.uid()),
      'mark_vehicle_no_signal',
      'vehicles',
      changed.id,
      jsonb_build_object(
        'source', case
          when (select auth.uid()) is null then 'database_scheduler'
          else 'admin_rpc'
        end,
        'previous_status', 'active',
        'new_status', 'no_signal'
      )
    from changed
    returning 1
  )
  select count(*)::integer into affected from logged;
  perform set_config('traut.audit_phase', 'final', true);

  return affected;
end;
$$;

comment on function private.mark_stale_vehicles_no_signal(interval) is
  'Worker interno para scheduler confiable; usa reloj de BD y audita cada cambio.';
revoke all on function private.mark_stale_vehicles_no_signal(interval)
  from public, anon, authenticated;

create or replace function public.mark_stale_vehicles_no_signal(
  stale_after interval default interval '5 minutes'
)
returns integer
language plpgsql
security definer
set search_path = ''
as $$
begin
  if not public.is_admin() then
    raise exception 'admin authorization required' using errcode = '42501';
  end if;

  if coalesce((select auth.jwt()) ->> 'aal', 'aal1') <> 'aal2' then
    raise exception 'aal2 authorization required' using errcode = '42501';
  end if;

  return private.mark_stale_vehicles_no_signal(stale_after);
end;
$$;

revoke all on function public.mark_stale_vehicles_no_signal(interval)
  from public, anon, authenticated;
grant execute on function public.mark_stale_vehicles_no_signal(interval)
  to authenticated;

commit;
