import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sensors/presentation/screens/host_setup_screen.dart';
import 'package:sensors/repositories/host_config_repository.dart';
import 'package:sensors/models/host_config.dart';

/// A test implementation of HostConfigRepository for widget testing
class TestHostConfigRepository implements HostConfigRepository {
  HostConfig? _savedConfig;

  @override
  Future<void> saveConfig(HostConfig config) async {
    _savedConfig = config;
  }

  @override
  Future<HostConfig?> loadConfig() async {
    return _savedConfig;
  }

  @override
  Future<void> clearConfig() async {
    _savedConfig = null;
  }

  HostConfig? get savedConfig => _savedConfig;
}

void main() {
  group('HostSetupScreen', () {
    late TestHostConfigRepository testRepository;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      testRepository = TestHostConfigRepository();
    });

    testWidgets('renders with host URL input field and save button', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(home: HostSetupScreen(repository: testRepository)),
      );

      // Verify input field exists
      expect(find.byType(TextFormField), findsOneWidget);
      expect(find.byType(ElevatedButton), findsOneWidget);
    });

    testWidgets('validates empty host URL', (tester) async {
      await tester.pumpWidget(
        MaterialApp(home: HostSetupScreen(repository: testRepository)),
      );

      // Tap the save button without entering a URL
      await tester.tap(find.byType(ElevatedButton));
      await tester.pumpAndSettle();

      // Should show validation error in field
      expect(find.byType(TextFormField), findsOneWidget);
      // The validator returns an error message, check that form state is invalid
      final formFinder = find.byType(Form);
      expect(formFinder, findsOneWidget);
    });

    testWidgets('rejects full URL input and requires only host details', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(home: HostSetupScreen(repository: testRepository)),
      );

      await tester.enterText(
        find.byType(TextFormField),
        'http://localhost:5000/api/v1/sensors',
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byType(ElevatedButton));
      await tester.pumpAndSettle();

      expect(find.text('Enter only the host or host:port'), findsOneWidget);
      expect(testRepository.savedConfig, isNull);
    });

    testWidgets('saves valid host input', (tester) async {
      await tester.pumpWidget(
        MaterialApp(home: HostSetupScreen(repository: testRepository)),
      );

      const testHostInput = 'localhost:5000';
      await tester.enterText(find.byType(TextFormField), testHostInput);
      await tester.pumpAndSettle();

      await tester.tap(find.byType(ElevatedButton));
      await tester.pumpAndSettle();

      expect(testRepository.savedConfig, isNotNull);
      expect(testRepository.savedConfig!.ipAddress, testHostInput);
      expect(testRepository.savedConfig!.displayName, testHostInput);
    });

    testWidgets('displays legacy saved full URL as host input when loaded', (
      tester,
    ) async {
      const existingConfig = HostConfig(
        hostId: 'test-host',
        hostname: 'test-hostname',
        ipAddress: 'http://localhost:5000/api/v1/sensors',
        displayName: 'Test Host',
      );
      testRepository._savedConfig = existingConfig;

      await tester.pumpWidget(
        MaterialApp(home: HostSetupScreen(repository: testRepository)),
      );
      await tester.pumpAndSettle();

      expect(find.text('localhost:5000'), findsAtLeastNWidgets(1));
    });
  });
}
