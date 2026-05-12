hl.on("hyprland.start", function()
	hl.exec_cmd("awww-daemon --quiet")
	hl.exec_cmd("swaync")
	hl.exec_cmd("/usr/lib/polkit-gnome/polkit-gnome-authentication-agent-1 &")
	hl.exec_cmd("hypridle")
	hl.exec_cmd("hyprsunset")
	hl.exec_cmd("dbus-update-activation-environment --systemd WAYLAND_DISPLAY XDG_CURRENT_DESKTOP")
	hl.exec_cmd(
		'waybar -c "$HOME/.config/waybar/themes/gus-config/config" -s "$HOME/.config/waybar/themes/gus-config/colored/style.css" &'
	)
end)
