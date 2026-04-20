import 'package:collection/collection.dart';

/// Network telemetry data collected from the host system.
///
/// Matches the `network_telemetry` definition in the sensors contract.
/// Nullable because network counters may be unavailable during collection.
class NetworkTelemetry {
  /// Received bytes per second.
  final double rxBytesPerSec;

  /// Transmitted bytes per second.
  final double txBytesPerSec;

  /// Total received bytes (cumulative).
  final int totalRxBytes;

  /// Total transmitted bytes (cumulative).
  final int totalTxBytes;

  /// Time window in seconds over which rates were sampled.
  final double sampleWindowSeconds;

  /// List of network interfaces included in this sample.
  final List<String> interfaces;

  const NetworkTelemetry({
    required this.rxBytesPerSec,
    required this.txBytesPerSec,
    required this.totalRxBytes,
    required this.totalTxBytes,
    required this.sampleWindowSeconds,
    required this.interfaces,
  });

  factory NetworkTelemetry.fromJson(Map<String, dynamic> json) {
    return NetworkTelemetry(
      rxBytesPerSec: (json['rx_bytes_per_sec'] as num).toDouble(),
      txBytesPerSec: (json['tx_bytes_per_sec'] as num).toDouble(),
      totalRxBytes: json['total_rx_bytes'] as int,
      totalTxBytes: json['total_tx_bytes'] as int,
      sampleWindowSeconds: (json['sample_window_seconds'] as num).toDouble(),
      interfaces: (json['interfaces'] as List<dynamic>)
          .map((i) => i as String)
          .toList(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'rx_bytes_per_sec': rxBytesPerSec,
      'tx_bytes_per_sec': txBytesPerSec,
      'total_rx_bytes': totalRxBytes,
      'total_tx_bytes': totalTxBytes,
      'sample_window_seconds': sampleWindowSeconds,
      'interfaces': interfaces,
    };
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is NetworkTelemetry &&
          runtimeType == other.runtimeType &&
          rxBytesPerSec == other.rxBytesPerSec &&
          txBytesPerSec == other.txBytesPerSec &&
          totalRxBytes == other.totalRxBytes &&
          totalTxBytes == other.totalTxBytes &&
          sampleWindowSeconds == other.sampleWindowSeconds &&
          ListEquality().equals(interfaces, other.interfaces);

  @override
  int get hashCode => Object.hash(
    rxBytesPerSec,
    txBytesPerSec,
    totalRxBytes,
    totalTxBytes,
    sampleWindowSeconds,
    ListEquality().hash(interfaces),
  );

  @override
  String toString() =>
      'NetworkTelemetry(rxBytesPerSec: $rxBytesPerSec, txBytesPerSec: $txBytesPerSec, totalRxBytes: $totalRxBytes, totalTxBytes: $totalTxBytes, sampleWindowSeconds: $sampleWindowSeconds, interfaces: $interfaces)';
}
