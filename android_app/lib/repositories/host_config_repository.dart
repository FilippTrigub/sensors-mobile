import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'package:sensors/models/host_config.dart';

/// Repository for persisting the single host configuration using SharedPreferences
class HostConfigRepository {
  static const String _hostConfigKey = 'current_host_config';

  /// Save the host configuration
  Future<void> saveConfig(HostConfig config) async {
    final prefs = await SharedPreferences.getInstance();
    final json = jsonEncode(config.toJson());
    await prefs.setString(_hostConfigKey, json);
  }

  /// Load the saved host configuration
  Future<HostConfig?> loadConfig() async {
    final prefs = await SharedPreferences.getInstance();
    final json = prefs.getString(_hostConfigKey);
    if (json == null) {
      return null;
    }
    return HostConfig.fromJson(jsonDecode(json) as Map<String, dynamic>);
  }

  /// Clear the saved configuration
  Future<void> clearConfig() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_hostConfigKey);
  }
}
