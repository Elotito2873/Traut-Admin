# Releases

El proyecto usa SemVer y comienza en `0.1.0+1`. Crea tags `v0.1.0`, `v0.1.1`,
`v0.2.0` o `v1.0.0` según compatibilidad.

CI y Release fijan Flutter 3.44.4 (Dart 3.12.2). No cambies esa versión durante
esta release sin repetir analyze, tests y todos los builds.

## Variables obligatorias

Configura GitHub Actions Secrets:

- `SUPABASE_URL`
- `SUPABASE_PUBLISHABLE_KEY`

No configures `service_role` para compilar clientes.

## Firma opcional de macOS

Sin certificado, CI genera un `.app`/DMG unsigned y Gatekeeper puede advertir al
usuario. Para firma y notarización futura agrega:

- `MACOS_CERTIFICATE` (P12 codificado en base64)
- `MACOS_CERTIFICATE_PASSWORD`
- `MACOS_SIGNING_IDENTITY`
- `APPLE_ID`
- `APPLE_TEAM_ID`
- `APPLE_APP_PASSWORD`

Los pasos son condicionales. La ausencia de estos secrets conserva el build
unsigned; nunca se inventan identidades.

## Artefactos

- `TrautAdmin-Setup-vX.Y.Z.exe`
- `TrautAdmin-windows-x64-vX.Y.Z.zip`
- `TrautAdmin-linux-x86_64-vX.Y.Z.AppImage`
- `TrautAdmin-linux-x86_64-vX.Y.Z.tar.gz`
- `TrautAdmin-macos-vX.Y.Z.dmg` y ZIP de respaldo
- `TrautAdmin-web-vX.Y.Z.zip`

El release depende de formato, analyze y tests. Los runners nativos verifican las
plataformas que no pueden compilarse desde Linux.
El job de publicación descarga todos los artefactos, genera `SHA256SUMS.txt` con
SHA-256 y lo adjunta a la release. Verifica hashes con `sha256sum -c
SHA256SUMS.txt` desde el directorio de descargas.

## Publicación

```bash
# Primero sincroniza version: X.Y.Z+BUILD en pubspec.yaml.
git tag v0.1.0
git push origin v0.1.0
```

El workflow compara `vX.Y.Z` con la parte `X.Y.Z` de `pubspec.yaml` y falla con
un mensaje explícito si no coinciden. Solo `SUPABASE_URL` y
`SUPABASE_PUBLISHABLE_KEY` entran a builds cliente; nunca `service_role`, y los
workflows no imprimen sus valores.

Revisa primero [CHANGELOG.md](../CHANGELOG.md), las propuestas SQL pendientes y
la disponibilidad de los secrets. El workflow crea GitHub Release; no publica en
AUR. `packaging/arch/PKGBUILD` es únicamente una base futura y requiere URL/hash.
