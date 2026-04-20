import 'package:collection/collection.dart';

import 'cpu_telemetry.dart';
import 'gpu_device_telemetry.dart';
import 'memory_telemetry.dart';
import 'network_telemetry.dart';

/// System telemetry aggregating CPU, memory, network, and GPU data.
///
/// Matches the `system_telemetry` definition in the sensors contract.
/// All sub-fields may be `null` when the corresponding subsystem is unavailable.
class SystemTelemetry {
  /// CPU usage telemetry. Nullable.
  final CpuTelemetry? cpu;

  /// Memory usage telemetry. Nullable.
  final MemoryTelemetry? memory;

  /// Network telemetry. Nullable.
  final NetworkTelemetry? network;

  /// List of GPU device telemetry entries. Always present but may be empty.
  final List<GpuDeviceTelemetry> gpuDevices;

  const SystemTelemetry({
    this.cpu,
    this.memory,
    this.network,
    required this.gpuDevices,
  });

  factory SystemTelemetry.fromJson(Map<String, dynamic> json) {
    return SystemTelemetry(
      cpu: json['cpu'] != null
          ? CpuTelemetry.fromJson(json['cpu'] as Map<String, dynamic>)
          : null,
      memory: json['memory'] != null
          ? MemoryTelemetry.fromJson(json['memory'] as Map<String, dynamic>)
          : null,
      network: json['network'] != null
          ? NetworkTelemetry.fromJson(json['network'] as Map<String, dynamic>)
          : null,
      gpuDevices:
          (json['gpu_devices'] as List<dynamic>?)
              ?.map(
                (d) => GpuDeviceTelemetry.fromJson(d as Map<String, dynamic>),
              )
              .toList() ??
          [],
    );
  }

  Map<String, dynamic> toJson() {
    final result = <String, dynamic>{
      'gpu_devices': gpuDevices.map((d) => d.toJson()).toList(),
    };
    if (cpu != null) result['cpu'] = cpu!.toJson();
    if (memory != null) result['memory'] = memory!.toJson();
    if (network != null) result['network'] = network!.toJson();
    return result;
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SystemTelemetry &&
          runtimeType == other.runtimeType &&
          cpu == other.cpu &&
          memory == other.memory &&
          network == other.network &&
          ListEquality().equals(gpuDevices, other.gpuDevices);

  @override
  int get hashCode =>
      Object.hash(cpu, memory, network, ListEquality().hash(gpuDevices));

  @override
  String toString() =>
      'SystemTelemetry(cpu: $cpu, memory: $memory, network: $network, gpuDevices: ${gpuDevices.length})';
}
