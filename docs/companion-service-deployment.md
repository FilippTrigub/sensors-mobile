# Companion Service Deployment Design

## Overview

This document defines the packaging and runtime deployment strategy for the Python Flask companion service that provides lm-sensors data and system telemetry to the Android Flutter client.

**Scope:** MVP deployment on private network/Tailscale, no authentication, no cloud infrastructure.

---

## 1. Install Location in Package Layout

### Decision

The Python host service will be installed under `/usr/lib/cockpit-sensors/` with the following structure:

```
/usr/lib/cockpit-sensors/
├── host_service/          # Python package
│   ├── __init__.py
│   ├── app.py            # Flask application factory
│   ├── endpoints.py      # API route definitions
│   ├── fixtures_loader.py
│   └── fixtures/         # Fixture JSON files
├── host_service.service   # systemd service unit (optional)
└── requirements.txt       # Python dependencies
```

### Rationale

- **Separation from Cockpit module:** The existing Cockpit module lives in `/usr/share/cockpit/sensors/`. Placing the Python service in `/usr/lib/cockpit-sensors/` keeps it separate but co-located under a project-specific prefix.
- **Standard Python packaging location:** `/usr/lib/` is the conventional location for system Python packages on Linux distributions (as opposed to `/usr/share/` for data/archives).
- **Clear project namespace:** `cockpit-sensors` namespace makes it obvious this service belongs to the Cockpit Sensors project, not a third-party or unrelated service.
- **Non-executable location:** Python packages in `/usr/lib/` are not directly executable; they are imported by a separate entrypoint (the systemd service), which aligns with security best practices.

### Package Manifest Impact

The `cockpit-sensors.spec.in` file will need to be extended to:
- Add Python dependencies to `BuildRequires` and `Requires`
- Install the `host_service/` directory to `/usr/lib/cockpit-sensors/host_service/`
- Install `requirements.txt` to `/usr/lib/cockpit-sensors/requirements.txt`
- Optionally install a systemd service unit file (see Section 2)

---

## 1b. Telemetry Expansion

The companion service has been extended beyond lm-sensors to include additive system telemetry:

- **CPU telemetry** — Usage percentage derived from `/proc/stat`
- **Memory (RAM) telemetry** — Usage percentage and bytes from `/proc/meminfo`
- **Network telemetry** — Active interfaces (excluding `lo`) with RX/TX throughput
- **GPU/VRAM telemetry** — Optional, NVIDIA-first via `nvidia-smi`; absent drivers or missing `nvidia-smi` yield `gpu_devices: []` without error
- **Collection warnings** — Non-fatal issues in any subsystem surface here rather than as payload errors

The payload version for telemetry-enabled responses is `1.1`. The API accepts `1.0` payloads for backward compatibility. When lm-sensors data is unavailable the API may still return telemetry data alongside `collection_warnings` rather than an error, since telemetry collection is additive and non-fatal.

GPU telemetry requires `nvidia-smi` on the host. AMD and Intel GPU support is not currently implemented.

---

## 2. Startup Mechanism (MVP)

### Decision: systemd Service Unit

For Fedora/RHEL-based distributions, the companion service will be deployed as a **systemd user service** (not system service) named `cockpit-sensors-host.service`.

### Service Unit Definition

```ini
[Unit]
Description=Cockpit Sensors Companion Service
Documentation=https://github.com/ocristopfer/cockpit-sensors
After=network.target

[Service]
Type=simple
WorkingDirectory=/usr/lib/cockpit-sensors
ExecStart=/usr/bin/python3 -m host_service
Restart=on-failure
RestartSec=5
EnvironmentFile=-%h/.config/cockpit-sensors-host.env
Environment=FLASK_ENV=production
Environment=HOST_SERVICE_HOST=0.0.0.0
Environment=HOST_SERVICE_PORT=5000

[Install]
WantedBy=default.target
```

### Rationale

