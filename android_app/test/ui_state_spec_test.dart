// UI State Specification Tests
//
// These tests validate the screen-state model defined in:
// android_app/docs/mvp_information_architecture.md
//
// They are lightweight specification tests that document expected behavior
// before the actual implementation (Tasks 10, 11, 12).
//
// Run: flutter test test/ui_state_spec_test.dart

import 'package:flutter_test/flutter_test.dart';

/// UI State IDs matching the state machine in the IA spec
enum UiState {
  setup, // No host configured
  loading, // Polling in progress
  success, // Sensor data rendered
  empty, // API returned EMPTY status
  error, // API returned error or timeout
}

/// Test suite for UI state specification
void main() {
  group('UI State Specification', () {
    // ---------------------------------------------------------------------
    // State Identity Tests
    // ---------------------------------------------------------------------

    test('UiState enum contains all required states', () {
      const allStates = UiState.values;
      expect(allStates.length, 5);
      expect(allStates, contains(UiState.setup));
      expect(allStates, contains(UiState.loading));
      expect(allStates, contains(UiState.success));
      expect(allStates, contains(UiState.empty));
      expect(allStates, contains(UiState.error));
    });

    test('UiState has exactly 5 mutually exclusive values', () {
      const allStates = UiState.values;
      // Verify no duplicates
      final uniqueStates = allStates.toSet();
      expect(uniqueStates.length, allStates.length);
    });

    // ---------------------------------------------------------------------
    // Transition Validation Tests
    // ---------------------------------------------------------------------

    group('State transitions', () {
      test('Setup → Loading is valid', () {
        // When host is saved from Setup screen, transition to Loading
        final validTransition = _isValidTransition(
          UiState.setup,
          UiState.loading,
        );
        expect(validTransition, isTrue);
      });

      test('Loading → Success is valid', () {
        // When API returns valid sensor data
        final validTransition = _isValidTransition(
          UiState.loading,
          UiState.success,
        );
        expect(validTransition, isTrue);
      });

      test('Loading → Empty is valid', () {
        // When API returns EMPTY status
        final validTransition = _isValidTransition(
          UiState.loading,
          UiState.empty,
        );
        expect(validTransition, isTrue);
      });

      test('Loading → Error is valid', () {
        // When API returns error or timeout
        final validTransition = _isValidTransition(
          UiState.loading,
          UiState.error,
        );
        expect(validTransition, isTrue);
      });

      test('Success → Loading is valid (manual refresh)', () {
        // User triggers pull-to-refresh while in success state
        final validTransition = _isValidTransition(
          UiState.success,
          UiState.loading,
        );
        expect(validTransition, isTrue);
      });

      test('Empty → Loading is valid (retry)', () {
        // User taps retry from empty state
        final validTransition = _isValidTransition(
          UiState.empty,
          UiState.loading,
        );
        expect(validTransition, isTrue);
      });

      test('Error → Loading is valid (retry)', () {
        // User taps retry from error state
        final validTransition = _isValidTransition(
          UiState.error,
          UiState.loading,
        );
        expect(validTransition, isTrue);
      });

      test('Setup → Success is INVALID (must go through Loading)', () {
        // Direct jump from setup to success without loading state is invalid
        final validTransition = _isValidTransition(
          UiState.setup,
          UiState.success,
        );
        expect(validTransition, isFalse);
      });

      test('Success → Error is INVALID (must go through Loading)', () {
        // Direct transition without intermediate loading is invalid
        final validTransition = _isValidTransition(
          UiState.success,
          UiState.error,
        );
        expect(validTransition, isFalse);
      });

      test('Empty → Error is INVALID (different error conditions)', () {
        // Empty and error are distinct terminal states
        final validTransition = _isValidTransition(
          UiState.empty,
          UiState.error,
        );
        expect(validTransition, isFalse);
      });
    });

    // ---------------------------------------------------------------------
    // Screen Visibility Tests
    // ---------------------------------------------------------------------

    group('Screen visibility by state', () {
      test('Setup state shows HostSetupScreen', () {
        final screen = _getVisibleScreen(UiState.setup);
        expect(screen, 'HostSetupScreen');
      });

      test('Loading state shows Dashboard with loading indicator', () {
        final screen = _getVisibleScreen(UiState.loading);
        expect(screen, 'Dashboard (loading)');
      });

      test('Success state shows Dashboard with sensors', () {
        final screen = _getVisibleScreen(UiState.success);
        expect(screen, 'Dashboard (success)');
      });

      test('Empty state shows EmptyStateCard in Dashboard', () {
        final screen = _getVisibleScreen(UiState.empty);
        expect(screen, 'Dashboard (empty)');
      });

      test('Error state shows ErrorStateCard in Dashboard', () {
        final screen = _getVisibleScreen(UiState.error);
        expect(screen, 'Dashboard (error)');
      });
    });

    // ---------------------------------------------------------------------
    // Action Validation Tests
    // ---------------------------------------------------------------------

    group('State actions', () {
      test('Setup state has Save action', () {
        final actions = _getActions(UiState.setup);
        expect(actions, contains('Save'));
        expect(actions, contains('Clear'));
      });

      test('Loading state has PullToRefresh action', () {
        final actions = _getActions(UiState.loading);
        expect(actions, contains('PullToRefresh'));
      });

      test('Success state has PullToRefresh and UnitToggle actions', () {
        final actions = _getActions(UiState.success);
        expect(actions, contains('PullToRefresh'));
        expect(actions, contains('UnitToggle'));
      });

      test('Empty state has Retry action', () {
        final actions = _getActions(UiState.empty);
        expect(actions, contains('Retry'));
      });

      test('Error state has Retry action', () {
        final actions = _getActions(UiState.error);
        expect(actions, contains('Retry'));
      });

      test('No state has multi-host navigation action', () {
        // Explicit scope guard
        const allStates = UiState.values;
        for (final state in allStates) {
          final actions = _getActions(state);
          expect(
            actions,
            isNot(contains('MultiHostNavigation')),
            reason: '$state should not have multi-host nav',
          );
        }
      });

      test('No state has notification settings action', () {
        // Explicit scope guard
        const allStates = UiState.values;
        for (final state in allStates) {
          final actions = _getActions(state);
          expect(
            actions,
            isNot(contains('NotificationSettings')),
            reason: '$state should not have notification settings',
          );
        }
      });

      test('No state has host-admin action', () {
        // Explicit scope guard
        const allStates = UiState.values;
        for (final state in allStates) {
          final actions = _getActions(state);
          expect(
            actions,
            isNot(contains('HostAdmin')),
            reason: '$state should not have host-admin actions',
          );
        }
      });
    });

    // ---------------------------------------------------------------------
    // Data Source Tests
    // ---------------------------------------------------------------------

    group('Data sources by state', () {
      test('Setup state has no data source', () {
        final dataSource = _getDataSource(UiState.setup);
        expect(dataSource, 'N/A');
      });

      test('Loading state shows previous data or blank', () {
        final dataSource = _getDataSource(UiState.loading);
        expect(dataSource, 'Previous data or blank');
      });

      test('Success state shows fresh API data', () {
        final dataSource = _getDataSource(UiState.success);
        expect(dataSource, 'Fresh API response');
      });

      test('Empty state shows EMPTY API response', () {
        final dataSource = _getDataSource(UiState.empty);
        expect(dataSource, 'API response with EMPTY status');
      });

      test('Error state shows stale data or blank', () {
        final dataSource = _getDataSource(UiState.error);
        expect(dataSource, 'Stale data or blank');
      });
    });

    // ---------------------------------------------------------------------
    // Grouping Model Tests
    // ---------------------------------------------------------------------

    group('Sensor grouping model', () {
      test('Groups are organized by hardware chip/adapter', () {
        // Verify the grouping model matches the IA spec
        expect(_getGroupingModel(), 'SensorGroupCard per chip/adapter');
      });

      test('Each group has collapsible header with chip name', () {
        expect(_getGroupStructure(), contains('Chip name'));
        expect(_getGroupStructure(), contains('Adapter'));
        expect(_getGroupStructure(), contains('Expand/Collapse toggle'));
      });

      test('Sensor rows have label, value with unit, and icon', () {
        expect(_getSensorRowStructure(), contains('Label'));
        expect(_getSensorRowStructure(), contains('Value with unit'));
        expect(_getSensorRowStructure(), contains('Icon'));
      });

      test('Temperature sensor uses thermometer icon', () {
        final iconForType = _getIconForSensorType('temperature');
        expect(iconForType, 'thermometer');
      });

      test('Fan sensor uses cool-to-air icon', () {
        final iconForType = _getIconForSensorType('fan');
        expect(iconForType, 'cool-to-air');
      });

      test('Voltage sensor uses power icon', () {
        final iconForType = _getIconForSensorType('voltage');
        expect(iconForType, 'power');
      });
    });

    // ---------------------------------------------------------------------
    // Unit Preference Tests
    // ---------------------------------------------------------------------

    group('Unit preference', () {
      test('Temperature unit is persisted in SharedPreferences', () {
        final preferenceKey = _getPreferenceKey();
        expect(preferenceKey, 'sensor_units');
      });

      test('Default temperature unit is Celsius', () {
        final defaultUnit = _getDefaultTemperatureUnit();
        expect(defaultUnit, 'C');
      });

      test('Temperature conversion formula is (C × 9/5) + 32', () {
        // Verify conversion logic
        final celsius = 20.0;
        final fahrenheit = (celsius * 9 / 5) + 32;
        expect(fahrenheit, 68.0);
      });

      test('Supported temperature units are C and F', () {
        final supportedUnits = _getSupportedTemperatureUnits();
        expect(supportedUnits, unorderedEquals(['C', 'F']));
      });
    });

    // ---------------------------------------------------------------------
    // Error Handling Tests
    // ---------------------------------------------------------------------

    group('Error handling', () {
      test('Network timeout shows "Connection timed out" message', () {
        final message = _getErrorMessage('network_timeout');
        expect(message, contains('Connection timed out'));
      });

      test('Host unreachable shows "Can\'t reach the host" message', () {
        final message = _getErrorMessage('host_unreachable');
        expect(message, contains("Can't reach the host"));
      });

      test('HTTP error shows error code in message', () {
        final message = _getErrorMessage('http_500');
        expect(message, contains('500'));
      });

      test('Parse error shows "Invalid data from host" message', () {
        final message = _getErrorMessage('parse_error');
        expect(message, contains('Invalid data from host'));
      });

      test('All errors are retryable', () {
        const errorTypes = [
          'network_timeout',
          'host_unreachable',
          'http_500',
          'parse_error',
          'empty',
        ];
        for (final errorType in errorTypes) {
          expect(
            _isRetryable(errorType),
            isTrue,
            reason: '$errorType should be retryable',
          );
        }
      });

      test('Stale data threshold is 30 seconds', () {
        final threshold = _getStaleDataThreshold();
        expect(threshold, 30);
      });
    });

    // ---------------------------------------------------------------------
    // Scope Guard Tests
    // ---------------------------------------------------------------------

    group('Scope guards (MVP constraints)', () {
      test('App has exactly 2 screens: Setup and Dashboard', () {
        final screens = _getScreenCount();
        expect(screens, 2);
      });

      test('No navigation bar is present', () {
        final hasNavBar = _hasNavigationBar();
        expect(hasNavBar, isFalse);
      });

      test('No tabs or bottom navigation is present', () {
        final hasTabs = _hasTabsOrBottomNav();
        expect(hasTabs, isFalse);
      });

      test('No background services declared', () {
        final hasBackgroundServices = _hasBackgroundServices();
        expect(hasBackgroundServices, isFalse);
      });

      test('No authentication flow is present', () {
        final hasAuth = _hasAuthenticationFlow();
        expect(hasAuth, isFalse);
      });

      test('No charts or graphs are rendered', () {
        final hasCharts = _hasCharts();
        expect(hasCharts, isFalse);
      });
    });
  });
}

