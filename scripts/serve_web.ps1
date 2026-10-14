param(
  [int]$Port = 8080
)

if (-not (Test-Path "build/web")) {
  Write-Error "No existe build/web. Ejecuta flutter build web --release primero."
  exit 1
}

Write-Host "Traut Admin disponible en http://localhost:$Port"
python -m http.server $Port --directory build/web
