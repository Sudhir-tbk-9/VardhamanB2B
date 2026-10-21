# Runs the web app for payment-gateway testing, keeping one `flutter run`
# session alive across gateway round trips.
#
# `flutter run -d chrome` shuts its dev server down as soon as the tab
# navigates to the gateway, so the return / cancel URL shows "This site can't
# be reached". `-d web-server` keeps serving on a fixed port, and the gateway's
# return POST (which flutter's dev server can't answer) is turned into a GET by
# scripts/dev_payment_proxy.py on $port, in front of flutter on $flutterPort.
# The separate Chrome profile below skips CORS checks for the JDE AIS calls
# (dev only). Chrome opens before the first build finishes: refresh the tab
# once flutter prints that it is serving.

$port = 8000
$flutterPort = 8001
$profileDir = Join-Path $env:TEMP 'vardhman_b2b_chrome_dev'

# A previous run left behind (window closed, crashed) still holds the ports
# and build\flutter_assets: stop it first.
Get-CimInstance Win32_Process | Where-Object {
  $_.CommandLine -match "flutter_tools\.snapshot`"?\s+run\s+-d\s+web-server\s+--web-port\s+$flutterPort" -or
  $_.CommandLine -match 'dev_payment_proxy\.py'
} | ForEach-Object {
  Write-Host "Stopping leftover $($_.Name) ($($_.ProcessId))"
  taskkill /PID $_.ProcessId /T /F | Out-Null
}

# A leftover dart.exe (an earlier flutter run, or the VS Code analysis server)
# can keep build\flutter_assets open too. Stopping it is harmless: VS Code
# restarts its analysis server on its own.
Get-Process -Name dart -ErrorAction SilentlyContinue | ForEach-Object {
  Write-Host "Stopping leftover dart.exe ($($_.Id))"
  Stop-Process -Id $_.Id -Force -ErrorAction SilentlyContinue
}

# flutter run deletes build\flutter_assets on start and stops with "Flutter
# failed to delete a directory" while any program has a file in it open,
# typically a dying flutter run that was streaming assets\B2B.mp4. A killed
# process lets go after a few seconds, so the delete is retried here first.
$assetsDir = Join-Path $PSScriptRoot '..\build\flutter_assets'

# Read-only attributes (copied or synced files) make the delete fail silently.
if (Test-Path $assetsDir) {
  Get-ChildItem $assetsDir -Recurse -Force -ErrorAction SilentlyContinue |
    ForEach-Object { $_.Attributes = 'Normal' }
}

for ($i = 0; ($i -lt 40) -and (Test-Path $assetsDir); $i++) {
  if ($i -eq 1) { Write-Host 'Waiting for build\flutter_assets to be released...' }

  Remove-Item $assetsDir -Recurse -Force -ErrorAction SilentlyContinue

  if (Test-Path $assetsDir) { Start-Sleep -Milliseconds 500 }
}

if (Test-Path $assetsDir) {
  # Ask Windows (Restart Manager) which programs have the remaining files open.
  Add-Type -ErrorAction SilentlyContinue -TypeDefinition @'
using System; using System.Collections.Generic; using System.Runtime.InteropServices;
public static class FileLocks {
  [StructLayout(LayoutKind.Sequential)] struct RM_UNIQUE_PROCESS { public int Pid; public System.Runtime.InteropServices.ComTypes.FILETIME Start; }
  [StructLayout(LayoutKind.Sequential, CharSet = CharSet.Unicode)] struct RM_PROCESS_INFO {
    public RM_UNIQUE_PROCESS Process;
    [MarshalAs(UnmanagedType.ByValTStr, SizeConst = 256)] public string AppName;
    [MarshalAs(UnmanagedType.ByValTStr, SizeConst = 64)] public string ServiceName;
    public int AppType; public int AppStatus; public int SessionId; [MarshalAs(UnmanagedType.Bool)] public bool Restartable; }
  [DllImport("rstrtmgr.dll", CharSet = CharSet.Unicode)] static extern int RmStartSession(out uint h, int f, string key);
  [DllImport("rstrtmgr.dll")] static extern int RmEndSession(uint h);
  [DllImport("rstrtmgr.dll", CharSet = CharSet.Unicode)] static extern int RmRegisterResources(uint h, uint nFiles, string[] files, uint nApps, RM_UNIQUE_PROCESS[] apps, uint nSvcs, string[] svcs);
  [DllImport("rstrtmgr.dll")] static extern int RmGetList(uint h, out uint needed, ref uint n, [In, Out] RM_PROCESS_INFO[] info, ref uint reasons);
  public static List<string> Holders(string[] files) {
    var result = new List<string>(); uint h; RmStartSession(out h, 0, Guid.NewGuid().ToString());
    try {
      RmRegisterResources(h, (uint)files.Length, files, 0, null, 0, null);
      uint needed = 0, n = 0, reasons = 0; RmGetList(h, out needed, ref n, null, ref reasons);
      if (needed > 0) { var info = new RM_PROCESS_INFO[needed]; n = needed; RmGetList(h, out needed, ref n, info, ref reasons);
        foreach (var p in info) result.Add(p.AppName + " (PID " + p.Process.Pid + ")"); }
    } finally { RmEndSession(h); }
    return result; } }
'@

  $files = @(Get-ChildItem $assetsDir -Recurse -File -Force | ForEach-Object FullName)
  $holders = if ($files) { [FileLocks]::Holders($files) | Sort-Object -Unique } else { @() }

  Write-Warning 'build\flutter_assets is still locked, so flutter run would fail.'

  if ($holders) {
    Write-Host 'Held open by:' -ForegroundColor Yellow
    $holders | ForEach-Object { Write-Host "  $_" -ForegroundColor Yellow }
    Write-Host 'Close it (or: Stop-Process -Id <PID>) and run this script again.'
  } else {
    Write-Host 'Close File Explorer windows showing build\ and any other flutter run, then run this script again.'
  }

  exit 1
}

# Preflight: flutter run writes into build\flutter_assets\assets. If Windows
# refuses that write, stop here rather than starting the proxy and the browser
# for a session that cannot start.
$assetsSubDir = Join-Path $assetsDir 'assets'
try {
  New-Item -ItemType Directory -Force -Path $assetsSubDir -ErrorAction Stop | Out-Null
  $probe = Join-Path $assetsSubDir 'preflight.tmp'
  [IO.File]::WriteAllText($probe, 'ok')
  Remove-Item $probe -Force -ErrorAction Stop
} catch {
  Write-Host "Cannot write to $assetsSubDir" -ForegroundColor Red
  Write-Host $_.Exception.Message -ForegroundColor Red
  Write-Host 'Likely causes: antivirus scanning the project (add the folder to Defender exclusions), a program holding build\, or read-only files.' -ForegroundColor Yellow
  exit 1
}

$proxy = Start-Process 'py' -ArgumentList @(
  (Join-Path $PSScriptRoot 'dev_payment_proxy.py'), $port, $flutterPort
) -NoNewWindow -PassThru

Start-Process 'chrome' -ArgumentList @(
  "--user-data-dir=$profileDir",
  '--disable-web-security',
  '--ignore-certificate-errors',
  "http://localhost:$port"
)

try {
  flutter run -d web-server --web-port $flutterPort
}
finally {
  # /T: the py launcher runs the proxy in a child python.exe.
  taskkill /PID $proxy.Id /T /F | Out-Null
}
