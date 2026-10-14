#!/usr/bin/env bash
set -euo pipefail

PORT="${1:-8080}"
if [[ ! -d build/web ]]; then
  echo "No existe build/web. Ejecuta flutter build web --release primero." >&2
  exit 1
fi

echo "Traut Admin disponible en http://localhost:${PORT}"
python3 -m http.server "${PORT}" --directory build/web
