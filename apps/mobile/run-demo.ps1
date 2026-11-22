param([string]$Device = 'chrome', [int]$Port = 5174)
$ErrorActionPreference = 'Stop'
Push-Location $PSScriptRoot
try {
  & flutter pub get
  if ($LASTEXITCODE -ne 0) { throw 'Flutter dependencies could not be loaded.' }
  if ($Device -eq 'chrome' -or $Device -eq 'edge' -or $Device -eq 'web-server') {
    & flutter run -d $Device -t lib/main_demo.dart --web-port $Port
  } else {
    & flutter run -d $Device -t lib/main_demo.dart
  }
  if ($LASTEXITCODE -ne 0) { throw 'Demo did not start. Check Flutter device setup.' }
} finally { Pop-Location }
