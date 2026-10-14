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
begin
  if not public.is_admin() then
    return coalesce(new, old);
  end if;

  target_id := case when tg_op = 'DELETE' then old.id else new.id end;

  insert into public.audit_logs (
    admin_user_id,
    action,
    entity_type,
    entity_id,
    metadata
  ) values (
    (select auth.uid()),
    lower(tg_op),
    tg_table_name,
    target_id,
    jsonb_build_object('source', 'database_trigger')
  );

  return coalesce(new, old);
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
