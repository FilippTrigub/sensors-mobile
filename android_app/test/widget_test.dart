// This is a basic Flutter widget test for the real app.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:android_app/main.dart';
import 'package:android_app/repositories/host_config_repository.dart';
import 'package:android_app/models/host_config.dart';

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
      ipAddress: 'http://localhost:5000/api/v1/sensors',
      displayName: 'Test Host',
    );
    await repository.saveConfig(testConfig);

    await tester.pumpWidget(const MyApp());
    await tester.pumpAndSettle();

    // Should show dashboard after pre-configured host
    expect(find.text('Sensors'), findsOneWidget);
    expect(find.byType(AppBar), findsOneWidget);
  });
}
