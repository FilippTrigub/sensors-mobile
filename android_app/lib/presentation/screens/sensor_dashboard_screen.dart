import 'package:flutter/material.dart';
import 'package:sensors/services/sensor_state_controller.dart';
import 'package:sensors/models/models.dart';

/// Primary dashboard screen for displaying sensor data.
///
/// Uses [SensorStateController] to manage state and display grouped
/// sensor cards. Supports loading, success, empty, error, and stale states.
class SensorDashboardScreen extends StatefulWidget {
  /// State controller for sensor data
  final SensorStateController controller;

  /// Refresh callback - triggers manual pull-to-refresh
  final Future<void> Function() onRefresh;

  /// Retry callback - used when in error state
  final Future<void> Function() onRetry;

  /// Clear saved host configuration and return to setup
  final Future<void> Function() onClearHostConfig;

  /// Current temperature unit preference
  final TemperatureUnit currentUnit;

  /// Callback when unit is changed
  final Future<void> Function(TemperatureUnit) onUnitChanged;

  const SensorDashboardScreen({
    super.key,
    required this.controller,
    required this.onRefresh,
    required this.onRetry,
    required this.onClearHostConfig,
    required this.currentUnit,
    required this.onUnitChanged,
  });

  @override
  State<SensorDashboardScreen> createState() => _SensorDashboardScreenState();
}

class _SensorDashboardScreenState extends State<SensorDashboardScreen> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('sensors'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        actions: [
          _buildUnitSelector(context),
          IconButton(
            icon: const Icon(Icons.clear),
            onPressed: widget.onClearHostConfig,
            tooltip: 'Clear Host Configuration',
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: widget.onRefresh,
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: StreamBuilder<SensorControllerState>(
        stream: widget.controller.stateStream,
        builder: (context, snapshot) {
          final state = snapshot.data ?? SensorControllerState.setup();

          switch (state.state) {
            case UiState.loading:
              return const Center(child: CircularProgressIndicator());

            case UiState.success:
              if (state.sensorData == null) {
                return const Center(child: Text('No sensor data available'));
              }
              return _buildSuccessState(context, state.sensorData!);

            case UiState.empty:
              return const EmptyState();

            case UiState.error:
              return _buildErrorState(context, state);

            case UiState.setup:
              // Should not reach here from dashboard, but show loading just in case
              return const Center(child: CircularProgressIndicator());
          }
        },
      ),
    );
  }

  Widget _buildUnitSelector(BuildContext context) {
    final currentUnit = widget.currentUnit;
    final unitIcon = currentUnit == TemperatureUnit.fahrenheit
        ? Icons.thermostat
        : Icons.thermostat;

    return PopupMenuButton<TemperatureUnit>(
      icon: Icon(unitIcon),
      tooltip: 'Temperature Unit',
      onSelected: (unit) => widget.onUnitChanged(unit),
      itemBuilder: (context) => [
        PopupMenuItem(
          value: TemperatureUnit.celsius,
          child: Row(
            children: [
              Text(
                currentUnit == TemperatureUnit.celsius ? '✓' : '○',
                style: const TextStyle(fontSize: 16),
              ),
              const SizedBox(width: 8),
              Text('Celsius (°C)'),
            ],
          ),
        ),
        PopupMenuItem(
          value: TemperatureUnit.fahrenheit,
          child: Row(
            children: [
              Text(
                currentUnit == TemperatureUnit.fahrenheit ? '✓' : '○',
                style: const TextStyle(fontSize: 16),
              ),
              const SizedBox(width: 8),
              Text('Fahrenheit (°F)'),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildSuccessState(BuildContext context, SensorData data) {
    final isStale = widget.controller.currentState.isDataStale;

    return RefreshIndicator(
      onRefresh: widget.onRefresh,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (isStale)
            Container(
              padding: const EdgeInsets.all(12),
              margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(
                color: Colors.orange[50],
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.orange[200]!),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.info_outline,
                    color: Colors.orange,
                    size: 20,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Data may be stale. Pull to refresh.',
                      style: TextStyle(color: Colors.orange[800]),
                    ),
                  ),
                ],
              ),
            ),
          _buildHostInfo(context, data),
          const SizedBox(height: 16),
          if (data.sensorGroups.isEmpty)
            const EmptyState()
          else
            ...data.sensorGroups.map(
              (group) => _buildSensorGroupCard(group, context),
            ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  Widget _buildHostInfo(BuildContext context, SensorData data) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.devices),
                const SizedBox(width: 8),
                Text(
                  data.hostIdentity.hostname,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              data.hostIdentity.fqdn,
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: Colors.grey[600]),
            ),
            const SizedBox(height: 8),
            Text(
              'Last updated: ${data.timestamp}',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSensorGroupCard(SensorGroup group, BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ExpansionTile(
        leading: const Icon(Icons.group),
        title: Text(
          group.name,
          style: const TextStyle(fontWeight: FontWeight.w500),
        ),
        subtitle: Text(
          group.adapter,
          style: Theme.of(context).textTheme.bodySmall,
        ),
        children: group.sensors.map((sensor) {
          return ListTile(
            leading: Icon(_getIconForUnit(sensor.unit)),
            title: Text(
              sensor.name,
              style: const TextStyle(fontWeight: FontWeight.w500),
            ),
            subtitle: Text(
              _formatSensorValue(sensor),
              style: Theme.of(context).textTheme.bodySmall,
            ),
          );
        }).toList(),
      ),
    );
  }

  IconData _getIconForUnit(SensorUnit unit) {
    switch (unit) {
      case SensorUnit.celsius:
      case SensorUnit.fahrenheit:
        return Icons.thermostat;
      case SensorUnit.rpm:
        return Icons.escalator;
      case SensorUnit.volts:
      case SensorUnit.millivolts:
        return Icons.battery_charging_full;
      default:
        return Icons.trending_up;
    }
  }

  String _formatSensorValue(Sensor sensor) {
    final displayValue = sensor.displayValueInUnit(widget.currentUnit);
    final displayUnit = sensor.displayUnitIn(widget.currentUnit);
    return '${displayValue.toStringAsFixed(2)} $displayUnit';
  }

  Widget _buildErrorState(BuildContext context, SensorControllerState state) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 64, color: Colors.red),
            const SizedBox(height: 16),
            Text(
              'Connection Error',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 8),
            Text(
              state.errorMessage ?? 'Failed to fetch sensor data',
              textAlign: TextAlign.center,
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(color: Colors.grey[600]),
            ),
            const SizedBox(height: 24),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              alignment: WrapAlignment.center,
              children: [
                ElevatedButton(
                  onPressed: widget.onRetry,
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 32,
                      vertical: 16,
                    ),
                  ),
                  child: const Text('Retry'),
                ),
                OutlinedButton.icon(
                  onPressed: widget.onClearHostConfig,
                  icon: const Icon(Icons.edit_location_alt_outlined),
                  label: const Text('Change Host'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Empty state widget for when no sensors are available
class EmptyState extends StatelessWidget {
  const EmptyState({super.key});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.cloud_off_outlined, size: 64, color: Colors.grey),
            const SizedBox(height: 16),
            Text(
              'No Sensors Found',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 8),
            Text(
              'The connected host has no sensors available',
              textAlign: TextAlign.center,
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(color: Colors.grey[600]),
            ),
          ],
        ),
      ),
    );
  }
}
