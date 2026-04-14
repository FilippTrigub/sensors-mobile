import 'package:collection/collection.dart';
import 'sensor_group.dart';
import 'sensor_status.dart';
import 'units.dart';
import 'host_identity.dart';

/// Main sensor data container matching the backend contract
class SensorData {
  final String? version;
  final HostIdentity hostIdentity;
  final String timestamp;
  final List<SensorGroup> sensorGroups;
  final SensorStatus status;
  final Units? units;
  final Map<String, dynamic>? errorDetails;

  const SensorData({
    this.version,
    required this.hostIdentity,
    required this.timestamp,
    required this.sensorGroups,
    required this.status,
    this.units,
    this.errorDetails,
  });

  factory SensorData.fromJson(Map<String, dynamic> json) {
    return SensorData(
      version: json['version'] as String?,
      hostIdentity: HostIdentity.fromJson(
        json['host_identity'] as Map<String, dynamic>,
      ),
      timestamp: json['timestamp'] as String,
      sensorGroups:
          (json['sensor_groups'] as List<dynamic>?)
              ?.map((g) => SensorGroup.fromJson(g as Map<String, dynamic>))
              .toList() ??
          [],
      status: SensorStatus.fromJson(json['status'] as Map<String, dynamic>),
      units: json['units'] != null
          ? Units.fromJson(json['units'] as Map<String, dynamic>)
          : null,
      errorDetails: json['error_details'] as Map<String, dynamic>?,
    );
  }

  Map<String, dynamic> toJson() {
    final result = <String, dynamic>{};
    if (version != null) result['version'] = version;
    result['host_identity'] = hostIdentity.toJson();
    result['timestamp'] = timestamp;
    result['sensor_groups'] = sensorGroups.map((g) => g.toJson()).toList();
    result['status'] = status.toJson();
    if (units != null) result['units'] = units!.toJson();
    if (errorDetails != null) result['error_details'] = errorDetails!;
    return result;
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SensorData &&
          runtimeType == other.runtimeType &&
          version == other.version &&
          hostIdentity == other.hostIdentity &&
          timestamp == other.timestamp &&
          ListEquality().equals(sensorGroups, other.sensorGroups) &&
          status == other.status &&
          units == other.units &&
          errorDetails == other.errorDetails;

  @override
  int get hashCode => Object.hash(
    version,
    hostIdentity,
    timestamp,
    ListEquality().hash(sensorGroups),
    status,
    units,
    errorDetails,
  );

  @override
  String toString() =>
      'SensorData(version: $version, hostIdentity: $hostIdentity, timestamp: $timestamp, sensorGroups: ${sensorGroups.length}, status: $status)';
}
