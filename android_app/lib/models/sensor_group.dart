import 'package:collection/collection.dart';
import 'sensor.dart';

/// A group of sensors (typically from the same hardware chip)
class SensorGroup {
  final String name;
  final String adapter;
  final List<Sensor> sensors;

  const SensorGroup({
    required this.name,
    required this.adapter,
    required this.sensors,
  });

  factory SensorGroup.fromJson(Map<String, dynamic> json) {
    return SensorGroup(
      name: json['name'] as String,
      adapter: json['adapter'] as String,
      sensors: (json['sensors'] as List<dynamic>)
          .map((s) => Sensor.fromJson(s as Map<String, dynamic>))
          .toList(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'adapter': adapter,
      'sensors': sensors.map((s) => s.toJson()).toList(),
    };
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SensorGroup &&
          runtimeType == other.runtimeType &&
          name == other.name &&
          adapter == other.adapter &&
          const ListEquality().equals(sensors, other.sensors);

  @override
  int get hashCode =>
      Object.hash(name, adapter, const ListEquality().hash(sensors));

  @override
  String toString() =>
      'SensorGroup(name: $name, adapter: $adapter, sensors: ${sensors.length})';
}
