import os
from pathlib import Path

from flask import Flask, Response, jsonify

from .endpoints import sensor_router

HOST_SERVICE_DIR = Path(__file__).resolve().parent


def create_app() -> Flask:
    app = Flask(__name__)
    app.config["TESTING"] = os.environ.get("HOST_SERVICE_TESTING", "0") == "1"

    app.register_blueprint(sensor_router, url_prefix="/api/v1")

    # JSON error model: all errors return JSON, never HTML debug pages
    @app.errorhandler(Exception)
    def handle_exception(e: Exception) -> tuple[Response, int]:
        """Handle unexpected exceptions with JSON error responses."""
        return (
            jsonify(
                {
                    "error": {
                        "type": "InternalError",
                        "message": str(e),
                        "error_code": "INTERNAL_ERROR",
                    }
                }
            ),
            500,
        )

    return app


def main() -> None:
    """Main entry point for the companion service."""
    host = os.environ.get("HOST_SERVICE_HOST", "0.0.0.0")
    port = int(os.environ.get("HOST_SERVICE_PORT", 5000))
    debug = os.environ.get("FLASK_ENV", "production") == "development"

    app = create_app()
    app.run(host=host, port=port, debug=debug)


if __name__ == "__main__":
    main()
