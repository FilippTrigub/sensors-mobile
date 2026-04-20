"""Tests for system_telemetry_collector."""

from __future__ import annotations

from datetime import UTC, datetime
from pathlib import Path
import subprocess
from unittest.mock import patch

import pytest

# Path setup matching existing test patterns
TEST_DIR = Path(__file__).resolve().parent
SRC_DIR = TEST_DIR.parents[1]
import sys

sys.path.insert(0, str(SRC_DIR))

from host_service.system_telemetry_collector import (
    CpuTelemetry,
    GpuDeviceTelemetry,
    MemoryTelemetry,
    NetworkTelemetry,
    SystemTelemetryCollector,
)


CPU_LINE_SAMPLE = "cpu  1234 56 789 4567 901 23 45 0 0 0"

MEMINFO_SNAPSHOT = """MemTotal:       8053708 kB
MemFree:          524288 kB
MemAvailable:    4026854 kB
Buffers:          256000 kB
Cached:           1500000 kB
SwapCached:            0 kB
"""

NETDEV_SNAPSHOT = (
    "Inter-Receive                                    Transmit\n"
    " face |bytes    packets errs drop fifo frame compressed multicast|bytes    packets errs drop fifo colls carrier compressed\n"
    "   lo:    1234     123    0    0    0     0          0         0     1234     123    0    0    0     0       0          0\n"
    " eth0:  987654    1234    0    0    0     0          0         0   987654    1234    0    0    0     0       0          0\n"
    "  wln0:  456789    567    0    0    0     0          0         0   123456    567    0    0    0     0       0          0\n"
)

NVIDIA_SMI_TWO_GPUS = """2026/04/20 10:00:00.000, GPU-bbbb, RTX B, 75, 2000, 8000
2026/04/20 10:00:00.000, GPU-aaaa, RTX A, 25, 1000, 4000
"""


def test_cpu_normal_delta():
    sample1_count = 0

    def cpu_reader():
        nonlocal sample1_count
        sample1_count += 1
        if sample1_count == 1:
            return CPU_LINE_SAMPLE
        # First: idle=901+23=924, total=1234+56+789+4567+901+23+45=7615
        # Second: idle=931+53=984, total=1234+56+789+4567+931+53+45=7675
        # delta_idle=60, delta_total=60 => idle=100%, usage=0%
        return "cpu  1234 56 789 4567 931 53 45 0 0 0"

    collector = SystemTelemetryCollector(
        clock=lambda: datetime(2026, 4, 14, 12, 0, 0, tzinfo=UTC),
        proc_stat_reader=cpu_reader,
    )

    with patch("time.sleep"):
        result = collector.collect()

    cpu = result["cpu"]
    assert cpu is not None
    assert 0 <= cpu["usage_percent"] <= 100


def test_cpu_nonzero_usage():
    sample1_count = 0

    def cpu_reader():
        nonlocal sample1_count
        sample1_count += 1
        if sample1_count == 1:
            return "cpu  1000 100 100 800 50 0 50 0 0 0"
        # First: idle=50+0=50, total=1000+100+100+800+50+0+50=2100
        # Second: idle=51+1=52, total=1050+100+100+800+51+1+50=2152
        # delta_idle=2, delta_total=52 => idle=2/52=3.8%, usage=96.2%
        return "cpu  1050 100 100 800 51 1 50 0 0 0"

    collector = SystemTelemetryCollector(proc_stat_reader=cpu_reader)

    with patch("time.sleep"):
        result = collector.collect()

    cpu = result["cpu"]
    assert cpu is not None
    assert cpu["usage_percent"] == pytest.approx(96.15, abs=0.1)


def test_cpu_invalid_window_zero_delta():
    def cpu_reader():
        return CPU_LINE_SAMPLE

    collector = SystemTelemetryCollector(
        proc_stat_reader=cpu_reader,
    )

    with patch("time.sleep"):
        result = collector.collect()

    assert result["cpu"] is None


def test_cpu_invalid_line_format():
    def cpu_reader():
        return "bogus line"

    collector = SystemTelemetryCollector(proc_stat_reader=cpu_reader)

    with patch("time.sleep"):
        result = collector.collect()

    assert result["cpu"] is None


