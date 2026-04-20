"""
Contract validation tests for the sensor API schema.
TDD approach: tests written before implementation.
"""

from copy import deepcopy
import json
from pathlib import Path
from typing import Any

import jsonschema
import pytest

# Paths - relative to test file location
TEST_DIR = Path(__file__).parent.resolve()
HOST_SERVICE_DIR = TEST_DIR.parent  # parent of tests/
FIXTURES_DIR = HOST_SERVICE_DIR / "fixtures"
CONTRACT_PATH = HOST_SERVICE_DIR / "sensors_contract.json"


@pytest.fixture
def contract_schema() -> dict[str, Any]:
    """Load the JSON contract schema."""
    with open(CONTRACT_PATH, "r") as f:
        return json.load(f)


@pytest.fixture
def success_fixture() -> dict[str, Any]:
    """Load the success fixture."""
    with open(FIXTURES_DIR / "success_fixture.json", "r") as f:
        return json.load(f)


@pytest.fixture
def empty_fixture() -> dict[str, Any]:
    """Load the empty fixture."""
    with open(FIXTURES_DIR / "empty_fixture.json", "r") as f:
        return json.load(f)


@pytest.fixture
def error_fixture() -> dict[str, Any]:
    """Load the error fixture."""
    with open(FIXTURES_DIR / "error_fixture.json", "r") as f:
        return json.load(f)


@pytest.fixture
def telemetry_only_fixture() -> dict[str, Any]:
    with open(FIXTURES_DIR / "telemetry_only_fixture.json", "r") as f:
        return json.load(f)


@pytest.fixture
def malformed_fixture() -> dict[str, Any]:
    """Load a malformed fixture (missing required field)."""
    return {
        "version": "1.0",
        # "host_identity" is missing - required field
        "timestamp": "2026-04-13T21:00:00Z",
        "sensor_groups": [],
        "status": {"code": "OK", "message": "Test"},
    }


class TestContractValidation:
    """Test suite for contract validation."""

    def test_success_fixture_validates_against_schema(
        self, success_fixture: dict[str, Any], contract_schema: dict[str, Any]
    ) -> None:
        """Test 1: success fixture should pass contract schema validation."""
        result = self._validate(success_fixture, contract_schema)
        assert result is True

    def test_empty_fixture_validates_against_schema(
        self, empty_fixture: dict[str, Any], contract_schema: dict[str, Any]
    ) -> None:
        """Test 2: empty fixture should pass contract schema validation."""
        result = self._validate(empty_fixture, contract_schema)
        assert result is True

    def test_error_fixture_validates_against_schema(
        self, error_fixture: dict[str, Any], contract_schema: dict[str, Any]
    ) -> None:
        """Test 3: error fixture should pass contract schema validation."""
        result = self._validate(error_fixture, contract_schema)
        assert result is True

    def test_telemetry_only_fixture_validates_against_schema(
        self, telemetry_only_fixture: dict[str, Any], contract_schema: dict[str, Any]
    ) -> None:
        result = self._validate(telemetry_only_fixture, contract_schema)
        assert result is True

    def test_legacy_payload_without_telemetry_validates(
        self, success_fixture: dict[str, Any], contract_schema: dict[str, Any]
    ) -> None:
        legacy_fixture = deepcopy(success_fixture)
        legacy_fixture["version"] = "1.0"
        legacy_fixture.pop("system_telemetry", None)
        legacy_fixture.pop("collection_warnings", None)

        result = self._validate(legacy_fixture, contract_schema)
        assert result is True

    def test_malformed_fixture_rejected(
        self, malformed_fixture: dict[str, Any], contract_schema: dict[str, Any]
    ) -> None:
        """Test 4: malformed JSON (missing required field) should be rejected."""
        result = self._validate(malformed_fixture, contract_schema)
        assert result is False

    @pytest.mark.parametrize(
        ("mutator", "description"),
        [
            (
                lambda payload: payload["system_telemetry"]["network"].update({"interfaces": [1, "eth0"]}),
                "network interfaces must be strings",
            ),
            (
                lambda payload: payload["system_telemetry"]["gpu_devices"][0].update(
                    {"memory_total_bytes": "8589934592"}
                ),
                "gpu memory totals must be integers or null",
            ),
            (
                lambda payload: payload["collection_warnings"].append({"source": "gpu", "code": "GPU_UNAVAILABLE"}),
                "warning entries require message text",
            ),
        ],
    )
    def test_malformed_telemetry_payload_rejected(
        self,
        success_fixture: dict[str, Any],
        contract_schema: dict[str, Any],
        mutator: Any,
        description: str,
    ) -> None:
        payload = deepcopy(success_fixture)
        mutator(payload)

        result = self._validate(payload, contract_schema)
        assert result is False, description

    @staticmethod
    def _validate(data: dict[str, Any], schema: dict[str, Any]) -> bool:
        """Validate data against JSON schema."""
        try:
            jsonschema.validate(instance=data, schema=schema)
            return True
        except jsonschema.ValidationError:
            return False
