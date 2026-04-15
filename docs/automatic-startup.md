# Automatic startup for the companion host service

This project ships a user-level systemd unit for the Android companion API:

- unit name: `cockpit-sensors-host.service`
- packaged unit path: `/usr/lib/systemd/user/cockpit-sensors-host.service`

## 1. One-command setup from the repository checkout

To install the host service files into `/usr/lib/cockpit-sensors`, create an isolated virtualenv with the service dependencies, install the user systemd unit, and start the service:

```bash
./tools/install_host_service.sh
```

The script uses `sudo` to copy files into `/usr/lib/cockpit-sensors`, create `/usr/lib/cockpit-sensors/venv`, install dependencies into that virtualenv, and keeps the service itself as a user-level systemd unit.

This is the recommended setup path for running the companion service from this repository checkout. It avoids installing Python dependencies into the global or user Python environment by bundling them into `/usr/lib/cockpit-sensors/venv` and running systemd with that interpreter.

Verify:

```bash
systemctl --user status cockpit-sensors-host.service
curl http://127.0.0.1:5000/api/v1/sensors
```

The installed user service runs the application with:

```text
/usr/lib/cockpit-sensors/venv/bin/python -m host_service
```

so dependency resolution comes from the bundled virtualenv instead of the system Python environment.

To remove the installed files and service later:

```bash
./tools/uninstall_host_service.sh
```

## 2. Start it now and enable it for future sessions

```bash
systemctl --user daemon-reload
systemctl --user enable --now cockpit-sensors-host.service
```

Verify:

```bash
systemctl --user status cockpit-sensors-host.service
curl http://127.0.0.1:5000/api/v1/sensors
```

## 3. Optional environment overrides

The service unit reads an optional environment file from:

```text
~/.config/cockpit-sensors-host.env
```

Example:

```bash
cat > ~/.config/cockpit-sensors-host.env <<'EOF'
HOST_SERVICE_HOST=0.0.0.0
HOST_SERVICE_PORT=5000
FLASK_ENV=production
EOF
```

After changing that file, reload and restart the service:

```bash
systemctl --user daemon-reload
systemctl --user restart cockpit-sensors-host.service
```

## 4. Start automatically even when you are not logged in

By default, a user service starts when that user logs in.

If you want the service to survive reboot without requiring an interactive login, enable lingering for the target user:

```bash
sudo loginctl enable-linger "$USER"
```

Then enable the service again if needed:

```bash
systemctl --user enable cockpit-sensors-host.service
```

## 5. Manual local-development startup

For local development from the repository checkout, use:

```bash
./tools/start_host_service.sh
```

You can override bind settings inline:

```bash
HOST_SERVICE_HOST=127.0.0.1 HOST_SERVICE_PORT=5056 FLASK_ENV=development ./tools/start_host_service.sh
```

## 6. Logs and troubleshooting

Show recent logs:

```bash
journalctl --user -u cockpit-sensors-host.service -n 200 --no-pager
```

Common checks:

```bash
systemctl --user status cockpit-sensors-host.service
curl http://127.0.0.1:5000/api/v1/sensors
tailscale ip
```

If Android clients connect over Tailscale, use the host's Tailscale IP with port `5000`.
