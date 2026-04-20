import 'package:sensors/models/enums.dart';
import 'package:sensors/models/host_identity.dart';
import 'package:sensors/models/sensor.dart';
import 'package:sensors/models/sensor_data.dart';
import 'package:sensors/models/sensor_group.dart';
import 'package:sensors/models/sensor_status.dart';
import 'package:sensors/models/system_telemetry.dart';
import 'package:sensors/models/cpu_telemetry.dart';
import 'package:sensors/models/memory_telemetry.dart';
import 'package:sensors/models/network_telemetry.dart';
import 'package:sensors/models/gpu_device_telemetry.dart';
import 'package:sensors/models/collection_warning.dart';
import 'package:sensors/presentation/screens/sensor_dashboard_screen.dart';
import 'package:sensors/services/sensor_api_client.dart';
import 'package:sensors/services/sensor_state_controller.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/testing.dart';

SensorStateController buildController() {
  return SensorStateController(
    apiClient: SensorApiClient(
      httpClient: MockClient((_) async => throw UnimplementedError()),
    ),
  );
}

SensorData buildData({
  required SensorStatusCode statusCode,
  required List<SensorGroup> groups,
  String message = 'OK',
  SystemTelemetry? systemTelemetry,
  List<CollectionWarning>? collectionWarnings,
}) {
  return SensorData(
    version: '1.0',
    hostIdentity: const HostIdentity(
      hostname: 'test-host',
      fqdn: 'test.local',
      platform: Platform.linux,
    ),
    timestamp: '2024-01-15T10:30:00Z',
    sensorGroups: groups,
    status: SensorStatus(code: statusCode, message: message),
    systemTelemetry: systemTelemetry,
    collectionWarnings: collectionWarnings,
  );
}

Future<void> pumpDashboard(
  WidgetTester tester, {
  required SensorStateController controller,
  required TemperatureUnit currentUnit,
  required Future<void> Function(TemperatureUnit) onUnitChanged,
  SensorData? data,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      home: SensorDashboardScreen(
        controller: controller,
        onRefresh: () async {},
        onRetry: () async {},
        onClearHostConfig: () async {},
        currentUnit: currentUnit,
        onUnitChanged: onUnitChanged,
      ),
    ),
  );
  await tester.pump();
  if (data != null) {
    controller.handleSuccess(data);
    await tester.pump();
  }
}

