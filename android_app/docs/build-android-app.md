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
./tools/start_host_service.sh
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
