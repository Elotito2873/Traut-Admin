# Seguridad

## Modelo de confianza

Flutter recibe únicamente `SUPABASE_URL` y `SUPABASE_PUBLISHABLE_KEY`. Ambas
identifican el proyecto, pero no sustituyen autorización. Cada lectura/escritura
queda restringida por JWT, RLS y `public.is_admin()`.

Nunca agregues al cliente, repositorio o variables de build:

- secret key / `service_role`;
- contraseña de Postgres;
- secretos TOTP;
- claves privadas o Client Secrets.

## Primer administrador

No existe registro público de administradores. Procedimiento manual recomendado:

1. crea el usuario en **Supabase Dashboard → Authentication → Users**;
2. copia su UUID y verifica personalmente la identidad;
3. desde SQL Editor, en una sesión administrativa, cambia el perfil exacto:

```sql
begin;
update public.profiles
set role = 'admin'
where id = 'UUID_CONFIRMADO'
  and email = 'correo-confirmado@example.com';
commit;
```

Confirma que se actualizó exactamente una fila. Nunca expongas un RPC genérico
para asignar `admin`.

## MFA

TOTP usa exclusivamente `auth.mfa.enroll`, `challengeAndVerify` y assurance level
de Supabase. La app no persiste secretos TOTP. Para exigirlo:

1. verifica en **Authentication → Multi-Factor** que TOTP esté disponible;
2. ejecuta temporalmente con `REQUIRE_ADMIN_MFA=true` y enrola todos los admins;
3. aplica la propuesta opcional `004_require_admin_aal2.sql`;
4. configura CI/release para compilar con `REQUIRE_ADMIN_MFA=true`.

La Edge Function `invite-driver` exige AAL2 aunque el cliente se haya compilado
sin enrolamiento forzoso, porque crear Auth users es una acción sensible.

## Edge Function

`invite-driver` usa auth de usuario, vuelve a consultar `profiles.role`, exige
AAL2, valida el body y solo entonces usa `ctx.supabaseAdmin`. La respuesta no
devuelve datos privados. La secret key es inyectada por Supabase y no se configura
en Flutter/GitHub Actions.

Despliega manualmente después de aplicar `audit_logs`:

```bash
supabase functions deploy invite-driver
```

Configura la URL de redirección de invitaciones en **Authentication → URL
Configuration** para el flujo real del conductor, no para Traut Admin.

## Sesiones y roles

El rol se lee desde `profiles`, nunca desde `user_metadata`. El cliente no tiene
política para modificar `profiles.role`. Si se revoca un administrador, revoca
también sus sesiones o usa JWT de corta duración; cambiar una fila no invalida un
access token ya emitido.

## Tiles OpenStreetMap

El template es configurable. El servidor público de OSM es adecuado para
desarrollo con atribución e identificación del cliente, pero una distribución de
alto tráfico debe usar tiles autoalojados o un proveedor compatible cuya política
permita ese volumen. No se requiere contratar una API de pago.