// ---------------------------------------------------------------------------
// Helper Functions (to be replaced with actual implementations in T10/T11)
// ---------------------------------------------------------------------------

bool _isValidTransition(UiState from, UiState to) {
  // Minimal implementation for spec validation
  // This will be replaced with actual state machine logic in T9
  final validTransitions = {
    (UiState.setup, UiState.loading): true,
    (UiState.loading, UiState.success): true,
    (UiState.loading, UiState.empty): true,
    (UiState.loading, UiState.error): true,
    (UiState.success, UiState.loading): true,
    (UiState.empty, UiState.loading): true,
    (UiState.error, UiState.loading): true,
  };
  return validTransitions[(from, to)] ?? false;
}

String _getVisibleScreen(UiState state) {
  switch (state) {
    case UiState.setup:
      return 'HostSetupScreen';
    case UiState.loading:
      return 'Dashboard (loading)';
    case UiState.success:
      return 'Dashboard (success)';
    case UiState.empty:
      return 'Dashboard (empty)';
    case UiState.error:
      return 'Dashboard (error)';
  }
}

List<String> _getActions(UiState state) {
  switch (state) {
    case UiState.setup:
      return ['Save', 'Clear'];
    case UiState.loading:
      return ['PullToRefresh'];
    case UiState.success:
      return ['PullToRefresh', 'UnitToggle'];
    case UiState.empty:
      return ['Retry'];
    case UiState.error:
      return ['Retry'];
  }
}

