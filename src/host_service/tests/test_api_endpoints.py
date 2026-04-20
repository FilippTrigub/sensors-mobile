"""
Endpoint tests for the sensor API.

TDD approach: tests written first to define explicit HTTP behavior.
Focus: HTTP status codes, JSON error responses, contract compliance.
"""

from __future__ import annotations

from datetime import UTC, datetime
from pathlib import Path
import sys

import pytest

sys.path.insert(0, str(Path(__file__).resolve().parents[2]))

from host_service.app import create_app
from host_service.sensor_collector import HostSensorCollector
from host_service.fixtures_loader import FixtureType, load_fixture


class TestSensorEndpoint:
    """Test suite for /api/v1/sensors endpoint behavior."""

    @pytest.fixture
    def app_with_stub_collector(self):
        """Create Flask app with a testable collector."""
        app = create_app()
        app.config["SENSOR_COLLECTOR"] = _make_stub_collector()
        return app

    @pytest.fixture
    def app_with_telemetry_only_collector(self):
        """Flask app where sensors fail but telemetry is available."""
        app = create_app()

        class TelemetryOnlyCollector:
            def collect(self) -> dict:
                payload = load_fixture(FixtureType.TELEMETRY_ONLY)
                return payload

        app.config["SENSOR_COLLECTOR"] = TelemetryOnlyCollector()
        return app

    @pytest.fixture
    def app_with_error_collector(self):
        """Create Flask app with a collector that raises errors."""
        app = create_app()

        class ErrorCollector:
            def collect(self) -> dict:
                raise Exception("Unexpected error in collector")

        app.config["SENSOR_COLLECTOR"] = ErrorCollector()
        return app

    @pytest.fixture
    def app_with_fixture_success(self):
        """Create Flask app with fixture-backed success response."""
        app = create_app()

        class FixtureSuccessCollector:
            def collect(self) -> dict:
                return load_fixture(FixtureType.SUCCESS)

        app.config["SENSOR_COLLECTOR"] = FixtureSuccessCollector()
        return app

    @pytest.fixture
    def app_with_fixture_empty(self):
        """Create Flask app with fixture-backed empty response."""
        app = create_app()

        class FixtureEmptyCollector:
            def collect(self) -> dict:
                return load_fixture(FixtureType.EMPTY)

        app.config["SENSOR_COLLECTOR"] = FixtureEmptyCollector()
        return app

    @pytest.fixture
    def app_with_fixture_error(self):
        """Create Flask app with fixture-backed error response."""
        app = create_app()

        class FixtureErrorCollector:
            def collect(self) -> dict:
                return load_fixture(FixtureType.ERROR)

        app.config["SENSOR_COLLECTOR"] = FixtureErrorCollector()
        return app

    def test_endpoint_returns_json_content_type(self, app_with_stub_collector):
        """Test 1: Endpoint returns application/json content type."""
        response = app_with_stub_collector.test_client().get("/api/v1/sensors")
        assert response.content_type == "application/json"

    def test_success_endpoint_returns_200(self, app_with_stub_collector):
        """Test 2: Successful collection returns HTTP 200."""
        response = app_with_stub_collector.test_client().get("/api/v1/sensors")
        assert response.status_code == 200

    def test_telemetry_only_partial_success_returns_200_with_ok_status(self, app_with_telemetry_only_collector):
        """Test 2b: Telemetry-only (sensors failed, telemetry ok) returns HTTP 200 with OK."""
        response = app_with_telemetry_only_collector.test_client().get("/api/v1/sensors")
        assert response.status_code == 200

        data = response.get_json()
        assert data["status"]["code"] == "OK"
        assert data["sensor_groups"] == []
        assert "system_telemetry" in data
        assert data["system_telemetry"]["cpu"] is not None
        assert len(data["collection_warnings"]) >= 1
        assert "source" in data["collection_warnings"][0]
        assert data["version"] in {"1.0", "1.1"}

    def test_success_endpoint_returns_contract_compliant_payload(self, app_with_fixture_success):
        """Test 3: Success response is contract-compliant JSON."""
        response = app_with_fixture_success.test_client().get("/api/v1/sensors")
        data = response.get_json()

        assert data is not None
        assert data["version"] in {"1.0", "1.1"}
        assert "host_identity" in data
        assert "timestamp" in data
        assert "sensor_groups" in data
        assert "status" in data
        assert data["status"]["code"] == "OK"

    def test_empty_status_returns_200_with_empty_payload(self, app_with_fixture_empty):
        """Test 4: Empty sensor data returns HTTP 200 (not 404) with EMPTY status."""
        response = app_with_fixture_empty.test_client().get("/api/v1/sensors")
        assert response.status_code == 200

        data = response.get_json()
        assert data["sensor_groups"] == []
        assert data["status"]["code"] == "EMPTY"

    def test_error_status_returns_200_with_error_payload(self, app_with_fixture_error):
        """Test 5: Error in collector returns HTTP 200 with ERROR status (contractual)."""
        response = app_with_fixture_error.test_client().get("/api/v1/sensors")
        assert response.status_code == 200

        data = response.get_json()
        assert data["status"]["code"] == "ERROR"
        assert "error_details" in data
        assert "error_code" in data["error_details"]

    def test_collector_exception_returns_500_with_json_error(self, app_with_error_collector):
        """Test 6: Unexpected collector exception returns HTTP 500 with JSON error."""
        response = app_with_error_collector.test_client().get("/api/v1/sensors")
        assert response.status_code == 500

        data = response.get_json()
        assert data is not None
        assert "error" in data
        assert data["error"]["type"] == "InternalError"
        assert "message" in data["error"]

    def test_unexpected_exception_does_not_return_html(self, app_with_error_collector):
        """Test 7: Error responses are JSON, not HTML debug pages."""
        response = app_with_error_collector.test_client().get("/api/v1/sensors")
        assert response.status_code == 500
        assert "text/html" not in response.content_type
        assert "application/json" in response.content_type


def _make_stub_collector() -> StubCollector:
    return StubCollector()


class StubCollector:
    """Stub collector for testing."""

    def __init__(self) -> None:
        self._data: dict = {
            "version": "1.1",
            "host_identity": {
                "hostname": "stubbed-host",
                "fqdn": "stubbed-host.local",
                "platform": "Linux",
            },
            "timestamp": "2026-04-14T12:30:00Z",
            "sensor_groups": [
                {
                    "name": "test-group",
                    "adapter": "test adapter",
                    "sensors": [
                        {
                            "name": "temp1",
                            "raw_name": "temp1_input",
                            "value": 42.0,
                            "unit": "°C",
                            "description": "Test sensor",
                        }
                    ],
                }
            ],
            "status": {
                "code": "OK",
                "message": "Test successful",
                "last_updated": "2026-04-14T12:30:00Z",
            },
            "system_telemetry": {
                "cpu": {"usage_percent": 10.0},
                "memory": {
                    "used_bytes": 4000000000,
                    "total_bytes": 8000000000,
                    "usage_percent": 50.0,
                },
                "network": None,
                "gpu_devices": [],
            },
            "collection_warnings": [],
            "units": {"temperature": "C"},
        }

    def collect(self) -> dict:
        return self._data
