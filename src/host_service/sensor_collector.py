from __future__ import annotations

from collections.abc import Callable
from datetime import UTC, datetime
import json
import platform
import re
import socket
import subprocess
from typing import Any

from .system_telemetry_collector import SystemTelemetryCollector


CommandRunner = Callable[[list[str]], str]
Clock = Callable[[], datetime]
HostIdentityProvider = Callable[[], dict[str, str]]

_SUGGESTIONS: dict[str, str] = {
    "LM_SENSORS_NOT_FOUND": "Install lm-sensors package and run sensors-detect",
    "SENSORS_COMMAND_FAILED": "Verify the sensors command can run successfully on the host",
    "SENSORS_PARSE_ERROR": "Verify the installed lm-sensors version supports JSON output (-j)",
}


class CommandExecutionError(Exception):
    def __init__(self, message: str, exit_code: int, stderr: str = "") -> None:
        super().__init__(message)
        self.exit_code = exit_code
        self.stderr = stderr


class HostSensorCollector:
    def __init__(
        self,
        command_runner: CommandRunner | None = None,
        clock: Clock | None = None,
        host_identity_provider: HostIdentityProvider | None = None,
        system_telemetry_collector: SystemTelemetryCollector | None = None,
    ) -> None:
        self._command_runner = command_runner or run_sensors_command
        self._clock = clock or utc_now
        self._host_identity_provider = host_identity_provider or get_host_identity
        self._system_telemetry_collector = system_telemetry_collector or SystemTelemetryCollector(clock=self._clock)

    def collect(self) -> dict[str, Any]:
        timestamp = format_timestamp(self._clock())
        host_identity = self._host_identity_provider()
        warnings: list[dict[str, str]] = []

        # Always collect telemetry (non-fatal, additive to sensor data)
        telemetry = self._system_telemetry_collector.collect()

        # Check if GPU telemetry is available; emit non-fatal warning when absent
        gpu_unavailable = not telemetry.get("gpu_devices", [])

        has_telemetry = any(telemetry.get(key) is not None for key in ("cpu", "memory", "network")) or telemetry.get(
            "gpu_devices", []
        )

        # Collect sensors — always attempt, never short-circuit on failure
        sensor_groups: list[dict[str, Any]] = []
        try:
            raw_output = self._command_runner(["sensors", "-j"])
            sensor_groups = parse_sensors_json(raw_output)
        except FileNotFoundError:
            warnings.append(
                {
                    "source": "lm-sensors",
                    "code": "LM_SENSORS_NOT_FOUND",
                    "message": "lm-sensors command is not available on this host",
                }
            )
        except CommandExecutionError as error:
            error_message = error.stderr.strip() or str(error)
            warnings.append(
                {
                    "source": "lm-sensors",
                    "code": "SENSORS_COMMAND_FAILED",
                    "message": f"lm-sensors command failed: {error_message}",
                }
            )
        except (json.JSONDecodeError, TypeError, ValueError) as error:
            warnings.append(
                {
                    "source": "lm-sensors",
                    "code": "SENSORS_PARSE_ERROR",
                    "message": f"Unable to parse lm-sensors JSON output: {error}",
                }
            )

        has_sensors = bool(sensor_groups)

        # Determine status code with partial-success semantics
        if has_sensors or has_telemetry:
            status_code = "OK"
            if has_sensors and has_telemetry:
                status_message = "Sensor and telemetry data collected successfully"
            elif has_sensors:
                status_message = "Sensor data collected successfully"
            else:
                status_message = "System telemetry collected successfully while hardware sensor data is unavailable"
            last_updated = timestamp
            error_details: dict[str, str] | None = None

            if gpu_unavailable:
                warnings.append(
                    {
                        "source": "gpu",
                        "code": "GPU_TELEMETRY_UNAVAILABLE",
                        "message": "GPU telemetry is not available on this host (no NVIDIA driver detected)",
                    }
                )
        elif warnings:
            # Warnings but no usable data at all → ERROR
            primary = warnings[0]
            status_code = "ERROR"
            status_message = primary["message"]
            last_updated = None
            error_details = {
                "error_code": primary["code"],
                "suggestion": _SUGGESTIONS.get(
                    primary["code"],
                    "Check host configuration and try again",
                ),
            }
        else:
            status_code = "EMPTY"
            status_message = "No sensor data detected - lm-sensors may not be installed or configured"
            last_updated = timestamp
            error_details = None

        payload: dict[str, Any] = {
            "version": "1.1",
            "host_identity": host_identity,
            "timestamp": timestamp,
            "sensor_groups": sensor_groups,
            "status": {
                "code": status_code,
                "message": status_message,
                "last_updated": last_updated,
            },
            "units": {"temperature": "C"},
            "system_telemetry": telemetry,
            "collection_warnings": warnings,
        }

        if error_details is not None:
            payload["error_details"] = error_details

        return payload


