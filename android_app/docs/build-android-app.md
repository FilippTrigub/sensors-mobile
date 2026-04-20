# Build the Android app

## Prerequisites

- Flutter SDK installed and available on `PATH`
- Android SDK installed
- Java 17 or 21 recommended
- `android_app/android/local.properties` configured with:
  - `flutter.sdk=/path/to/flutter`
  - `sdk.dir=/path/to/android-sdk`

## 1. Fetch dependencies

```bash
cd /home/filipp/Projects/cockpit-sensors/android_app
flutter pub get
```

## 2. Static verification

```bash
flutter analyze
flutter test
```

## 3. Build a debug APK

```bash
flutter build apk --debug
```

Output:

```text
build/app/outputs/flutter-apk/app-debug.apk
```

## 4. Build a release APK

```bash
flutter build apk --release
```

Output:

```text
build/app/outputs/flutter-apk/app-release.apk
```

## 5. Run on an emulator or connected device

List devices:

```bash
flutter devices
```

Run the app:

```bash
flutter run -d <device-id>
```

## 6. Local emulator + host service workflow

Start the host service from the repository root:

```bash
cd /home/filipp/Projects/cockpit-sensors
pip install -r src/host_service/requirements.txt
python -m src.host_service
```

If you are using the Android emulator, forward the host service port into the emulator:

```bash
adb reverse tcp:5000 tcp:5000
```

Then run the app and configure the saved host URL as:

```text
http://127.0.0.1:5000/api/v1/sensors
```

## 7. Physical device or Tailscale workflow

If you are using a real Android device, run the host service on the Linux machine and use the machine's Tailscale IP:

```text
http://<tailscale-ip>:5000/api/v1/sensors
```

## 8. Common troubleshooting

Check toolchain health:

```bash
flutter doctor -v
```

Check available emulators:

```bash
flutter emulators
```

If the build fails, confirm:

- `flutter.sdk` in `android/local.properties` points to the active Flutter install
- `sdk.dir` points to the Android SDK
- Java version is compatible with the Android Gradle plugin

## 9. AdMob Ads

The app supports AdMob ads via build-time `--dart-define` flags. Ads are **disabled by default** in dev and debug builds so you don't hit quota limits while developing.

### Available dart-define keys

| Key | Description | Format | Default |
|-----|-------------|--------|---------|
| `ADS_ENABLED` | Enable or disable ads for this build | `true` or `false` | `false` |
| `ADMOB_APP_ID` | AdMob application ID for Android | `ca-app-pub-XXXXXXXX~YYYYYYYY` | `''` (empty) |
| `ADMOB_BANNER_UNIT_ID` | Admob banner ad unit ID for Android | `ca-app-pub-XXXXXXXX/YYYYYYYY` | `''` (empty) |

### Dev build (ads disabled)

No flags needed. Ads stay off by default:

```bash
flutter run -d <device-id>
```

Or build a release APK without ads:

```bash
flutter build apk --release
```

### Test build (ads enabled with Google test IDs)

```bash
flutter run --dart-define=ADS_ENABLED=true \
  --dart-define=ADMOB_APP_ID=ca-app-pub-3940256099942544~3347511713 \
  --dart-define=ADMOB_BANNER_UNIT_ID=ca-app-pub-3940256099942544/6300978111 \
  -d <device-id>
```

### Banner scope

The AdMob banner appears **only on the dashboard screen** (the main sensor data screen). It does not appear on the host setup screen where you enter the Tailscale or LAN IP address.

### Production note

The test commands above use Google's test ad IDs. Before releasing the app, replace those values with your production AdMob App ID and Banner Unit ID, and update the `APPLICATION_ID` meta-data in `android/app/src/main/AndroidManifest.xml`.
