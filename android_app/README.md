# Cockpit Sensors — Android App

A Flutter Android app that connects to the Cockpit Sensors companion host service and displays hardware telemetry from a Linux machine on your private network.

## What it does

The app polls the host service at `http://<host>:5000/api/v1/sensors` and displays:

- **Host identity** — hostname, operating system, and architecture
- **Sensor groups** — temperature, fan, and voltage readings from `lm-sensors`
- **System telemetry** — CPU usage, memory usage, network interfaces, and (when available) GPU/VRAM data
- **Collection warnings** — yellow banner when any collection subsystem (sensors, telemetry) reported partial issues

## How it works

1. **Host setup** — Enter your Linux machine's IP address (or Tailscale IP) in the setup screen
2. **Polling** — The app polls the host service at regular intervals (default: 5 seconds)
3. **Parsing** — JSON payloads are deserialized into strongly-typed Dart models (`SensorData`, `SystemTelemetry`, `CpuTelemetry`, `MemoryTelemetry`, `NetworkTelemetry`, `GpuDeviceTelemetry`, `CollectionWarning`)
4. **Rendering** — The dashboard shows host info, telemetry cards with progress bars, sensor groups in expansion tiles, and a warnings banner

## Building and running

See `android_app/docs/build-android-app.md` for full build instructions.

Quick start:

```bash
cd android_app
flutter pub get
flutter run
```

## Architecture

- **Models** (`lib/models/`) — Strongly-typed Dart classes for all payload fields, with `fromJson`/`toJson`, equality, and hashing
- **Services** (`lib/services/`) — `SensorApiClient` handles HTTP polling; `SensorStateController` manages polling lifecycle
- **Repositories** (`lib/repositories/`) — `HostConfigRepository` persists host address locally; `UserPreferencesRepository` stores temperature unit preference
- **Presentation** (`lib/presentation/`) — `HostSetupScreen` and `SensorDashboardScreen` (with telemetry cards and warnings banner)

## Connection options

- **Tailscale** — Add your Tailscale IP to the Android app; both devices must share the same tailnet
- **Emulator port forwarding** — Run `adb reverse tcp:5000 tcp:5000` and use `http://127.0.0.1:5000`
- **Local Wi-Fi** — Use the host machine's LAN IP address
