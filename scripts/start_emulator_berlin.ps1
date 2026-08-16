param(
  [string]$EmulatorName,
  [string]$DeviceId = "emulator-5554",
  [string]$Timezone = "Europe/Berlin"
)

$ErrorActionPreference = "Stop"

function Require-Command {
  param([string]$Name)
  if (-not (Get-Command $Name -ErrorAction SilentlyContinue)) {
    throw "Befehl '$Name' wurde nicht gefunden. Bitte Android SDK/Platform-Tools installieren."
  }
}

Require-Command "adb"

if ($EmulatorName) {
  Require-Command "emulator"
  Write-Host "Starte Emulator '$EmulatorName'..."
  Start-Process -FilePath "emulator" -ArgumentList "-avd", $EmulatorName
}

Write-Host "Warte auf ADB-Device '$DeviceId'..."
adb -s $DeviceId wait-for-device | Out-Null

Write-Host "Setze Zeitzone auf $Timezone..."
adb -s $DeviceId shell settings put global auto_time_zone 0 | Out-Null
adb -s $DeviceId shell cmd alarm set-timezone $Timezone | Out-Null

$effectiveTz = adb -s $DeviceId shell getprop persist.sys.timezone
$deviceDate = adb -s $DeviceId shell date

Write-Host "Zeitzone aktiv: $effectiveTz"
Write-Host "Gerätezeit: $deviceDate"

