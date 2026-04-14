import os
import sys

from pathlib import Path

# Add the project root to sys.path to allow imports
project_root = Path(__file__).resolve().parent.parent.parent
if str(project_root) not in sys.path:
    sys.path.insert(0, str(project_root))

from .app import create_app

HOST = os.environ.get("HOST_SERVICE_HOST", "0.0.0.0")
PORT = int(os.environ.get("HOST_SERVICE_PORT", 5000))
FLASK_ENV = os.environ.get("FLASK_ENV", "production")


def main() -> None:
    """Main entry point for the companion service."""
    app = create_app()
    debug_mode = FLASK_ENV == "development"
    app.run(host=HOST, port=PORT, debug=debug_mode)


if __name__ == "__main__":
    main()
