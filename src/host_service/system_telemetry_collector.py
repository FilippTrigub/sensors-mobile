"""System telemetry collector for Linux host services.

Collects CPU, memory, network, and optional NVIDIA GPU telemetry via
injected callables so that production code reads real procfs/sysfs
paths and tests can inject stub data.
"""

from __future__ import annotations

import csv
from collections.abc import Callable
from dataclasses import dataclass
from datetime import UTC, datetime
import subprocess
import time
from typing import Any


@dataclass(frozen=True)
class CpuTelemetry:
    """CPU utilization sampled over a 1-second window."""

    usage_percent: float


@dataclass(frozen=True)
class MemoryTelemetry:
    """Memory usage parsed from /proc/meminfo."""

    used_bytes: int
    total_bytes: int
    usage_percent: float


@dataclass(frozen=True)
class NetworkTelemetry:
    """Network byte-rate sampled over a 1-second window."""

    rx_bytes_per_sec: float
    tx_bytes_per_sec: float
    total_rx_bytes: int
    total_tx_bytes: int
    sample_window_seconds: float
    interfaces: list[str]


@dataclass(frozen=True)
class GpuDeviceTelemetry:
    id: str
    name: str
    vendor: str
    utilization_percent: float | None
    memory_used_bytes: int | None
    memory_total_bytes: int | None
    memory_usage_percent: float | None


Clock = Callable[[], datetime]
ProcStatReader = Callable[[], str]
ProcMeminfoReader = Callable[[], str]
ProcNetDevReader = Callable[[], str]
SysNetOperstateReader = Callable[[str], str | None]
NvidiaSmiRunner = Callable[[], str]


