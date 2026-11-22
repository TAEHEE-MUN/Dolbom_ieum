param([int]$Port = 5175)
$ErrorActionPreference = 'Stop'
$repoRoot = Split-Path (Split-Path $PSScriptRoot -Parent) -Parent
$demoPython = Join-Path $repoRoot '.venv/Scripts/python.exe'
if (Test-Path -LiteralPath $demoPython) {
    & $demoPython -m http.server $Port --bind 127.0.0.1 --directory $PSScriptRoot
} elseif (Get-Command python -ErrorAction SilentlyContinue) {
    python -m http.server $Port --bind 127.0.0.1 --directory $PSScriptRoot
} else {
    throw 'Python is required.'
}
