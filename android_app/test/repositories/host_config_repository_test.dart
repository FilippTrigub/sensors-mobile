import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:android_app/repositories/user_preferences_repository.dart';
import 'package:android_app/repositories/host_config_repository.dart';
import 'package:android_app/models/host_config.dart';
import 'package:android_app/models/enums.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('HostConfigRepository', () {
    test('saves host configuration', () async {
      final repo = HostConfigRepository();
      final config = HostConfig(
        hostId: 'host-001',
        hostname: 'dev-server',
        ipAddress: '192.168.1.100',
        displayName: 'Development Server',
        isOnline: true,
        lastConnected: DateTime(2026, 4, 13, 21, 0, 0).toIso8601String(),
      );

      await repo.saveConfig(config);

      final saved = await repo.loadConfig();
      expect(saved, isNotNull);
      expect(saved!.hostId, 'host-001');
      expect(saved.hostname, 'dev-server');
      expect(saved.ipAddress, '192.168.1.100');
    });

    test('loads null when no config exists', () async {
      final repo = HostConfigRepository();
      final config = await repo.loadConfig();
      expect(config, isNull);
    });

    test('updates existing host configuration', () async {
      final repo = HostConfigRepository();
      final initialConfig = HostConfig(
        hostId: 'host-001',
        hostname: 'dev-server',
        ipAddress: '192.168.1.100',
        displayName: 'Dev Server',
        isOnline: true,
        lastConnected: DateTime(2026, 4, 13, 21, 0, 0).toIso8601String(),
      );

      await repo.saveConfig(initialConfig);

      final updatedConfig = HostConfig(
        hostId: 'host-001',
        hostname: 'updated-server',
        ipAddress: '192.168.1.200',
        displayName: 'Updated Server',
        isOnline: false,
        lastConnected: DateTime(2026, 4, 14, 10, 0, 0).toIso8601String(),
      );

      await repo.saveConfig(updatedConfig);

      final loaded = await repo.loadConfig();
      expect(loaded!.hostname, 'updated-server');
      expect(loaded.ipAddress, '192.168.1.200');
      expect(loaded.displayName, 'Updated Server');
      expect(loaded.isOnline, false);
    });

    test('serializes and deserializes correctly', () async {
      final repo = HostConfigRepository();
      final config = HostConfig(
        hostId: 'unique-host-id',
        hostname: 'test-host',
        ipAddress: '10.0.0.1',
        displayName: 'Test Host',
        isOnline: true,
        lastConnected: '2026-04-14T00:00:00.000Z',
      );

      await repo.saveConfig(config);

      final loaded = await repo.loadConfig();
      expect(loaded?.hostId, config.hostId);
      expect(loaded?.hostname, config.hostname);
      expect(loaded?.ipAddress, config.ipAddress);
      expect(loaded?.displayName, config.displayName);
      expect(loaded?.isOnline, config.isOnline);
      expect(loaded?.lastConnected, config.lastConnected);
    });
  });

  group('UserPreferencesRepository', () {
    late UserPreferencesRepository repo;

    setUp(() {
      SharedPreferences.setMockInitialValues({});
      repo = UserPreferencesRepository();
    });

    test('saves and retrieves temperature unit preference', () async {
      await repo.setTemperatureUnit(TemperatureUnit.celsius);
      final unit = await repo.getTemperatureUnit();
      expect(unit, TemperatureUnit.celsius);
    });

    test('defaults to Celsius when not set', () async {
      final unit = await repo.getTemperatureUnit();
      expect(unit, TemperatureUnit.celsius);
    });

    test('updates temperature unit preference', () async {
      await repo.setTemperatureUnit(TemperatureUnit.celsius);
      await repo.setTemperatureUnit(TemperatureUnit.fahrenheit);
      final unit = await repo.getTemperatureUnit();
      expect(unit, TemperatureUnit.fahrenheit);
    });

    test('saves and retrieves autoRefresh preference', () async {
      await repo.setAutoRefresh(true);
      final autoRefresh = await repo.getAutoRefresh();
      expect(autoRefresh, true);
    });

    test('defaults autoRefresh to false when not set', () async {
      final autoRefresh = await repo.getAutoRefresh();
      expect(autoRefresh, false);
    });

    test('saves and retrieves showDetailedView preference', () async {
      await repo.setShowDetailedView(true);
      final showDetails = await repo.getShowDetailedView();
      expect(showDetails, true);
    });

    test('defaults showDetailedView to true when not set', () async {
      final showDetails = await repo.getShowDetailedView();
      expect(showDetails, true);
    });
  });

  group('HostConfig model equality', () {
    test('two configs with same values are equal', () {
      final config1 = HostConfig(
        hostId: 'host-001',
        hostname: 'server',
        ipAddress: '192.168.1.1',
        displayName: 'Test',
        isOnline: true,
        lastConnected: '2026-04-14T00:00:00Z',
      );
      final config2 = HostConfig(
        hostId: 'host-001',
        hostname: 'server',
        ipAddress: '192.168.1.1',
        displayName: 'Test',
        isOnline: true,
        lastConnected: '2026-04-14T00:00:00Z',
      );

      expect(config1, equals(config2));
    });

    test('two configs with different IPs are not equal', () {
      final config1 = HostConfig(
        hostId: 'host-001',
        hostname: 'server',
        ipAddress: '192.168.1.1',
        displayName: 'Test',
        isOnline: true,
        lastConnected: '2026-04-14T00:00:00Z',
      );
      final config2 = HostConfig(
        hostId: 'host-001',
        hostname: 'server',
        ipAddress: '192.168.1.2',
        displayName: 'Test',
        isOnline: true,
        lastConnected: '2026-04-14T00:00:00Z',
      );

      expect(config1, isNot(equals(config2)));
    });
  });
}
