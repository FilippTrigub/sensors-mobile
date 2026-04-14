/// Sensor State Controller for foreground polling and state management.
///
/// This controller manages the app's state machine (setup, loading, success,
/// empty, error, stale) and handles foreground polling with a configurable
/// interval. It's designed to work with Flutter's StatefulWidget pattern
/// using StreamController for UI updates.
///
/// The controller is foreground-oriented:
/// - Polling starts when [startPolling] is called
/// - Polling stops when [stopPolling] is called
/// - No background services or notifications
/// - Manual refresh supported via [refresh]
///
/// See also:
/// - [SensorApiClient] for HTTP communication
/// - [UiState] for state enumeration
/// - [SensorData] for sensor data model
library;

import 'dart:async';
import 'package:flutter/foundation.dart';

import 'sensor_api_client.dart';
import '../models/models.dart';

/// UI state enum matching the state machine from Task 4/Task 7.
///
/// States:
/// - [setup]: No host configured - show host setup screen
/// - [loading]: Polling in progress - show loading indicator
/// - [success]: Fresh sensor data - show dashboard
/// - [empty]: API returned EMPTY status - show empty state
/// - [error]: API error or network failure - show error with retry
///
/// Valid transitions:
/// - setup → loading (when host is saved)
/// - loading → success (API returns OK)
/// - loading → empty (API returns EMPTY)
/// - loading → error (API returns ERROR/500/network failure)
/// - success → loading (manual refresh)
/// - empty → loading (retry)
/// - error → loading (retry)
///
/// Invalid transitions:
/// - setup → success (must go through loading)
/// - success → error (must go through loading)
/// - empty → error (distinct terminal states)
enum UiState {
  /// No host configured - show host setup screen
  setup,

  /// Polling in progress - show loading indicator
  loading,

  /// Sensor data rendered successfully
  success,

  /// API returned EMPTY status - no sensors detected
  empty,

  /// API returned error or network failure - show error with retry
  error,
}

/// Represents a complete sensor state with data and UI state.
///
/// This class is the primary data structure for UI consumption.
/// It combines the current [UiState] with [sensorData] (when available)
/// and tracking metadata for stale data detection.
///
/// Example:
/// ```dart
/// // Success state with data
/// final success = SensorControllerState(
///   state: UiState.success,
///   sensorData: data,
///   lastUpdate: DateTime.now(),
/// );
///
/// // Error state with stale data
/// final error = SensorControllerState(
///   state: UiState.error,
///   sensorData: staleData,
///   lastUpdate: staleData.timestamp,
///   lastSuccessfulUpdate: staleData.timestamp,
/// );
/// ```
class SensorControllerState {
  /// The current UI state
  final UiState state;

  /// Current sensor data (may be stale in error state)
  final SensorData? sensorData;

  /// Time of the last data fetch attempt
  final DateTime lastUpdate;

  /// Time of the last successful data fetch (for stale data display)
  final DateTime? lastSuccessfulUpdate;

  /// Error message if in error state
  final String? errorMessage;

  SensorControllerState({
    required this.state,
    this.sensorData,
    required this.lastUpdate,
    this.lastSuccessfulUpdate,
    this.errorMessage,
  });

  /// Create a loading state
  static SensorControllerState loading() {
    return SensorControllerState(
      state: UiState.loading,
      lastUpdate: DateTime.now(),
    );
  }

  /// Create a success state
  static SensorControllerState success(SensorData data) {
    return SensorControllerState(
      state: UiState.success,
      sensorData: data,
      lastUpdate: DateTime.now(),
      lastSuccessfulUpdate: DateTime.now(),
    );
  }

  /// Create an empty state
  static SensorControllerState empty() {
    return SensorControllerState(
      state: UiState.empty,
      lastUpdate: DateTime.now(),
    );
  }

  /// Create an error state with optional stale data
  static SensorControllerState error({
    required String message,
    SensorData? staleData,
  }) {
    return SensorControllerState(
      state: UiState.error,
      sensorData: staleData,
      lastUpdate: DateTime.now(),
      errorMessage: message,
    );
  }

  /// Create a setup state (no host configured)
  static SensorControllerState setup() {
    return SensorControllerState(
      state: UiState.setup,
      lastUpdate: DateTime.now(),
    );
  }

  /// Check if current data is stale (older than threshold)
  bool get isDataStale {
    if (lastSuccessfulUpdate == null) return false;
    return DateTime.now().difference(lastSuccessfulUpdate!) >
        const Duration(seconds: 30);
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SensorControllerState &&
          runtimeType == other.runtimeType &&
          state == other.state &&
          sensorData == other.sensorData &&
          lastUpdate == other.lastUpdate &&
          lastSuccessfulUpdate == other.lastSuccessfulUpdate &&
          errorMessage == other.errorMessage;

  @override
  int get hashCode => Object.hash(
    state,
    sensorData,
    lastUpdate,
    lastSuccessfulUpdate,
    errorMessage,
  );

  @override
  String toString() =>
      'SensorControllerState('
      'state: $state, '
      'sensorData: ${sensorData != null ? "present" : "null"}, '
      'lastUpdate: $lastUpdate, '
      'lastSuccessfulUpdate: $lastSuccessfulUpdate, '
      'errorMessage: $errorMessage)';
}

/// State controller for sensor data fetching and state management.
///
/// This controller:
/// - Manages the UI state machine (setup, loading, success, empty, error)
/// - Handles foreground polling with configurable interval
/// - Provides a StreamController for UI updates
/// - Supports manual refresh
/// - Tracks stale data for graceful degradation
///
/// Usage:
/// ```dart
/// final controller = SensorStateController(
///   apiKeyClient: SensorApiClient(),
///   pollingIntervalMs: 5000,
/// );
///
/// // Start polling
/// controller.startPolling('http://localhost:5000/api/v1/sensors');
///
/// // Listen for state updates
/// controller.stateStream.listen((state) {
///   setState(() => currentSensorState = state);
/// });
///
/// // Manual refresh
/// await controller.refresh();
///
/// // Stop polling when done
/// controller.stopPolling();
/// controller.dispose();
/// ```
class SensorStateController extends ChangeNotifier {
  /// The API client for HTTP communication
  final SensorApiClient _apiClient;

