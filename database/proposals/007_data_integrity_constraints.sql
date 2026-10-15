-- PROPUESTA: validaciones aditivas en la base de datos.
-- El bloque de preflight aborta la transacción completa si existen datos que
-- incumplen las reglas; no corrige ni elimina filas automáticamente.

begin;

do $$
begin
  if exists (select 1 from public.stops where stop_order <= 0) then
    raise exception 'stops.stop_order contains values <= 0';
  end if;
  if exists (select 1 from public.stops where fare < 0) then
    raise exception 'stops.fare contains negative values';
  end if;
  if exists (select 1 from public.stops where latitude not between -90 and 90) then
    raise exception 'stops.latitude contains out-of-range values';
  end if;
  if exists (select 1 from public.stops where longitude not between -180 and 180) then
    raise exception 'stops.longitude contains out-of-range values';
  end if;
  if exists (select 1 from public.vehicles where nullif(btrim(code), '') is null) then
    raise exception 'vehicles.code contains empty values';
  end if;
  if exists (select 1 from public.vehicles where nullif(btrim(plate), '') is null) then
    raise exception 'vehicles.plate contains empty values';
  end if;
end;
$$;

do $$
begin
  if not exists (
    select 1 from pg_constraint
    where conname = 'stops_stop_order_positive'
      and conrelid = 'public.stops'::regclass
  ) then
    alter table public.stops add constraint stops_stop_order_positive check (stop_order > 0);
  end if;
  if not exists (
    select 1 from pg_constraint
    where conname = 'stops_fare_nonnegative'
      and conrelid = 'public.stops'::regclass
  ) then
    alter table public.stops add constraint stops_fare_nonnegative check (fare >= 0);
  end if;
  if not exists (
    select 1 from pg_constraint
    where conname = 'stops_latitude_range'
      and conrelid = 'public.stops'::regclass
  ) then
    alter table public.stops add constraint stops_latitude_range check (latitude between -90 and 90);
  end if;
  if not exists (
    select 1 from pg_constraint
    where conname = 'stops_longitude_range'
      and conrelid = 'public.stops'::regclass
  ) then
    alter table public.stops add constraint stops_longitude_range check (longitude between -180 and 180);
  end if;
  if not exists (
    select 1 from pg_constraint
    where conname = 'vehicles_code_not_empty'
      and conrelid = 'public.vehicles'::regclass
  ) then
    alter table public.vehicles add constraint vehicles_code_not_empty check (nullif(btrim(code), '') is not null);
  end if;
  if not exists (
    select 1 from pg_constraint
    where conname = 'vehicles_plate_not_empty'
      and conrelid = 'public.vehicles'::regclass
  ) then
    alter table public.vehicles add constraint vehicles_plate_not_empty check (nullif(btrim(plate), '') is not null);
  end if;
end;
$$;

-- No reemplazar un default canónico existente. Solo permite que el INSERT de
-- invite-driver omita el UUID cuando la tabla aún no tiene default.
do $$
begin
  if not exists (
    select 1
    from pg_attrdef
    where adrelid = 'public.drivers'::regclass
      and adnum = (
        select attnum from pg_attribute
        where attrelid = 'public.drivers'::regclass
          and attname = 'id'
          and not attisdropped
      )
  ) then
    alter table public.drivers alter column id set default gen_random_uuid();
  end if;
end;
$$;

commit;
