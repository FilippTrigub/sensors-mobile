from __future__ import annotations

from datetime import UTC, datetime
from pathlib import Path
import sys

import pytest

sys.path.insert(0, str(Path(__file__).resolve().parents[2]))

from host_service.app import create_app
from host_service.sensor_collector import CommandExecutionError, HostSensorCollector, parse_sensors_json
from host_service.system_telemetry_collector import SystemTelemetryCollector

# ── Fixtures ──────────────────────────────────────────────────────

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

_STUB_TELEMETRY = {
    "cpu": {"usage_percent": 12.5},
    "memory": {"used_bytes": 4000000000, "total_bytes": 8000000000, "usage_percent": 50.0},
    "network": None,
    "gpu_devices": [
        {
            "id": "gpu-0",
            "name": "NVIDIA A100",
            "vendor": "NVIDIA",
            "utilization_percent": 45.0,
            "memory_used_bytes": 10737418240,
            "memory_total_bytes": 40265318400,
            "memory_usage_percent": 26.67,
        }
    ],
}

_EMPTY_TELEMETRY = {
    "cpu": None,
    "memory": None,
    "network": None,
    "gpu_devices": [],
}


class _StubTelemetryCollector(SystemTelemetryCollector):
    """Stub telemetry collector for testing — delegates collect() to injected data."""

    def __init__(self, data: dict | None = None) -> None:
        # Skip parent __init__ to avoid real /proc reads
        self._data = data if data is not None else _STUB_TELEMETRY

    def collect(self) -> dict:
        return self._data


# ── Tests ─────────────────────────────────────────────────────────


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
        system_telemetry_collector=_StubTelemetryCollector(_STUB_TELEMETRY),
    )

    payload = collector.collect()

    assert payload["version"] == "1.1"
    assert payload["host_identity"]["hostname"] == "test-host"
    assert payload["timestamp"] == "2026-04-14T12:30:00Z"
    assert payload["status"]["code"] == "OK"
    assert payload["status"]["message"] == "Sensor and telemetry data collected successfully"
    assert payload["status"]["last_updated"] == "2026-04-14T12:30:00Z"
    assert payload["units"] == {"temperature": "C"}
    assert len(payload["sensor_groups"]) == 2
    assert payload["system_telemetry"]["cpu"]["usage_percent"] == 12.5
    assert payload["collection_warnings"] == []


def test_sensors_endpoint_uses_configured_collector():
    class StubCollector:
        def collect(self) -> dict:
            return {
                "version": "1.1",
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


def test_collector_returns_ok_with_telemetry_when_sensors_fail():
    def raise_file_not_found(_command: list[str]) -> str:
        raise FileNotFoundError("sensors")

    collector = HostSensorCollector(
        command_runner=raise_file_not_found,
        clock=lambda: datetime(2026, 4, 14, 12, 30, tzinfo=UTC),
        host_identity_provider=lambda: {
            "hostname": "test-host",
            "fqdn": "test-host.local",
            "platform": "Linux",
        },
        system_telemetry_collector=_StubTelemetryCollector(_STUB_TELEMETRY),
    )

    payload = collector.collect()

    assert payload["version"] == "1.1"
    assert payload["sensor_groups"] == []
    assert payload["status"]["code"] == "OK"
    assert "telemetry" in payload["status"]["message"].lower()
    assert payload["status"]["last_updated"] == "2026-04-14T12:30:00Z"
    assert len(payload["collection_warnings"]) == 1
    assert payload["collection_warnings"][0]["code"] == "LM_SENSORS_NOT_FOUND"
    assert payload["system_telemetry"]["cpu"]["usage_percent"] == 12.5


def test_collector_returns_empty_when_no_sensors_and_no_telemetry():
    collector = HostSensorCollector(
        command_runner=lambda command: SENSORS_JSON_OUTPUT,
        clock=lambda: datetime(2026, 4, 14, 12, 30, tzinfo=UTC),
        host_identity_provider=lambda: {
            "hostname": "test-host",
            "fqdn": "test-host.local",
            "platform": "Linux",
        },
        system_telemetry_collector=_StubTelemetryCollector(_EMPTY_TELEMETRY),
    )

    payload = collector.collect()

    assert payload["version"] == "1.1"
    assert payload["status"]["code"] == "OK"
    assert payload["system_telemetry"]["cpu"] is None


def test_collector_returns_explicit_empty_status_when_sensors_empty_and_telemetry_none():
    collector = HostSensorCollector(
        command_runner=lambda command: '{"chip0": {"Adapter": "Virtual adapter"}}',
        clock=lambda: datetime(2026, 4, 14, 12, 30, tzinfo=UTC),
        host_identity_provider=lambda: {
            "hostname": "test-host",
            "fqdn": "test-host.local",
            "platform": "Linux",
        },
        system_telemetry_collector=_StubTelemetryCollector(_EMPTY_TELEMETRY),
    )

    payload = collector.collect()

    assert payload["sensor_groups"] == []
    assert payload["status"]["code"] == "EMPTY"
    assert "lm-sensors" in payload["status"]["message"].lower() or "no" in payload["status"]["message"].lower()
    assert payload["status"]["last_updated"] == "2026-04-14T12:30:00Z"
    assert "error_details" not in payload


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
        system_telemetry_collector=_StubTelemetryCollector(_EMPTY_TELEMETRY),
    )

    payload = collector.collect()

    assert payload["sensor_groups"] == []
    assert payload["status"]["code"] == "ERROR"
    assert message_fragment in payload["status"]["message"]
    assert payload["status"]["last_updated"] is None
    assert payload["error_details"]["error_code"] == error_code


def _empty_gpu_telemetry() -> dict:
    return {
        "cpu": {"usage_percent": 22.0},
        "memory": {"used_bytes": 5000000000, "total_bytes": 8000000000, "usage_percent": 62.5},
        "network": None,
        "gpu_devices": [],
    }


def test_collector_emits_gpu_warning_when_no_gpu_devices():
    collector = HostSensorCollector(
        command_runner=lambda command: SENSORS_JSON_OUTPUT,
        clock=lambda: datetime(2026, 4, 14, 12, 30, tzinfo=UTC),
        host_identity_provider=lambda: {
            "hostname": "test-host",
            "fqdn": "test-host.local",
            "platform": "Linux",
        },
        system_telemetry_collector=_StubTelemetryCollector(_empty_gpu_telemetry()),
    )

    payload = collector.collect()

    assert payload["status"]["code"] == "OK"
    assert len(payload["collection_warnings"]) == 1
    warning = payload["collection_warnings"][0]
    assert warning["source"] == "gpu"
    assert warning["code"] == "GPU_TELEMETRY_UNAVAILABLE"
    assert "no nvidia driver" in warning["message"].lower()
