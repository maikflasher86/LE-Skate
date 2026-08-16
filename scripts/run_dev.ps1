#Requires -Version 5.1
<#
.SYNOPSIS
    Startet die App mit den lokalen Secrets (secrets.json).

.DESCRIPTION
    Wrapper um `flutter run`, der automatisch --dart-define-from-file=secrets.json
    anhängt, damit der LLM_API_KEY nicht manuell übergeben werden muss.
    secrets.json muss zuvor aus secrets.example.json erstellt und befuellt werden.

.PARAMETER Args
    Zusaetzliche Argumente, die 1:1 an `flutter run` weitergereicht werden
    (z.B. -d windows, -d chrome, --release).
#>
param(
    [Parameter(ValueFromRemainingArguments = $true)]
    [string[]]$Args
)

$ErrorActionPreference = 'Continue'
$repoRoot = Split-Path -Parent $PSScriptRoot
$secretsFile = Join-Path $repoRoot 'secrets.json'

if (-not (Test-Path $secretsFile)) {
    Write-Warning "secrets.json nicht gefunden unter $secretsFile - kopiere secrets.example.json und befuelle den LLM_API_KEY."
    exit 1
}

Set-Location $repoRoot
flutter run --dart-define-from-file=secrets.json @Args
exit $LASTEXITCODE
