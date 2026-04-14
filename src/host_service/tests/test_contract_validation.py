"""
Contract validation tests for the sensor API schema.
TDD approach: tests written before implementation.
"""

import json
from pathlib import Path

import jsonschema
import pytest

# Paths - relative to test file location
TEST_DIR = Path(__file__).parent.resolve()
HOST_SERVICE_DIR = TEST_DIR.parent  # parent of tests/
FIXTURES_DIR = HOST_SERVICE_DIR / "fixtures"
CONTRACT_PATH = HOST_SERVICE_DIR / "sensors_contract.json"


@pytest.fixture
def contract_schema():
    """Load the JSON contract schema."""
    with open(CONTRACT_PATH, "r") as f:
        return json.load(f)


@pytest.fixture
def success_fixture():
    """Load the success fixture."""
    with open(FIXTURES_DIR / "success_fixture.json", "r") as f:
        return json.load(f)


@pytest.fixture
def empty_fixture():
    """Load the empty fixture."""
    with open(FIXTURES_DIR / "empty_fixture.json", "r") as f:
        return json.load(f)


@pytest.fixture
def error_fixture():
    """Load the error fixture."""
    with open(FIXTURES_DIR / "error_fixture.json", "r") as f:
        return json.load(f)


@pytest.fixture
def malformed_fixture():
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

    def test_success_fixture_validates_against_schema(self, success_fixture, contract_schema):
        """Test 1: success fixture should pass contract schema validation."""
        result = self._validate(success_fixture, contract_schema)
        assert result is True

    def test_empty_fixture_validates_against_schema(self, empty_fixture, contract_schema):
        """Test 2: empty fixture should pass contract schema validation."""
        result = self._validate(empty_fixture, contract_schema)
        assert result is True

    def test_error_fixture_validates_against_schema(self, error_fixture, contract_schema):
        """Test 3: error fixture should pass contract schema validation."""
        result = self._validate(error_fixture, contract_schema)
        assert result is True

    def test_malformed_fixture_rejected(self, malformed_fixture, contract_schema):
        """Test 4: malformed JSON (missing required field) should be rejected."""
        result = self._validate(malformed_fixture, contract_schema)
        assert result is False

    @staticmethod
    def _validate(data, schema):
        """Validate data against JSON schema."""
        try:
            jsonschema.validate(instance=data, schema=schema)
            return True
        except jsonschema.ValidationError:
            return False
