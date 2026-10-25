# Release web build for UAT (PY), served under /vytldev/.
# Builds into the default build\web (`--output` skips copying the files in
# web\, e.g. sqlite3.wasm and drift_worker.js), then moves it to
# build\web_uat so it never mixes with a production build, and zips it as
# build\vytldev_py_<yyyy-MM-dd>.zip for the server.
# No $ErrorActionPreference = 'Stop': PowerShell 5.1 would treat flutter's
# stderr warnings as errors; the exit code is checked instead.

$root = Split-Path $PSScriptRoot -Parent
$web = Join-Path $root 'build\web'
$webUat = Join-Path $root 'build\web_uat'
$zip = Join-Path $root "build\vytldev_py_$(Get-Date -Format 'yyyy-MM-dd').zip"

Push-Location $root
try {
  flutter build web --release --base-href /vytldev/ --no-wasm-dry-run
  if ($LASTEXITCODE -ne 0) { throw 'flutter build web failed' }

  if (-not (Test-Path (Join-Path $web 'main.dart.js'))) {
    throw 'build\web has no main.dart.js: run the script again'
  }

  if (Test-Path $webUat) { Remove-Item $webUat -Recurse -Force }
  Move-Item $web $webUat

  # tar, not Compress-Archive: PowerShell 5.1 writes backslashes into the zip's
  # paths, which unzip tools on a Linux server may not turn into folders.
  if (Test-Path $zip) { Remove-Item $zip }
  Push-Location $webUat
  try {
    & "$env:SystemRoot\System32\tar.exe" -a -c -f $zip *
    if ($LASTEXITCODE -ne 0) { throw 'zip failed' }
  } finally {
    Pop-Location
  }

  Write-Host "Built $webUat"
  Write-Host "Zip:  $zip"
} finally {
  Pop-Location
}
