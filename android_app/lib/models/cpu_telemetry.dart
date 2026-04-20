/// CPU telemetry data collected from the host system.
///
/// Matches the `cpu_telemetry` definition in the sensors contract.
class CpuTelemetry {
  /// CPU usage percentage (0–100).
  final double usagePercent;

  const CpuTelemetry({required this.usagePercent});

  factory CpuTelemetry.fromJson(Map<String, dynamic> json) {
    return CpuTelemetry(
      usagePercent: (json['usage_percent'] as num).toDouble(),
    );
  }

  Map<String, dynamic> toJson() {
    return {'usage_percent': usagePercent};
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is CpuTelemetry &&
          runtimeType == other.runtimeType &&
          usagePercent == other.usagePercent;

  @override
  int get hashCode => usagePercent.hashCode;

  @override
  String toString() => 'CpuTelemetry(usagePercent: $usagePercent)';
}
