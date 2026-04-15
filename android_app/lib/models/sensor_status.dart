import 'package:sensors/models/enums.dart';

/// Status of the sensor data collection
class SensorStatus {
  final SensorStatusCode code;
  final String message;
  final String? lastUpdated;

  const SensorStatus({
    required this.code,
    required this.message,
    this.lastUpdated,
  });

  factory SensorStatus.fromJson(Map<String, dynamic> json) {
    return SensorStatus(
      code: sensorStatusCodeFromString(json['code'] as String),
      message: json['message'] as String,
      lastUpdated: json['last_updated'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'code': sensorStatusCodeToJson(code),
      'message': message,
      if (lastUpdated != null) 'last_updated': lastUpdated,
    };
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SensorStatus &&
          runtimeType == other.runtimeType &&
          code == other.code &&
          message == other.message &&
          lastUpdated == other.lastUpdated;

  @override
  int get hashCode => Object.hash(code, message, lastUpdated);

  @override
  String toString() => 'SensorStatus(code: $code, message: $message)';
}
