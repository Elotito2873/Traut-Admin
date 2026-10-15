# Traut Admin

Aplicación administrativa Flutter para operar el sistema de transporte Traut en
Linux, Windows, macOS y Web. Usa el mismo proyecto Supabase que las aplicaciones
de pasajeros y conductores, sin incluir credenciales privilegiadas en el cliente.

## Funcionalidad

- inicio de sesión exclusivo para perfiles `role = 'admin'`;
- MFA TOTP oficial de Supabase, enrolamiento y challenge AAL2;
- dashboard con métricas calculadas desde datos reales;
- monitoreo OpenStreetMap y actualizaciones Realtime de `vehicle_locations`;
- CRUD y asignaciones de flota, rutas, paradas, tarifas y conductores;
- reordenamiento visual de paradas y edición de coordenadas desde el mapa;
- revisión de viajes e incidencias sin borrar el historial;
- buscador global con debounce;
- tema claro/oscuro, diseño responsive, teclado y objetivos táctiles amplios;
- propuestas aditivas de RLS, auditoría e historial bajo `database/proposals/`;
- Edge Function segura para invitar conductores.

## Requisitos

- Flutter 3.44.4 y Dart 3.12.2 para reproducir CI y los binarios de esta release;
- toolchain de la plataforma que se desea compilar;
- un proyecto Supabase existente con el esquema descrito en
  [docs/DATABASE.md](docs/DATABASE.md);
- Python 3 únicamente para el servidor local sencillo de Web.

Este repositorio no contiene Android ni iOS y ningún workflow genera APK.

## Configuración local

```bash
cp config/example.json config/dev.json
```

Completa únicamente `SUPABASE_URL` y `SUPABASE_PUBLISHABLE_KEY`. El archivo
`config/dev.json` está ignorado por Git. Nunca uses una secret key, `service_role`,
contraseña de Postgres ni Client Secret.

`REQUIRE_ADMIN_MFA` controla el gate de enrolamiento del cliente. Para imponer
MFA también en la base, revisa la propuesta `004_require_admin_aal2.sql`.
`ADMIN_INACTIVITY_TIMEOUT_MINUTES` controla el lock local (20 minutos por
defecto). Con TOTP, conserva formularios y exige un nuevo challenge; sin TOTP
cierra la sesión y exige reautenticación.

## Ejecutar

```bash
# Linux
flutter run -d linux --dart-define-from-file=config/dev.json

# Web (requiere Chrome para flutter run)
flutter run -d chrome --web-port=8080 --dart-define-from-file=config/dev.json

# Windows, desde Windows
flutter run -d windows --dart-define-from-file=config/dev.json

# macOS, desde macOS
flutter run -d macos --dart-define-from-file=config/dev.json
```

## Verificación y builds

```bash
flutter pub get
dart format --output=none --set-exit-if-changed .
flutter analyze
flutter test

flutter build linux --release --dart-define-from-file=config/dev.json
flutter build web --release --dart-define-from-file=config/dev.json
./scripts/serve_web.sh 8080
```

En PowerShell, `scripts/serve_web.ps1 -Port 8080` sirve `build/web` en
<http://localhost:8080>. Localhost es solo una opción de prueba, no el destino de
producción.

Windows y macOS deben compilarse en sus sistemas nativos o con los runners de
GitHub Actions. El ZIP de Windows contiene el bundle Release completo; el `.exe`
interno no debe distribuirse aislado.

## Supabase

No ejecutes `supabase db push` desde este repositorio. Revisa los SQL propuestos,
incorpóralos a la historia canónica de migraciones de Traut y aplícalos desde ese
repositorio. Consulta [docs/DATABASE.md](docs/DATABASE.md) y
[docs/SECURITY.md](docs/SECURITY.md).

La invitación de conductores requiere desplegar manualmente `invite-driver` luego
de aplicar RLS, auditoría y el default UUID de `drivers`:

```bash
supabase secrets set \
  DRIVER_INVITE_REDIRECT_URL=https://conductor.example.com/auth/accept-invite
supabase functions deploy invite-driver
```

La redirección corresponde a Traut Conductor. Supabase administra las secret
keys del entorno de Functions. No las copies a este repositorio.

## Arquitectura

La UI no consulta Supabase directamente. El flujo es:

`presentation → controllers/usecases → repository interfaces → implementación Supabase`

Los filtros de pantalla son locales; Auth, transporte, ubicaciones, viajes,
incidencias y auditoría permanecen en Supabase. Más detalles en
[docs/ARCHITECTURE.md](docs/ARCHITECTURE.md).

## Releases

Los tags SemVer `v*.*.*` activan builds nativos para Linux, Windows, macOS y Web.
El workflow rechaza un tag que no coincida con `version:` en `pubspec.yaml` y
publica `SHA256SUMS.txt` junto con los artefactos.
Consulta [docs/RELEASING.md](docs/RELEASING.md) para secrets, firma y artefactos.

## Seguridad

- Auth + verificación de `profiles.role` + RLS; ocultar un botón nunca concede acceso.
- `service_role` existe solo en el servidor administrado de Edge Functions.
- `profiles.role` nunca se modifica desde Flutter.
- las políticas administrativas usan `public.is_admin()`, no `TO authenticated`
  como única autorización;
- las acciones destructivas visibles requieren confirmación.

Lee [docs/SECURITY.md](docs/SECURITY.md) antes de conectar producción.
