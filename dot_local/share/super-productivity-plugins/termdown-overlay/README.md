# Super Productivity Waybar Timer (v2.4.0)

A local Super Productivity desktop plugin and Waybar custom module for this Hyprland configuration.

When task tracking changes, the plugin writes owner-only state files under:

```text
~/.local/state/super-productivity-waybar-timer/
```

Waybar shows the current task and remaining estimate. The Rofi picker lists unfinished tasks planned for Super Productivity's current logical day, with each task's **NET** estimate (estimate minus time already tracked). Press **SUPER+D** to choose a task and then a session duration: 15, 25, 30, 45, 60 minutes, or a custom value from 1 to 480 minutes. The task's overall estimate is not changed. At session end, tracking stops, the task remains open, and Super Productivity records the actual time worked so the remaining estimate decreases normally. A short completion sound plays once when the session reaches zero.

Click the Waybar timer during a session to choose **End early** or **Pause**. End early stops tracking and keeps the task open. Pause stops tracking and freezes the session countdown; the menu then offers **Resume** or **End early**.

Super Productivity must run in the background so its plugin can start/stop tracking. If it is closed, SUPER+D starts it with the installed app's `--start-minimized` option; with this setup's tray enabled, its main window remains hidden while Rofi opens. SUPER+D does not focus or show the app window. After installing/updating the plugin, open Super Productivity once and approve the `nodeExecution` permission; later hidden launches can initialize it without showing the app.

The integration does not use the Super Productivity REST API, access Hyprland from the plugin, or send data over the network. The Hyprland scripts access only the plugin's local state files.

## Install or update

1. In Super Productivity, go to **Settings → Plugins** and remove the previous **Super Productivity Waybar Timer** plugin (or the earlier **Termdown Task Overlay**, if it is still installed).
2. Install `super-productivity-waybar-timer.zip`.
3. Enable **Super Productivity Waybar Timer** and approve its desktop `nodeExecution` permission.
4. Restart Waybar if needed (for this setup, run `~/.config/waybar/launch.sh`).

The app's `nodeExecution` permission is broadly privileged. This plugin uses it to read and write its local state files; it does not run shell commands.
