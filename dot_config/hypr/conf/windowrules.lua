-- hyprland-run window
hl.window_rule({
	name = "move-hyprland-run",
	match = { class = "^(hyprland-run)$" },
	float = true,
	move = "20% 80%",
})

-- GNOME Calculator
hl.window_rule({
	name = "float-gnome-calculator",
	match = { class = "^org[.]gnome[.]Calculator$" },
	float = true,
	center = true,
})

-- Floating termdown stopwatch/timer overlay
hl.window_rule({
	name = "float-termdown-stopwatch",
	match = { class = "^com[.]gus[.]termdown_stopwatch$" },
	float = true,
	pin = true,
	no_initial_focus = true,
	size = "360 200",
	move = "monitor_w-376 57",
})

-- Remove right-click menu blur in Chromium browsers
hl.window_rule({
	name = "no-blur-chromium",
	match = { class = "^(brave|chromium|google-chrome|chrome)$" },
	no_blur = true,
})

-- Bitwarden's Zen extension popup maps as an ordinary Zen window, then changes
-- its title. `float` is a static rule effect, so a title-matching window rule
-- is too late; react to that title change instead.
hl.on("window.title", function(window)
	local is_bitwarden_popup = window.class == "zen"
		and window.title:match("^Extension:%s*%(%s*Bitwarden Password Manager%s*%)%s*%-%s*Bitwarden.*")

	if not is_bitwarden_popup then
		return
	end

	-- Dispatcher selectors need the explicit `address:` prefix; a bare address
	-- silently targets no window. `enable` is idempotent, so later title changes
	-- cannot tile an already-floating popup.
	local selector = "address:" .. window.address
	hl.dispatch(hl.dsp.window.float({ action = "enable", window = selector }))
	hl.dispatch(hl.dsp.window.center({ window = selector }))
end)

-- File pickers floating & centered
hl.window_rule({
	name = "float-file-pickers",
	match = {
		title = "^(Open File|Open Folder|Open|Save|Save As|Export|Import|Choose File|Rename|script-fu|kdenlive|brave)$",
	},
	float = true,
	center = true,
})

-- GTK portal dialogs use their D-Bus application ID as the Wayland class.
-- xdg-desktop-portal-hyprland is a backend and does not create these dialogs.
hl.window_rule({
	name = "float-xdg-portal-gtk",
	match = { class = "^org[.]freedesktop[.]impl[.]portal[.]desktop[.]gtk$" },
	float = true,
	center = true,
	border_size = 0,
})

-- Disable borders for swaync
hl.window_rule({
	name = "no-border-swaync",
	match = { class = "^(swaync)$" },
	border_size = 0,
})
-- SwayNC
hl.layer_rule({ name = "swaync-cc-blur", match = { namespace = "swaync-control-center" }, blur = true })
hl.layer_rule({ name = "swaync-notif-blur", match = { namespace = "swaync-notification-window" }, blur = true })
hl.layer_rule({ name = "swaync-cc-alpha", match = { namespace = "swaync-control-center" }, ignore_alpha = 0.5 })
hl.layer_rule({ name = "swaync-notif-alpha", match = { namespace = "swaync-notification-window" }, ignore_alpha = 0.5 })

-- Logout dialog
hl.layer_rule({ name = "logout-anim", match = { namespace = "logout_dialog" }, animation = "fade" })
hl.layer_rule({ name = "logout-blur", match = { namespace = "logout_dialog" }, blur = true })

-- Rofi
hl.layer_rule({ name = "rofi-anim", match = { namespace = "rofi" }, animation = "popin 90%" })