  /// Polling interval in milliseconds (default 5 seconds)
  final int _pollingIntervalMs;

  /// StreamController for state updates
  final StreamController<SensorControllerState> _stateController =
      StreamController<SensorControllerState>.broadcast();

  /// Current polling timer
  Timer? _pollingTimer;

  /// Current host endpoint URL
  String? _currentEndpointUrl;

  /// Current state
  SensorControllerState _currentState = SensorControllerState.setup();

  /// Get the current state
  SensorControllerState get currentState => _currentState;

  /// Get the state stream for UI listening
  Stream<SensorControllerState> get stateStream => _stateController.stream;

  /// Get polling interval in seconds
  int get pollingIntervalSeconds => _pollingIntervalMs ~/ 1000;

  /// Create a new state controller
  ///
  /// [apiClient] should be a configured [SensorApiClient]
  /// [pollingIntervalMs] is the polling interval in milliseconds (default 5000)
  SensorStateController({
    required SensorApiClient apiClient,
    int pollingIntervalMs = SensorApiClient.defaultPollingIntervalMs,
  }) : _apiClient = apiClient,
       _pollingIntervalMs = pollingIntervalMs;

  /// Start polling at the specified endpoint
  ///
  /// This transitions state to [UiState.loading] and begins periodic fetching.
  /// Polling continues until [stopPolling] is called.
  ///
  /// The first fetch happens immediately, then at regular intervals.
  void startPolling(String endpointUrl) {
    if (_pollingTimer != null && _pollingTimer!.isActive) {
      // Already polling, just update URL if changed
      _currentEndpointUrl = endpointUrl;
      return;
    }

    _currentEndpointUrl = endpointUrl;
    _transitionState(SensorControllerState.loading());

    // Initial fetch
    _performFetch();

    // Start polling
    _pollingTimer = Timer.periodic(
      Duration(milliseconds: _pollingIntervalMs),
      (_) => _performFetch(),
    );
  }

  /// Stop polling
  ///
  /// Cancels the polling timer. State is not changed automatically,
  /// but the controller will no longer fetch new data.
  void stopPolling() {
    _pollingTimer?.cancel();
    _pollingTimer = null;
    _currentEndpointUrl = null;
  }

  /// Manually refresh data
  ///
  /// Triggers an immediate fetch and transitions to [UiState.loading].
  /// Useful for pull-to-refresh or retry actions.
  Future<void> refresh() async {
    if (_currentEndpointUrl == null) {
      throw StateError('No endpoint configured. Call startPolling first.');
    }

    _transitionState(SensorControllerState.loading());
    await _performFetch();
  }

  /// Reset to setup state (e.g., when clearing host config)
  void resetToSetup() {
    stopPolling();
    _transitionState(SensorControllerState.setup());
  }

  /// Set host config (called when user saves host configuration)
  ///
  /// Transitions from [UiState.setup] to [UiState.loading] and starts polling.
  Future<void> setHostConfig(String hostUrl) async {
    resetToSetup();
    startPolling(hostUrl);
  }

  /// Handle error state from failed fetch
  void handleError(String errorMessage, {SensorData? staleData}) {
    _transitionState(
      SensorControllerState.error(message: errorMessage, staleData: staleData),
    );
  }

  /// Handle successful fetch
  void handleSuccess(SensorData data) {
    SensorControllerState newState;

    switch (data.status.code) {
      case SensorStatusCode.ok:
        newState = SensorControllerState.success(data);
        break;
      case SensorStatusCode.empty:
        newState = SensorControllerState.empty();
        break;
      case SensorStatusCode.error:
        newState = SensorControllerState.error(
          message: data.status.message,
          staleData: data,
        );
        break;
      case SensorStatusCode.stale:
        newState = SensorControllerState(
          state: UiState.success,
          sensorData: data,
          lastUpdate: DateTime.now(),
          lastSuccessfulUpdate: DateTime.tryParse(data.timestamp),
        );
        break;
    }

    _transitionState(newState);
  }

  /// Perform a single fetch attempt
  Future<void> _performFetch() async {
    if (_currentEndpointUrl == null) {
      return;
    }

    try {
      final data = await _apiClient.fetchSensors(_currentEndpointUrl!);
      handleSuccess(data);
    } on ApiException catch (e) {
      handleError(e.message);
    } catch (e) {
      handleError('Unexpected error: $e');
    }
  }

  /// Transition to a new state
  void _transitionState(SensorControllerState newState) {
    _currentState = newState;
    _stateController.add(newState);
    notifyListeners();
  }

  /// Check if currently polling
  bool get isPolling => _pollingTimer != null && _pollingTimer!.isActive;

  /// Check if currently in loading state
  bool get isLoading => _currentState.state == UiState.loading;

  /// Check if currently in success state
  bool get isSuccess => _currentState.state == UiState.success;

  /// Check if currently in error state
  bool get isError => _currentState.state == UiState.error;

  /// Check if currently in empty state
  bool get isEmpty => _currentState.state == UiState.empty;

  /// Check if currently in setup state
  bool get isSetup => _currentState.state == UiState.setup;

  @override
  void dispose() {
    stopPolling();
    _stateController.close();
    _apiClient.dispose();
    super.dispose();
  }
}
