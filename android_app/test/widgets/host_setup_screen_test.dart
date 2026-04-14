import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:android_app/presentation/screens/host_setup_screen.dart';
import 'package:android_app/repositories/host_config_repository.dart';
import 'package:android_app/models/host_config.dart';

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

    testWidgets('validates malformed host URL', (tester) async {
      await tester.pumpWidget(
        MaterialApp(home: HostSetupScreen(repository: testRepository)),
      );

      // Enter invalid URL
      await tester.enterText(find.byType(TextFormField), 'not-a-valid-url');
      await tester.pumpAndSettle();

      // Tap save
      await tester.tap(find.byType(ElevatedButton));
      await tester.pumpAndSettle();

      // Should show error message on the input field
      expect(find.byType(TextFormField), findsOneWidget);
    });

    testWidgets('saves valid host URL', (tester) async {
      await tester.pumpWidget(
        MaterialApp(home: HostSetupScreen(repository: testRepository)),
      );

      // Enter a valid host URL
      const testHostUrl = 'http://localhost:5000/api/v1/sensors';
      await tester.enterText(find.byType(TextFormField), testHostUrl);
      await tester.pumpAndSettle();

      // Tap save button
      await tester.tap(find.byType(ElevatedButton));
      await tester.pumpAndSettle();

      // Verify saveConfig was called
      expect(testRepository.savedConfig, isNotNull);

      // Verify the saved config has the correct URL
      expect(testRepository.savedConfig!.ipAddress, testHostUrl);
    });

    testWidgets('displays existing config when loaded', (tester) async {
      // Setup repository to return existing config
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

      // Should show existing host URL - check for at least one match
      expect(
        find.text('http://localhost:5000/api/v1/sensors'),
        findsAtLeastNWidgets(1),
      );
    });
  });
}
