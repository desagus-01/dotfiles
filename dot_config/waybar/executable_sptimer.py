#!/usr/bin/env python3
"""Waybar custom module for the current Super Productivity task timer."""

from __future__ import annotations

import json
import math
import os
import shutil
import subprocess
import time
from pathlib import Path


DEFAULT_STATE_FILE = Path.home() / ".local/state/super-productivity-waybar-timer/active.json"
STATE_FILE = Path(os.environ.get("SP_WAYBAR_TIMER_STATE", DEFAULT_STATE_FILE))
ALERT_FILE = STATE_FILE.with_name("session-alert.json")
SOUND_FILE = Path(os.environ.get(
    "SP_WAYBAR_TIMER_SOUND",
    "/usr/share/sounds/freedesktop/stereo/complete.oga",
))


def consume_session_alert() -> None:
    claimed_file = ALERT_FILE.with_name(f"session-alert.{os.getpid()}.{time.time_ns()}.claim")
    try:
        os.replace(ALERT_FILE, claimed_file)
    except FileNotFoundError:
        return

    try:
        alert = json.loads(claimed_file.read_text(encoding="utf8"))
        created_at_ms = int(alert.get("createdAtMs", 0))
        if int(time.time() * 1000) - created_at_ms > 60_000 or not SOUND_FILE.is_file():
            return

        players = [
            ("paplay", [str(SOUND_FILE)]),
            ("pw-play", [str(SOUND_FILE)]),
            ("canberra-gtk-play", ["-f", str(SOUND_FILE)]),
        ]
        for command, args in players:
            executable = shutil.which(command)
            if executable:
                subprocess.Popen(
                    [executable, *args],
                    stdin=subprocess.DEVNULL,
                    stdout=subprocess.DEVNULL,
                    stderr=subprocess.DEVNULL,
                    start_new_session=True,
                )
                break
    except (OSError, ValueError, TypeError, json.JSONDecodeError):
        pass
    finally:
        try:
            claimed_file.unlink()
        except FileNotFoundError:
            pass


def format_duration(seconds: int) -> str:
    hours, remainder = divmod(max(0, seconds), 3600)
    minutes, seconds = divmod(remainder, 60)
    if hours:
        return f"{hours}:{minutes:02d}:{seconds:02d}"
    return f"{minutes}:{seconds:02d}"


def waybar_output(text: str = "", tooltip: str = "No task being tracked", css_class: str = "idle") -> None:
    print(json.dumps({"text": text, "tooltip": tooltip, "class": css_class}, ensure_ascii=False))


def main() -> None:
    consume_session_alert()
    try:
        state = json.loads(STATE_FILE.read_text(encoding="utf8"))
        estimate_ms = max(0, int(state.get("timeEstimateMs", 0)))
        spent_ms = max(0, int(state.get("timeSpentMs", 0)))
        started_at_ms = int(state.get("startedAtMs", 0))
        title = " ".join(str(state.get("title") or "Current task").split())
    except FileNotFoundError:
        waybar_output()
        return
    except (OSError, ValueError, TypeError, json.JSONDecodeError):
        waybar_output("Timer unavailable", "Could not read the Super Productivity timer state", "error")
        return

    now_ms = int(time.time() * 1000)
    session_state = str(state.get("sessionState") or "")
    elapsed_ms = 0 if session_state == "paused" else max(0, now_ms - started_at_ms)
    tracked_ms = spent_ms + elapsed_ms
    task_remaining_ms = estimate_ms - tracked_ms if estimate_ms > 0 else None
    session_ends_at_ms = max(0, int(state.get("sessionEndsAtMs", 0)))
    session_remaining_ms = (
        max(0, int(state.get("sessionRemainingMs", 0)))
        if session_state == "paused"
        else session_ends_at_ms - now_ms
    )

    if session_state in {"running", "paused"}:
        display_time = format_duration(math.ceil(max(0, session_remaining_ms) / 1000))
        css_class = "paused" if session_state == "paused" else "session"
        if task_remaining_ms is None:
            task_status = f"Time tracked: {format_duration(math.floor(tracked_ms / 1000))}"
        elif task_remaining_ms > 0:
            task_status = f"Task estimate remaining: {format_duration(math.ceil(task_remaining_ms / 1000))}"
        else:
            task_status = f"Task overtime: {format_duration(math.floor(-task_remaining_ms / 1000))}"
        status = "Session paused" if session_state == "paused" else "Session remaining"
        tooltip = f"{title}\n{status}: {display_time}\n{task_status}"
    elif task_remaining_ms is not None and task_remaining_ms > 0:
        display_time = format_duration(math.ceil(task_remaining_ms / 1000))
        css_class = "running"
        tooltip = f"{title}\nTask estimate remaining: {display_time}"
    elif task_remaining_ms is not None:
        display_time = "+" + format_duration(math.floor(-task_remaining_ms / 1000))
        css_class = "overtime"
        tooltip = f"{title}\nTask estimate exceeded by {display_time[1:]}"
    else:
        display_time = format_duration(math.floor(tracked_ms / 1000))
        css_class = "stopwatch"
        tooltip = f"{title}\nTime tracked"

    short_title = title if len(title) <= 32 else title[:31].rstrip() + "…"
    icon = "⏸" if session_state == "paused" else "⏱"
    waybar_output(f"{icon} {short_title} {display_time}", tooltip, css_class)


if __name__ == "__main__":
    main()
