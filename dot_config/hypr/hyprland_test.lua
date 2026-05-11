-- TEMP TEST CONFIG

require("conf_lua.monitors")
require("conf_lua.cursor")
require("conf_lua.keyboard")
require("conf_lua.workspace")
require("conf_lua.windows")
require("conf_lua.decorations")
require("conf_lua.layout")
require("conf_lua.misc")
require("conf_lua.keybindings")
require("conf_lua.animations")
-- Nested test binds
-- ~/.config/hypr/hyprland-test.lua

hl.bind("CONTROL + RETURN", function()
	hl.notification.create({
		text = "ALT + RETURN was detected",
		timeout = 3000,
		icon = "ok",
	})

	hl.dispatch(hl.dsp.exec_cmd("ghostty"))
end)

hl.bind("ALT + Q", hl.dsp.exit())
