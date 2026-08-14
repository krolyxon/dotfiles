#!/usr/bin/env python3
"""
screen_rotate.py — Hyprland 0.55+ IPC-only Screen Rotation Utility

Rotates the focused monitor 90° clockwise (+90) or counter-clockwise (-90).

Usage:
    screen_rotate.py +90
    screen_rotate.py -90

Design principles:
  • Zero config-file access — reads/writes nothing on disk.
  • Temporary by design — changes reset on `hyprctl reload`.
  • Mode-string fidelity — resolves active mode natively without resolution corruption.
  • Flip-transform aware — rotates within the current flip state (0-3 / 4-7).
  • Keybind safe — pipes critical errors to notify-send and debounces rapid inputs.
"""

from __future__ import annotations

import fcntl
import json
import os
import subprocess
import sys
import tempfile
import time
from typing import Any


# ── Concurrency Lock ───────────────────────────────────────────────────────────

def acquire_lock() -> None:
    """
    Acquire an exclusive lock. If another instance is running, exit silently.
    This prevents race conditions when the keybind is spammed.
    """
    lock_file = os.path.join(tempfile.gettempdir(), "hypr_screen_rotate.lock")
    fd = os.open(lock_file, os.O_CREAT | os.O_RDWR)
    try:
        fcntl.flock(fd, fcntl.LOCK_EX | fcntl.LOCK_NB)
    except BlockingIOError:
        # Another instance is running. Silently drop this execution.
        sys.exit(0)
    # The file descriptor remains open and locked until the process exits.
    # The OS automatically releases the lock when the script finishes.


# ── ANSI colour helpers ────────────────────────────────────────────────────────

_COLOURS = sys.stderr.isatty() or sys.stdout.isatty()

def _c(code: str, text: str) -> str:
    return f"\033[{code}m{text}\033[0m" if _COLOURS else text

def _red(t: str)    -> str: return _c("31", t)
def _green(t: str)  -> str: return _c("32", t)
def _yellow(t: str) -> str: return _c("33", t)
def _blue(t: str)   -> str: return _c("34", t)
def _bold(t: str)   -> str: return _c("1",  t)


# ── Logging ────────────────────────────────────────────────────────────────────

def log_info(msg: str)    -> None: print(f"{_blue('[INFO]')}    {msg}")
def log_ok(msg: str)      -> None: print(f"{_green('[OK]')}      {msg}")
def log_warn(msg: str)    -> None: print(f"{_yellow('[WARN]')}   {msg}", file=sys.stderr)
def log_payload(msg: str) -> None: print(f"{_yellow('[PAYLOAD]')} {msg}")

def die(msg: str, code: int = 1) -> None:
    """Print to stderr and send a desktop notification so keybinds don't fail silently."""
    print(f"{_red('[ERROR]')}   {msg}", file=sys.stderr)
    try:
        subprocess.run(
            [
                "notify-send",
                "--app-name=screen_rotate.py",
                "--urgency=critical",
                "Screen Rotation Error",
                msg
            ],
            capture_output=True,
            timeout=2
        )
    except Exception:
        pass
    sys.exit(code)


# ── Dependency / environment checks ───────────────────────────────────────────

def check_environment() -> None:
    if os.geteuid() == 0:
        die("Do not run as root — hyprctl requires user-space socket access.")

    if not os.environ.get("HYPRLAND_INSTANCE_SIGNATURE"):
        die(
            "HYPRLAND_INSTANCE_SIGNATURE is not set.\n"
            "Is Hyprland running, and are you in the correct session?"
        )

    result = subprocess.run(
        ["hyprctl", "--version"],
        capture_output=True,
        text=True,
    )
    if result.returncode != 0 and "not found" in (result.stderr or "").lower():
        die("'hyprctl' not found. Install Hyprland.")


# ── Argument parsing ───────────────────────────────────────────────────────────

