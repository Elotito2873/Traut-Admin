-- PROPUESTA: campos aditivos para conservar el seguimiento de incidencias.
-- La aplicación funciona con el esquema actual, pero sin estos campos únicamente
-- puede persistir status. Aplicar en el repositorio canónico para guardar notas.

begin;

alter table public.incidents
  add column if not exists updated_at timestamptz not null default now(),
  add column if not exists resolved_at timestamptz,
  add column if not exists resolution_notes text;

create index if not exists incidents_status_created_at_idx
  on public.incidents (status, created_at desc);

grant select (updated_at, resolved_at, resolution_notes),
  update (resolution_notes)
  on public.incidents to authenticated;

create schema if not exists private;
revoke all on schema private from public, anon, authenticated;

create or replace function private.set_incident_server_timestamps()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  new.updated_at := now();
  if tg_op = 'INSERT' then
    if new.status = 'resolved' and new.resolved_at is null then
      new.resolved_at := now();
    elsif new.status is distinct from 'resolved' then
      new.resolved_at := null;
    end if;
  else
    if new.status = 'resolved' and old.status is distinct from 'resolved' then
      new.resolved_at := now();
    elsif new.status is distinct from 'resolved' then
      new.resolved_at := null;
    end if;
  end if;
  return new;
end;
$$;

revoke all on function private.set_incident_server_timestamps()
  from public, anon, authenticated;

drop trigger if exists traut_set_incident_server_timestamps on public.incidents;
create trigger traut_set_incident_server_timestamps
before insert or update on public.incidents
for each row execute function private.set_incident_server_timestamps();

commit;
