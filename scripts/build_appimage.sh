#!/usr/bin/env bash
set -euo pipefail

VERSION="${1:?Uso: scripts/build_appimage.sh VERSION}"
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
APP_DIR="${ROOT_DIR}/packaging/AppDir"
OUTPUT_DIR="${ROOT_DIR}/packaging/output"
BUNDLE_DIR="${ROOT_DIR}/build/linux/x64/release/bundle"

if [[ ! -x "${BUNDLE_DIR}/traut_admin" ]]; then
  echo "Primero ejecuta flutter build linux --release." >&2
  exit 1
fi

rm -rf "${APP_DIR}"
mkdir -p "${APP_DIR}/usr/bin" "${APP_DIR}/usr/share/applications" "${APP_DIR}/usr/share/metainfo" "${OUTPUT_DIR}"
cp -a "${BUNDLE_DIR}/." "${APP_DIR}/usr/bin/"
cp "${ROOT_DIR}/packaging/linux/traut-admin.desktop" "${APP_DIR}/com.traut.admin.desktop"
cp "${ROOT_DIR}/packaging/linux/traut-admin.desktop" "${APP_DIR}/usr/share/applications/com.traut.admin.desktop"
cp "${ROOT_DIR}/packaging/linux/traut-admin.appdata.xml" "${APP_DIR}/usr/share/metainfo/com.traut.admin.appdata.xml"
cp "${ROOT_DIR}/web/icons/Icon-512.png" "${APP_DIR}/traut-admin.png"
cp "${ROOT_DIR}/packaging/linux/AppRun" "${APP_DIR}/AppRun"
chmod +x "${APP_DIR}/AppRun"

APPIMAGETOOL="${APPIMAGETOOL:-${ROOT_DIR}/packaging/appimagetool-x86_64.AppImage}"
if [[ ! -x "${APPIMAGETOOL}" ]]; then
  curl -L --fail --retry 3 \
    -o "${APPIMAGETOOL}" \
    https://github.com/AppImage/AppImageKit/releases/download/continuous/appimagetool-x86_64.AppImage
  chmod +x "${APPIMAGETOOL}"
fi

ARCH=x86_64 "${APPIMAGETOOL}" \
  "${APP_DIR}" \
  "${OUTPUT_DIR}/TrautAdmin-linux-x86_64-v${VERSION}.AppImage"