def parse_direction() -> int:
    prog = os.path.basename(sys.argv[0])
    
    # Graceful help handler
    if len(sys.argv) == 2 and sys.argv[1] in ("-h", "--help"):
        print(f"Usage: {prog} [+90|-90]")
        print("Rotates the focused monitor 90° clockwise (+90) or counter-clockwise (-90).")
        sys.exit(0)

    # Strict arg checking for actual usage
    if len(sys.argv) != 2 or sys.argv[1] not in ("+90", "-90"):
        die(f"Invalid argument.\nUsage: {prog} [+90|-90]")
        
    return 1 if sys.argv[1] == "+90" else -1


# ── hyprctl IPC wrappers ───────────────────────────────────────────────────────

def hyprctl_json(args: list[str]) -> Any:
    try:
        proc = subprocess.run(
            ["hyprctl", "-j"] + args,
            capture_output=True,
            text=True,
            timeout=5,
        )
    except FileNotFoundError:
        die("'hyprctl' not found.")
    except subprocess.TimeoutExpired:
        die("hyprctl timed out — is Hyprland responsive?")

    if proc.returncode != 0:
        die(f"hyprctl exited {proc.returncode}: {proc.stderr.strip() or '(no stderr)'}")

    raw = proc.stdout.strip()

    if raw and not raw[0] in ("[", "{"):
        for i, line in enumerate(raw.splitlines()):
            line = line.strip()
            if line.startswith(("[", "{")):
                raw = "\n".join(raw.splitlines()[i:])
                break

    if not raw:
        die("hyprctl returned empty output.")

    try:
        return json.loads(raw)
    except json.JSONDecodeError as exc:
        die(f"Failed to parse hyprctl JSON: {exc}\nRaw output: {raw[:300]!r}")


def hyprctl_eval(lua_str: str) -> bool:
    try:
        proc = subprocess.run(
            ["hyprctl", "eval", lua_str],
            capture_output=True,
            text=True,
            timeout=5,
        )
    except subprocess.TimeoutExpired:
        die("hyprctl eval timed out — compositor may be unresponsive.")

    return proc.returncode == 0


# ── Mode resolution ────────────────────────────────────────────────────────────

def _parse_hz(mode_str: str) -> float | None:
    try:
        _, hz_part = mode_str.split("@", 1)
        return float(hz_part.rstrip("HhZz"))
    except (ValueError, IndexError):
        return None


def resolve_active_mode(monitor: dict[str, Any]) -> str:
    """
    Return the best-matching physical mode string for `hl.monitor()`
    (WITHOUT the Hz suffix, e.g. "1920x1080@144.00").
    """
    # Hyprland IPC `width` and `height` ALWAYS represent the physical 
    # native resolution. They do not swap when rotated.
    native_w: int    = int(monitor["width"])
    native_h: int    = int(monitor["height"])
    refresh: float   = float(monitor["refreshRate"])
    available: list  = monitor.get("availableModes", [])

    target_prefix = f"{native_w}x{native_h}@"

    candidates: list[tuple[float, str]] = []
    for mode in available:
        if not mode.lower().startswith(target_prefix.lower()):
            continue
        hz = _parse_hz(mode)
        if hz is None:
            continue
        clean = mode.rstrip("HhZz")
        candidates.append((hz, clean))

    if not candidates:
        log_warn(
            f"No availableModes entry for {native_w}x{native_h} "
            f"(IPC refreshRate={refresh:.5f}). "
            "Reconstructing mode string from IPC data."
        )
        return f"{native_w}x{native_h}@{refresh:.2f}"

    best_hz, best_clean = min(candidates, key=lambda c: abs(c[0] - refresh))
    return best_clean


# ── Transform arithmetic ───────────────────────────────────────────────────────

def compute_new_transform(current: int, direction: int) -> int:
    flip_bit      = current & 4
    rotation_bits = current & 3
    new_rotation  = (rotation_bits + direction + 4) % 4
    return flip_bit | new_rotation


# ── Scale formatting ───────────────────────────────────────────────────────────

