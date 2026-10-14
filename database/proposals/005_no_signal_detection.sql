-- PROPUESTA: operación segura para marcar unidades activas sin señal reciente.
-- No se agenda automáticamente. Configurar Supabase Cron manualmente solo después
-- de acordar el umbral operativo. Nunca reactiva unidades de forma automática.

begin;

create or replace function public.mark_stale_vehicles_no_signal(
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
  if not public.is_admin() then
    raise exception 'admin authorization required' using errcode = '42501';
  end if;

  if stale_after < interval '1 minute' then
    raise exception 'stale_after must be at least one minute';
  end if;

  update public.vehicles as vehicle
  set status = 'no_signal'
  where vehicle.status = 'active'
    and not exists (
      select 1
      from public.vehicle_locations as location
      where location.vehicle_id = vehicle.id
        and location.updated_at >= now() - stale_after
    );

  get diagnostics affected = row_count;
  return affected;
end;
$$;

revoke all on function public.mark_stale_vehicles_no_signal(interval)
  from public, anon;
grant execute on function public.mark_stale_vehicles_no_signal(interval)
  to authenticated;

commit;
