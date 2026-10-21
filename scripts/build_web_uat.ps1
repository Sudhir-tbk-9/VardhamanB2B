# Release web build for UAT (PY), served under /vytldev/.
# Builds into the default build\web (`--output` skips copying the files in
# web\, e.g. sqlite3.wasm and drift_worker.js), then moves it to
# build\web_uat so it never mixes with a production build.
# No $ErrorActionPreference = 'Stop': PowerShell 5.1 would treat flutter's
# stderr warnings as errors; the exit code is checked instead.

$root = Split-Path $PSScriptRoot -Parent
$web = Join-Path $root 'build\web'
$webUat = Join-Path $root 'build\web_uat'

Push-Location $root
try {
  flutter build web --release --base-href /vytldev/
  if ($LASTEXITCODE -ne 0) { throw 'flutter build web failed' }

  if (Test-Path $webUat) { Remove-Item $webUat -Recurse -Force }
  Move-Item $web $webUat
} finally {
  Pop-Location
}