**Why systemd user service (not system service):**
- The companion service runs as the logged-in user, not root
- It only needs access to lm-sensors data (which the user already has via `lm-sensors` package)
- User-scoped services automatically clean up when the user logs out, reducing resource leaks
- No need for root privileges or complex permissions

**Why systemd (not alternatives):**
- **systemd is ubiquitous** on Fedora, RHEL, and most modern Linux distributions
- **Native integration** with the init system (auto-start on login, restart on failure)
- **No additional dependencies** (unlike supervisord or other process managers)
- **Logging integration** via `journalctl -u cockpit-sensors-host`
- **Consistent with Cockpit's own architecture** (Cockpit uses systemd extensively)

**Why not run from Cockpit module directly:**
- Cockpit runs on-demand when the browser accesses the module; the companion service needs to be **always available** for the Flutter app to poll
- Cockpit runs as a system service (`cockpit.socket`), while the companion service is user-specific
- Decoupling allows the companion service to be **independently managed** (start/stop/restart) without affecting Cockpit

**Alternative considered and rejected:**
- **Cron @reboot:** Fragile, no automatic restart on failure, harder to debug
- **XDG autostart:** Works for desktop environments but less robust than systemd user services
- **Manual startup script:** Not suitable for production; requires user intervention

---

## 3. Endpoint Exposure Assumptions

### Decision: Bind to All Interfaces for Private Network Access

The Flask service will bind to `0.0.0.0:5000` (all interfaces) in production, with the following assumptions:

| Parameter | Value | Rationale |
|-----------|-------|-----------|
| **Host** | `0.0.0.0` | Accessible from all network interfaces; Tailscale and local access |
| **Port** | `5000` | Non-privileged, commonly used for development (easy to remember) |
| **Protocol** | HTTP | No TLS needed in private network; added complexity not justified for MVP |
| **Access control** | None | Private network (Tailscale) provides isolation; auth not required |

### Private Network Assumption (Tailscale)

The Android client is expected to connect via **Tailscale** or similar private network tool:

1. **Tailscale setup:** Both the Linux host and Android device join the same Tailscale network
2. **Service binding:** The Flask service binds to `0.0.0.0:5000`, making it accessible via the host's Tailscale IP
3. **Flutter client configuration:** The Android app connects to `http://[Tailscale-IP]:5000/api/v1/sensors`

### Tailscale Setup Instructions (For End Users)

To enable the Android client to access the companion service:

1. **Install Tailscale** on both the Linux host and Android device
2. **Join the same tailnet:** Ensure both devices are logged into the same Tailscale network
3. **Get the host's Tailscale IP:** Run `tailscale ip` on the Linux host to get the Tailscale IPv4 address
4. **Update Flutter app config:** Set the base URL in the Android app to `http://[Tailscale-IP]:5000`
5. **Verify connectivity:** From the Android device, test with `curl http://[Tailscale-IP]:5000/api/v1/sensors`

Example:
```bash
# On Linux host
$ tailscale ip
100.72.15.42

# Android app config
BASE_URL = "http://100.72.15.42:5000"
```

### Why Bind to `0.0.0.0` (not `127.0.0.1`)

- **Direct Tailscale access:** Binding to all interfaces allows the Tailscale interface to reach the service directly
- **Simpler MVP deployment:** No need for `tailscale serve` or manual port forwarding configuration
- **Still private:** The Tailscale overlay network provides end-to-end encryption; binding to `0.0.0.0` does not expose the service to the public internet
- **Local testing still works:** On the same machine, `http://127.0.0.1:5000` still works for debugging

### Alternative: Tailscale Serve (Not Chosen for MVP)

An alternative would be to bind to `127.0.0.1` and use `tailscale serve --tcp=5000` to expose the service. This was rejected because:
- Adds dependency on Tailscale CLI/config at runtime
- Requires additional user setup steps
- More complex documentation for MVP
- `tailscale serve` may change behavior or be deprecated

