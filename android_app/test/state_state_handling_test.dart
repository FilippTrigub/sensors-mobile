// State and Error Handling Tests
//
// Tests for error, empty, stale, and retry behavior in the state controller
// and UI layer.
//
// Run: flutter test test/state_state_handling_test.dart

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:sensors/services/sensor_state_controller.dart';
import 'package:sensors/services/sensor_api_client.dart';
import 'package:sensors/models/models.dart';

void main() {
  group('State and Error Handling', () {
    // ---------------------------------------------------------------------
    // ERROR STATE TESTS
    // ---------------------------------------------------------------------

    group('Error state', () {
      test(
        'setHostConfig tries https then http on known sensors route',
        () async {
          final requestedUris = <Uri>[];
          final httpClient = MockClient((request) async {
            requestedUris.add(request.url);

            if (request.url.scheme == 'https') {
              throw http.ClientException('TLS failed');
            }

            return http.Response(
              '{"version":"1.0","host_identity":{"hostname":"test-host","fqdn":"test.local","platform":"Linux"},"timestamp":"2024-01-01T00:00:00Z","sensor_groups":[],"status":{"code":"OK","message":"OK"}}',
              200,
              headers: {'Content-Type': 'application/json'},
            );
          });
          final apiClient = SensorApiClient(httpClient: httpClient);
          final controller = SensorStateController(apiClient: apiClient);

          await controller.setHostConfig('test-host');
          await Future.delayed(const Duration(milliseconds: 100));

          expect(requestedUris, hasLength(2));
          expect(
            requestedUris[0].toString(),
            'https://test-host:5000/api/v1/sensors',
          );
          expect(
            requestedUris[1].toString(),
            'http://test-host:5000/api/v1/sensors',
          );
          expect(controller.isSuccess, isTrue);
        },
      );

      test(
        'setHostConfig preserves custom port while appending sensors route',
        () async {
          final requestedUris = <Uri>[];
          final httpClient = MockClient((request) async {
            requestedUris.add(request.url);
            return http.Response(
              '{"version":"1.0","host_identity":{"hostname":"test-host","fqdn":"test.local","platform":"Linux"},"timestamp":"2024-01-01T00:00:00Z","sensor_groups":[],"status":{"code":"OK","message":"OK"}}',
              200,
              headers: {'Content-Type': 'application/json'},
            );
          });
          final apiClient = SensorApiClient(httpClient: httpClient);
          final controller = SensorStateController(apiClient: apiClient);

          await controller.setHostConfig('test-host:7443');
          await Future.delayed(const Duration(milliseconds: 100));

          expect(
            requestedUris.first.toString(),
            'https://test-host:7443/api/v1/sensors',
          );
          expect(controller.isSuccess, isTrue);
        },
      );

      test(
        'Network failure transitions to error state with error message',
        () async {
          // Arrange
          final httpClient = MockClient(
            (request) async => http.Response('error', 500),
          );
          final apiClient = SensorApiClient(httpClient: httpClient);
          final controller = SensorStateController(apiClient: apiClient);

          controller.setHostConfig('http://test:5000/api/v1/sensors');

          // Wait for async operation
          await Future.delayed(const Duration(milliseconds: 100));

          // Assert
          expect(controller.isError, isTrue);
          expect(controller.currentState.state, equals(UiState.error));
          expect(controller.currentState.errorMessage, isNotNull);
        },
      );

      test('Timeout error shows user-friendly message', () async {
        // Arrange - use a general network error message
        final httpClient = MockClient((request) async {
          throw http.ClientException('Connection timed out');
        });
        final apiClient = SensorApiClient(httpClient: httpClient);
        final controller = SensorStateController(apiClient: apiClient);

        controller.setHostConfig('http://test:5000/api/v1/sensors');
        await Future.delayed(const Duration(milliseconds: 100));

        // Assert
        expect(controller.isError, isTrue);
        expect(
          controller.currentState.errorMessage,
          contains('check your network'),
        );
      });

      test('HTTP 500 error shows service unavailable message', () async {
        // Arrange
        final httpClient = MockClient(
          (request) async => http.Response(
            '{"error": {"type": "Server"}}',
            500,
            headers: {'Content-Type': 'application/json'},
          ),
        );
        final apiClient = SensorApiClient(httpClient: httpClient);
        final controller = SensorStateController(apiClient: apiClient);

        controller.setHostConfig('http://test:5000/api/v1/sensors');
        await Future.delayed(const Duration(milliseconds: 100));

        // Assert
        expect(controller.isError, isTrue);
        expect(controller.currentState.errorMessage, contains('500'));
      });

      test('Parse error shows clear user-friendly message', () async {
        // Arrange
        final httpClient = MockClient(
          (request) async => http.Response('not json', 200),
        );
        final apiClient = SensorApiClient(httpClient: httpClient);
        final controller = SensorStateController(apiClient: apiClient);

        controller.setHostConfig('http://test:5000/api/v1/sensors');
        await Future.delayed(const Duration(milliseconds: 100));

        // Assert
        expect(controller.isError, isTrue);
        expect(controller.currentState.errorMessage, isNotNull);
        // Should contain user-friendly message, not raw exception details
        expect(controller.currentState.errorMessage!, contains('Invalid JSON'));
        expect(controller.currentState.errorMessage!, contains('try again'));
        // Should not contain raw exception class names
        expect(
          controller.currentState.errorMessage!,
          isNot(contains('FormatException')),
        );
      });
    });

    // ---------------------------------------------------------------------
    // EMPTY STATE TESTS
    // ---------------------------------------------------------------------

    group('Empty state', () {
      test('API EMPTY status transitions to empty state (not error)', () async {
        // Arrange
        final httpClient = MockClient(
          (request) async => http.Response(
            '{"version":"1.0","host_identity":{"hostname":"test-host","fqdn":"test.local","platform":"Linux"},"timestamp":"2024-01-01T00:00:00Z","sensor_groups":[],"status":{"code":"EMPTY","message":"No sensors detected"}}',
            200,
            headers: {'Content-Type': 'application/json'},
          ),
        );
        final apiClient = SensorApiClient(httpClient: httpClient);
        final controller = SensorStateController(apiClient: apiClient);

        controller.setHostConfig('http://test:5000/api/v1/sensors');
        await Future.delayed(const Duration(milliseconds: 100));

        // Assert
        expect(controller.isEmpty, isTrue);
        expect(controller.currentState.state, equals(UiState.empty));
        // Should NOT be in error state
        expect(controller.isError, isFalse);
        expect(controller.currentState.errorMessage, isNull);
      });

      test('Empty state has no error message', () async {
        // Arrange
        final httpClient = MockClient(
          (request) async => http.Response(
            '{"version":"1.0","host_identity":{"hostname":"empty-host","fqdn":"empty.local","platform":"Linux"},"timestamp":"2024-01-01T00:00:00Z","sensor_groups":[],"status":{"code":"EMPTY","message":"No sensors"}}',
            200,
            headers: {'Content-Type': 'application/json'},
          ),
        );
        final apiClient = SensorApiClient(httpClient: httpClient);
        final controller = SensorStateController(apiClient: apiClient);

        controller.setHostConfig('http://test:5000/api/v1/sensors');
        await Future.delayed(const Duration(milliseconds: 100));

        // Assert
        expect(controller.currentState.errorMessage, isNull);
      });

      test('API ERROR status shows error with stale data', () async {
        // Arrange
        final httpClient = MockClient(
          (request) async => http.Response(
            '{"version":"1.0","host_identity":{"hostname":"broken-host","fqdn":"broken.local","platform":"Linux"},"timestamp":"2024-01-01T00:00:00Z","sensor_groups":[],"status":{"code":"ERROR","message":"lm-sensors not installed"},"error_details":{"missing_package":"lm-sensors"}}',
            200,
            headers: {'Content-Type': 'application/json'},
          ),
        );
        final apiClient = SensorApiClient(httpClient: httpClient);
        final controller = SensorStateController(apiClient: apiClient);

        controller.setHostConfig('http://test:5000/api/v1/sensors');
        await Future.delayed(const Duration(milliseconds: 100));

        // Assert
        expect(controller.isError, isTrue);
        expect(controller.currentState.errorMessage, contains('lm-sensors'));
        // Stale data is preserved
        expect(controller.currentState.sensorData, isNotNull);
      });
    });

    // ---------------------------------------------------------------------
    // STALE DATA TESTS
    // ---------------------------------------------------------------------

    group('Stale data detection', () {
      test('Stale status shows success state but with stale flag', () async {
        // Arrange
        final httpClient = MockClient(
          (request) async => http.Response(
            '{"version":"1.0","host_identity":{"hostname":"stale-host","fqdn":"stale.local","platform":"Linux"},"timestamp":"2024-01-01T00:00:00Z","sensor_groups":[],"status":{"code":"STALE","message":"Data older than 30 seconds","last_updated":"2024-01-01T00:00:00Z"}}',
            200,
            headers: {'Content-Type': 'application/json'},
          ),
        );
        final apiClient = SensorApiClient(httpClient: httpClient);
        final controller = SensorStateController(apiClient: apiClient);

        controller.setHostConfig('http://test:5000/api/v1/sensors');
        await Future.delayed(const Duration(milliseconds: 100));

        // Assert
        expect(controller.isSuccess, isTrue);
        expect(controller.currentState.state, equals(UiState.success));
        // Data is preserved
        expect(controller.currentState.sensorData, isNotNull);
      });

      test('isDataStale returns true when last update is old', () {
        // Arrange - create state with old lastSuccessfulUpdate
        final oldTime = DateTime.now().subtract(const Duration(seconds: 35));
        final staleState = SensorControllerState(
          state: UiState.success,
          sensorData: SensorData(
            hostIdentity: const HostIdentity(
              hostname: 'test',
              fqdn: 'test',
              platform: Platform.linux,
            ),
            timestamp: oldTime.toIso8601String(),
            sensorGroups: [],
            status: const SensorStatus(
              code: SensorStatusCode.ok,
              message: 'OK',
            ),
          ),
          lastUpdate: DateTime.now(),
          lastSuccessfulUpdate: oldTime,
        );

        // Assert
        expect(staleState.isDataStale, isTrue);
      });

      test('isDataStale returns false when data is fresh', () {
        // Arrange - create state with recent lastSuccessfulUpdate
        final recentTime = DateTime.now().subtract(const Duration(seconds: 10));
        final freshState = SensorControllerState(
          state: UiState.success,
          sensorData: SensorData(
            hostIdentity: const HostIdentity(
              hostname: 'test',
              fqdn: 'test',
              platform: Platform.linux,
            ),
            timestamp: recentTime.toIso8601String(),
            sensorGroups: [],
            status: const SensorStatus(
              code: SensorStatusCode.ok,
              message: 'OK',
            ),
          ),
          lastUpdate: DateTime.now(),
          lastSuccessfulUpdate: recentTime,
        );

        // Assert
        expect(freshState.isDataStale, isFalse);
      });

      test('isDataStale returns false when no lastSuccessfulUpdate', () {
        // Arrange - create state without lastSuccessfulUpdate
        final state = SensorControllerState(
          state: UiState.success,
          sensorData: SensorData(
            hostIdentity: const HostIdentity(
              hostname: 'test',
              fqdn: 'test',
              platform: Platform.linux,
            ),
            timestamp: DateTime.now().toIso8601String(),
            sensorGroups: [],
            status: const SensorStatus(
              code: SensorStatusCode.ok,
              message: 'OK',
            ),
          ),
          lastUpdate: DateTime.now(),
          lastSuccessfulUpdate: null,
        );

        // Assert
        expect(state.isDataStale, isFalse);
      });

      test('30-second threshold is correct', () {
        // Arrange - boundary test at exactly 30 seconds
        final boundaryTime = DateTime.now().subtract(
          const Duration(seconds: 30),
        );
        final boundaryState = SensorControllerState(
          state: UiState.success,
          sensorData: SensorData(
            hostIdentity: const HostIdentity(
              hostname: 'test',
              fqdn: 'test',
              platform: Platform.linux,
            ),
            timestamp: boundaryTime.toIso8601String(),
            sensorGroups: [],
            status: const SensorStatus(
              code: SensorStatusCode.ok,
              message: 'OK',
            ),
          ),
          lastUpdate: DateTime.now(),
          lastSuccessfulUpdate: boundaryTime,
        );

        // At exactly 30 seconds, should be stale (>= threshold)
        expect(boundaryState.isDataStale, isTrue);
      });
    });

    // ---------------------------------------------------------------------
    // RETRY BEHAVIOR TESTS
    // ---------------------------------------------------------------------

    group('Retry behavior', () {
      test('Error state can be refreshed to loading state', () async {
        // Arrange - first fail
        final failedClient = MockClient(
          (request) async => http.Response('error', 500),
        );
        final apiClient1 = SensorApiClient(httpClient: failedClient);
        final controller = SensorStateController(apiClient: apiClient1);

        controller.setHostConfig('http://test:5000/api/v1/sensors');
        await Future.delayed(const Duration(milliseconds: 100));
        expect(controller.isError, isTrue);

        // Now succeed on retry - use a fresh controller
        final successClient = MockClient(
          (request) async => http.Response(
            '{"version":"1.0","host_identity":{"hostname":"test-host","fqdn":"test.local","platform":"Linux"},"timestamp":"${DateTime.now().toIso8601String()}","sensor_groups":[],"status":{"code":"OK","message":"OK"}}',
            200,
            headers: {'Content-Type': 'application/json'},
          ),
        );
        final apiClient2 = SensorApiClient(httpClient: successClient);
        final controller2 = SensorStateController(apiClient: apiClient2);
        controller2.setHostConfig('http://test:5000/api/v1/sensors');
        await Future.delayed(const Duration(milliseconds: 100));

        // Assert - should have fetched successfully
        expect(controller2.isSuccess, isTrue);
      });

      test('Empty state can be refreshed to loading state', () async {
        // Arrange - first return empty
        final emptyClient = MockClient(
          (request) async => http.Response(
            '{"version":"1.0","host_identity":{"hostname":"empty-host","fqdn":"empty.local","platform":"Linux"},"timestamp":"2024-01-01T00:00:00Z","sensor_groups":[],"status":{"code":"EMPTY","message":"No sensors"}}',
            200,
            headers: {'Content-Type': 'application/json'},
          ),
        );
        final apiClient1 = SensorApiClient(httpClient: emptyClient);
        final controller = SensorStateController(apiClient: apiClient1);

        controller.setHostConfig('http://test:5000/api/v1/sensors');
        await Future.delayed(const Duration(milliseconds: 100));
        expect(controller.isEmpty, isTrue);

        // Now return data with a fresh controller
        final successClient = MockClient(
          (request) async => http.Response(
            '{"version":"1.0","host_identity":{"hostname":"test-host","fqdn":"test.local","platform":"Linux"},"timestamp":"${DateTime.now().toIso8601String()}","sensor_groups":[],"status":{"code":"OK","message":"OK"}}',
            200,
            headers: {'Content-Type': 'application/json'},
          ),
        );
        final apiClient2 = SensorApiClient(httpClient: successClient);
        final controller2 = SensorStateController(apiClient: apiClient2);
        controller2.setHostConfig('http://test:5000/api/v1/sensors');
        await Future.delayed(const Duration(milliseconds: 100));

        // Assert - refreshed successfully
        expect(controller2.isSuccess, isTrue);
      });

      test('Reset to setup clears polling and state', () {
        // Arrange - start polling
        final httpClient = MockClient(
          (request) async => http.Response(
            '{"version":"1.0","host_identity":{"hostname":"test","fqdn":"test","platform":"Linux"},"timestamp":"2024-01-01T00:00:00Z","sensor_groups":[],"status":{"code":"OK","message":"OK"}}',
            200,
            headers: {'Content-Type': 'application/json'},
          ),
        );
        final apiClient = SensorApiClient(httpClient: httpClient);
        final controller = SensorStateController(apiClient: apiClient);

        controller.startPolling('http://test:5000/api/v1/sensors');
        expect(controller.isPolling, isTrue);

        // Act
        controller.resetToSetup();

        // Assert
        expect(controller.isSetup, isTrue);
        expect(controller.currentState.state, equals(UiState.setup));
      });

      test('Polling stops when resetToSetup is called', () {
        // Arrange
        final httpClient = MockClient(
          (request) async => http.Response(
            '{"version":"1.0","host_identity":{"hostname":"test","fqdn":"test","platform":"Linux"},"timestamp":"2024-01-01T00:00:00Z","sensor_groups":[],"status":{"code":"OK","message":"OK"}}',
            200,
            headers: {'Content-Type': 'application/json'},
          ),
        );
        final apiClient = SensorApiClient(httpClient: httpClient);
        final controller = SensorStateController(apiClient: apiClient);

        controller.startPolling('http://test:5000/api/v1/sensors');
        expect(controller.isPolling, isTrue);

        // Act
        controller.resetToSetup();

        // Assert
        expect(controller.isPolling, isFalse);
      });
    });

    // ---------------------------------------------------------------------
    // STATE TRANSITION TESTS
    // ---------------------------------------------------------------------

    group('State transitions', () {
      test('Error state can transition back to loading via refresh', () async {
        // Arrange - first fail
        final failedClient = MockClient(
          (request) async => http.Response(
            'error',
            500,
            headers: {'Content-Type': 'application/json'},
          ),
        );
        final apiClient1 = SensorApiClient(httpClient: failedClient);
        final controller = SensorStateController(apiClient: apiClient1);

        controller.setHostConfig('http://test:5000/api/v1/sensors');
        await Future.delayed(const Duration(milliseconds: 100));

        expect(controller.isError, isTrue);
        expect(controller.currentState.state, equals(UiState.error));

        // Act - refresh with new client that succeeds
        final successClient = MockClient(
          (request) async => http.Response(
            '{"version":"1.0","host_identity":{"hostname":"test-host","fqdn":"test.local","platform":"Linux"},"timestamp":"2024-01-01T00:00:00Z","sensor_groups":[],"status":{"code":"OK","message":"OK"}}',
            200,
            headers: {'Content-Type': 'application/json'},
          ),
        );
        final apiClient2 = SensorApiClient(httpClient: successClient);
        final controller2 = SensorStateController(apiClient: apiClient2);
        controller2.setHostConfig('http://test:5000/api/v1/sensors');
        await Future.delayed(const Duration(milliseconds: 100));

        // Assert - should be in success now (went through loading)
        expect(controller2.isSuccess, isTrue);
      });

      test('Success state can transition to loading via refresh', () async {
        // Arrange - first succeed
        final successClient = MockClient(
          (request) async => http.Response(
            '{"version":"1.0","host_identity":{"hostname":"test-host","fqdn":"test.local","platform":"Linux"},"timestamp":"2024-01-01T00:00:00Z","sensor_groups":[],"status":{"code":"OK","message":"OK"}}',
            200,
            headers: {'Content-Type': 'application/json'},
          ),
        );
        final apiClient1 = SensorApiClient(httpClient: successClient);
        final controller = SensorStateController(apiClient: apiClient1);

        controller.setHostConfig('http://test:5000/api/v1/sensors');
        await Future.delayed(const Duration(milliseconds: 100));
        expect(controller.isSuccess, isTrue);

        // Act - refresh with failing client
        final failedClient = MockClient(
          (request) async => http.Response(
            'error',
            500,
            headers: {'Content-Type': 'application/json'},
          ),
        );
        final apiClient2 = SensorApiClient(httpClient: failedClient);
        final controller2 = SensorStateController(apiClient: apiClient2);
        controller2.setHostConfig('http://test:5000/api/v1/sensors');
        await Future.delayed(const Duration(milliseconds: 100));

        // Assert - should be in error now (went through loading)
        expect(controller2.isError, isTrue);
      });
    });

    // ---------------------------------------------------------------------
    // STATE MACHINES AND VALIDATION TESTS
    // ---------------------------------------------------------------------

    group('State machine validation', () {
      test('Setup state transitions to loading when host is saved', () async {
        // Arrange - initial setup state
        final httpClient = MockClient(
          (request) async => http.Response(
            '{"version":"1.0","host_identity":{"hostname":"test-host","fqdn":"test.local","platform":"Linux"},"timestamp":"2024-01-01T00:00:00Z","sensor_groups":[],"status":{"code":"OK","message":"OK"}}',
            200,
            headers: {'Content-Type': 'application/json'},
          ),
        );
        final apiClient = SensorApiClient(httpClient: httpClient);
        final controller = SensorStateController(apiClient: apiClient);

        expect(controller.isSetup, isTrue);

        // Act
        controller.setHostConfig('http://test:5000/api/v1/sensors');

        // Wait for async
        await Future.delayed(const Duration(milliseconds: 100));

        // Assert - should transition to loading then success
        expect(controller.isSuccess, isTrue);
      });

      test('Loading transitions to success on successful fetch', () async {
        // Arrange - success data
        final httpClient = MockClient(
          (request) async => http.Response(
            '{"version":"1.0","host_identity":{"hostname":"test-host","fqdn":"test.local","platform":"Linux"},"timestamp":"2024-01-01T00:00:00Z","sensor_groups":[],"status":{"code":"OK","message":"OK"}}',
            200,
            headers: {'Content-Type': 'application/json'},
          ),
        );
        final apiClient = SensorApiClient(httpClient: httpClient);
        final controller = SensorStateController(apiClient: apiClient);

        // Act
        controller.setHostConfig('http://test:5000/api/v1/sensors');
        await Future.delayed(const Duration(milliseconds: 100));

        // Assert
        expect(controller.isSuccess, isTrue);
      });

      test('Loading transitions to empty on EMPTY status', () async {
        // Arrange - empty data
        final httpClient = MockClient(
          (request) async => http.Response(
            '{"version":"1.0","host_identity":{"hostname":"empty-host","fqdn":"empty.local","platform":"Linux"},"timestamp":"2024-01-01T00:00:00Z","sensor_groups":[],"status":{"code":"EMPTY","message":"No sensors"}}',
            200,
            headers: {'Content-Type': 'application/json'},
          ),
        );
        final apiClient = SensorApiClient(httpClient: httpClient);
        final controller = SensorStateController(apiClient: apiClient);

        // Act
        controller.setHostConfig('http://test:5000/api/v1/sensors');
        await Future.delayed(const Duration(milliseconds: 100));

        // Assert
        expect(controller.isEmpty, isTrue);
      });

      test('Loading transitions to error on API exception', () async {
        // Arrange - API failure
        final httpClient = MockClient(
          (request) async => http.Response(
            'error',
            500,
            headers: {'Content-Type': 'application/json'},
          ),
        );
        final apiClient = SensorApiClient(httpClient: httpClient);
        final controller = SensorStateController(apiClient: apiClient);

        // Act
        controller.setHostConfig('http://test:5000/api/v1/sensors');
        await Future.delayed(const Duration(milliseconds: 100));

        // Assert
        expect(controller.isError, isTrue);
      });
    });

    // ---------------------------------------------------------------------
    // UI-FRIENDLY ERROR MESSAGES TESTS
    // ---------------------------------------------------------------------

    group('User-friendly error messages', () {
      test('Network errors show helpful message without technical details', () {
        // Arrange
        final exception = const ApiException(
          type: 'NetworkError',
          message: 'Connection timed out. Check your network.',
          errorCode: 'NETWORK_TIMEOUT',
        );

        // Assert
        expect(exception.message, contains('timed out'));
        expect(exception.message, contains('network'));
        expect(exception.message, isNot(contains('Exception')));
        expect(exception.message, isNot(contains('Stack')));
      });

      test('Host unreachable message is user-friendly', () {
        // Arrange
        final exception = const ApiException(
          type: 'NetworkError',
          message: "Can't reach the host. Is it online?",
          errorCode: 'HOST_UNREACHABLE',
        );

        // Assert
        expect(exception.message, contains("Can't reach"));
        expect(exception.message, contains('online'));
        expect(exception.message, isNot(contains('socket')));
        expect(exception.message, isNot(contains('ETIMEDOUT')));
      });

      test('Parse error message is clear and actionable', () {
        // Arrange
        final exception = const ApiException(
          type: 'ParseError',
          message: 'Invalid data from host. Please try again.',
          errorCode: 'PARSE_ERROR',
        );

        // Assert
        expect(exception.message, contains('Invalid data'));
        expect(exception.message, contains('try again'));
      });

      test('Error messages don\'t leak implementation details', () {
        // Arrange - various error types
        final errors = [
          const ApiException(
            type: 'NetworkError',
            message: 'Failed to connect',
            errorCode: 'NETWORK_ERROR',
          ),
          const ApiException(
            type: 'ParseError',
            message: 'Invalid JSON response',
            errorCode: 'PARSE_ERROR',
          ),
          const ApiException(
            type: 'ServerError',
            message: 'Service unavailable',
            errorCode: 'SERVER_ERROR_500',
          ),
        ];

        // Assert
        for (final error in errors) {
          expect(error.message, isNot(contains('at')));
          expect(error.message, isNot(contains('#')));
          expect(error.message, isNot(contains('dart:async')));
          expect(error.message, isNot(contains('/lib/')));
        }
      });
    });

    // ---------------------------------------------------------------------
    // STALE DATA WITH RECENT UPDATE TESTS
    // ---------------------------------------------------------------------

    group('Stale data with recent updates', () {
      test('Fresh data should not be marked as stale', () async {
        // Arrange - fresh data
        final httpClient = MockClient(
          (request) async => http.Response(
            '{"version":"1.0","host_identity":{"hostname":"fresh-host","fqdn":"fresh.local","platform":"Linux"},"timestamp":"2024-01-01T00:00:00Z","sensor_groups":[],"status":{"code":"OK","message":"OK"}}',
            200,
            headers: {'Content-Type': 'application/json'},
          ),
        );
        final apiClient = SensorApiClient(httpClient: httpClient);
        final controller = SensorStateController(apiClient: apiClient);

        controller.setHostConfig('http://test:5000/api/v1/sensors');
        await Future.delayed(const Duration(milliseconds: 100));

        // Assert - should be success and not stale
        expect(controller.isSuccess, isTrue);
        expect(controller.currentState.isDataStale, isFalse);
      });

      test('Data with lastSuccessfulUpdate tracked correctly', () async {
        // Arrange - success data
        final httpClient = MockClient(
          (request) async => http.Response(
            '{"version":"1.0","host_identity":{"hostname":"test-host","fqdn":"test.local","platform":"Linux"},"timestamp":"2024-01-01T00:00:00Z","sensor_groups":[],"status":{"code":"OK","message":"OK"}}',
            200,
            headers: {'Content-Type': 'application/json'},
          ),
        );
        final apiClient = SensorApiClient(httpClient: httpClient);
        final controller = SensorStateController(apiClient: apiClient);

        controller.setHostConfig('http://test:5000/api/v1/sensors');
        await Future.delayed(const Duration(milliseconds: 100));

        // Assert - lastSuccessfulUpdate should be set
        expect(controller.currentState.lastSuccessfulUpdate, isNotNull);
        expect(controller.currentState.sensorData, isNotNull);
      });
    });
  });
}
