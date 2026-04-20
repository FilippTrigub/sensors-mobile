import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:sensors/ad_config.dart';
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
      bottomNavigationBar: _buildAdBanner(),
    );
  }

  Widget _buildAdBanner() {
    if (!AdConfig.adsEnabled || AdConfig.bannerUnitId.isEmpty) {
      return const SizedBox.shrink();
    }
    return const _AdBannerWidget();
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
    final telemetryWidget = _buildSystemTelemetrySection(data, context);
    final warningsWidget =
        (data.collectionWarnings != null && data.collectionWarnings!.isNotEmpty)
        ? _buildWarningsBanner(data.collectionWarnings!, context)
        : null;

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
          if (warningsWidget != null) warningsWidget,
          _buildHostInfo(context, data),
          if (telemetryWidget != null) ...[
            const SizedBox(height: 16),
            telemetryWidget,
            const SizedBox(height: 16),
          ],
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

  // ---------------------------------------------------------------------------
  // System Telemetry Section
  // ---------------------------------------------------------------------------

  /// Builds the system telemetry section.
  ///
  /// Returns null when telemetry is absent so the caller can skip rendering.
  Widget? _buildSystemTelemetrySection(SensorData data, BuildContext context) {
    final telemetry = data.systemTelemetry;
    if (telemetry == null) return null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildTelemetrySectionHeader(context),
        const SizedBox(height: 12),
        if (telemetry.cpu != null) _buildCpuCard(telemetry.cpu!, context),
        if (telemetry.cpu != null) const SizedBox(height: 12),
        if (telemetry.memory != null)
          _buildMemoryCard(telemetry.memory!, context),
        if (telemetry.memory != null) const SizedBox(height: 12),
        if (telemetry.network != null)
          _buildNetworkCard(telemetry.network!, context),
        if (telemetry.network != null) const SizedBox(height: 12),
        if (telemetry.gpuDevices.isNotEmpty)
          ...telemetry.gpuDevices.map(
            (gpu) => _buildGpuDeviceCard(gpu, context),
          ),
      ],
    );
  }

  Widget _buildTelemetrySectionHeader(BuildContext context) {
    return Row(
      children: [
        Icon(Icons.monitor_heart, size: 20, color: Colors.blue[700]),
        const SizedBox(width: 8),
        Text(
          'System Telemetry',
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
            color: Colors.blue[700],
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }

  Widget _buildCpuCard(CpuTelemetry cpu, BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            Icon(Icons.memory, color: Colors.blue[700]),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'CPU',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Colors.grey[600],
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '${cpu.usagePercent.toStringAsFixed(1)}%',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: Colors.blue[700],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMemoryCard(MemoryTelemetry memory, BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            Icon(Icons.dock, color: Colors.purple[700]),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'RAM',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Colors.grey[600],
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${_formatBytes(memory.usedBytes)} / ${_formatBytes(memory.totalBytes)}',
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 2),
                  LinearProgressIndicator(
                    value: memory.usagePercent / 100,
                    backgroundColor: Colors.grey[200],
                    valueColor: AlwaysStoppedAnimation<Color>(
                      Colors.purple[700]!,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${memory.usagePercent.toStringAsFixed(1)}% used',
                    style: Theme.of(
                      context,
                    ).textTheme.bodySmall?.copyWith(color: Colors.grey[600]),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNetworkCard(NetworkTelemetry network, BuildContext context) {
    final interfaceSummary = network.interfaces.isNotEmpty
        ? network.interfaces.length <= 3
              ? network.interfaces.join(', ')
              : '${network.interfaces.length} interfaces'
        : 'no interfaces';

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.wifi, color: Colors.teal[700]),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Network',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Colors.grey[600],
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          Icon(
                            Icons.arrow_downward,
                            size: 16,
                            color: Colors.teal[700],
                          ),
                          const SizedBox(width: 4),
                          Text(
                            '${_formatBytesThroughput(network.rxBytesPerSec)}/s',
                            style: Theme.of(context).textTheme.bodyMedium,
                          ),
                          const SizedBox(width: 16),
                          Icon(
                            Icons.arrow_upward,
                            size: 16,
                            color: Colors.teal[700],
                          ),
                          const SizedBox(width: 4),
                          Text(
                            '${_formatBytesThroughput(network.txBytesPerSec)}/s',
                            style: Theme.of(context).textTheme.bodyMedium,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              interfaceSummary,
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: Colors.grey[600]),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGpuDeviceCard(GpuDeviceTelemetry gpu, BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.graphic_eq, color: Colors.orange[700]),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    gpu.name,
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                Text(
                  gpu.vendor,
                  style: Theme.of(
                    context,
                  ).textTheme.bodySmall?.copyWith(color: Colors.grey[600]),
                ),
              ],
            ),
            if (gpu.utilizationPercent != null) ...[
              const SizedBox(height: 8),
              Row(
                children: [
                  Text(
                    'Utilization:',
                    style: Theme.of(
                      context,
                    ).textTheme.bodySmall?.copyWith(color: Colors.grey[600]),
                  ),
                  const SizedBox(width: 8),
                  SizedBox(
                    width: 100,
                    child: LinearProgressIndicator(
                      value: gpu.utilizationPercent! / 100,
                      backgroundColor: Colors.grey[200],
                      valueColor: AlwaysStoppedAnimation<Color>(
                        Colors.orange[700]!,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    '${gpu.utilizationPercent!.toStringAsFixed(1)}%',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ],
            if (gpu.memoryUsedBytes != null && gpu.memoryTotalBytes != null)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  'VRAM: ${_formatBytes(gpu.memoryUsedBytes!)} / ${_formatBytes(gpu.memoryTotalBytes!)}'
                  '${gpu.memoryUsagePercent != null ? ' (${gpu.memoryUsagePercent!.toStringAsFixed(1)}%)' : ''}',
                  style: Theme.of(
                    context,
                  ).textTheme.bodySmall?.copyWith(color: Colors.grey[700]),
                ),
              ),
          ],
        ),
      ),
    );
  }

  String _formatBytes(int bytes) {
    if (bytes < 1024) return '$bytes B';
    final kb = bytes / 1024;
    if (kb < 1024) return '${kb.toStringAsFixed(1)} KB';
    final mb = kb / 1024;
    if (mb < 1024) return '${mb.toStringAsFixed(1)} MB';
    final gb = mb / 1024;
    if (gb < 1024) return '${gb.toStringAsFixed(1)} GiB';
    return '${(gb / 1024).toStringAsFixed(1)} TB';
  }

  String _formatBytesThroughput(double bytesPerSec) {
    if (bytesPerSec < 1024) return '${bytesPerSec.toStringAsFixed(0)} B/s';
    final kb = bytesPerSec / 1024;
    if (kb < 1024) return '${kb.toStringAsFixed(1)} KB/s';
    final mb = kb / 1024;
    if (mb < 1024) return '${mb.toStringAsFixed(1)} MB/s';
    final gb = mb / 1024;
    return '${gb.toStringAsFixed(2)} GB/s';
  }

  // ---------------------------------------------------------------------------
  // Collection Warnings Banner
  // ---------------------------------------------------------------------------

  /// Builds a non-blocking warnings banner/list.
  ///
  /// Returns null when there are no warnings.
  Widget? _buildWarningsBanner(
    List<CollectionWarning> warnings,
    BuildContext context,
  ) {
    if (warnings.isEmpty) return null;

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.amber[50],
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.amber[200]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                Icon(Icons.warning_amber_rounded, color: Colors.amber[800]),
                const SizedBox(width: 8),
                Text(
                  'Collection Warnings',
                  style: TextStyle(
                    color: Colors.amber[800],
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1, thickness: 0.5),
          ...warnings.map(
            (w) => Padding(
              padding: const EdgeInsets.fromLTRB(24, 4, 16, 4),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(w.message, style: TextStyle(color: Colors.amber[900])),
                  if (w.code.isNotEmpty)
                    Text(
                      w.code,
                      style: TextStyle(color: Colors.amber[700], fontSize: 11),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
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

/// Bottom AdMob banner widget for the dashboard.
///
/// Only renders when [AdConfig.adsEnabled] is true and a valid banner unit
/// ID is configured. Fails gracefully — returns an empty widget on any
/// load error so the dashboard layout is unaffected.
class _AdBannerWidget extends StatefulWidget {
  const _AdBannerWidget();

  @override
  State<_AdBannerWidget> createState() => _AdBannerWidgetState();
}

class _AdBannerWidgetState extends State<_AdBannerWidget> {
  BannerAd? _bannerAd;
  bool _isLoaded = false;
  bool _adDisabled = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _initializeAd());
  }

  Future<void> _initializeAd() async {
    if (!AdConfig.adsEnabled || AdConfig.bannerUnitId.isEmpty) {
      setState(() => _adDisabled = true);
      return;
    }

    final width = MediaQuery.of(context).size.width.truncate();
    final size =
        await AdSize.getLargeAnchoredAdaptiveBannerAdSizeWithOrientation(
          Orientation.portrait,
          width,
        );

    if (size == null || !mounted) {
      setState(() => _adDisabled = true);
      return;
    }

    _bannerAd = BannerAd(
      adUnitId: AdConfig.bannerUnitId,
      size: size,
      request: const AdRequest(),
      listener: BannerAdListener(
        onAdLoaded: (ad) {
          if (!mounted) return;
          setState(() {
            _bannerAd = ad as BannerAd;
            _isLoaded = true;
          });
        },
        onAdFailedToLoad: (ad, error) {
          if (!mounted) return;
          ad.dispose();
          setState(() => _adDisabled = true);
        },
      ),
    );

    _bannerAd!.load();
  }

  @override
  void dispose() {
    _bannerAd?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_adDisabled || !_isLoaded || _bannerAd == null) {
      return const SizedBox.shrink();
    }
    return SafeArea(child: AdWidget(ad: _bannerAd!));
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
