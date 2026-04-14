import 'package:android_app/models/enums.dart';

/// Individual sensor reading
class Sensor {
  final String name;
  final String? rawName;
  final double value;
  final SensorUnit unit;
  final String? description;

  const Sensor({
    required this.name,
    this.rawName,
    required this.value,
    required this.unit,
    this.description,
  });

  factory Sensor.fromJson(Map<String, dynamic> json) {
    return Sensor(
      name: json['name'] as String,
      rawName: json['raw_name'] as String?,
      value: (json['value'] as num).toDouble(),
      unit: sensorUnitFromString(json['unit'] as String),
      description: json['description'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      if (rawName != null) 'raw_name': rawName,
      'value': value,
      'unit': sensorUnitToJson(unit),
      if (description != null) 'description': description,
    };
  }

  /// Get the display value for this sensor in the specified temperature unit.
  /// Only converts temperature sensors; non-temperature units are returned as-is.
  double displayValueInUnit(TemperatureUnit displayUnit) {
    // Only convert temperature sensors
    if (unit == SensorUnit.celsius || unit == SensorUnit.fahrenheit) {
      // Convert to Celsius first (canonical representation), then to display unit
      final celsius = unit == SensorUnit.fahrenheit
          ? temperatureUnitToCelsius(TemperatureUnit.fahrenheit, value)
          : value;
      return temperatureUnitFromCelsius(displayUnit, celsius);
    }
    return value;
  }

  /// Get the display unit for this sensor when shown in the specified temperature unit.
  /// Returns the actual unit string that should be displayed.
  String displayUnitIn(TemperatureUnit displayUnit) {
    if (unit == SensorUnit.celsius || unit == SensorUnit.fahrenheit) {
      return displayUnit == TemperatureUnit.fahrenheit ? '°F' : '°C';
    }
    return sensorUnitToJson(unit);
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Sensor &&
          runtimeType == other.runtimeType &&
          name == other.name &&
          rawName == other.rawName &&
          value == other.value &&
          unit == other.unit &&
          description == other.description;

  @override
  int get hashCode => Object.hash(name, rawName, value, unit, description);

  @override
  String toString() => 'Sensor(name: $name, value: $value, unit: $unit)';
}