String _getDataSource(UiState state) {
  switch (state) {
    case UiState.setup:
      return 'N/A';
    case UiState.loading:
      return 'Previous data or blank';
    case UiState.success:
      return 'Fresh API response';
    case UiState.empty:
      return 'API response with EMPTY status';
    case UiState.error:
      return 'Stale data or blank';
  }
}

String _getGroupingModel() {
  return 'SensorGroupCard per chip/adapter';
}

List<String> _getGroupStructure() {
  return ['Chip name', 'Adapter', 'Expand/Collapse toggle'];
}

List<String> _getSensorRowStructure() {
  return ['Label', 'Value with unit', 'Icon'];
}

String _getIconForSensorType(String type) {
  switch (type) {
    case 'temperature':
      return 'thermometer';
    case 'fan':
      return 'cool-to-air';
    case 'voltage':
      return 'power';
    default:
      return 'unknown';
  }
}

String _getPreferenceKey() {
  return 'sensor_units';
}

String _getDefaultTemperatureUnit() {
  return 'C';
}

List<String> _getSupportedTemperatureUnits() {
  return ['C', 'F'];
}

String _getErrorMessage(String errorType) {
  switch (errorType) {
    case 'network_timeout':
      return 'Connection timed out. Check your network.';
    case 'host_unreachable':
      return "Can't reach the host. Is it online?";
    case 'http_500':
      return 'Service unavailable (error code: 500)';
    case 'parse_error':
      return 'Invalid data from host.';
    default:
      return 'Unknown error';
  }
}

bool _isRetryable(String errorType) {
  // All error types are retryable per the spec
  return true;
}

int _getStaleDataThreshold() {
  return 30; // seconds
}

int _getScreenCount() {
  return 2; // Setup and Dashboard
}

bool _hasNavigationBar() {
  return false;
}

bool _hasTabsOrBottomNav() {
  return false;
}

bool _hasBackgroundServices() {
  return false;
}

bool _hasAuthenticationFlow() {
  return false;
}

bool _hasCharts() {
  return false;
}
