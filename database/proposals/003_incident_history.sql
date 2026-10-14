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

commit;
