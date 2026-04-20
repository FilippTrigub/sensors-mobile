/// Memory telemetry data collected from the host system.
///
/// Matches the `memory_telemetry` definition in the sensors contract.
class MemoryTelemetry {
  /// Used memory in bytes.
  final int usedBytes;

  /// Total memory in bytes.
  final int totalBytes;

  /// Memory usage percentage (0–100).
  final double usagePercent;

  const MemoryTelemetry({
    required this.usedBytes,
    required this.totalBytes,
    required this.usagePercent,
  });

  factory MemoryTelemetry.fromJson(Map<String, dynamic> json) {
    return MemoryTelemetry(
      usedBytes: json['used_bytes'] as int,
      totalBytes: json['total_bytes'] as int,
      usagePercent: (json['usage_percent'] as num).toDouble(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'used_bytes': usedBytes,
      'total_bytes': totalBytes,
      'usage_percent': usagePercent,
    };
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is MemoryTelemetry &&
          runtimeType == other.runtimeType &&
          usedBytes == other.usedBytes &&
          totalBytes == other.totalBytes &&
          usagePercent == other.usagePercent;

  @override
  int get hashCode => Object.hash(usedBytes, totalBytes, usagePercent);

  @override
  String toString() =>
      'MemoryTelemetry(usedBytes: $usedBytes, totalBytes: $totalBytes, usagePercent: $usagePercent)';
}