def test_memory_normal_case():
    collector = SystemTelemetryCollector(
        clock=lambda: datetime(2026, 4, 14, 12, 0, 0, tzinfo=UTC),
        proc_meminfo_reader=lambda: MEMINFO_SNAPSHOT,
    )

    result = collector.collect()
    mem = result["memory"]

    assert mem is not None
    assert mem["total_bytes"] == 8053708 * 1024
    assert mem["used_bytes"] == (8053708 - 4026854) * 1024
    assert mem["usage_percent"] == pytest.approx(50.0, abs=0.1)


def test_memory_missing_mem_available():
    bad_meminfo = """MemTotal:       8053708 kB
MemFree:          524288 kB
"""
    collector = SystemTelemetryCollector(
        proc_meminfo_reader=lambda: bad_meminfo,
    )

    result = collector.collect()
    assert result["memory"] is None


def test_network_normal_two_interfaces():
    call_count = 0

    def netdev_reader():
        nonlocal call_count
        call_count += 1
        if call_count == 1:
            return NETDEV_SNAPSHOT
        # eth0: rx 987654 -> 1987654 (+1000000), tx 987654 -> 1987654 (+1000000)
        # wln0: rx 456789 -> 656789 (+200000), tx 123456 -> 223456 (+100000)
        return (
            "Inter-Receive                                    Transmit\n"
            " face |bytes    packets errs drop fifo frame compressed multicast|bytes    packets errs drop fifo colls carrier compressed\n"
            "   lo:    2234     223    0    0    0     0          0         0     2234     223    0    0    0     0       0          0\n"
            " eth0: 1987654    2234    0    0    0     0          0         0  1987654    2234    0    0    0     0       0          0\n"
            "  wln0: 656789    667    0    0    0     0          0         0   223456    667    0    0    0     0       0          0\n"
        )

    collector = SystemTelemetryCollector(
        proc_net_dev_reader=netdev_reader,
    )

    with patch("time.sleep"):
        result = collector.collect()

    net = result["network"]
    assert net is not None
    assert "lo" not in net["interfaces"]
    assert net["rx_bytes_per_sec"] == 1200000  # eth0: 1M + wln0: 200K
    assert net["tx_bytes_per_sec"] == 1100000  # eth0: 1M + wln0: 100K
    assert net["sample_window_seconds"] == 1.0
    assert sorted(net["interfaces"]) == ["eth0", "wln0"]


def test_network_counter_wrap():
    call_count = 0

    def netdev_reader():
        nonlocal call_count
        call_count += 1
        if call_count == 1:
            return NETDEV_SNAPSHOT
        # eth0 rx decreased (counter wrap): 987654 -> 500000
        # eth0 tx increased: 987654 -> 2000000 (+1012346)
        # wln0 rx increased: 456789 -> 656789 (+200000), tx +100000
        return (
            "Inter-Receive                                    Transmit\n"
            " face |bytes    packets errs drop fifo frame compressed multicast|bytes    packets errs drop fifo colls carrier compressed\n"
            "   lo:    1234     123    0    0    0     0          0         0     1234     123    0    0    0     0       0          0\n"
            " eth0:  500000    1234    0    0    0     0          0         0  2000000    1234    0    0    0     0       0          0\n"
            "  wln0: 656789    567    0    0    0     0          0         0   223456    567    0    0    0     0       0          0\n"
        )

    collector = SystemTelemetryCollector(proc_net_dev_reader=netdev_reader)

    with patch("time.sleep"):
        result = collector.collect()

    net = result["network"]
    assert net is not None
    # eth0 rx decreased -> 0, eth0 tx = 1012346, wln0 rx=200000, tx=100000
    assert net["rx_bytes_per_sec"] == 200000  # only wln0's rx (eth0 wrap = 0)
    # eth0 tx delta = 2000000 - 987654 = 1012346, wln0 tx delta = 100000 => total 1112346
    assert net["tx_bytes_per_sec"] == 1112346


def test_network_all_loopback_returns_none():
    loopback_only = (
        "Inter-Receive                                    Transmit\n"
        " face |bytes    packets errs drop fifo frame compressed multicast|bytes    packets errs drop fifo colls carrier compressed\n"
        "   lo:    1234     123    0    0    0     0          0         0     1234     123    0    0    0     0       0          0\n"
    )
    collector = SystemTelemetryCollector(
        proc_net_dev_reader=lambda: loopback_only,
    )

    with patch("time.sleep"):
        result = collector.collect()

    assert result["network"] is None


def test_network_no_interfaces_returns_none():
    collector = SystemTelemetryCollector(
        proc_net_dev_reader=lambda: "",
    )

    with patch("time.sleep"):
        result = collector.collect()

    assert result["network"] is None


