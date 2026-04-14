from __future__ import annotations

from datetime import UTC, datetime
from pathlib import Path
import sys

import pytest

sys.path.insert(0, str(Path(__file__).resolve().parents[2]))

from host_service.app import create_app
from host_service.sensor_collector import CommandExecutionError, HostSensorCollector, parse_sensors_json


SENSORS_JSON_OUTPUT = """
{
  "nvme-pci-0100": {
    "Adapter": "PCI adapter",
    "Composite": {
      "temp1_input": 38.5,
      "temp1_max": 84.8,
      "temp1_min": -20.1
    },
    "Sensor 1": {
      "temp2_input": 36.0
    }
  },
  "coretemp-isa-0000": {
    "Adapter": "ISA adapter",
    "Package id 0": {
      "temp1_input": 42.0,
      "temp1_crit": 100.0
    },
    "Core 0": {
      "temp2_input": 40.0
    },
    "fan1": {
      "fan1_input": 1200.0
    },
    "in0": {
      "in0_input": 1.24
    }
  }
}
""".strip()


def test_parse_sensors_json_normalizes_machine_readable_output():
    groups = parse_sensors_json(SENSORS_JSON_OUTPUT)

    assert [group["name"] for group in groups] == ["nvme-pci-0100", "coretemp-isa-0000"]
    assert groups[0]["adapter"] == "PCI adapter"
    assert groups[0]["sensors"] == [
        {
            "name": "composite",
            "raw_name": "Composite",
            "value": 38.5,
            "unit": "°C",
            "description": "Composite temperature",
        },
        {
            "name": "sensor_1",
            "raw_name": "Sensor 1",
            "value": 36.0,
            "unit": "°C",
            "description": "Sensor 1 temperature",
        },
    ]
    assert groups[1]["sensors"] == [
        {
            "name": "package_id_0",
            "raw_name": "Package id 0",
            "value": 42.0,
            "unit": "°C",
            "description": "Package id 0 temperature",
        },
        {
            "name": "core_0",
            "raw_name": "Core 0",
            "value": 40.0,
            "unit": "°C",
            "description": "Core 0 temperature",
        },
        {
            "name": "fan1",
            "raw_name": "fan1",
            "value": 1200.0,
            "unit": "RPM",
            "description": "fan1 fan speed",
        },
        {
            "name": "in0",
            "raw_name": "in0",
            "value": 1.24,
            "unit": "V",
            "description": "in0 voltage",
        },
    ]


def test_collector_returns_contract_shaped_success_payload():
    collector = HostSensorCollector(
        command_runner=lambda command: SENSORS_JSON_OUTPUT,
        clock=lambda: datetime(2026, 4, 14, 12, 30, tzinfo=UTC),
        host_identity_provider=lambda: {
            "hostname": "test-host",
            "fqdn": "test-host.local",
            "platform": "Linux",
        },
    )

    payload = collector.collect()

    assert payload["version"] == "1.0"
    assert payload["host_identity"]["hostname"] == "test-host"
    assert payload["timestamp"] == "2026-04-14T12:30:00Z"
    assert payload["status"] == {
        "code": "OK",
        "message": "Sensors data collected successfully",
        "last_updated": "2026-04-14T12:30:00Z",
    }
    assert payload["units"] == {"temperature": "C"}
    assert len(payload["sensor_groups"]) == 2


def test_sensors_endpoint_uses_configured_collector():
    class StubCollector:
        def collect(self) -> dict:
            return {
                "version": "1.0",
                "host_identity": {
                    "hostname": "stubbed-host",
                    "fqdn": "stubbed-host.local",
                    "platform": "Linux",
                },
                "timestamp": "2026-04-14T12:30:00Z",
                "sensor_groups": [],
                "status": {
                    "code": "EMPTY",
                    "message": "No sensor data detected from stub collector",
                    "last_updated": "2026-04-14T12:30:00Z",
                },
                "units": {"temperature": "C"},
            }

    app = create_app()
    app.config["SENSOR_COLLECTOR"] = StubCollector()

    response = app.test_client().get("/api/v1/sensors")

    assert response.status_code == 200
    assert response.get_json()["host_identity"]["hostname"] == "stubbed-host"


def test_collector_returns_explicit_empty_payload_when_no_readings_exist():
    collector = HostSensorCollector(
        command_runner=lambda command: '{"chip0": {"Adapter": "Virtual adapter"}}',
        clock=lambda: datetime(2026, 4, 14, 12, 30, tzinfo=UTC),
        host_identity_provider=lambda: {
            "hostname": "test-host",
            "fqdn": "test-host.local",
            "platform": "Linux",
        },
    )

    payload = collector.collect()

    assert payload["sensor_groups"] == []
    assert payload["status"] == {
        "code": "EMPTY",
        "message": "No sensor data detected from lm-sensors output",
        "last_updated": "2026-04-14T12:30:00Z",
    }


@pytest.mark.parametrize(
    ("error", "error_code", "message_fragment"),
    [
        (FileNotFoundError("No such file or directory: 'sensors'"), "LM_SENSORS_NOT_FOUND", "not available"),
        (
            CommandExecutionError("sensors command failed", exit_code=1, stderr="Permission denied"),
            "SENSORS_COMMAND_FAILED",
            "Permission denied",
        ),
    ],
)
def test_collector_returns_explicit_error_payload_for_command_failures(error, error_code, message_fragment):
    def raise_error(_command: list[str]) -> str:
        raise error

    collector = HostSensorCollector(
        command_runner=raise_error,
        clock=lambda: datetime(2026, 4, 14, 12, 30, tzinfo=UTC),
        host_identity_provider=lambda: {
            "hostname": "test-host",
            "fqdn": "test-host.local",
            "platform": "Linux",
        },
    )

    payload = collector.collect()

    assert payload["sensor_groups"] == []
    assert payload["status"]["code"] == "ERROR"
    assert message_fragment in payload["status"]["message"]
    assert payload["status"]["last_updated"] is None
    assert payload["error_details"]["error_code"] == error_code
