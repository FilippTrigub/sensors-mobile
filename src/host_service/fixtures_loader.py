"""
Fixture loader for sensor data.

Provides access to pre-defined JSON fixtures for testing.
"""

import json
from enum import Enum
from pathlib import Path


class FixtureType(Enum):
    """Types of available fixtures."""

    SUCCESS = "success"
    EMPTY = "empty"
    ERROR = "error"
    TELEMETRY_ONLY = "telemetry_only"


FIXTURES_DIR = Path(__file__).resolve().parent / "fixtures"


def load_fixture(fixture_type: FixtureType) -> dict:
    """Load a fixture by type."""
    path = FIXTURES_DIR / f"{fixture_type.value}_fixture.json"
    with open(path, "r") as f:
        return json.load(f)
