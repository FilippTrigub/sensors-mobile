import 'package:sensors/models/enums.dart';
import 'package:sensors/models/sensor.dart';
import 'package:sensors/repositories/user_preferences_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('Unit preference persistence', () {
    test('defaults to Celsius when not set', () async {
      final repository = UserPreferencesRepository();

      final unit = await repository.getTemperatureUnit();

      expect(unit, TemperatureUnit.celsius);
    });

    test('persists Fahrenheit preference', () async {
      final repository = UserPreferencesRepository();

      await repository.setTemperatureUnit(TemperatureUnit.fahrenheit);
      final unit = await repository.getTemperatureUnit();

      expect(unit, TemperatureUnit.fahrenheit);
    });

    test('updates preference across writes', () async {
      final repository = UserPreferencesRepository();

      await repository.setTemperatureUnit(TemperatureUnit.celsius);
      await repository.setTemperatureUnit(TemperatureUnit.fahrenheit);
      final unit = await repository.getTemperatureUnit();

      expect(unit, TemperatureUnit.fahrenheit);
    });
  });

  group('Temperature display conversion', () {
    test('keeps Celsius values in Celsius mode', () {
      const sensor = Sensor(
        name: 'CPU Temp',
        value: 45.0,
        unit: SensorUnit.celsius,
      );

      expect(sensor.displayValueInUnit(TemperatureUnit.celsius), 45.0);
      expect(sensor.displayUnitIn(TemperatureUnit.celsius), '°C');
    });

    test('converts Celsius values to Fahrenheit mode', () {
      const sensor = Sensor(
        name: 'CPU Temp',
        value: 45.0,
        unit: SensorUnit.celsius,
      );

      expect(sensor.displayValueInUnit(TemperatureUnit.fahrenheit), 113.0);
      expect(sensor.displayUnitIn(TemperatureUnit.fahrenheit), '°F');
    });

    test('does not convert non-temperature units', () {
      const sensor = Sensor(name: 'Fan 1', value: 2500.0, unit: SensorUnit.rpm);

      expect(sensor.displayValueInUnit(TemperatureUnit.fahrenheit), 2500.0);
      expect(sensor.displayUnitIn(TemperatureUnit.fahrenheit), 'RPM');
    });
  });
}
