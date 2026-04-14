import 'package:shared_preferences/shared_preferences.dart';
import 'package:android_app/models/enums.dart';

/// Repository for persisting user preferences using SharedPreferences
class UserPreferencesRepository {
  static const String _tempUnitKey = 'temperature_unit';
  static const String _autoRefreshKey = 'auto_refresh';
  static const String _showDetailedViewKey = 'show_detailed_view';

  /// Get temperature unit preference, defaults to Celsius
  Future<TemperatureUnit> getTemperatureUnit() async {
    final prefs = await SharedPreferences.getInstance();
    final unit = prefs.getString(_tempUnitKey);
    return unit != null
        ? temperatureUnitFromString(unit)
        : TemperatureUnit.celsius;
  }

  /// Set temperature unit preference
  Future<void> setTemperatureUnit(TemperatureUnit unit) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_tempUnitKey, temperatureUnitToJson(unit));
  }

  /// Get auto-refresh preference, defaults to false
  Future<bool> getAutoRefresh() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_autoRefreshKey) ?? false;
  }

  /// Set auto-refresh preference
  Future<void> setAutoRefresh(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_autoRefreshKey, enabled);
  }

  /// Get show detailed view preference, defaults to true
  Future<bool> getShowDetailedView() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_showDetailedViewKey) ?? true;
  }

  /// Set show detailed view preference
  Future<void> setShowDetailedView(bool show) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_showDetailedViewKey, show);
  }
}
