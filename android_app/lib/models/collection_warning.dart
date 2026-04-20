/// A warning collected during sensor/telemetry data collection.
///
/// Matches the `collection_warning` definition in the sensors contract.
/// Warnings are non-fatal and indicate partial data availability.
class CollectionWarning {
  /// Source subsystem that generated the warning (e.g., "network", "gpu").
  final String source;

  /// Machine-readable warning code (e.g., "NETWORK_SAMPLE_UNAVAILABLE").
  final String code;

  /// Human-readable explanation of the warning.
  final String message;

  const CollectionWarning({
    required this.source,
    required this.code,
    required this.message,
  });

  factory CollectionWarning.fromJson(Map<String, dynamic> json) {
    return CollectionWarning(
      source: json['source'] as String,
      code: json['code'] as String,
      message: json['message'] as String,
    );
  }

  Map<String, dynamic> toJson() {
    return {'source': source, 'code': code, 'message': message};
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is CollectionWarning &&
          runtimeType == other.runtimeType &&
          source == other.source &&
          code == other.code &&
          message == other.message;

  @override
  int get hashCode => Object.hash(source, code, message);

  @override
  String toString() =>
      'CollectionWarning(source: $source, code: $code, message: $message)';
}
