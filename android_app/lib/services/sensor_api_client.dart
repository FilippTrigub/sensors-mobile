/// Sensor API Client for fetching sensor data from host API.
///
/// This service handles HTTP communication with the host sensor API,
/// parsing responses into SensorData models and surface errors appropriately.
///
/// See also:
/// - [SensorStateController] for state management
/// - [SensorData] for data models
library;

import 'dart:convert';
import 'dart:async';
import 'package:http/http.dart' as http;

import '../models/models.dart';
import '../models/sensor_data.dart';

/// Exception thrown by [SensorApiClient] on API errors.
///
/// Use this exception to surface API failures to the UI layer.
/// The exception includes [type], [message], and optional [errorCode]
/// for error handling and display.
class ApiException implements Exception {
  /// The type/category of the error (e.g., 'NetworkError', 'ParseError')
  final String type;

  /// Human-readable error message for display
  final String message;

  /// Machine-readable error code for programmatic handling
  final String errorCode;

  const ApiException({
    required this.type,
    required this.message,
    this.errorCode = 'UNKNOWN_ERROR',
  });

  @override
  String toString() =>
      'ApiException(type: $type, message: $message, errorCode: $errorCode)';
}

/// API Client for fetching sensor data from the host sensor API.
///
/// Handles:
/// - HTTP GET requests to `/api/v1/sensors`
/// - JSON parsing and validation
/// - Mapping HTTP status codes to contract status codes
/// - Error surface for UI (no HTML/traceback leakage)
///
/// The client is stateless and thread-safe. It relies on the underlying
/// [http.Client] for HTTP communication.
///
/// Example:
/// ```dart
/// final client = SensorApiClient();
/// final data = await client.fetchSensors('http://localhost:5000/api/v1/sensors');
/// if (data.status.code == SensorStatusCode.ok) {
///   // Display sensors
/// } else if (data.status.code == SensorStatusCode.error) {
///   // Show error UI with data.errorDetails
/// }
/// ```
class SensorApiClient {
  /// The HTTP client used for network requests.
  ///
  /// Defaults to a global client for production use.
  /// For testing, inject a mock client.
  final http.Client _httpClient;

  /// Default polling interval in milliseconds (5 seconds).
  static const int defaultPollingIntervalMs = 5000;

  /// Default request timeout in milliseconds (10 seconds).
  static const int defaultTimeoutMs = 10000;

  /// Create a new API client with optional HTTP client.
  ///
  /// [httpClient] should be a properly configured [http.Client].
  /// For testing, inject a mock client.
  SensorApiClient({http.Client? httpClient})
    : _httpClient = httpClient ?? http.Client();

  /// Fetch sensor data from the specified host API endpoint.
  ///
  /// [endpointUrl] should be the full URL to the `/api/v1/sensors` endpoint,
  /// e.g., `http://localhost:5000/api/v1/sensors`.
  ///
  /// Returns [SensorData] on success (HTTP 200 with any status.code).
  /// Throws [ApiException] on:
  /// - HTTP errors (4xx, 5xx)
  /// - Network failures (timeout, unreachable host)
  /// - JSON parse errors
  ///
  /// The method handles:
  /// - Contractual errors (HTTP 200 with status.code=ERROR) - returns [SensorData]
  /// - Empty state (HTTP 200 with status.code=EMPTY) - returns [SensorData]
  /// - Stale data (HTTP 200 with status.code=STALE) - returns [SensorData]
  /// - Unexpected errors (HTTP 500, network failures) - throws [ApiException]
  Future<SensorData> fetchSensors(String endpointUrl) async {
    late final http.Response response;

    try {
      response = await _httpClient
          .get(Uri.parse(endpointUrl))
          .timeout(Duration(milliseconds: defaultTimeoutMs));
    } on http.ClientException {
      // Network-level failures (timeout, unreachable host)
      throw ApiException(
        type: 'NetworkError',
        message: 'Failed to connect to host. Please check your network.',
        errorCode: 'NETWORK_ERROR',
      );
    } on TimeoutException {
      throw ApiException(
        type: 'NetworkError',
        message: 'Connection timed out. Check your network.',
        errorCode: 'NETWORK_TIMEOUT',
      );
    } catch (e) {
      throw ApiException(
        type: 'NetworkError',
        message: 'Failed to connect to host. Please try again.',
        errorCode: 'NETWORK_ERROR',
      );
    }

    // Handle HTTP status codes
    if (response.statusCode >= 200 && response.statusCode < 300) {
      // Success range - parse and return data
      try {
        final json = jsonDecode(response.body) as Map<String, dynamic>;
        return SensorData.fromJson(json);
      } on FormatException {
        throw ApiException(
          type: 'ParseError',
          message: 'Invalid JSON response from host. Please try again.',
          errorCode: 'PARSE_ERROR',
        );
      } catch (e) {
        throw ApiException(
          type: 'ParseError',
          message: 'Failed to parse response from host. Please try again.',
          errorCode: 'PARSE_ERROR',
        );
      }
    } else if (response.statusCode >= 400 && response.statusCode < 500) {
      // Client error (4xx)
      String message;
      switch (response.statusCode) {
        case 401:
          message = 'Authentication required';
          break;
        case 403:
          message = 'Access forbidden';
          break;
        case 404:
          message = 'Endpoint not found';
          break;
        default:
          message = 'Client error: ${response.statusCode}';
      }
      throw ApiException(
        type: 'ClientError',
        message: message,
        errorCode: 'CLIENT_ERROR_${response.statusCode}',
      );
    } else if (response.statusCode >= 500) {
      // Server error (5xx) - backend exception
      try {
        final json = jsonDecode(response.body) as Map<String, dynamic>;
        final error = json['error'] as Map<String, dynamic>?;
        if (error != null) {
          final type = error['type'] as String? ?? 'InternalError';
          final message = error['message'] as String? ?? 'Server error';
          final errorCode = error['error_code'] as String? ?? 'INTERNAL_ERROR';
          throw ApiException(
            type: type,
            message: message,
            errorCode: errorCode,
          );
        }
      } catch (_) {}

      throw ApiException(
        type: 'ServerError',
        message: 'Service unavailable (error code: ${response.statusCode})',
        errorCode: 'SERVER_ERROR_${response.statusCode}',
      );
    }

    throw ApiException(
      type: 'UnknownError',
      message: 'Unexpected HTTP status: ${response.statusCode}',
      errorCode: 'UNKNOWN_STATUS',
    );
  }

  /// Dispose the HTTP client.
  ///
  /// Call this when the client is no longer needed to release resources.
  void dispose() {
    _httpClient.close();
  }
}
