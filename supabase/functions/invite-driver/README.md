# invite-driver

Función de servidor para invitar exclusivamente cuentas con rol `driver`.
Valida JWT, AAL2 y `profiles.role = 'admin'` antes de usar el cliente privilegiado.

No se despliega desde este repositorio automáticamente y aquí no se ha
comprobado su estado remoto. Las propuestas 001/002/003/006/007/008/005 ya
están incorporadas al historial canónico de Komport según el contexto del
proyecto; 004 sigue pendiente.

`DRIVER_INVITE_REDIRECT_URL` debe apuntar al callback real de **Traut
Conductor**, nunca a Traut Usuario ni a este panel. La función falla de forma
cerrada si falta o no es HTTPS (solo acepta HTTP para localhost). Añade el mismo
destino a la allowlist de **Authentication → URL Configuration**.

`ADMIN_ALLOWED_ORIGINS` debe contener los orígenes HTTPS exactos del Web Admin
separados por comas. Si no se configura, las peticiones Web con `Origin` se
rechazan; los clientes desktop sin `Origin` continúan sujetos a JWT, admin y
AAL2. No usar `*`. El body está limitado a 4096 caracteres, email a 254,
nombre a 120 y licencia a 80.

Si el email ya es conductor, responde conflicto. Si existe con otro rol, no lo
convierte implícitamente. Un perfil ya marcado `driver` pero incompleto puede
repararse con un `INSERT` auditado; PostgreSQL genera el UUID y `profile_id`
permanece estable.

La invitación por correo no puede des-enviarse si una escritura posterior
falla. El rollback compensatorio elimina los registros cuando es seguro hacerlo;
antes de reintentar revisa si el email ya fue invitado o necesita reparación.

Validación local sin secretos: `deno check supabase/functions/invite-driver/index.ts`
y `deno test supabase/functions/invite-driver/index_test.ts`.

El entorno administrado de Supabase inyecta las claves del proyecto. No agregues
`service_role`, secret keys ni credenciales a archivos locales o GitHub Actions.
