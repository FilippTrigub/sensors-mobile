import 'package:android_app/models/enums.dart';

/// Host identity information from the backend
class HostIdentity {
  final String hostname;
  final String fqdn;
  final Platform platform;

  const HostIdentity({
    required this.hostname,
    required this.fqdn,
    required this.platform,
  });

  factory HostIdentity.fromJson(Map<String, dynamic> json) {
    final hostname = json['hostname'] as String?;
    final fqdn = json['fqdn'] as String?;
    final platform = json['platform'] as String?;

    if (hostname == null || fqdn == null || platform == null) {
      throw ArgumentError(
        'HostIdentity requires hostname, fqdn, and platform fields',
      );
    }

    return HostIdentity(
      hostname: hostname,
      fqdn: fqdn,
      platform: platformFromString(platform),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'hostname': hostname,
      'fqdn': fqdn,
      'platform': platformToJson(platform),
    };
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is HostIdentity &&
          runtimeType == other.runtimeType &&
          hostname == other.hostname &&
          fqdn == other.fqdn &&
          platform == other.platform;

  @override
  int get hashCode => Object.hash(hostname, fqdn, platform);

  @override
  String toString() =>
      'HostIdentity(hostname: $hostname, fqdn: $fqdn, platform: $platform)';
}