---

### Configurable Bind Address (Future-Proofing)

The service will support environment variable configuration:

```python
# In app.py
import os

HOST = os.environ.get("HOST_SERVICE_HOST", "0.0.0.0")
PORT = int(os.environ.get("HOST_SERVICE_PORT", 5000))

if __name__ == "__main__":
    app = create_app()
    app.run(host=HOST, port=PORT, debug=os.environ.get("FLASK_ENV") == "development")
```

This allows:
- **Production (MVP):** Default `0.0.0.0:5000` for direct Tailscale access
- **Local testing only:** `HOST_SERVICE_HOST=127.0.0.1` to restrict to localhost
- **Tailscale serve mode:** `HOST_SERVICE_HOST=127.0.0.1` with `tailscale serve --tcp=5000`
- **Docker/container deployment:** `HOST_SERVICE_HOST=0.0.0.0` for container networking

### Why No Public Internet Auth/Cloud?

- **MVP scope:** Private network only; no need for authentication or cloud infrastructure
- **lm-sensors is local-only:** Sensor data cannot be meaningfully accessed remotely without additional infrastructure
- **Security by isolation:** Tailscale provides end-to-end encryption and network-level access control
- **User-controlled deployment:** Users can deploy on any private network (Tailscale, WireGuard, VPN) without changes to the service

### Configurable Bind Address (Future-Proofing)

The service will support environment variable configuration:

```python
# In app.py
import os

HOST = os.environ.get("HOST_SERVICE_HOST", "0.0.0.0")
PORT = int(os.environ.get("HOST_SERVICE_PORT", 5000))

if __name__ == "__main__":
    app = create_app()
    app.run(host=HOST, port=PORT, debug=os.environ.get("FLASK_ENV") == "development")
```

This allows:
- **Production (default):** `0.0.0.0:5000` for direct Tailscale access from Android
- **Local testing only:** `HOST_SERVICE_HOST=127.0.0.1` to restrict to localhost
- **Tailscale serve mode:** `HOST_SERVICE_HOST=127.0.0.1` with `tailscale serve --tcp=5000` (alternative approach)
- **Docker/container deployment:** `HOST_SERVICE_HOST=0.0.0.0` for container networking

---

## 4. Configuration Source

### Decision: Environment Variables Only

The companion service will use **environment variables** for configuration in both production and development:

| Variable | Default | Description |
|----------|---------|-------------|
| `HOST_SERVICE_HOST` | `0.0.0.0` | Bind address (all interfaces for Tailscale access) |
| `HOST_SERVICE_PORT` | `5000` | Bind port |
| `FLASK_ENV` | `production` | Flask environment (`production` or `development`) |
| `FIXTURE_PATH` | *(hardcoded)* | Path to fixture directory (not configurable in MVP) |

### Rationale

- **Simple for MVP:** Environment variables are straightforward to configure in systemd service units and local development
- **No config file needed:** Avoids file permission issues and extra file management
- **Systemd integration:** Easy to pass environment variables in `service` unit via `Environment=` directives
- **Development flexibility:** Users can override defaults without modifying code

### Configuration Priority

```
1. Environment variables (highest priority)
2. Hardcoded defaults (lowest priority)
```

No config file parsing or `app.config` files are needed for MVP.

---

## 5. Local Development Workflow

### Decision: Direct Python Execution with Hot Reload

During development, the companion service will be run directly via Python's `-m` module flag with Flask's debug mode enabled:

```bash
cd /home/filipp/Projects/cockpit-sensors
PYTHONPATH=src python -m host_service
```

### Development Setup Steps

1. **Install Python dependencies:**
   ```bash
    pip install -r src/host_service/requirements.txt
   ```

