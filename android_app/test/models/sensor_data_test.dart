import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:sensors/models/models.dart';

void main() {
  group('SensorData parsing from JSON', () {
    test('parses success_fixture.json correctly', () {
      final json = '''
{
  "version": "1.0",
  "host_identity": {
    "hostname": "dev-server",
    "fqdn": "dev-server.local",
    "platform": "Linux"
  },
  "timestamp": "2026-04-13T21:00:00Z",
  "sensor_groups": [
    {
      "name": "nvme-pci-0000:01:00.0",
      "adapter": "PCI adapter at 0000:01:00.0",
      "sensors": [
        {
          "name": "composite",
          "raw_name": "composite",
          "value": 38.5,
          "unit": "°C",
          "description": "Overall NVMe temperature"
        },
        {
          "name": "nvme_temp_1",
          "raw_name": "nvme_temp_1",
          "value": 36.0,
          "unit": "°C",
          "description": "NVMe drive temperature"
        }
      ]
    },
    {
      "name": "coretemp-isa-0000",
      "adapter": "isa adapter",
      "sensors": [
        {
          "name": "coretemp",
          "raw_name": "Package id 0",
          "value": 42.3,
          "unit": "°C",
          "description": "CPU package temperature"
        }
      ]
    }
  ],
  "status": {
    "code": "OK",
    "message": "Sensors data collected successfully",
    "last_updated": "2026-04-13T21:00:00Z"
  },
  "units": {
    "temperature": "C"
  }
}
''';

      final sensorData = SensorData.fromJson(jsonDecode(json));

      expect(sensorData.version, '1.0');
      expect(sensorData.hostIdentity.hostname, 'dev-server');
      expect(sensorData.hostIdentity.fqdn, 'dev-server.local');
      expect(sensorData.hostIdentity.platform, Platform.linux);
      expect(sensorData.timestamp, '2026-04-13T21:00:00Z');
      expect(sensorData.sensorGroups.length, 2);
      expect(sensorData.sensorGroups[0].name, 'nvme-pci-0000:01:00.0');
      expect(sensorData.sensorGroups[0].sensors.length, 2);
      expect(sensorData.sensorGroups[0].sensors[0].value, 38.5);
      expect(sensorData.sensorGroups[0].sensors[0].unit, SensorUnit.celsius);
      expect(sensorData.status.code, SensorStatusCode.ok);
      expect(sensorData.units?.temperature, TemperatureUnit.celsius);
    });

    test('parses empty_fixture.json correctly', () {
      final json = '''
{
  "version": "1.0",
  "host_identity": {
    "hostname": "dev-server",
    "fqdn": "dev-server.local",
    "platform": "Linux"
  },
  "timestamp": "2026-04-13T21:00:00Z",
  "sensor_groups": [],
  "status": {
    "code": "EMPTY",
    "message": "No sensor data detected - lm-sensors may not be installed or configured",
    "last_updated": "2026-04-13T21:00:00Z"
  },
  "units": {
    "temperature": "C"
  }
}
''';

      final sensorData = SensorData.fromJson(jsonDecode(json));

      expect(sensorData.sensorGroups.isEmpty, true);
      expect(sensorData.status.code, SensorStatusCode.empty);
      expect(sensorData.status.message, contains('No sensor data'));
    });

    test('parses error_fixture.json correctly', () {
      final json = '''
{
  "version": "1.0",
  "host_identity": {
    "hostname": "dev-server",
    "fqdn": "dev-server.local",
    "platform": "Linux"
  },
  "timestamp": "2026-04-13T21:00:00Z",
  "sensor_groups": [],
  "status": {
    "code": "ERROR",
    "message": "lm-sensors command failed: command not found",
    "last_updated": null
  },
  "error_details": {
    "error_code": "LM_SENSORS_NOT_FOUND",
    "suggestion": "Install lm-sensors package and run sensors-detect"
  },
  "units": {
    "temperature": "C"
  }
}
''';

      final sensorData = SensorData.fromJson(jsonDecode(json));

      expect(sensorData.status.code, SensorStatusCode.error);
      expect(sensorData.status.lastUpdated, isNull);
      expect((sensorData as dynamic).errorDetails, isNotNull);
    });

    test('handles missing optional fields gracefully', () {
      final json = '''
{
  "host_identity": {
    "hostname": "test",
    "fqdn": "test.local",
    "platform": "Linux"
  },
  "timestamp": "2026-04-13T21:00:00Z",
  "sensor_groups": [],
  "status": {
    "code": "OK",
    "message": "Success"
  }
}
''';

      final sensorData = SensorData.fromJson(jsonDecode(json));

      expect(sensorData.version, isNull);
      expect(sensorData.units, isNull);
      expect(sensorData.status.lastUpdated, isNull);
    });

    test('toMap produces correct JSON structure', () {
      final sensorData = SensorData(
        version: '1.0',
        hostIdentity: HostIdentity(
          hostname: 'test-host',
          fqdn: 'test.local',
          platform: Platform.linux,
        ),
        timestamp: '2026-04-13T21:00:00Z',
        sensorGroups: [],
        status: SensorStatus(code: SensorStatusCode.ok, message: 'Success'),
        units: Units(temperature: TemperatureUnit.celsius),
      );

      final map = sensorData.toJson();

      expect(map['version'], '1.0');
      expect(map['host_identity']['hostname'], 'test-host');
      expect(map['status']['code'], 'OK');
    });
  });

  group('HostIdentity model', () {
    test('creates HostIdentity from JSON', () {
      final json = {
        'hostname': 'my-server',
        'fqdn': 'my-server.example.com',
        'platform': 'Linux',
      };

      final identity = HostIdentity.fromJson(json);

      expect(identity.hostname, 'my-server');
      expect(identity.fqdn, 'my-server.example.com');
      expect(identity.platform, Platform.linux);
    });

    test('throws on missing required fields', () {
      final json = {'hostname': 'test'};

      expect(() => HostIdentity.fromJson(json), throwsA(isA<ArgumentError>()));
    });
  });

  group('SensorGroup model', () {
    test('creates SensorGroup from JSON', () {
      final json = {
        'name': 'coretemp-isa-0000',
        'adapter': 'isa adapter',
        'sensors': [
          {
            'name': 'coretemp',
            'raw_name': 'Package id 0',
            'value': 42.3,
            'unit': '°C',
            'description': 'CPU package',
          },
        ],
      };

      final group = SensorGroup.fromJson(json);

      expect(group.name, 'coretemp-isa-0000');
      expect(group.adapter, 'isa adapter');
      expect(group.sensors.length, 1);
      expect(group.sensors[0].value, 42.3);
    });

    test('handles empty sensors array', () {
      final json = {'name': 'empty-group', 'adapter': 'test', 'sensors': []};

      final group = SensorGroup.fromJson(json);

      expect(group.sensors.isEmpty, true);
    });
  });

  group('Sensor model', () {
    test('parses °C unit', () {
      final json = {
        'name': 'temp1',
        'raw_name': 'temp1',
        'value': 25.5,
        'unit': '°C',
      };

      final sensor = Sensor.fromJson(json);

      expect(sensor.unit, SensorUnit.celsius);
    });

    test('parses °F unit', () {
      final json = {
        'name': 'temp1',
        'raw_name': 'temp1',
        'value': 77.9,
        'unit': '°F',
      };

      final sensor = Sensor.fromJson(json);

      expect(sensor.unit, SensorUnit.fahrenheit);
    });

    test('parses RPM unit', () {
      final json = {'name': 'fan1', 'value': 1200, 'unit': 'RPM'};

      final sensor = Sensor.fromJson(json);

      expect(sensor.unit, SensorUnit.rpm);
    });

    test('parses V unit', () {
      final json = {'name': 'in1', 'value': 1.05, 'unit': 'V'};

      final sensor = Sensor.fromJson(json);

      expect(sensor.unit, SensorUnit.volts);
    });

    test('parses mV unit', () {
      final json = {'name': 'in1', 'value': 1050, 'unit': 'mV'};

      final sensor = Sensor.fromJson(json);

      expect(sensor.unit, SensorUnit.millivolts);
    });

    test('handles unknown unit', () {
      final json = {'name': 'test', 'value': 42, 'unit': 'unknown'};

      final sensor = Sensor.fromJson(json);

      expect(sensor.unit, SensorUnit.unknown);
    });
  });

  group('SensorStatus model', () {
    test('creates Status from OK code', () {
      final json = {
        'code': 'OK',
        'message': 'Success',
        'last_updated': '2026-04-13T21:00:00Z',
      };

      final status = SensorStatus.fromJson(json);

      expect(status.code, SensorStatusCode.ok);
      expect(status.message, 'Success');
      expect(status.lastUpdated, '2026-04-13T21:00:00Z');
    });

    test('creates Status from STALE code', () {
      final json = {
        'code': 'STALE',
        'message': 'Data is stale',
        'last_updated': '2026-04-13T20:00:00Z',
      };

      final status = SensorStatus.fromJson(json);

      expect(status.code, SensorStatusCode.stale);
    });

    test('allows null last_updated', () {
      final json = {
        'code': 'ERROR',
        'message': 'Something went wrong',
        'last_updated': null,
      };

      final status = SensorStatus.fromJson(json);

      expect(status.code, SensorStatusCode.error);
      expect(status.lastUpdated, isNull);
    });
  });

  group('Units model', () {
    test('parses Celsius temperature unit', () {
      final json = {'temperature': 'C'};
      final units = Units.fromJson(json);
      expect(units.temperature, TemperatureUnit.celsius);
    });

    test('parses Fahrenheit temperature unit', () {
      final json = {'temperature': 'F'};
      final units = Units.fromJson(json);
      expect(units.temperature, TemperatureUnit.fahrenheit);
    });

    test('handles missing units', () {
      final units = Units.fromJson({});
      expect(units.temperature, isNull);
    });
  });
}
