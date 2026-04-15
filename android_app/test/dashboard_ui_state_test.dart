import 'package:sensors/models/enums.dart';
import 'package:sensors/models/host_identity.dart';
import 'package:sensors/models/sensor.dart';
import 'package:sensors/models/sensor_data.dart';
import 'package:sensors/models/sensor_group.dart';
import 'package:sensors/models/sensor_status.dart';
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
  });
}