2. **Run the service:**
    ```bash
    PYTHONPATH=src python -m host_service
    ```
    
    This starts Flask in debug mode with:
    - Hot reload on file changes
    - Interactive debugger
    - Bind to `0.0.0.0:5000` (accessible via Tailscale IP)
    - Use `HOST_SERVICE_HOST=127.0.0.1` to restrict to localhost only for local testing

3. **Test the API:**
    ```bash
    curl http://127.0.0.1:5000/api/v1/sensors  # From the same host
    curl http://[Tailscale-IP]:5000/api/v1/sensors  # From Android device on Tailscale
    ```

4. **Run tests:**
   ```bash
   pytest src/host_service/tests/ -v
   ```

### Development vs Production Parity

To ensure development matches production behavior:

- **Use same port:** `5000` in both modes
- **Use same entrypoint:** `python -m host_service` (matching systemd `ExecStart`)
- **Development binding:** `0.0.0.0` by default (matches production); override with `HOST_SERVICE_HOST=127.0.0.1` for localhost-only testing
- **Use fixtures in development:** Same fixture files are used; no live lm-sensors integration in MVP

### Future Development Enhancements (Out of Scope for MVP)

- **Systemd user service for testing:** Copy `cockpit-sensors-host.service` to `~/.config/systemd/user/` and run `systemctl --user start cockpit-sensors-host`
- **Virtual environment:** Use `venv` or `poetry` for isolated Python dependencies
- **Docker container:** Not needed for MVP but can be added later for consistent testing environments

---

## 6. Integration with Cockpit-Side Solution

### How the Companion Service Stays Integrated

1. **Single repository:** The Python service lives in the same repo as the Cockpit module (`cockpit-sensors`), ensuring coordinated releases and versioning.

2. **Shared build process:** The RPM build process (via `cockpit-sensors.spec.in`) packages both the Cockpit module and the Python service together.

3. **User-facing consistency:** The service is named `cockpit-sensors-host` to make it clear it belongs to the Cockpit Sensors project, not a separate product.

4. **No direct Flutter-Cockpit coupling:** The Flutter app talks to the Flask service via HTTP; it does not access Cockpit internals directly. This keeps the Flutter app as a **companion client**, not a replacement or integration with Cockpit.

5. **Private network assumption:** The service is designed for private networks (Tailscale), matching the Cockpit Sensors deployment model where users access sensor data from trusted networks.

---

## 7. Files Changed for Implementation (Task 13)

When Task 13 implements the packaging/runtime code, the following files will be created/modified:

### Create

- `packaging/cockpit-sensors-host.service` – systemd user service unit file
- `src/host_service/__main__.py` – Entry point for `python -m host_service`
- `docs/companion-service-deployment.md` – This document
- `.sisyphus/evidence/task-5-deployment.md` – Evidence document

### Modify

- `packaging/cockpit-sensors.spec.in` – Add Python service packaging rules
- `pyproject.toml` – Add Python dependencies if not in `requirements.txt`
- `src/host_service/app.py` – Add environment variable configuration

---

## 8. Decisions Summary

| Decision | Value | Rationale |
|----------|-------|-----------|
| **Install path** | `/usr/lib/cockpit-sensors/host_service/` | Clear project namespace; standard Python location |
| **Startup mechanism** | systemd user service | Native Linux integration; auto-restart; logging |
| **Bind address** | `0.0.0.0:5000` | All interfaces; direct Tailscale access from Android |
| **Auth** | None (MVP) | Tailscale provides network-level isolation |
| **Config source** | Environment variables | Simple; integrates with systemd; no file management |
| **Dev workflow** | `PYTHONPATH=src python -m host_service` | Direct execution with debug mode; matches production entrypoint |

---

## 9. Open Questions (For Future Tasks)

- Should the service integrate with actual lm-sensors output (via `sensors` CLI) instead of fixtures in production?
- Should there be a health check endpoint (`/health`) for the systemd service to monitor?
- Should the service support hot-swapping fixture data for testing without restart?

These questions are **out of scope for MVP** and should be addressed in future tasks if needed.