void main() {
  group('Dashboard unit preference and grouped rendering', () {
    testWidgets('error state exposes change host action', (tester) async {
      final controller = buildController();

      await pumpDashboard(
        tester,
        controller: controller,
        currentUnit: TemperatureUnit.celsius,
        onUnitChanged: (_) async {},
      );

      controller.handleError('Failed to connect');
      await tester.pump();

      expect(find.text('Connection Error'), findsOneWidget);
      expect(find.text('Change Host'), findsOneWidget);
      expect(find.text('Retry'), findsOneWidget);
    });

    testWidgets('renders temperatures in Celsius by default', (tester) async {
      final controller = buildController();
      final data = buildData(
        statusCode: SensorStatusCode.ok,
        groups: const [
          SensorGroup(
            name: 'CPU Temp',
            adapter: 'coretemp-isa-0000',
            sensors: [
              Sensor(name: 'Core 0', value: 45.0, unit: SensorUnit.celsius),
            ],
          ),
        ],
      );

      await pumpDashboard(
        tester,
        controller: controller,
        currentUnit: TemperatureUnit.celsius,
        onUnitChanged: (_) async {},
        data: data,
      );

      await tester.tap(find.text('CPU Temp'));
      await tester.pumpAndSettle();

      expect(find.text('45.00 °C'), findsOneWidget);
    });

    testWidgets('renders temperatures in Fahrenheit when selected', (
      tester,
    ) async {
      final controller = buildController();
      final data = buildData(
        statusCode: SensorStatusCode.ok,
        groups: const [
          SensorGroup(
            name: 'CPU Temp',
            adapter: 'coretemp-isa-0000',
            sensors: [
              Sensor(name: 'Core 0', value: 45.0, unit: SensorUnit.celsius),
            ],
          ),
        ],
      );

      await pumpDashboard(
        tester,
        controller: controller,
        currentUnit: TemperatureUnit.fahrenheit,
        onUnitChanged: (_) async {},
        data: data,
      );

      await tester.tap(find.text('CPU Temp'));
      await tester.pumpAndSettle();

      expect(find.text('113.00 °F'), findsOneWidget);
    });

    testWidgets('unit selector invokes callback', (tester) async {
      final controller = buildController();
      final data = buildData(
        statusCode: SensorStatusCode.ok,
        groups: const [
          SensorGroup(name: 'CPU Temp', adapter: 'coretemp', sensors: []),
        ],
      );

      TemperatureUnit? selected;
      await pumpDashboard(
        tester,
        controller: controller,
        currentUnit: TemperatureUnit.celsius,
        onUnitChanged: (unit) async {
          selected = unit;
        },
        data: data,
      );

      await tester.tap(find.byTooltip('Temperature Unit'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Fahrenheit (°F)').last);
      await tester.pumpAndSettle();

      expect(selected, TemperatureUnit.fahrenheit);
    });

    testWidgets('renders grouped cards for dense sensor data', (tester) async {
      final controller = buildController();
      final data = buildData(
        statusCode: SensorStatusCode.ok,
        groups: const [
          SensorGroup(
            name: 'CPU Temp',
            adapter: 'coretemp-isa-0000',
            sensors: [
              Sensor(name: 'Core 0', value: 45.0, unit: SensorUnit.celsius),
              Sensor(name: 'Core 1', value: 44.0, unit: SensorUnit.celsius),
            ],
          ),
          SensorGroup(
            name: 'Fans',
            adapter: 'nct6775-isa-0290',
            sensors: [
              Sensor(name: 'Fan 1', value: 2500.0, unit: SensorUnit.rpm),
              Sensor(name: 'Fan 2', value: 2600.0, unit: SensorUnit.rpm),
            ],
          ),
        ],
      );

      await pumpDashboard(
        tester,
        controller: controller,
        currentUnit: TemperatureUnit.celsius,
        onUnitChanged: (_) async {},
        data: data,
      );

      expect(find.byType(ExpansionTile), findsNWidgets(2));
      expect(find.text('CPU Temp'), findsOneWidget);
      expect(find.text('Fans'), findsOneWidget);
      expect(find.text('coretemp-isa-0000'), findsOneWidget);
      expect(find.text('nct6775-isa-0290'), findsOneWidget);
    });

    testWidgets('does not show out-of-scope controls', (tester) async {
      final controller = buildController();
      final data = buildData(
        statusCode: SensorStatusCode.ok,
        groups: const [
          SensorGroup(name: 'CPU Temp', adapter: 'coretemp', sensors: []),
        ],
      );

      await pumpDashboard(
        tester,
        controller: controller,
        currentUnit: TemperatureUnit.celsius,
        onUnitChanged: (_) async {},
        data: data,
      );

      expect(find.textContaining('Hide'), findsNothing);
      expect(find.textContaining('Expand all'), findsNothing);
      expect(find.byIcon(Icons.bar_chart), findsNothing);
    });

    testWidgets('renders system telemetry section when present', (
      tester,
    ) async {
      final controller = buildController();
      final data = buildData(
        statusCode: SensorStatusCode.ok,
        groups: const [
          SensorGroup(name: 'CPU Temp', adapter: 'coretemp', sensors: []),
        ],
        systemTelemetry: SystemTelemetry(
          cpu: CpuTelemetry(usagePercent: 42.5),
          memory: MemoryTelemetry(
            usedBytes: 4 * 1024 * 1024 * 1024,
            totalBytes: 16 * 1024 * 1024 * 1024,
            usagePercent: 25.0,
          ),
          network: NetworkTelemetry(
            rxBytesPerSec: 1024 * 500,
            txBytesPerSec: 1024 * 200,
            totalRxBytes: 1024 * 1024 * 100,
            totalTxBytes: 1024 * 1024 * 50,
            sampleWindowSeconds: 1.0,
            interfaces: ['eth0'],
          ),
          gpuDevices: [
            GpuDeviceTelemetry(
              id: 'gpu-0',
              name: 'Test GPU',
              vendor: 'TestVendor',
              utilizationPercent: 75.0,
              memoryUsedBytes: 1024 * 1024 * 512,
              memoryTotalBytes: 1024 * 1024 * 2048,
              memoryUsagePercent: 25.0,
            ),
          ],
        ),
      );

      await pumpDashboard(
        tester,
        controller: controller,
        currentUnit: TemperatureUnit.celsius,
        onUnitChanged: (_) async {},
        data: data,
      );
      await tester.pumpAndSettle();

      expect(find.text('System Telemetry'), findsOneWidget);
      expect(find.text('42.5%'), findsOneWidget);
      expect(find.textContaining('4.0 GiB'), findsOneWidget);
      expect(find.textContaining('Test GPU'), findsOneWidget);
      expect(find.text('75.0%'), findsOneWidget);
      // Sensor group Card still renders below telemetry (verify via Card type)
      // Cards: host + CPU + RAM + Network + GPU = 5
      expect(find.byType(Card), findsNWidgets(5));
    });

    testWidgets('does not render telemetry section when absent', (
      tester,
    ) async {
      final controller = buildController();
      final data = buildData(
        statusCode: SensorStatusCode.ok,
        groups: const [
          SensorGroup(name: 'Fans', adapter: 'nct6775', sensors: []),
        ],
      );

      await pumpDashboard(
        tester,
        controller: controller,
        currentUnit: TemperatureUnit.celsius,
        onUnitChanged: (_) async {},
        data: data,
      );

      expect(find.text('System Telemetry'), findsNothing);
      expect(find.text('Fans'), findsOneWidget);
    });

    testWidgets('renders warnings banner when collectionWarnings present', (
      tester,
    ) async {
      final controller = buildController();
      final data = buildData(
        statusCode: SensorStatusCode.ok,
        groups: const [
          SensorGroup(name: 'CPU Temp', adapter: 'coretemp', sensors: []),
        ],
        collectionWarnings: const [
          CollectionWarning(
            source: 'gpu',
            code: 'GPU_UNAVAILABLE',
            message: 'GPU telemetry unavailable',
          ),
        ],
      );

      await pumpDashboard(
        tester,
        controller: controller,
        currentUnit: TemperatureUnit.celsius,
        onUnitChanged: (_) async {},
        data: data,
      );

      expect(find.text('Collection Warnings'), findsOneWidget);
      expect(find.text('GPU telemetry unavailable'), findsOneWidget);
      expect(find.text('GPU_UNAVAILABLE'), findsOneWidget);
    });

    testWidgets('does not render warnings when collectionWarnings absent', (
      tester,
    ) async {
      final controller = buildController();
      final data = buildData(
        statusCode: SensorStatusCode.ok,
        groups: const [
          SensorGroup(name: 'CPU Temp', adapter: 'coretemp', sensors: []),
        ],
      );

      await pumpDashboard(
        tester,
        controller: controller,
        currentUnit: TemperatureUnit.celsius,
        onUnitChanged: (_) async {},
        data: data,
      );

      expect(find.textContaining('Collection Warnings'), findsNothing);
      expect(find.textContaining('Warning'), findsNothing);
    });

    testWidgets('host card remains first major card with telemetry', (
      tester,
    ) async {
      final controller = buildController();
      final data = buildData(
        statusCode: SensorStatusCode.ok,
        groups: const [
          SensorGroup(name: 'Fans', adapter: 'nct6775', sensors: []),
        ],
        systemTelemetry: SystemTelemetry(
          cpu: CpuTelemetry(usagePercent: 10.0),
          memory: MemoryTelemetry(
            usedBytes: 2 * 1024 * 1024 * 1024,
            totalBytes: 8 * 1024 * 1024 * 1024,
            usagePercent: 25.0,
          ),
          network: NetworkTelemetry(
            rxBytesPerSec: 0,
            txBytesPerSec: 0,
            totalRxBytes: 0,
            totalTxBytes: 0,
            sampleWindowSeconds: 1.0,
            interfaces: [],
          ),
          gpuDevices: [],
        ),
      );

      await pumpDashboard(
        tester,
        controller: controller,
        currentUnit: TemperatureUnit.celsius,
        onUnitChanged: (_) async {},
        data: data,
      );

      // Host info card should be present
      expect(find.text('test-host'), findsOneWidget);
      // Telemetry section present
      expect(find.text('System Telemetry'), findsOneWidget);
      // Sensor group present below
      expect(find.text('Fans'), findsOneWidget);
    });
  });
}
