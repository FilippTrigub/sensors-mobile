/// Platform type from the host identity
enum Platform {
  linux,
  unknown,
}

/// Convert a string value to a Platform enum
Platform platformFromString(String value) {
  switch (value.toLowerCase()) {
    case 'linux':
      return Platform.linux;
    default:
      return Platform.unknown;
  }
}

/// Convert a Platform enum to JSON string
String platformToJson(Platform platform) {
  switch (platform) {
    case Platform.linux:
      return 'Linux';
    case Platform.unknown:
      return 'Unknown';
  }
}

/// Status code from the sensor API
enum SensorStatusCode {
  ok,
  empty,
  error,
  stale,
}

/// Convert a status code string to SensorStatusCode enum
SensorStatusCode sensorStatusCodeFromString(String value) {
  switch (value.toUpperCase()) {
    case 'OK':
      return SensorStatusCode.ok;
    case 'EMPTY':
      return SensorStatusCode.empty;
    case 'ERROR':
      return SensorStatusCode.error;
    case 'STALE':
      return SensorStatusCode.stale;
    default:
      throw ArgumentError('Unknown status code: $value');
  }
}

/// Convert a SensorStatusCode enum to JSON string
String sensorStatusCodeToJson(SensorStatusCode code) {
  switch (code) {
    case SensorStatusCode.ok:
      return 'OK';
    case SensorStatusCode.empty:
      return 'EMPTY';
    case SensorStatusCode.error:
      return 'ERROR';
    case SensorStatusCode.stale:
      return 'STALE';
  }
}

/// Unit of measurement for sensor readings
enum SensorUnit {
  celsius,
  fahrenheit,
  rpm,
  volts,
  millivolts,
  ratio,
  unknown,
}

/// Convert a unit string to SensorUnit enum
SensorUnit sensorUnitFromString(String value) {
  switch (value) {
    case '°C':
      return SensorUnit.celsius;
    case '°F':
      return SensorUnit.fahrenheit;
    case 'RPM':
      return SensorUnit.rpm;
    case 'V':
      return SensorUnit.volts;
    case 'mV':
      return SensorUnit.millivolts;
    case 'ratio':
      return SensorUnit.ratio;
    default:
      return SensorUnit.unknown;
  }
}

/// Convert a SensorUnit enum to JSON string
String sensorUnitToJson(SensorUnit unit) {
  switch (unit) {
    case SensorUnit.celsius:
      return '°C';
    case SensorUnit.fahrenheit:
      return '°F';
    case SensorUnit.rpm:
      return 'RPM';
    case SensorUnit.volts:
      return 'V';
    case SensorUnit.millivolts:
      return 'mV';
    case SensorUnit.ratio:
      return 'ratio';
    case SensorUnit.unknown:
      return 'unknown';
  }
}

/// Temperature unit preference
enum TemperatureUnit {
  celsius,
  fahrenheit,
}

/// Convert a temperature unit string to TemperatureUnit enum
TemperatureUnit temperatureUnitFromString(String value) {
  switch (value) {
    case 'C':
      return TemperatureUnit.celsius;
    case 'F':
      return TemperatureUnit.fahrenheit;
    default:
      return TemperatureUnit.celsius;
  }
}

/// Convert a TemperatureUnit enum to JSON string
String temperatureUnitToJson(TemperatureUnit unit) {
  switch (unit) {
    case TemperatureUnit.celsius:
      return 'C';
    case TemperatureUnit.fahrenheit:
      return 'F';
  }
}

/// Get display name for temperature unit
String temperatureUnitDisplayName(TemperatureUnit unit) {
  switch (unit) {
    case TemperatureUnit.celsius:
      return 'Celsius (°C)';
    case TemperatureUnit.fahrenheit:
      return 'Fahrenheit (°F)';
  }
}

/// Convert a temperature value from this unit to Celsius
double temperatureUnitToCelsius(TemperatureUnit unit, double value) {
  switch (unit) {
    case TemperatureUnit.celsius:
      return value;
    case TemperatureUnit.fahrenheit:
      return (value - 32) * 5 / 9;
  }
}

/// Convert a temperature value from Celsius to this unit
double temperatureUnitFromCelsius(TemperatureUnit unit, double celsius) {
  switch (unit) {
    case TemperatureUnit.celsius:
      return celsius;
    case TemperatureUnit.fahrenheit:
      return celsius * 9 / 5 + 32;
  }
}
