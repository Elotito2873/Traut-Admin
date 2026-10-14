# Releases

El proyecto usa SemVer y comienza en `0.1.0+1`. Crea tags `v0.1.0`, `v0.1.1`,
`v0.2.0` o `v1.0.0` según compatibilidad.

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

## Publicación

```bash
git tag v0.1.0
git push origin v0.1.0
```

Revisa primero [CHANGELOG.md](../CHANGELOG.md), las propuestas SQL pendientes y
la disponibilidad de los secrets. El workflow crea GitHub Release; no publica en
AUR. `packaging/arch/PKGBUILD` es únicamente una base futura y requiere URL/hash.