class SystemTelemetryCollector:
    """Collects system-level telemetry (CPU, memory, network, GPU).

    All I/O dependencies are injected callables so production can use
    real procfs/sysfs reads and tests can inject deterministic data.
    """

    def __init__(
        self,
        clock: Clock | None = None,
        proc_stat_reader: ProcStatReader | None = None,
        proc_meminfo_reader: ProcMeminfoReader | None = None,
        proc_net_dev_reader: ProcNetDevReader | None = None,
        sys_net_operstate_reader: SysNetOperstateReader | None = None,
        nvidia_smi_runner: NvidiaSmiRunner | None = None,
    ) -> None:
        self._clock = clock or (lambda: datetime.now(tz=UTC))
        self._proc_stat_reader = proc_stat_reader or _default_read_proc_stat
        self._proc_meminfo_reader = proc_meminfo_reader or _default_read_proc_meminfo
        self._proc_net_dev_reader = proc_net_dev_reader or _default_read_proc_net_dev
        self._sys_net_operstate_reader = sys_net_operstate_reader or _default_read_sys_net_operstate
        self._nvidia_smi_runner = nvidia_smi_runner or _default_run_nvidia_smi

    def collect(self) -> dict[str, Any]:
        """Collect all available telemetry slices.

        Returns a dict with keys ``cpu``, ``memory``, ``network``, and
        ``gpu_devices``.
        Individual sections that could not be collected are ``None``.
        """
        result: dict[str, Any] = {
            "cpu": None,
            "memory": None,
            "network": None,
            "gpu_devices": [],
        }

        cpu = self._collect_cpu()
        if cpu is not None:
            result["cpu"] = {"usage_percent": cpu.usage_percent}

        memory = self._collect_memory()
        if memory is not None:
            result["memory"] = {
                "used_bytes": memory.used_bytes,
                "total_bytes": memory.total_bytes,
                "usage_percent": memory.usage_percent,
            }

        network = self._collect_network()
        if network is not None:
            result["network"] = {
                "rx_bytes_per_sec": network.rx_bytes_per_sec,
                "tx_bytes_per_sec": network.tx_bytes_per_sec,
                "total_rx_bytes": network.total_rx_bytes,
                "total_tx_bytes": network.total_tx_bytes,
                "sample_window_seconds": network.sample_window_seconds,
                "interfaces": network.interfaces,
            }

        result["gpu_devices"] = [
            {
                "id": device.id,
                "name": device.name,
                "vendor": device.vendor,
                "utilization_percent": device.utilization_percent,
                "memory_used_bytes": device.memory_used_bytes,
                "memory_total_bytes": device.memory_total_bytes,
                "memory_usage_percent": device.memory_usage_percent,
            }
            for device in self._collect_gpu()
        ]

        return result

    def _collect_cpu(self) -> CpuTelemetry | None:
        try:
            line1_str = self._proc_stat_reader()
            sample1 = self._parse_cpu_line(line1_str)
            if sample1 is None:
                return None
        except (IndexError, ValueError, TypeError):
            return None

        time.sleep(1.0)

        try:
            line2_str = self._proc_stat_reader()
            sample2 = self._parse_cpu_line(line2_str)
            if sample2 is None:
                return None
        except (IndexError, ValueError, TypeError):
            return None

        delta_idle = sample2[0] - sample1[0]
        delta_total = sample2[1] - sample1[1]

        if delta_total <= 0:
            return None

        usage_percent = 100.0 * (delta_total - delta_idle) / delta_total
        return CpuTelemetry(usage_percent=round(usage_percent, 2))

    @staticmethod
    def _parse_cpu_line(line: str) -> tuple[int, int] | None:
        """Return ``(idle, total)`` from a cpu aggregate line.

        idle = idle + iowait, total = sum of all CPU fields.
        """
        parts = line.strip().split()
        if not parts or parts[0] != "cpu":
            return None
        fields = parts[1:]
        idle = int(fields[4]) + int(fields[5])  # idle + iowait
        total = sum(int(f) for f in fields)
        return (idle, total)

    def _collect_memory(self) -> MemoryTelemetry | None:
        try:
            raw = self._proc_meminfo_reader()
            values = self._parse_meminfo(raw)
        except (ValueError, TypeError):
            return None

        if "MemAvailable" not in values or "MemTotal" not in values:
            return None

        total_bytes = values["MemTotal"] * 1024
        used_bytes = (values["MemTotal"] - values["MemAvailable"]) * 1024
        usage_percent = (used_bytes / total_bytes * 100) if total_bytes > 0 else 0.0
        return MemoryTelemetry(
            used_bytes=used_bytes,
            total_bytes=total_bytes,
            usage_percent=round(usage_percent, 2),
        )

    @staticmethod
    def _parse_meminfo(raw: str) -> dict[str, int]:
        """Return ``{key: value_in_kB}`` from /proc/meminfo text."""
        values: dict[str, int] = {}
        for line in raw.splitlines():
            parts = line.split(":")
            if len(parts) == 2:
                key = parts[0].strip()
                value_str = parts[1].strip().split()[0]
                values[key] = int(value_str)
        return values

    def _collect_network(self) -> NetworkTelemetry | None:
        try:
            raw1 = self._proc_net_dev_reader()
            counters1 = self._parse_net_dev(raw1)
            if not counters1:
                return None
        except (ValueError, TypeError):
            return None

        # Exclude loopback from active interfaces
        active_ifaces = self._get_active_interfaces([name for name in counters1.keys() if name != "lo"])

        time.sleep(1.0)

        try:
            raw2 = self._proc_net_dev_reader()
            counters2 = self._parse_net_dev(raw2)
            if not counters2:
                return None
        except (ValueError, TypeError):
            return None

        return self._compute_rates(counters1, counters2, active_ifaces)

    def _collect_gpu(self) -> list[GpuDeviceTelemetry]:
        try:
            raw = self._nvidia_smi_runner()
        except Exception as exc:
            if _is_nvidia_smi_availability_error(exc):
                return []
            return []

        try:
            devices = self._parse_nvidia_smi_csv(raw)
        except (csv.Error, TypeError, ValueError):
            return []

        return sorted(devices, key=lambda device: device.id)

    @staticmethod
    def _parse_nvidia_smi_csv(raw: str) -> list[GpuDeviceTelemetry]:
        devices: list[GpuDeviceTelemetry] = []

        for row in csv.reader(raw.splitlines()):
            if not row:
                continue
            if len(row) != 6:
                raise ValueError("Unexpected nvidia-smi row shape")

            _timestamp, uuid, name, utilization, memory_used, memory_total = (value.strip() for value in row)
            if not uuid or not name:
                continue

            memory_used_bytes = _mib_to_bytes(memory_used)
            memory_total_bytes = _mib_to_bytes(memory_total)
            devices.append(
                GpuDeviceTelemetry(
                    id=uuid,
                    name=name,
                    vendor="NVIDIA",
                    utilization_percent=_parse_nullable_float(utilization),
                    memory_used_bytes=memory_used_bytes,
                    memory_total_bytes=memory_total_bytes,
                    memory_usage_percent=_compute_percent(memory_used_bytes, memory_total_bytes),
                )
            )

        return devices

    def _get_active_interfaces(self, iface_names: list[str]) -> set[str]:
        """Return set of interface names that have an active-ish operstate."""
        if self._sys_net_operstate_reader is None:
            return set(iface_names)

        active: set[str] = set()
        for name in iface_names:
            try:
                state_path = f"/sys/class/net/{name}/operstate"
                state = self._sys_net_operstate_reader(state_path)
            except (OSError, IOError):
                state = None

            if state is None:
                active.add(name)
            elif state.lower() in ("up", "lower_layer_up", "unknown"):
                active.add(name)
        return active

    @staticmethod
    def _parse_net_dev(raw: str) -> dict[str, tuple[int, int]]:
        """Return ``{iface_name: (rx_bytes, tx_bytes)}`` from /proc/net/dev."""
        counters: dict[str, tuple[int, int]] = {}
        lines = raw.splitlines()

        # First two lines are headers, skip them
        for line in lines[2:]:
            line = line.strip()
            if not line:
                continue
            parts = line.split(":")
            if len(parts) != 2:
                continue
            iface = parts[0].strip()
            fields = parts[1].split()
            if len(fields) < 16:
                continue
            rx_bytes = int(fields[0])
            tx_bytes = int(fields[8])
            counters[iface] = (rx_bytes, tx_bytes)

        return counters

    @staticmethod
    def _compute_rates(
        counters1: dict[str, tuple[int, int]],
        counters2: dict[str, tuple[int, int]],
        active_ifaces: set[str],
    ) -> NetworkTelemetry | None:
        """Compute per-second byte rates from two snapshots.

        Returns ``None`` only when there are no active interfaces at all.
        Zero-traffic interfaces are still valid and produce ``0`` rates.
        """
        total_rx = 0
        total_tx = 0
        all_ifaces: list[str] = []

        for iface in sorted(active_ifaces):
            if iface not in counters1 or iface not in counters2:
                continue
            rx1, tx1 = counters1[iface]
            rx2, tx2 = counters2[iface]

            delta_rx = rx2 - rx1
            delta_tx = tx2 - tx1

            if delta_rx < 0:
                delta_rx = 0
            if delta_tx < 0:
                delta_tx = 0

            if delta_rx > 0 or delta_tx > 0:
                total_rx += delta_rx
                total_tx += delta_tx

            all_ifaces.append(iface)

        if not all_ifaces:
            return None

        rx_per_sec = float(total_rx)
        tx_per_sec = float(total_tx)
        return NetworkTelemetry(
            rx_bytes_per_sec=rx_per_sec,
            tx_bytes_per_sec=tx_per_sec,
            total_rx_bytes=total_rx,
            total_tx_bytes=total_tx,
            sample_window_seconds=1.0,
            interfaces=all_ifaces,
        )


