import 'package:sensors/models/enums.dart';

/// User preferences for temperature units
class Units {
  final TemperatureUnit? temperature;

  const Units({this.temperature});

  factory Units.fromJson(Map<String, dynamic> json) {
    return Units(
      temperature: json['temperature'] != null
          ? temperatureUnitFromString(json['temperature'] as String)
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      if (temperature != null)
        'temperature': temperatureUnitToJson(temperature!),
    };
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Units &&
          runtimeType == other.runtimeType &&
          temperature == other.temperature;

  @override
  int get hashCode => Object.hash(temperature, runtimeType);

  @override
  String toString() => 'Units(temperature: $temperature)';
}
