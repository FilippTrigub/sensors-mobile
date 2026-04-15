// This is a basic Flutter widget test for the real app.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sensors/main.dart';
import 'package:sensors/repositories/host_config_repository.dart';
import 'package:sensors/models/host_config.dart';

void main() {
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('App loads and shows setup screen when no host configured', (
    tester,
  ) async {
    await tester.pumpWidget(const MyApp());
    await tester.pumpAndSettle();

    // Should show setup screen with title
    expect(find.text('Host Setup'), findsOneWidget);
    expect(find.byType(TextFormField), findsOneWidget);
    expect(find.byType(ElevatedButton), findsOneWidget);
  });

  testWidgets('App transitions to dashboard when host is saved', (
    tester,
  ) async {
    // Pre-configure a host
    final repository = HostConfigRepository();
    const testConfig = HostConfig(
      hostId: 'test-host',
      hostname: 'test-hostname',
      ipAddress: 'localhost:5000',
      displayName: 'Test Host',
    );
    await repository.saveConfig(testConfig);

    await tester.pumpWidget(const MyApp());
    await tester.pumpAndSettle();

    // Should show dashboard after pre-configured host
    expect(find.text('sensors'), findsOneWidget);
    expect(find.byType(AppBar), findsOneWidget);
  });

  testWidgets('App clears saved host config and returns to setup', (
    tester,
  ) async {
    final repository = HostConfigRepository();
    const testConfig = HostConfig(
      hostId: 'test-host',
      hostname: 'test-hostname',
      ipAddress: 'localhost:5000',
      displayName: 'Test Host',
    );
    await repository.saveConfig(testConfig);

    await tester.pumpWidget(const MyApp());
    await tester.pumpAndSettle();

    expect(find.text('sensors'), findsOneWidget);

    await tester.tap(find.byTooltip('Clear Host Configuration'));
    await tester.pumpAndSettle();

    expect(find.text('Host Setup'), findsOneWidget);
    expect(await repository.loadConfig(), isNull);
  });
}
