#Requires -Version 5.1
<#
.SYNOPSIS
    Builds the app with local secrets (secrets.json).

.DESCRIPTION
    Wrapper around `flutter build` that automatically appends --dart-define-from-file=secrets.json
    so the LLM_API_KEY does not need to be passed manually.
    secrets.json must be created from secrets.example.json and filled in beforehand.

    Release builds automatically include --obfuscate and --split-debug-info
    to make reverse engineering harder.

.PARAMETER Target
    Build target as used by `flutter build`, e.g. windows, apk, appbundle, ios. Default: apk.

.PARAMETER Args
    Additional arguments passed directly to `flutter build`
    (e.g. --release, --debug).
#>
param(
    [Parameter(Position = 0)]
    [string]$Target = 'apk',

    [Parameter(ValueFromRemainingArguments = $true)]
    [string[]]$ExtraArgs
)

$ErrorActionPreference = 'Continue'
$repoRoot = Split-Path -Parent $PSScriptRoot
$secretsFile = Join-Path $repoRoot 'secrets.json'

if (-not (Test-Path $secretsFile)) {
    Write-Warning "secrets.json not found at $secretsFile - copy secrets.example.json and fill in the LLM_API_KEY."
    exit 1
}

Set-Location $repoRoot

# Add obfuscation flags automatically for release builds.
$isRelease = ($ExtraArgs -contains '--release') -or (-not ($ExtraArgs -contains '--debug'))
$obfuscationArgs = @()
if ($isRelease) {
    $debugInfoDir = Join-Path $repoRoot "debug-info\$Target"
    # $obfuscationArgs = @('--obfuscate', "--split-debug-info=$debugInfoDir")
    Write-Host "Release build: obfuscation enabled (debug symbols -> $debugInfoDir)" -ForegroundColor Cyan
}

# $fullCmd = "flutter build $Target --dart-define-from-file=secrets.json --target-platform=android-arm64 $($obfuscationArgs -join ' ') $($ExtraArgs -join ' ')"
$splitArgs = @()
if ($Target -eq 'apk') {
    $splitArgs = @('--split-per-abi')
}

$fullCmd = "flutter build $Target --dart-define-from-file=secrets.json $($splitArgs -join ' ') $($obfuscationArgs -join ' ') $($ExtraArgs -join ' ')"
Write-Host "Running: $fullCmd" -ForegroundColor DarkGray

flutter clean
flutter build $Target --dart-define-from-file=secrets.json @splitArgs @obfuscationArgs @ExtraArgs
$buildExitCode = $LASTEXITCODE

if ($buildExitCode -eq 0 -and $Target -eq 'apk') {
    adb install -r (Join-Path $repoRoot 'build\app\outputs\flutter-apk\app-arm64-v8a-release.apk')
}

exit $buildExitCode

exit $LASTEXITCODE