def test_gpu_collects_nvidia_devices_sorted_by_id():
    collector = SystemTelemetryCollector(
        nvidia_smi_runner=lambda: NVIDIA_SMI_TWO_GPUS,
    )

    result = collector.collect()

    assert result["gpu_devices"] == [
        {
            "id": "GPU-aaaa",
            "name": "RTX A",
            "vendor": "NVIDIA",
            "utilization_percent": 25.0,
            "memory_used_bytes": 1000 * 1024 * 1024,
            "memory_total_bytes": 4000 * 1024 * 1024,
            "memory_usage_percent": 25.0,
        },
        {
            "id": "GPU-bbbb",
            "name": "RTX B",
            "vendor": "NVIDIA",
            "utilization_percent": 75.0,
            "memory_used_bytes": 2000 * 1024 * 1024,
            "memory_total_bytes": 8000 * 1024 * 1024,
            "memory_usage_percent": 25.0,
        },
    ]


def test_gpu_blank_and_unknown_values_become_none():
    collector = SystemTelemetryCollector(
        nvidia_smi_runner=lambda: "2026/04/20 10:00:00.000, GPU-aaaa, RTX A, --, , --\n",
    )

    result = collector.collect()

    assert result["gpu_devices"] == [
        {
            "id": "GPU-aaaa",
            "name": "RTX A",
            "vendor": "NVIDIA",
            "utilization_percent": None,
            "memory_used_bytes": None,
            "memory_total_bytes": None,
            "memory_usage_percent": None,
        }
    ]


def test_gpu_availability_failure_returns_empty_list_without_breaking_other_telemetry():
    sample1_count = 0

    def cpu_reader():
        nonlocal sample1_count
        sample1_count += 1
        if sample1_count == 1:
            return CPU_LINE_SAMPLE
        return "cpu  1234 56 789 4567 931 53 45 0 0 0"

    collector = SystemTelemetryCollector(
        proc_stat_reader=cpu_reader,
        proc_meminfo_reader=lambda: MEMINFO_SNAPSHOT,
        nvidia_smi_runner=lambda: (_ for _ in ()).throw(FileNotFoundError("nvidia-smi")),
    )

    with patch("time.sleep"):
        result = collector.collect()

    assert result["cpu"] is not None
    assert result["memory"] is not None
    assert result["gpu_devices"] == []


def test_gpu_runtime_availability_error_returns_empty_list():
    def nvidia_smi_runner():
        raise subprocess.CalledProcessError(
            1,
            ["nvidia-smi"],
            output="NVIDIA-SMI has failed because it couldn't communicate with the NVIDIA driver.",
        )

    collector = SystemTelemetryCollector(nvidia_smi_runner=nvidia_smi_runner)

    result = collector.collect()

    assert result["gpu_devices"] == []


def test_collect_returns_all_keys():
    collector = SystemTelemetryCollector(
        proc_stat_reader=lambda: "cpu  0 0 0 0 0 0 0 0 0 0",
        proc_meminfo_reader=lambda: "",
        proc_net_dev_reader=lambda: "",
        nvidia_smi_runner=lambda: "",
    )

    with patch("time.sleep"):
        result = collector.collect()

    assert set(result.keys()) == {"cpu", "memory", "network", "gpu_devices"}
    assert result["gpu_devices"] == []


def test_dataclass_immutability():
    cpu = CpuTelemetry(usage_percent=50.0)
    with pytest.raises(Exception):
        setattr(cpu, "usage_percent", 0)

    mem = MemoryTelemetry(used_bytes=100, total_bytes=200, usage_percent=50.0)
    with pytest.raises(Exception):
        setattr(mem, "used_bytes", 0)

    net = NetworkTelemetry(
        rx_bytes_per_sec=100,
        tx_bytes_per_sec=50,
        total_rx_bytes=1000,
        total_tx_bytes=500,
        sample_window_seconds=1.0,
        interfaces=["eth0"],
    )
    with pytest.raises(Exception):
        setattr(net, "rx_bytes_per_sec", 0)

    gpu = GpuDeviceTelemetry(
        id="GPU-1",
        name="RTX",
        vendor="NVIDIA",
        utilization_percent=50.0,
        memory_used_bytes=1024,
        memory_total_bytes=2048,
        memory_usage_percent=50.0,
    )
    with pytest.raises(Exception):
        setattr(gpu, "vendor", "AMD")
