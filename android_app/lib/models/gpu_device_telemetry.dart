import 'package:collection/collection.dart';

/// GPU device telemetry data.
///
/// Matches the `gpu_device` definition in the sensors contract.
/// Nullable utilization/VRAM fields are optional.
class GpuDeviceTelemetry {
  /// PCI or unique device identifier (e.g., "0000:01:00.0").
  final String id;

  /// GPU product name (e.g., "NVIDIA GeForce RTX 4060").
  final String name;

  /// GPU vendor (e.g., "NVIDIA", "AMD", "Intel").
  final String vendor;

  /// GPU core utilization percentage (0–100). Nullable.
  final double? utilizationPercent;

  /// VRAM used in bytes. Nullable.
  final int? memoryUsedBytes;

  /// VRAM total in bytes. Nullable.
  final int? memoryTotalBytes;

  /// VRAM usage percentage (0–100). Nullable.
  final double? memoryUsagePercent;

  const GpuDeviceTelemetry({
    required this.id,
    required this.name,
    required this.vendor,
    this.utilizationPercent,
    this.memoryUsedBytes,
    this.memoryTotalBytes,
    this.memoryUsagePercent,
  });

  factory GpuDeviceTelemetry.fromJson(Map<String, dynamic> json) {
    return GpuDeviceTelemetry(
      id: json['id'] as String,
      name: json['name'] as String,
      vendor: json['vendor'] as String,
      utilizationPercent: json['utilization_percent'] != null
          ? (json['utilization_percent'] as num).toDouble()
          : null,
      memoryUsedBytes: json['memory_used_bytes'] != null
          ? json['memory_used_bytes'] as int
          : null,
      memoryTotalBytes: json['memory_total_bytes'] != null
          ? json['memory_total_bytes'] as int
          : null,
      memoryUsagePercent: json['memory_usage_percent'] != null
          ? (json['memory_usage_percent'] as num).toDouble()
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    final result = <String, dynamic>{'id': id, 'name': name, 'vendor': vendor};
    if (utilizationPercent != null)
      result['utilization_percent'] = utilizationPercent;
    if (memoryUsedBytes != null) result['memory_used_bytes'] = memoryUsedBytes;
    if (memoryTotalBytes != null)
      result['memory_total_bytes'] = memoryTotalBytes;
    if (memoryUsagePercent != null)
      result['memory_usage_percent'] = memoryUsagePercent;
    return result;
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is GpuDeviceTelemetry &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          name == other.name &&
          vendor == other.vendor &&
          utilizationPercent == other.utilizationPercent &&
          memoryUsedBytes == other.memoryUsedBytes &&
          memoryTotalBytes == other.memoryTotalBytes &&
          memoryUsagePercent == other.memoryUsagePercent;

  @override
  int get hashCode => Object.hash(
    id,
    name,
    vendor,
    utilizationPercent,
    memoryUsedBytes,
    memoryTotalBytes,
    memoryUsagePercent,
  );

  @override
  String toString() =>
      'GpuDeviceTelemetry(id: $id, name: $name, vendor: $vendor, utilizationPercent: $utilizationPercent)';
}
