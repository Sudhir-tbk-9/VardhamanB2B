# Release web build for production (PD), served at the site root
# (https://b2b.amefird.in/). Run it on the deploy/prod-sync branch, where the
# code is set to PD (see docs/PD_ENVIRONMENT_CHECKLIST.md).
# Builds into the default build\web (`--output` skips copying the files in
# web\, e.g. sqlite3.wasm and drift_worker.js), then moves it to
# build\web_pd so it never mixes with a UAT build, and zips it as
# build\b2b_pd_<yyyy-MM-dd>.zip for the server.
# No $ErrorActionPreference = 'Stop': PowerShell 5.1 would treat flutter's
# stderr warnings as errors; the exit code is checked instead.
# --no-tree-shake-icons: see scripts/build_web_uat.ps1.

$root = Split-Path $PSScriptRoot -Parent
$web = Join-Path $root 'build\web'
$webPd = Join-Path $root 'build\web_pd'
$zip = Join-Path $root "build\b2b_pd_$(Get-Date -Format 'yyyy-MM-dd').zip"

Push-Location $root
try {
  # On this machine the copy of the assets into build\web sometimes fails at
  # random ("Flutter failed to copy file ... cannot access the file"), a
  # different file each time. Start from an empty build\web and try again.
  $built = $false
  foreach ($attempt in 1..3) {
    if (Test-Path $web) { Remove-Item $web -Recurse -Force }
    flutter build web --release --base-href / --no-wasm-dry-run --no-tree-shake-icons
    if ($LASTEXITCODE -eq 0) { $built = $true; break }
    Write-Host "flutter build web failed (attempt $attempt of 3)"
    Start-Sleep -Seconds 5
  }
  if (-not $built) { throw 'flutter build web failed' }

  if (-not (Test-Path (Join-Path $web 'main.dart.js'))) {
    throw 'build\web has no main.dart.js: run the script again'
  }

  if (Test-Path $webPd) { Remove-Item $webPd -Recurse -Force }
  Move-Item $web $webPd

  # tar, not Compress-Archive: PowerShell 5.1 writes backslashes into the zip's
  # paths, which unzip tools on a Linux server may not turn into folders.
  if (Test-Path $zip) { Remove-Item $zip }
  Push-Location $webPd
  try {
    & "$env:SystemRoot\System32\tar.exe" -a -c -f $zip *
    if ($LASTEXITCODE -ne 0) { throw 'zip failed' }
  } finally {
    Pop-Location
  }

  Write-Host "Built $webPd"
  Write-Host "Zip:  $zip"
} finally {
  Pop-Location
}
