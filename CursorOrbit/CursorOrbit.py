"""Reset Fusion's native orbit pivot when the macOS helper releases Shift."""

import os
import socket
import tempfile
import threading
import time
import traceback
from typing import List, Optional

import adsk.core

_CUSTOM_EVENT_ID = "com.sean.CursorOrbit.ResetPivot.v3"
_SOCKET_PATH = os.path.join(
    tempfile.gettempdir(), "com.sean.CursorOrbit.reset.sock"
)

_app: Optional[adsk.core.Application] = None
_ui: Optional[adsk.core.UserInterface] = None
_reset_handler = None
_reset_event = None
_listener_socket: Optional[socket.socket] = None
_listener_thread = None
_stop_listener = threading.Event()
_handlers: List[object] = []


def _log(message: str):
    path = os.path.join(tempfile.gettempdir(), "CursorOrbit.log")
    try:
        with open(path, "a", encoding="utf-8") as stream:
            stream.write(f"{time.strftime('%Y-%m-%d %H:%M:%S')} {message}\n")
    except Exception:
        pass


def _reset_native_pivot() -> bool:
    if _ui is None:
        return False

    command = _ui.commandDefinitions.itemById("ResetOrbitCenterCommand")
    if command is None:
        _log("ResetOrbitCenterCommand unavailable")
        return False

    result = bool(command.execute())
    _log(f"Native pivot reset: {result}")
    return result


class _ResetPivotHandler(adsk.core.CustomEventHandler):
    def __init__(self):
        super().__init__()

    def notify(self, args: adsk.core.CustomEventArgs):
        try:
            _reset_native_pivot()
        except Exception:
            _log(traceback.format_exc())


class _ResetListener(threading.Thread):
    def __init__(self, listener: socket.socket):
        super().__init__(name="CursorOrbitResetListener", daemon=True)
        self._listener = listener

    def run(self):
        try:
            while not _stop_listener.is_set():
                message = self._listener.recv(32)
                if message == b"stop":
                    return
                if message == b"reset" and _app is not None:
                    _app.fireCustomEvent(_CUSTOM_EVENT_ID, "")
        except OSError:
            if not _stop_listener.is_set():
                _log(traceback.format_exc())
        except Exception:
            _log(traceback.format_exc())


def _wake_listener():
    try:
        sender = socket.socket(socket.AF_UNIX, socket.SOCK_DGRAM)
        try:
            sender.sendto(b"stop", _SOCKET_PATH)
        finally:
            sender.close()
    except OSError:
        pass


def run(context):
    global _app, _ui, _reset_handler, _reset_event
    global _listener_socket, _listener_thread

    try:
        _app = adsk.core.Application.get()
        _ui = _app.userInterface
        _stop_listener.clear()

        try:
            _app.unregisterCustomEvent(_CUSTOM_EVENT_ID)
        except Exception:
            pass

        _reset_event = _app.registerCustomEvent(_CUSTOM_EVENT_ID)
        if _reset_event is None:
            raise RuntimeError("Could not register reset-pivot event")

        _reset_handler = _ResetPivotHandler()
        _reset_event.add(_reset_handler)
        _handlers.append(_reset_handler)

        try:
            os.unlink(_SOCKET_PATH)
        except FileNotFoundError:
            pass

        _listener_socket = socket.socket(socket.AF_UNIX, socket.SOCK_DGRAM)
        _listener_socket.bind(_SOCKET_PATH)

        _reset_native_pivot()

        _listener_thread = _ResetListener(_listener_socket)
        _listener_thread.start()
        _log("Started native reset listener v0.3.0")
    except Exception:
        _log(traceback.format_exc())
        if _ui:
            _ui.messageBox(
                "CursorOrbit failed to start. See $TMPDIR/CursorOrbit.log."
            )


def stop(context):
    global _reset_handler, _reset_event
    global _listener_socket, _listener_thread, _app, _ui

    try:
        _stop_listener.set()
        _wake_listener()

        if _listener_thread and _listener_thread.is_alive():
            _listener_thread.join(timeout=0.25)

        _reset_native_pivot()

        if _listener_socket:
            _listener_socket.close()
        if _reset_event and _reset_handler:
            _reset_event.remove(_reset_handler)
        if _app:
            _app.unregisterCustomEvent(_CUSTOM_EVENT_ID)
    except Exception:
        _log(traceback.format_exc())
    finally:
        try:
            os.unlink(_SOCKET_PATH)
        except FileNotFoundError:
            pass

        _handlers.clear()
        _reset_handler = None
        _reset_event = None
        _listener_socket = None
        _listener_thread = None
        _app = None
        _ui = None
        _log("Stopped")
