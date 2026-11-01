import json
import logging
import signal
import subprocess
import sys
import time


logging.basicConfig(level=logging.INFO)
running = True
saved = {}


def stop(*_):
    global running
    running = False


def command(*args):
    return subprocess.run(
        [sys.argv[1], *args],
        check=True,
        capture_output=True,
        text=True,
        timeout=3,
    ).stdout


def snapshot(name):
    return json.loads(command("-j", name))


def set_state(address, internal):
    selector = json.dumps("address:" + address)
    response = command(
        "eval",
        "hl.dispatch(hl.dsp.window.fullscreen_state({"
        f"window = {selector}, internal = {internal}, client = -1, "
        'action = "set", layout_aware = false}))',
    )
    if response.strip() != "ok":
        raise RuntimeError(response)


def reconcile(keyboard_monitors, monitors, clients):
    windows = {window["address"]: window for window in clients}
    for address, original in list(saved.items()):
        window = windows.get(address)
        if not window:
            del saved[address]
            continue
        # Respect explicit fullscreen changes made by the app or user.
        if window["fullscreen"] != 1 or window["fullscreenClient"] != original[1]:
            del saved[address]
            continue
        if monitors.get(window["monitor"]) not in keyboard_monitors:
            set_state(address, original[0])
            del saved[address]
            logging.info("Restored fullscreen for %s", address)
    for address, window in windows.items():
        if (
            address not in saved
            and window.get("mapped")
            and window.get("visible")
            and window["fullscreen"] in (2, 3)
            and monitors.get(window["monitor"]) in keyboard_monitors
        ):
            original = (window["fullscreen"], window["fullscreenClient"])
            set_state(address, 1)
            saved[address] = original
            logging.info("Reserved keyboard space for %s", address)


def main():
    signal.signal(signal.SIGTERM, stop)
    signal.signal(signal.SIGINT, stop)
    try:
        while running:
            try:
                layers = snapshot("layers")
                keyboard_monitors = {
                    name
                    for name, output in layers.items()
                    if any(
                        layer.get("namespace") == "wvkbd" and layer.get("h", 0) > 0
                        for level in output["levels"].values()
                        for layer in level
                    )
                }
                monitors = {
                    monitor["id"]: monitor["name"] for monitor in snapshot("monitors")
                }
                reconcile(keyboard_monitors, monitors, snapshot("clients"))
            except (
                OSError,
                ValueError,
                KeyError,
                subprocess.SubprocessError,
                RuntimeError,
            ):
                logging.exception("Keyboard space reconciliation failed")
            time.sleep(0.3)
    finally:
        # Restore only windows still in the state set by this helper.
        reconcile(set(), {}, snapshot("clients"))


if __name__ == "__main__":
    main()
