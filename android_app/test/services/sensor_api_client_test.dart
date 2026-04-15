// Sensor API Client Tests
//
// TDD tests for the API client.
// Covers: success, empty, error, stale, and polling behavior.
//
// Run: flutter test test/services/sensor_api_client_test.dart

import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:mockito/annotations.dart';
import 'package:http/http.dart' as http;

import 'package:sensors/services/sensor_api_client.dart';
import 'package:sensors/models/models.dart';

// Mock HTTP client for testing
@GenerateMocks([http.Client])
import 'sensor_api_client_test.mocks.dart';

void main() {
  group('SensorApiClient', () {
    late SensorApiClient client;
    late MockClient mockHttpClient;

    setUp(() {
      mockHttpClient = MockClient();
      client = SensorApiClient(httpClient: mockHttpClient);
    });

    // ---------------------------------------------------------------------
    // SUCCESS SCENARIO TESTS
    // ---------------------------------------------------------------------

    group('Fetch success scenarios', () {
      test('fetchSensors returns SensorData with OK status', () async {
        // Arrange
        final mockResponse = http.Response(
          '''{
            "version": "1.0",
            "host_identity": {
              "hostname": "test-host",
              "fqdn": "test.local",
              "platform": "Linux"
            },
            "timestamp": "2024-01-01T00:00:00Z",
            "sensor_groups": [],
            "status": {
              "code": "OK",
              "message": "Sensors collected successfully"
            }
          }''',
          200,
          headers: {'Content-Type': 'application/json'},
        );

        when(mockHttpClient.get(any)).thenAnswer((_) async => mockResponse);

        // Act
        final result = await client.fetchSensors(
          'http://test:5000/api/v1/sensors',
        );

        // Assert
        expect(result, isA<SensorData>());
        expect(result.status.code, SensorStatusCode.ok);
        expect(result.hostIdentity.hostname, 'test-host');
      });

      test('fetchSensors parses sensor groups correctly', () async {
        // Arrange - contract-compliant JSON with adapter (singular)
        final mockResponse = http.Response(
          '''{
            "version": "1.0",
            "host_identity": {
              "hostname": "test-host",
              "fqdn": "test.local",
              "platform": "Linux"
            },
            "timestamp": "2024-01-01T00:00:00Z",
            "sensor_groups": [
              {
                "name": "coretemp-isa-0000",
                "adapter": "isa0",
                "sensors": [
                  {"name": "Core Temperature", "value": 42.5, "unit": "°C"}
                ]
              }
            ],
            "status": {
              "code": "OK",
              "message": "Sensors collected successfully"
            }
          }''',
          200,
          headers: {'Content-Type': 'application/json'},
        );

        when(mockHttpClient.get(any)).thenAnswer((_) async => mockResponse);

        // Act
        final result = await client.fetchSensors(
          'http://test:5000/api/v1/sensors',
        );

        // Assert
        expect(result.sensorGroups.length, 1);
        expect(result.sensorGroups.first.name, 'coretemp-isa-0000');
        expect(result.sensorGroups.first.sensors.length, 1);
      });

      test('fetchSensors handles empty sensor groups', () async {
        // Arrange
        final mockResponse = http.Response(
          '''{
            "host_identity": {
              "hostname": "empty-host",
              "fqdn": "empty.local",
              "platform": "Linux"
            },
            "timestamp": "2024-01-01T00:00:00Z",
            "sensor_groups": [],
            "status": {
              "code": "OK",
              "message": "No sensors detected"
            }
          }''',
          200,
          headers: {'Content-Type': 'application/json'},
        );

        when(mockHttpClient.get(any)).thenAnswer((_) async => mockResponse);

        // Act
        final result = await client.fetchSensors(
          'http://test:5000/api/v1/sensors',
        );

        // Assert
        expect(result, isA<SensorData>());
        expect(result.sensorGroups.isEmpty, isTrue);
        expect(result.status.code, SensorStatusCode.ok);
      });
    });

    // ---------------------------------------------------------------------
    // EMPTY STATUS SCENARIO TESTS
    // ---------------------------------------------------------------------

    group('Fetch EMPTY status scenarios', () {
      test(
        'fetchSensors returns EMPTY status when host has no sensors',
        () async {
          // Arrange
          final mockResponse = http.Response(
            '''{
            "host_identity": {
              "hostname": "bare-metal",
              "fqdn": "bare.local",
              "platform": "Linux"
            },
            "timestamp": "2024-01-01T00:00:00Z",
            "sensor_groups": [],
            "status": {
              "code": "EMPTY",
              "message": "No sensors detected on this host"
            }
          }''',
            200,
            headers: {'Content-Type': 'application/json'},
          );

          when(mockHttpClient.get(any)).thenAnswer((_) async => mockResponse);

          // Act
          final result = await client.fetchSensors(
            'http://test:5000/api/v1/sensors',
          );

          // Assert
          expect(result.status.code, SensorStatusCode.empty);
          expect(result.status.message, contains('No sensors'));
        },
      );

      test('EMPTY response has HTTP 200 status code', () async {
        // Arrange - full contract with required fields
        final mockResponse = http.Response(
          '''{
            "host_identity": {
              "hostname": "empty-host",
              "fqdn": "empty.local",
              "platform": "Linux"
            },
            "timestamp": "2024-01-01T00:00:00Z",
            "sensor_groups": [],
            "status": {
              "code": "EMPTY",
              "message": "No sensors"
            }
          }''',
          200,
          headers: {'Content-Type': 'application/json'},
        );

        when(mockHttpClient.get(any)).thenAnswer((_) async => mockResponse);

        // Act
        final result = await client.fetchSensors(
          'http://test:5000/api/v1/sensors',
        );

        // Assert
        expect(result.status.code, SensorStatusCode.empty);
        // Should NOT throw exception - HTTP 200 means transport success
      });
    });

    // ---------------------------------------------------------------------
    // ERROR STATUS SCENARIO TESTS
    // ---------------------------------------------------------------------

    group('Fetch ERROR status scenarios', () {
      test('fetchSensors returns ERROR status for collector issues', () async {
        // Arrange - full contract with required fields
        // Note: error_details is at top level, not inside status
        final mockResponse = http.Response(
          '''{
            "host_identity": {
              "hostname": "broken-host",
              "fqdn": "broken.local",
              "platform": "Linux"
            },
            "timestamp": "2024-01-01T00:00:00Z",
            "sensor_groups": [],
            "status": {
              "code": "ERROR",
              "message": "lm-sensors not installed"
            },
            "error_details": {"missing_package": "lm-sensors"}
          }''',
          200,
          headers: {'Content-Type': 'application/json'},
        );

        when(mockHttpClient.get(any)).thenAnswer((_) async => mockResponse);

        // Act
        final result = await client.fetchSensors(
          'http://test:5000/api/v1/sensors',
        );

        // Assert
        expect(result.status.code, SensorStatusCode.error);
        expect(result.status.message, contains('lm-sensors'));
        expect(result.errorDetails, isNotNull);
      });

      test('ERROR response preserves error_details for UI display', () async {
        // Arrange - full contract with required fields
        // Note: error_details is at top level, not inside status
        final mockResponse = http.Response(
          '''{
            "host_identity": {
              "hostname": "perm-host",
              "fqdn": "perm.local",
              "platform": "Linux"
            },
            "timestamp": "2024-01-01T00:00:00Z",
            "sensor_groups": [],
            "status": {
              "code": "ERROR",
              "message": "Permission denied reading sensors"
            },
            "error_details": {"permission": "device_not_readable"}
          }''',
          200,
          headers: {'Content-Type': 'application/json'},
        );

        when(mockHttpClient.get(any)).thenAnswer((_) async => mockResponse);

        // Act
        final result = await client.fetchSensors(
          'http://test:5000/api/v1/sensors',
        );

        // Assert
        expect(result.errorDetails?['permission'], 'device_not_readable');
      });
    });

    // ---------------------------------------------------------------------
    // HTTP ERROR SCENARIO TESTS (500, network failures)
    // ---------------------------------------------------------------------

    group('Fetch HTTP error scenarios', () {
      test('fetchSensors throws exception on HTTP 500', () async {
        // Arrange
        final mockResponse = http.Response(
          '{"error": {"type": "InternalError", "message": "Server error"}}',
          500,
          headers: {'Content-Type': 'application/json'},
        );

        when(mockHttpClient.get(any)).thenAnswer((_) async => mockResponse);

        // Act & Assert
        expect(
          () => client.fetchSensors('http://test:5000/api/v1/sensors'),
          throwsA(isA<ApiException>()),
        );
      });

      test('fetchSensors throws ApiException on network timeout', () async {
        // Arrange
        when(
          mockHttpClient.get(any),
        ).thenThrow(http.ClientException('Connection timed out'));

        // Act & Assert
        expect(
          () => client.fetchSensors('http://test:5000/api/v1/sensors'),
          throwsA(isA<ApiException>()),
        );
      });

      test('fetchSensors throws ApiException on host unreachable', () async {
        // Arrange
        when(
          mockHttpClient.get(any),
        ).thenThrow(http.ClientException('Host unreachable'));

        // Act & Assert
        expect(
          () => client.fetchSensors('http://test:5000/api/v1/sensors'),
          throwsA(isA<ApiException>()),
        );
      });
    });

    // ---------------------------------------------------------------------
    // STALE DATA SCENARIO TESTS
    // ---------------------------------------------------------------------

    group('Fetch STALE status scenarios', () {
      test('fetchSensors returns STALE status when data is old', () async {
        // Arrange
        final mockResponse = http.Response(
          '''{
            "host_identity": {
              "hostname": "stale-host",
              "fqdn": "stale.local",
              "platform": "Linux"
            },
            "timestamp": "2024-01-01T00:00:00Z",
            "sensor_groups": [],
            "status": {
              "code": "STALE",
              "message": "Data older than 30 seconds",
              "last_updated": "2024-01-01T00:00:00Z"
            }
          }''',
          200,
          headers: {'Content-Type': 'application/json'},
        );

        when(mockHttpClient.get(any)).thenAnswer((_) async => mockResponse);

        // Act
        final result = await client.fetchSensors(
          'http://test:5000/api/v1/sensors',
        );

        // Assert
        expect(result.status.code, SensorStatusCode.stale);
        expect(result.status.lastUpdated, '2024-01-01T00:00:00Z');
      });

      test('STALE response includes lastUpdated for UI display', () async {
        // Arrange - full contract with required fields
        final mockResponse = http.Response(
          '''{
            "host_identity": {
              "hostname": "stale-host",
              "fqdn": "stale.local",
              "platform": "Linux"
            },
            "timestamp": "2024-01-01T00:00:00Z",
            "sensor_groups": [],
            "status": {
              "code": "STALE",
              "message": "Outdated data",
              "last_updated": "2024-01-01T00:00:00Z"
            }
          }''',
          200,
          headers: {'Content-Type': 'application/json'},
        );

        when(mockHttpClient.get(any)).thenAnswer((_) async => mockResponse);

        // Act
        final result = await client.fetchSensors(
          'http://test:5000/api/v1/sensors',
        );

        // Assert
        expect(result.status.lastUpdated, isNotNull);
        expect(result.status.lastUpdated, '2024-01-01T00:00:00Z');
      });
    });

    // ---------------------------------------------------------------------
    // POLLING BEHAVIOR TESTS
    // ---------------------------------------------------------------------

    group('Polling behavior', () {
      test('fetchSensors can be called multiple times (idempotent)', () async {
        // Arrange
        final mockResponse = http.Response(
          '''{
            "host_identity": {
              "hostname": "poll-host",
              "fqdn": "poll.local",
              "platform": "Linux"
            },
            "timestamp": "2024-01-01T00:00:00Z",
            "sensor_groups": [],
            "status": {
              "code": "OK",
              "message": "OK"
            }
          }''',
          200,
          headers: {'Content-Type': 'application/json'},
        );

        when(mockHttpClient.get(any)).thenAnswer((_) async => mockResponse);

        // Act
        final result1 = await client.fetchSensors(
          'http://test:5000/api/v1/sensors',
        );
        final result2 = await client.fetchSensors(
          'http://test:5000/api/v1/sensors',
        );

        // Assert
        expect(result1, isA<SensorData>());
        expect(result2, isA<SensorData>());
        expect(result1.timestamp, equals(result2.timestamp));
      });

      test('fetchSensors uses correct URL with /api/v1 prefix', () async {
        // Arrange - full contract with required fields
        final expectedUrl = 'http://test:5000/api/v1/sensors';
        final mockResponse = http.Response(
          '{"host_identity": {"hostname": "test", "fqdn": "t", "platform": "Linux"}, "timestamp": "2024-01-01T00:00:00Z", "sensor_groups": [], "status": {"code": "OK", "message": "OK"}}',
          200,
        );

        when(
          mockHttpClient.get(Uri.parse(expectedUrl)),
        ).thenAnswer((_) async => mockResponse);

        // Act
        final result = await client.fetchSensors(expectedUrl);

        // Assert
        expect(result, isA<SensorData>());
      });
    });

    // ---------------------------------------------------------------------
    // EXCEPTION CLASS TESTS
    // ---------------------------------------------------------------------

    group('ApiException', () {
      test('ApiException has type and message properties', () {
        final exception = const ApiException(
          type: 'NetworkError',
          message: 'Connection failed',
        );

        expect(exception.type, 'NetworkError');
        expect(exception.message, 'Connection failed');
      });

      test('ApiException includes error code', () {
        final exception = const ApiException(
          type: 'NetworkError',
          message: 'Connection failed',
          errorCode: 'NETWORK_TIMEOUT',
        );

        expect(exception.errorCode, 'NETWORK_TIMEOUT');
      });

      test('ApiException toString includes all details', () {
        final exception = const ApiException(
          type: 'NetworkError',
          message: 'Connection failed',
          errorCode: 'NETWORK_TIMEOUT',
        );

        final string = exception.toString();
        expect(string, contains('NetworkError'));
        expect(string, contains('Connection failed'));
        expect(string, contains('NETWORK_TIMEOUT'));
      });
    });

    // ---------------------------------------------------------------------
    // URL VALIDATION TESTS
    // ---------------------------------------------------------------------

    group('URL validation', () {
      test('fetchSensors accepts valid HTTP URLs', () async {
        final mockResponse = http.Response(
          '{"host_identity": {"hostname": "t", "fqdn": "t", "platform": "Linux"}, "timestamp": "2024-01-01T00:00:00Z", "sensor_groups": [], "status": {"code": "OK", "message": "OK"}}',
          200,
        );
        when(mockHttpClient.get(any)).thenAnswer((_) async => mockResponse);

        expect(
          () => client.fetchSensors('http://localhost:5000/api/v1/sensors'),
          returnsNormally,
        );
      });

      test('fetchSensors accepts HTTPS URLs', () async {
        final mockResponse = http.Response(
          '{"host_identity": {"hostname": "t", "fqdn": "t", "platform": "Linux"}, "timestamp": "2024-01-01T00:00:00Z", "sensor_groups": [], "status": {"code": "OK", "message": "OK"}}',
          200,
        );
        when(mockHttpClient.get(any)).thenAnswer((_) async => mockResponse);

        expect(
          () => client.fetchSensors('https://localhost:5000/api/v1/sensors'),
          returnsNormally,
        );
      });

      test('fetchSensors throws on invalid URLs', () {
        expect(
          () => client.fetchSensors('not-a-url'),
          throwsA(isA<Exception>()),
        );
      });
    });
  });
}
