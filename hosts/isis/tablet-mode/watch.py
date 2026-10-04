"""Surface SW_TABLET_MODE detection, separate from session state transitions."""

import fcntl
import json
import logging
import os
from pathlib import Path
import select
import signal
import subprocess
import sys
import time

from evdev import InputDevice, ecodes, list_devices


LOG = logging.getLogger("surface-tablet")


def discover_switch():
    for path in list_devices():
        try:
            device = InputDevice(path)
            if (
                device.name == "Microsoft Surface KIP Tablet Mode Switch"
                and ecodes.SW_TABLET_MODE in device.capabilities().get(ecodes.EV_SW, [])
            ):
                return device
            device.close()
        except OSError:
            continue
    return None


def tablet_state(device):
    # EVIOCGSW: read the current kernel switch bitmap, including at startup
    # and after SYN_DROPPED. Never infer state from another input device.
    bitmap = bytearray(8)
    fcntl.ioctl(device.fd, (2 << 30) | (len(bitmap) << 16) | (ord("E") << 8) | 0x1B, bitmap)
    return bool(int.from_bytes(bitmap, sys.byteorder) & (1 << ecodes.SW_TABLET_MODE))


class Session:
    """Runtime-only policy; future gesture services can follow the same state."""

    def __init__(self, config):
        self.config = config
        self.normal_layout = config["normalLayout"]
        self.initialized = False
        self.previous = None
        self.marker = Path(os.environ["XDG_RUNTIME_DIR"]) / "surface-tablet/tablet"

    def command(self, key, *args):
        result = subprocess.run(
            [self.config[key], *args], capture_output=True, text=True, timeout=3, check=True
        )
        return result.stdout.strip()

    def apply(self, tablet):
        # Stop the OSK promptly even if DMS or Hyprland IPC is unavailable.
        if not tablet:
            self.marker.unlink(missing_ok=True)
            self.command("systemctl", "--user", "stop", *self.config["tabletServices"])

        option = json.loads(self.command("hyprctl", "-j", "getoption", "general:layout"))
        current = option["str"]
        if not self.initialized or tablet or self.previous is False:
            if current != "scrolling":
                self.normal_layout = current
            self.initialized = True
        desired = "scrolling" if tablet else self.normal_layout
        if current != desired:
            response = self.command(
                "hyprctl", "eval", f"hl.config({{general = {{layout = {json.dumps(desired)}}}}})"
            )
            if response != "ok":
                raise RuntimeError(f"Hyprland layout: {response}")

        value = "true" if tablet else "false"
        if self.command("dms", "ipc", "call", "surfaceTablet", "status") != value:
            response = self.command("dms", "ipc", "call", "surfaceTablet", "set", value)
            if response != "TABLET_SET_SUCCESS":
                raise RuntimeError(f"DMS tablet IPC: {response}")

        if tablet:
            self.marker.parent.mkdir(parents=True, exist_ok=True)
            self.marker.touch()
            self.command("systemctl", "--user", "start", *self.config["tabletServices"])
        if self.previous != tablet:
            LOG.info("Applied %s mode", "tablet" if tablet else "laptop")
        self.previous = tablet


def main():
    logging.basicConfig(level=logging.INFO, format="%(name)s: %(message)s")
    with open(sys.argv[1]) as file:
        session = Session(json.load(file))
    device = None
    last_error = None

    def stop(_signal, _frame):
        raise SystemExit(0)

    signal.signal(signal.SIGTERM, stop)
    signal.signal(signal.SIGINT, stop)
    try:
        while True:
            if device is None:
                device = discover_switch()
                if device is None:
                    LOG.warning("Waiting for the Surface SW_TABLET_MODE switch")
                    time.sleep(5)
                    continue
                LOG.info("Watching %s (%s)", device.name, device.path)
            try:
                state = tablet_state(device)
            except OSError:
                device.close()
                device = None
                continue
            try:
                session.apply(state)
                last_error = None
            except (OSError, ValueError, KeyError, RuntimeError, subprocess.SubprocessError) as error:
                message = str(error)
                if message != last_error:
                    LOG.warning("Waiting for session readiness: %s", message)
                    last_error = message
            # Events wake us immediately; periodic reconciliation handles IPC
            # startup/restarts, config reloads, dropped events and resume.
            if select.select([device.fd], [], [], 2)[0]:
                try:
                    list(device.read())
                except OSError:
                    device.close()
                    device = None
    finally:
        session.marker.unlink(missing_ok=True)
        try:
            session.apply(False)
        except (OSError, ValueError, KeyError, RuntimeError, subprocess.SubprocessError):
            # Logout may have already stopped the compositor or shell.
            LOG.info("Session unavailable during tablet override cleanup")
        if device is not None:
            device.close()


if __name__ == "__main__":
    main()
