# LE Skate App

Flutter app for inline skating training with integrated weather rating.

## Features

- Fixed geo position: `51.3720365653869, 12.343817084568474`
- Training series 1: Sunday `10:00-12:00`, every 2 weeks
- Training series 2: Friday `19:00-21:00`, every 2 weeks
- Weather score per session (`Go`, `Maybe`, `No`)
- Python approach implemented directly in the client (no additional server process)
- Optional LLM rating of training forecasts (Google Gemini API)
- Modern UI with gradients, maps, and weather metrics

## Project Structure

- Flutter Client: `lib/main.dart`

## Running the App

```powershell
flutter pub get
flutter run
```

## Optional: Enable LLM for Weather Rating

When `LLM_API_KEY` is set, rule-based scores are refined with an additional
LLM assessment (Google Gemini API). Without the key, the app works as before.

The key is **no longer** embedded in code but passed on first start via
`--dart-define-from-file` and then securely stored (Keychain/Keystore/DPAPI)
through `SecureConfigService`.

### One-Time Setup

1. Copy `secrets.example.json` to `secrets.json` (already in repo root):
  ```powershell
  Copy-Item secrets.example.json secrets.json
  ```
2. Add your actual Gemini API key to `secrets.json` (obtainable at
  https://aistudio.google.com/apikey). This file is excluded from Git via
  `.gitignore` and will **never** be committed.

### Running with Secrets File

```powershell
flutter run --dart-define-from-file=secrets.json
```

The same works for builds:

```powershell
flutter build windows --dart-define-from-file=secrets.json
flutter build apk --dart-define-from-file=secrets.json
```

### Integrated into Build Process

So you don't have to manually type `--dart-define-from-file=secrets.json` each time:

- **IntelliJ / Android Studio**: The `main.dart` run configuration
  (`.idea/runConfigurations/main_dart.xml`) already passes the flag automatically –
  just start via the normal Run/Debug button.
- **PowerShell scripts** (work everywhere, even without IDE):
  ```powershell
  # Equivalent to: flutter run --dart-define-from-file=secrets.json
  .\scripts\run_dev.ps1
  .\scripts\run_dev.ps1 -d windows        # pass additional flutter-run arguments

  # Equivalent to: flutter build <target> --dart-define-from-file=secrets.json
  .\scripts\build_release.ps1 windows --release
  .\scripts\build_release.ps1 apk --release
  ```
  Both scripts exit with a warning if `secrets.json` is missing.

After the first start, the key is securely stored – subsequent starts
without `--dart-define-from-file` will continue to work as long as the
device's secure storage data is preserved.

## Creating Release Build

Requirement: `secrets.json` is configured (see above) so the LLM key
is included in the release build.

```powershell
flutter test                                  # optional: verify tests first
.\scripts\build_release.ps1 apk --release     # Android: APK
.\scripts\build_release.ps1 appbundle --release # Android: Play Store Bundle
.\scripts\build_release.ps1 windows --release   # Windows Desktop
```

Results:
- Android APK: `build\app\outputs\flutter-apk\app-release.apk`
- Windows: `build\windows\x64\runner\Release\inliner2.exe`

Note: The Android release build is currently signed with the **Debug Keystore**
(see `android/app/build.gradle.kts`) – sufficient for side-loading,
but a custom signing key must be configured first for Play Store upload.

## Start Android Emulator with Europe/Berlin Timezone

If the emulator runs in UTC, rain times in the app may appear incorrect.
The script reproducibly sets the timezone to `Europe/Berlin`.

```powershell
.\scripts\start_emulator_berlin.ps1 -DeviceId emulator-5554
```

Optionally, you can start an AVD directly:

```powershell
.\scripts\start_emulator_berlin.ps1 -EmulatorName Pixel_8_API_35 -DeviceId emulator-5554
```

## Tests

```powershell
flutter test
```

## Notes

- The app calls Open-Meteo directly and calculates the training score locally in the client.