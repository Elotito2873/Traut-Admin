-- PROPUESTA: timestamps operativos de viajes calculados por PostgreSQL.

begin;

create schema if not exists private;
revoke all on schema private from public, anon, authenticated;

create or replace function private.set_trip_server_timestamps()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  if new.status = 'active' then
    new.ended_at := null;
  elsif new.status in ('finished', 'cancelled') then
    if tg_op = 'INSERT' then
      -- Ignora cualquier timestamp recibido del cliente al crear o terminar.
      new.ended_at := now();
    elsif old.status is null
       or old.status not in ('finished', 'cancelled')
       or old.ended_at is null then
      new.ended_at := now();
    else
      -- Un UPDATE posterior no puede reemplazar el valor ya generado por BD.
      new.ended_at := old.ended_at;
    end if;
  end if;
  return new;
end;
$$;

revoke all on function private.set_trip_server_timestamps()
  from public, anon, authenticated;

drop trigger if exists traut_set_trip_server_timestamps on public.trips;
create trigger traut_set_trip_server_timestamps
before insert or update on public.trips
for each row execute function private.set_trip_server_timestamps();

commit;
