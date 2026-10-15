-- PROPUESTA: auditoría persistente de cambios administrativos.
-- Aditiva e idempotente. No guarda contraseñas, tokens ni filas completas.
-- Requiere 001_admin_rls.sql.

begin;

create table if not exists public.audit_logs (
  id uuid primary key default gen_random_uuid(),
  admin_user_id uuid references public.profiles(id) on delete set null,
  action text not null,
  entity_type text not null,
  entity_id uuid,
  metadata jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now()
);

comment on table public.audit_logs is
  'Registro inmutable de acciones administrativas sensibles.';

create index if not exists audit_logs_created_at_idx
  on public.audit_logs (created_at desc);
create index if not exists audit_logs_entity_idx
  on public.audit_logs (entity_type, entity_id);
create index if not exists audit_logs_admin_idx
  on public.audit_logs (admin_user_id, created_at desc);

alter table public.audit_logs enable row level security;
revoke all on public.audit_logs from public, anon, authenticated;
grant select on public.audit_logs to authenticated;

drop policy if exists traut_admin_select_audit_logs on public.audit_logs;
create policy traut_admin_select_audit_logs
on public.audit_logs for select to authenticated
using ((select public.is_admin()));

create schema if not exists private;
revoke all on schema private from public, anon, authenticated;

create or replace function private.audit_admin_change()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  target_id uuid;
  old_row jsonb := case when tg_op = 'INSERT' then '{}'::jsonb else to_jsonb(old) end;
  new_row jsonb := case when tg_op = 'DELETE' then '{}'::jsonb else to_jsonb(new) end;
  action_name text;
  safe_metadata jsonb := jsonb_build_object('source', 'database_trigger');
begin
  if not public.is_admin() then
    return null;
  end if;

  -- Las fases técnicas intermedias de un RPC no representan una acción final.
  if current_setting('traut.audit_phase', true) = 'temporary' then
    return null;
  end if;

  -- Un UPDATE sin cambios efectivos no es una acción administrativa auditable.
  if tg_op = 'UPDATE' and old_row = new_row then
    return null;
  end if;

  target_id := case when tg_op = 'DELETE' then old.id else new.id end;
  action_name := case
    when tg_table_name = 'vehicles' and tg_op = 'INSERT' then 'create_vehicle'
    when tg_table_name = 'vehicles'
      and (old_row -> 'driver_id') is distinct from (new_row -> 'driver_id')
      then case
        when new_row ->> 'driver_id' is null then 'unassign_driver'
        when old_row ->> 'driver_id' is null then 'assign_driver'
        else 'change_vehicle_driver'
      end
    when tg_table_name = 'vehicles' and (old_row -> 'status') is distinct from (new_row -> 'status')
      then 'change_vehicle_status'
    when tg_table_name = 'vehicles' then 'edit_vehicle'
    when tg_table_name = 'routes' and tg_op = 'INSERT' then 'create_route'
    when tg_table_name = 'routes' and (old_row -> 'active') is distinct from (new_row -> 'active')
      then 'change_route_activation'
    when tg_table_name = 'routes' then 'edit_route'
    when tg_table_name = 'stops' and tg_op = 'INSERT' then 'create_stop'
    when tg_table_name = 'stops' and tg_op = 'DELETE' then 'delete_stop'
    when tg_table_name = 'stops' and (old_row -> 'fare') is distinct from (new_row -> 'fare')
      then 'change_stop_fare'
    when tg_table_name = 'stops' and (old_row -> 'stop_order') is distinct from (new_row -> 'stop_order')
      then 'reorder_stop'
    when tg_table_name = 'stops' then 'edit_stop'
    when tg_table_name = 'drivers' and (old_row -> 'status') is distinct from (new_row -> 'status')
      then 'change_driver_status'
    when tg_table_name = 'drivers' then 'edit_driver'
    when tg_table_name = 'incidents' and (old_row -> 'status') is distinct from (new_row -> 'status')
      then 'change_incident_status'
    when tg_table_name = 'incidents' then 'edit_incident'
    when tg_table_name = 'trips' and (old_row -> 'status') is distinct from (new_row -> 'status')
      then 'change_trip_status'
    else lower(tg_op)
  end;

  if (old_row -> 'status') is distinct from (new_row -> 'status') then
    safe_metadata := safe_metadata || jsonb_build_object(
      'previous_status', old_row -> 'status',
      'new_status', new_row -> 'status'
    );
  end if;

  insert into public.audit_logs (
    admin_user_id,
    action,
    entity_type,
    entity_id,
    metadata
  ) values (
    (select auth.uid()),
    action_name,
    tg_table_name,
    target_id,
    safe_metadata
  );

  return null;
end;
$$;

revoke all on function private.audit_admin_change() from public, anon, authenticated;

do $$
declare
  table_name text;
begin
  foreach table_name in array array[
    'routes', 'stops', 'drivers', 'vehicles', 'trips', 'incidents'
  ] loop
    execute format(
      'drop trigger if exists traut_admin_audit_change on public.%I',
      table_name
    );
    execute format(
      'create trigger traut_admin_audit_change after insert or update or delete on public.%I for each row execute function private.audit_admin_change()',
      table_name
    );
  end loop;
end;
$$;

commit;
