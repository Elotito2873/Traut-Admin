# invite-driver

Función de servidor para invitar exclusivamente cuentas con rol `driver`.
Valida JWT, AAL2 y `profiles.role = 'admin'` antes de usar el cliente privilegiado.

No se despliega desde este repositorio automáticamente. Después de incorporar y
aplicar las propuestas SQL canónicas:

```bash
supabase secrets set \
  DRIVER_INVITE_REDIRECT_URL=https://conductor.example.com/auth/accept-invite
supabase functions deploy invite-driver
```

`DRIVER_INVITE_REDIRECT_URL` debe apuntar al callback de la futura app **Traut
Conductor**, nunca a Traut Usuario ni a este panel. La función falla de forma
cerrada si falta o no es HTTPS (solo acepta HTTP para localhost). Añade el mismo
destino a la allowlist de **Authentication → URL Configuration**.

Si el email ya es conductor, responde conflicto. Si existe con otro rol, no lo
convierte implícitamente. Un perfil ya marcado `driver` pero incompleto puede
repararse con un `INSERT` auditado; PostgreSQL genera el UUID y `profile_id`
permanece estable.

El entorno administrado de Supabase inyecta las claves del proyecto. No agregues
`service_role`, secret keys ni credenciales a archivos locales o GitHub Actions.
