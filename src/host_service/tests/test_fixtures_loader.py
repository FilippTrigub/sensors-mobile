from __future__ import annotations

from pathlib import Path
import sys

sys.path.insert(0, str(Path(__file__).resolve().parents[2]))

from host_service.fixtures_loader import FixtureType, load_fixture


def test_loads_telemetry_only_fixture() -> None:
    fixture = load_fixture(FixtureType.TELEMETRY_ONLY)

    assert fixture["version"] == "1.1"
    assert fixture["sensor_groups"] == []
    assert fixture["status"]["code"] == "OK"
    assert "system_telemetry" in fixture
    assert "collection_warnings" in fixture