def utc_now() -> datetime:
    return datetime.now(tz=UTC)


def format_timestamp(value: datetime) -> str:
    return value.astimezone(UTC).isoformat().replace("+00:00", "Z")


def get_host_identity() -> dict[str, str]:
    return {
        "hostname": socket.gethostname(),
        "fqdn": socket.getfqdn(),
        "platform": "Linux" if platform.system() == "Linux" else "Unknown",
    }


def run_sensors_command(command: list[str]) -> str:
    completed_process = subprocess.run(
        command,
        capture_output=True,
        check=False,
        text=True,
    )
    if completed_process.returncode != 0:
        raise CommandExecutionError(
            "sensors command failed",
            exit_code=completed_process.returncode,
            stderr=completed_process.stderr,
        )
    return completed_process.stdout


def parse_sensors_json(raw_output: str) -> list[dict[str, Any]]:
    if not raw_output.strip():
        return []

    parsed_output = json.loads(raw_output)
    if not isinstance(parsed_output, dict):
        raise ValueError("top-level lm-sensors payload must be an object")

    sensor_groups: list[dict[str, Any]] = []
    for chip_name, chip_payload in parsed_output.items():
        if not isinstance(chip_payload, dict):
            continue

        adapter = chip_payload.get("Adapter")
        sensors: list[dict[str, Any]] = []
        for raw_name, raw_sensor_payload in chip_payload.items():
            if raw_name == "Adapter" or not isinstance(raw_sensor_payload, dict):
                continue

            input_metrics = [
                (metric_name, metric_value)
                for metric_name, metric_value in raw_sensor_payload.items()
                if is_input_metric(metric_name) and isinstance(metric_value, int | float)
            ]

            for metric_name, metric_value in input_metrics:
                unit = infer_unit(metric_name)
                sensors.append(
                    {
                        "name": normalize_name(raw_name),
                        "raw_name": raw_name,
                        "value": float(metric_value),
                        "unit": unit,
                        "description": describe_sensor(raw_name, unit),
                    }
                )

        if sensors:
            sensor_groups.append(
                {
                    "name": chip_name,
                    "adapter": adapter if isinstance(adapter, str) and adapter else "Unknown adapter",
                    "sensors": sensors,
                }
            )

    return sensor_groups


def is_input_metric(metric_name: str) -> bool:
    return metric_name.endswith("_input")


def normalize_name(value: str) -> str:
    return re.sub(r"[^a-z0-9]+", "_", value.lower()).strip("_") or "sensor"


def infer_unit(metric_name: str) -> str:
    metric_prefix = metric_name.split("_", 1)[0].lower()
    if metric_prefix.startswith("temp"):
        return "°C"
    if metric_prefix.startswith("fan"):
        return "RPM"
    if metric_prefix.startswith("in"):
        return "V"
    return "unknown"


def describe_sensor(raw_name: str, unit: str) -> str:
    if unit == "°C":
        return f"{raw_name} temperature"
    if unit == "RPM":
        return f"{raw_name} fan speed"
    if unit == "V":
        return f"{raw_name} voltage"
    return raw_name