# ── Default I/O functions (production) ──────────────────────────


def _default_read_proc_stat() -> str:
    with open("/proc/stat", "r") as f:
        for line in f:
            if line.startswith("cpu "):
                return line
    raise OSError("/proc/stat does not contain a cpu aggregate line")


def _default_read_proc_meminfo() -> str:
    with open("/proc/meminfo", "r") as f:
        return f.read()


def _default_read_proc_net_dev() -> str:
    with open("/proc/net/dev", "r") as f:
        return f.read()


def _default_read_sys_net_operstate(path: str) -> str | None:
    try:
        with open(path, "r") as f:
            return f.read().strip() or None
    except (OSError, IOError):
        return None


def _default_run_nvidia_smi() -> str:
    return subprocess.check_output(
        [
            "nvidia-smi",
            "--query-gpu=timestamp,uuid,name,utilization.gpu,memory.used,memory.total",
            "--format=csv,noheader,nounits",
        ],
        text=True,
        stderr=subprocess.STDOUT,
    )


def _parse_nullable_float(value: str) -> float | None:
    if value in ("", "--", "N/A", "[N/A]", "Unknown", "unknown"):
        return None
    return float(value)


def _mib_to_bytes(value: str) -> int | None:
    amount = _parse_nullable_float(value)
    if amount is None:
        return None
    return int(amount * 1024 * 1024)


def _compute_percent(used: int | None, total: int | None) -> float | None:
    if used is None or total is None or total <= 0:
        return None
    return round((used / total) * 100, 2)


def _is_nvidia_smi_availability_error(exc: Exception) -> bool:
    if isinstance(exc, FileNotFoundError):
        return True

    if isinstance(exc, subprocess.CalledProcessError):
        output = exc.output or ""
        lowered_output = output.lower()
        known_markers = (
            "couldn't communicate with the nvidia driver",
            "no devices were found",
            "driver/library version mismatch",
            "has failed because it couldn't communicate with the nvidia driver",
        )
        return any(marker in lowered_output for marker in known_markers)

    return False
