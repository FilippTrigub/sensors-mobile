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

  // -------------------------------------------------------------------
  // TELEMETRY PARSING TESTS (v1.1 payloads)
  // -------------------------------------------------------------------

  group('SensorData telemetry parsing (v1.1)', () {
    test('parses full 1.1 payload with telemetry and empty warnings', () {
      final json = '''
{
  "version": "1.1",
  "host_identity": {
    "hostname": "dev-server",
    "fqdn": "dev-server.local",
    "platform": "Linux"
  },
  "timestamp": "2026-04-13T21:00:00Z",
  "sensor_groups": [],
  "status": {
    "code": "OK",
    "message": "Sensors data collected successfully",
    "last_updated": "2026-04-13T21:00:00Z"
  },
  "system_telemetry": {
    "cpu": {
      "usage_percent": 18.4
    },
    "memory": {
      "used_bytes": 6442450944,
      "total_bytes": 17179869184,
      "usage_percent": 37.5
    },
    "network": {
      "rx_bytes_per_sec": 2048.5,
      "tx_bytes_per_sec": 1024.25,
      "total_rx_bytes": 987654321,
      "total_tx_bytes": 123456789,
      "sample_window_seconds": 1.0,
      "interfaces": ["eth0", "wlan0"]
    },
    "gpu_devices": [
      {
        "id": "0000:01:00.0",
        "name": "NVIDIA GeForce RTX 4060",
        "vendor": "NVIDIA",
        "utilization_percent": 24.0,
        "memory_used_bytes": 1073741824,
        "memory_total_bytes": 8589934592,
        "memory_usage_percent": 12.5
      }
    ]
  },
  "collection_warnings": [],
  "units": {
    "temperature": "C"
  }
}
''';

      final sensorData = SensorData.fromJson(jsonDecode(json));

      expect(sensorData.version, '1.1');
      expect(sensorData.systemTelemetry, isNotNull);
      expect(sensorData.systemTelemetry!.cpu, isNotNull);
      expect(sensorData.systemTelemetry!.cpu!.usagePercent, 18.4);
      expect(sensorData.systemTelemetry!.memory, isNotNull);
      expect(sensorData.systemTelemetry!.memory!.usedBytes, 6442450944);
      expect(sensorData.systemTelemetry!.memory!.totalBytes, 17179869184);
      expect(sensorData.systemTelemetry!.memory!.usagePercent, 37.5);
      expect(sensorData.systemTelemetry!.network, isNotNull);
      expect(sensorData.systemTelemetry!.network!.rxBytesPerSec, 2048.5);
      expect(sensorData.systemTelemetry!.network!.txBytesPerSec, 1024.25);
      expect(sensorData.systemTelemetry!.network!.totalRxBytes, 987654321);
      expect(sensorData.systemTelemetry!.network!.totalTxBytes, 123456789);
      expect(sensorData.systemTelemetry!.network!.sampleWindowSeconds, 1.0);
      expect(sensorData.systemTelemetry!.network!.interfaces, [
        'eth0',
        'wlan0',
      ]);
      expect(sensorData.systemTelemetry!.gpuDevices.length, 1);
      expect(sensorData.systemTelemetry!.gpuDevices[0].id, '0000:01:00.0');
      expect(
        sensorData.systemTelemetry!.gpuDevices[0].name,
        'NVIDIA GeForce RTX 4060',
      );
      expect(sensorData.systemTelemetry!.gpuDevices[0].vendor, 'NVIDIA');
      expect(
        sensorData.systemTelemetry!.gpuDevices[0].utilizationPercent,
        24.0,
      );
      expect(
        sensorData.systemTelemetry!.gpuDevices[0].memoryUsedBytes,
        1073741824,
      );
      expect(
        sensorData.systemTelemetry!.gpuDevices[0].memoryTotalBytes,
        8589934592,
      );
      expect(
        sensorData.systemTelemetry!.gpuDevices[0].memoryUsagePercent,
        12.5,
      );
      expect(sensorData.collectionWarnings, isNotNull);
      expect(sensorData.collectionWarnings!.isEmpty, true);
    });

    test('parses telemetry-only payload with warnings and null network', () {
      final json = '''
{
  "version": "1.1",
  "host_identity": {
    "hostname": "dev-server",
    "fqdn": "dev-server.local",
    "platform": "Linux"
  },
  "timestamp": "2026-04-13T21:00:00Z",
  "sensor_groups": [],
  "status": {
    "code": "OK",
    "message": "System telemetry collected successfully while hardware sensor data is unavailable",
    "last_updated": "2026-04-13T21:00:00Z"
  },
  "system_telemetry": {
    "cpu": {
      "usage_percent": 9.25
    },
    "memory": {
      "used_bytes": 2147483648,
      "total_bytes": 8589934592,
      "usage_percent": 25.0
    },
    "network": null,
    "gpu_devices": []
  },
  "collection_warnings": [
    {
      "source": "network",
      "code": "NETWORK_SAMPLE_UNAVAILABLE",
      "message": "Network counters could not be sampled during this collection pass"
    }
  ],
  "units": {
    "temperature": "C"
  }
}
''';

      final sensorData = SensorData.fromJson(jsonDecode(json));

      expect(sensorData.version, '1.1');
      expect(sensorData.systemTelemetry, isNotNull);
      expect(sensorData.systemTelemetry!.cpu!.usagePercent, 9.25);
      expect(sensorData.systemTelemetry!.memory!.usagePercent, 25.0);
      expect(sensorData.systemTelemetry!.network, isNull);
      expect(sensorData.systemTelemetry!.gpuDevices.isEmpty, true);
      expect(sensorData.collectionWarnings, isNotNull);
      expect(sensorData.collectionWarnings!.length, 1);
      expect(sensorData.collectionWarnings![0].source, 'network');
      expect(
        sensorData.collectionWarnings![0].code,
        'NETWORK_SAMPLE_UNAVAILABLE',
      );
      expect(
        sensorData.collectionWarnings![0].message,
        contains('Network counters'),
      );
    });

    test('parses telemetry with null cpu and memory', () {
      final json = '''
{
  "version": "1.1",
  "host_identity": {
    "hostname": "test-host",
    "fqdn": "test.local",
    "platform": "Linux"
  },
  "timestamp": "2026-04-13T22:00:00Z",
  "sensor_groups": [],
  "status": {
    "code": "OK",
    "message": "Telemetry partially available"
  },
  "system_telemetry": {
    "cpu": null,
    "memory": null,
    "network": {
      "rx_bytes_per_sec": 0,
      "tx_bytes_per_sec": 0,
      "total_rx_bytes": 0,
      "total_tx_bytes": 0,
      "sample_window_seconds": 1.0,
      "interfaces": []
    },
    "gpu_devices": []
  },
  "collection_warnings": []
}
''';

      final sensorData = SensorData.fromJson(jsonDecode(json));

      expect(sensorData.systemTelemetry!.cpu, isNull);
      expect(sensorData.systemTelemetry!.memory, isNull);
      expect(sensorData.systemTelemetry!.network, isNotNull);
      expect(sensorData.systemTelemetry!.network!.interfaces.isEmpty, true);
    });

    test('parses GPU device with nullable fields', () {
      final json = '''
{
  "version": "1.1",
  "host_identity": {
    "hostname": "gpu-test",
    "fqdn": "gpu.local",
    "platform": "Linux"
  },
  "timestamp": "2026-04-13T23:00:00Z",
  "sensor_groups": [],
  "status": {
    "code": "OK",
    "message": "OK"
  },
  "system_telemetry": {
    "cpu": { "usage_percent": 5.0 },
    "memory": { "used_bytes": 1000, "total_bytes": 2000, "usage_percent": 50.0 },
    "network": {
      "rx_bytes_per_sec": 0,
      "tx_bytes_per_sec": 0,
      "total_rx_bytes": 0,
      "total_tx_bytes": 0,
      "sample_window_seconds": 1.0,
      "interfaces": []
    },
    "gpu_devices": [
      {
        "id": "0000:02:00.0",
        "name": "AMD Radeon RX 7800",
        "vendor": "AMD"
      }
    ]
  },
  "collection_warnings": []
}
''';

      final sensorData = SensorData.fromJson(jsonDecode(json));

      final gpu = sensorData.systemTelemetry!.gpuDevices[0];
      expect(gpu.id, '0000:02:00.0');
      expect(gpu.name, 'AMD Radeon RX 7800');
      expect(gpu.vendor, 'AMD');
      expect(gpu.utilizationPercent, isNull);
      expect(gpu.memoryUsedBytes, isNull);
      expect(gpu.memoryTotalBytes, isNull);
      expect(gpu.memoryUsagePercent, isNull);
    });

    test('handles missing telemetry fields as null (backward compatible)', () {
      final json = '''
{
  "host_identity": {
    "hostname": "no-telemetry",
    "fqdn": "no-telemetry.local",
    "platform": "Linux"
  },
  "timestamp": "2026-04-13T21:00:00Z",
  "sensor_groups": [],
  "status": {
    "code": "OK",
    "message": "OK"
  }
}
''';

      final sensorData = SensorData.fromJson(jsonDecode(json));

      expect(sensorData.systemTelemetry, isNull);
      expect(sensorData.collectionWarnings, isNull);
    });
  });

  // -------------------------------------------------------------------
  // LEGACY 1.0 PAYLOAD TESTS (no telemetry)
  // -------------------------------------------------------------------

  group('Legacy 1.0 payload backward compatibility', () {
    test('parses 1.0 payload without telemetry fields successfully', () {
      final json = '''
{
  "version": "1.0",
  "host_identity": {
    "hostname": "legacy-host",
    "fqdn": "legacy.local",
    "platform": "Linux"
  },
  "timestamp": "2026-04-13T21:00:00Z",
  "sensor_groups": [
    {
      "name": "coretemp-isa-0000",
      "adapter": "isa adapter",
      "sensors": [
        {
          "name": "Package id 0",
          "raw_name": "Package id 0",
          "value": 55.0,
          "unit": "°C",
          "description": "CPU package"
        }
      ]
    }
  ],
  "status": {
    "code": "OK",
    "message": "Sensors collected",
    "last_updated": "2026-04-13T21:00:00Z"
  },
  "units": {
    "temperature": "C"
  }
}
''';

      final sensorData = SensorData.fromJson(jsonDecode(json));

      expect(sensorData.version, '1.0');
      expect(sensorData.systemTelemetry, isNull);
      expect(sensorData.collectionWarnings, isNull);
      expect(sensorData.sensorGroups.length, 1);
      expect(sensorData.sensorGroups[0].sensors.length, 1);
      expect(sensorData.sensorGroups[0].sensors[0].value, 55.0);
    });

    test('1.0 payload with error_details still works without telemetry', () {
      final json = '''
{
  "version": "1.0",
  "host_identity": {
    "hostname": "error-host",
    "fqdn": "error.local",
    "platform": "Linux"
  },
  "timestamp": "2026-04-13T21:00:00Z",
  "sensor_groups": [],
  "status": {
    "code": "ERROR",
    "message": "lm-sensors command failed",
    "last_updated": null
  },
  "error_details": {
    "error_code": "LM_SENSORS_NOT_FOUND",
    "suggestion": "Install lm-sensors"
  }
}
''';

      final sensorData = SensorData.fromJson(jsonDecode(json));

      expect(sensorData.version, '1.0');
      expect(sensorData.status.code, SensorStatusCode.error);
      expect(sensorData.errorDetails, isNotNull);
      expect(sensorData.errorDetails!['error_code'], 'LM_SENSORS_NOT_FOUND');
      expect(sensorData.systemTelemetry, isNull);
      expect(sensorData.collectionWarnings, isNull);
    });
  });

  // -------------------------------------------------------------------
  // TELEMETRY MODEL UNIT TESTS
  // -------------------------------------------------------------------

  group('CpuTelemetry model', () {
    test('creates CpuTelemetry from JSON', () {
      final json = {'usage_percent': 42.5};
      final cpu = CpuTelemetry.fromJson(json);
      expect(cpu.usagePercent, 42.5);
    });

    test('round-trips toJson/fromJson', () {
      final cpu = CpuTelemetry(usagePercent: 15.0);
      final json = cpu.toJson();
      final cpu2 = CpuTelemetry.fromJson(json);
      expect(cpu2.usagePercent, 15.0);
    });
  });

  group('MemoryTelemetry model', () {
    test('creates MemoryTelemetry from JSON', () {
      final json = {
        'used_bytes': 4294967296,
        'total_bytes': 8589934592,
        'usage_percent': 50.0,
      };
      final mem = MemoryTelemetry.fromJson(json);
      expect(mem.usedBytes, 4294967296);
      expect(mem.totalBytes, 8589934592);
      expect(mem.usagePercent, 50.0);
    });
  });

  group('NetworkTelemetry model', () {
    test('creates NetworkTelemetry from JSON', () {
      final json = {
        'rx_bytes_per_sec': 1024.0,
        'tx_bytes_per_sec': 512.0,
        'total_rx_bytes': 1000000,
        'total_tx_bytes': 500000,
        'sample_window_seconds': 2.0,
        'interfaces': ['eth0'],
      };
      final net = NetworkTelemetry.fromJson(json);
      expect(net.rxBytesPerSec, 1024.0);
      expect(net.txBytesPerSec, 512.0);
      expect(net.totalRxBytes, 1000000);
      expect(net.totalTxBytes, 500000);
      expect(net.sampleWindowSeconds, 2.0);
      expect(net.interfaces, ['eth0']);
    });
  });

  group('GpuDeviceTelemetry model', () {
    test('creates GpuDeviceTelemetry with all fields', () {
      final json = {
        'id': '0000:01:00.0',
        'name': 'RTX 4060',
        'vendor': 'NVIDIA',
        'utilization_percent': 30.0,
        'memory_used_bytes': 2000000000,
        'memory_total_bytes': 8000000000,
        'memory_usage_percent': 25.0,
      };
      final gpu = GpuDeviceTelemetry.fromJson(json);
      expect(gpu.id, '0000:01:00.0');
      expect(gpu.utilizationPercent, 30.0);
      expect(gpu.memoryUsedBytes, 2000000000);
    });

    test('creates GpuDeviceTelemetry with nullable fields absent', () {
      final json = {
        'id': '0000:02:00.0',
        'name': 'Basic GPU',
        'vendor': 'Intel',
      };
      final gpu = GpuDeviceTelemetry.fromJson(json);
      expect(gpu.utilizationPercent, isNull);
      expect(gpu.memoryUsedBytes, isNull);
    });
  });

  group('CollectionWarning model', () {
    test('creates CollectionWarning from JSON', () {
      final json = {
        'source': 'gpu',
        'code': 'GPU_NOT_SUPPORTED',
        'message': 'GPU telemetry not available',
      };
      final warning = CollectionWarning.fromJson(json);
      expect(warning.source, 'gpu');
      expect(warning.code, 'GPU_NOT_SUPPORTED');
      expect(warning.message, 'GPU telemetry not available');
    });
  });

  group('SystemTelemetry model', () {
    test('creates SystemTelemetry with all sub-fields', () {
      final json = {
        'cpu': {'usage_percent': 10.0},
        'memory': {
          'used_bytes': 1000,
          'total_bytes': 4000,
          'usage_percent': 25.0,
        },
        'network': {
          'rx_bytes_per_sec': 100,
          'tx_bytes_per_sec': 50,
          'total_rx_bytes': 1000,
          'total_tx_bytes': 500,
          'sample_window_seconds': 1.0,
          'interfaces': ['lo'],
        },
        'gpu_devices': [
          {'id': '0', 'name': 'TestGPU', 'vendor': 'TestVendor'},
        ],
      };
      final sys = SystemTelemetry.fromJson(json);
      expect(sys.cpu!.usagePercent, 10.0);
      expect(sys.memory!.usedBytes, 1000);
      expect(sys.network!.interfaces, ['lo']);
      expect(sys.gpuDevices.length, 1);
      expect(sys.gpuDevices[0].name, 'TestGPU');
    });

    test('handles null cpu and memory', () {
      final json = {
        'cpu': null,
        'memory': null,
        'network': null,
        'gpu_devices': [],
      };
      final sys = SystemTelemetry.fromJson(json);
      expect(sys.cpu, isNull);
      expect(sys.memory, isNull);
      expect(sys.network, isNull);
      expect(sys.gpuDevices.isEmpty, true);
    });
  });
}
