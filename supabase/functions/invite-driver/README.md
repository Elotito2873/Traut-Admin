# invite-driver

Función de servidor para invitar exclusivamente cuentas con rol `driver`.
Valida JWT, AAL2 y `profiles.role = 'admin'` antes de usar el cliente privilegiado.

No se despliega desde este repositorio automáticamente. Después de incorporar y
aplicar las propuestas SQL canónicas:

```bash
supabase functions deploy invite-driver
```

El entorno administrado de Supabase inyecta las claves del proyecto. No agregues
`service_role`, secret keys ni credenciales a archivos locales o GitHub Actions.
