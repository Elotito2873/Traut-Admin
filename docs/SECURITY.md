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

1. crea y valida manualmente el primer administrador;
2. inicia sesión como ese administrador;
3. verifica en **Authentication → Multi-Factor** que TOTP esté disponible y
   enróllalo con `REQUIRE_ADMIN_MFA=true`;
4. completa un challenge y confirma que el JWT reporta `aal = aal2`;
5. recién entonces considera aplicar manualmente `004_require_admin_aal2.sql`;
6. compila releases con `REQUIRE_ADMIN_MFA=true`.

La policy restrictiva exige AAL2 solamente cuando `public.is_admin()` es
verdadero, por lo que no agrega el requisito a pasajeros ni conductores. Los RPC
sensibles también validan admin y AAL2. Después de cada challenge Flutter vuelve
a leer sesión, perfil, rol y assurance level; un rol revocado durante el
challenge no obtiene acceso.

La Edge Function `invite-driver` exige AAL2 aunque el cliente se haya compilado
sin enrolamiento forzoso, porque crear Auth users es una acción sensible.

## Edge Function

`invite-driver` usa auth de usuario, vuelve a consultar `profiles.role`, exige
AAL2, valida el body y solo entonces usa `ctx.supabaseAdmin`. La respuesta no
devuelve datos privados. La secret key es inyectada por Supabase y no se configura
en Flutter/GitHub Actions.

No se ha verificado si la función está desplegada. Antes de desplegarla desde un
entorno autorizado, define `DRIVER_INVITE_REDIRECT_URL` con el callback HTTPS
real de Traut Conductor y `ADMIN_ALLOWED_ORIGINS` con los orígenes exactos de
Web Admin separados por comas. La función niega peticiones Web con `Origin` no
permitido; desktop sin `Origin` continúa usando JWT, role y AAL2. No incluyas
dominios ficticios.

Configura la URL de redirección de invitaciones en **Authentication → URL
Configuration** para el flujo real de Traut Conductor, no para Traut Admin ni
Traut Usuario. Si falta, la función falla sin mostrar secretos. Correos existentes
con otro rol no se convierten implícitamente; duplicados devuelven conflicto.
`drivers.id` lo genera PostgreSQL.
El envío del correo no es transaccional: no puede des-enviarse si falla una
escritura posterior. La función hace rollback compensatorio de datos y ofrece
un camino de reparación idempotente para un perfil `driver` incompleto.

## Sesiones y roles

El rol se lee desde `profiles`, nunca desde `user_metadata`. El cliente no tiene
política para modificar `profiles.role`. Si se revoca un administrador, revoca
también sus sesiones o usa JWT de corta duración; cambiar una fila no invalida un
access token ya emitido.

Flutter no recibe `UPDATE` sobre `profiles`; no existe formulario ni repositorio
que escriba `role`. Solo `invite-driver`, en contexto privilegiado de servidor y
después de autenticar admin+AAL2, puede crear el perfil `driver`.

## Auditoría e inactividad

Los triggers nombran operaciones de flota, rutas, paradas, tarifas, conductores,
incidencias y viajes. La Edge Function registra invitaciones. La metadata se
limita a origen y transiciones de estado; nunca guarda JWT, passwords, tokens,
secret keys ni filas completas.

Tras el timeout configurable (20 minutos por defecto), la interfaz queda bajo
una barrera. Con TOTP conserva el árbol de formularios y exige otro challenge;
sin TOTP cierra sesión para requerir reautenticación. No se guarda la contraseña.
No se persiste refresh token en disco ni se reintentan escrituras offline. Tras
un timeout de escritura, comprueba el resultado antes de reintentar.

La detección manual de unidades sin señal entra por el RPC público protegido con
admin+AAL2. Un scheduler de PostgreSQL carece de ese JWT: debe llamar al worker
homónimo del schema `private` bajo un rol de base de datos confiable. Ese worker
no es ejecutable por `public`, `anon` ni `authenticated`, solo modifica unidades
`active`, usa `now()` y registra una auditoría mínima por unidad. No se expone
`service_role` en Flutter y la propuesta no crea jobs automáticamente.

## Tiles OpenStreetMap

El template es configurable. El servidor público de OSM es adecuado para
desarrollo con atribución e identificación del cliente, pero una distribución de
alto tráfico debe usar tiles autoalojados o un proveedor compatible cuya política
permita ese volumen. No se requiere contratar una API de pago.
