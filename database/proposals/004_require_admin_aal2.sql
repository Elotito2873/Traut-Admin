-- PROPUESTA OPCIONAL: exigir MFA (AAL2) a administradores en la base de datos.
-- Requiere 001_admin_rls.sql. Las políticas RESTRICTIVE no alteran el acceso de
-- pasajeros/conductores: solo agregan AAL2 cuando public.is_admin() es verdadero.
-- Revisar primero que todos los administradores hayan enrolado TOTP y que su
-- sesión ya reporte auth.jwt()->>'aal' = 'aal2'. Aplicar al final.

begin;

do $$
declare
  table_name text;
begin
  foreach table_name in array array[
    'profiles', 'routes', 'stops', 'drivers', 'vehicles',
    'vehicle_locations', 'trips', 'incidents', 'audit_logs'
  ] loop
    if to_regclass(format('public.%I', table_name)) is not null then
      execute format(
        'drop policy if exists traut_admin_require_aal2 on public.%I',
        table_name
      );
      execute format(
        'create policy traut_admin_require_aal2 on public.%I as restrictive for all to authenticated using ((not (select public.is_admin())) or ((select auth.jwt()) ->> ''aal'') = ''aal2'') with check ((not (select public.is_admin())) or ((select auth.jwt()) ->> ''aal'') = ''aal2'')',
        table_name
      );
    end if;
  end loop;
end;
$$;

commit;