def format_scale(scale: float) -> str:
    rounded = f"{scale:.6f}".rstrip("0").rstrip(".")
    return rounded


# ── Main ───────────────────────────────────────────────────────────────────────

def main() -> None:
    # 1. Establish concurrency lock immediately to debounce keybind spam
    acquire_lock()
    
    check_environment()
    direction = parse_direction()

    monitors: list[dict] = hyprctl_json(["monitors"])

    if not isinstance(monitors, list) or not monitors:
        die("hyprctl returned no monitor data.")

    focused: dict | None = next(
        (m for m in monitors if m.get("focused") is True), None
    )
    if focused is None:
        log_warn("No focused monitor found; using first monitor.")
        focused = monitors[0]

    name: str           = str(focused.get("name", ""))
    current_transform   = int(focused.get("transform", 0))
    x: int              = int(focused.get("x", 0))
    y: int              = int(focused.get("y", 0))
    scale: float        = float(focused.get("scale", 1.0))
    disabled: bool      = bool(focused.get("disabled", False))

    if not name or name == "null":
        die("Could not read monitor name from IPC.")

    if disabled:
        die(f"Monitor '{name}' is currently disabled; cannot rotate.")

    if current_transform not in range(8):
        die(f"Unexpected transform value '{current_transform}' from IPC. Expected 0-7.")

    new_transform = compute_new_transform(current_transform, direction)
    active_mode = resolve_active_mode(focused)

    pos_str   = f"{x}x{y}"
    scale_str = format_scale(scale)
    lua_name = name.replace("\\", "\\\\").replace('"', '\\"')

    lua_call = (
        f'hl.monitor({{ output = "{lua_name}", mode = "{active_mode}", '
        f'position = "{pos_str}", scale = {scale_str}, transform = {new_transform} }})'
    )

    print()
    log_info(f"Monitor   : {_bold(name)}")
    log_info(f"Mode      : {active_mode}")
    log_info(f"Position  : {pos_str}   Scale: {scale_str}")
    log_info(f"Transform : {current_transform} → {new_transform}  ({direction:+d} × 90°)")
    log_payload(lua_call)
    print()

    eval_ok = hyprctl_eval(lua_call)
    if not eval_ok:
        die(
            "hyprctl eval returned a non-zero exit code.\n"
            "Is Hyprland 0.55+ running and the socket accessible?\n"
            f"Lua: {lua_call}"
        )

    actual_transform = current_transform
    for _ in range(25):
        time.sleep(0.1)
        try:
            polled = hyprctl_json(["monitors"])
            for m in polled:
                if m.get("name") == name:
                    actual_transform = int(m.get("transform", current_transform))
                    break
        except SystemExit:
            break
        if actual_transform != current_transform:
            break

    if actual_transform != new_transform:
        die(
            f"Transform did not change after eval (expected {new_transform}, IPC reports {actual_transform}).\n"
            "This may indicate the compositor overrode the value.\n"
            f"Lua sent: {lua_call}"
        )

    log_ok(f"Rotation applied — transform {current_transform} → {new_transform}")
    _notify(name, new_transform, active_mode)


def _notify(monitor: str, transform: int, mode: str) -> None:
    _TRANSFORM_NAMES = {
        0: "0° (normal)",   1: "90°",    2: "180°",   3: "270°",
        4: "0° (flipped)",  5: "90°+flip", 6: "180°+flip", 7: "270°+flip",
    }
    label = _TRANSFORM_NAMES.get(transform, str(transform))
    body  = f"{monitor} • {label}"

    try:
        subprocess.run(
            [
                "notify-send",
                "--app-name=hypr-rotate",
                "--icon=object-rotate-right",
                "-t", "1500",
                "Display Rotated",
                body,
                "--hint=string:x-canonical-private-synchronous:display-rotate",
            ],
            capture_output=True,
            timeout=3,
        )
    except Exception:
        pass


if __name__ == "__main__":
    main()
