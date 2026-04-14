/// Configuration for a single monitored host
class HostConfig {
  final String hostId;
  final String hostname;
  final String ipAddress;
  final String displayName;
  final bool isOnline;
  final String lastConnected;

  const HostConfig({
    required this.hostId,
    required this.hostname,
    required this.ipAddress,
    required this.displayName,
    this.isOnline = false,
    this.lastConnected = '',
  });

  /// Create from JSON (for repository persistence)
  factory HostConfig.fromJson(Map<String, dynamic> json) {
    return HostConfig(
      hostId: json['host_id'] as String,
      hostname: json['hostname'] as String,
      ipAddress: json['ip_address'] as String,
      displayName: json['display_name'] as String,
      isOnline: json['is_online'] as bool? ?? false,
      lastConnected: json['last_connected'] as String? ?? '',
    );
  }

  /// Convert to JSON (for repository persistence)
  Map<String, dynamic> toJson() {
    return {
      'host_id': hostId,
      'hostname': hostname,
      'ip_address': ipAddress,
      'display_name': displayName,
      'is_online': isOnline,
      'last_connected': lastConnected,
    };
  }

  /// Create a copy with updated values
  HostConfig copyWith({
    String? hostId,
    String? hostname,
    String? ipAddress,
    String? displayName,
    bool? isOnline,
    String? lastConnected,
  }) {
    return HostConfig(
      hostId: hostId ?? this.hostId,
      hostname: hostname ?? this.hostname,
      ipAddress: ipAddress ?? this.ipAddress,
      displayName: displayName ?? this.displayName,
      isOnline: isOnline ?? this.isOnline,
      lastConnected: lastConnected ?? this.lastConnected,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is HostConfig &&
          runtimeType == other.runtimeType &&
          hostId == other.hostId &&
          hostname == other.hostname &&
          ipAddress == other.ipAddress &&
          displayName == other.displayName &&
          isOnline == other.isOnline &&
          lastConnected == other.lastConnected;

  @override
  int get hashCode => Object.hash(
    hostId,
    hostname,
    ipAddress,
    displayName,
    isOnline,
    lastConnected,
  );

  @override
  String toString() =>
      'HostConfig(hostId: $hostId, hostname: $hostname, ipAddress: $ipAddress, displayName: $displayName)';
}
