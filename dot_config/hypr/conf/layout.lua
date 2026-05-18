hl.config({
	dwindle = { preserve_split = true },
	scrolling = { column_width = 1 },
	binds = {
		workspace_back_and_forth = true,
		allow_workspace_cycles = true,
	},
	general = { gaps_in = 5, gaps_out = 7, border_size = 4, resize_on_border = true },
})

-- keybinding rule
local globals = require("hypr_globals")

local function require_color(value, name)
	if type(value) ~= "string" or value == "" then
		error("Missing or empty colour in hypr_globals: " .. name)
	end

	return value
end

local function update_border_colors(layout)
	local active_colors

	if layout == "scrolling" then
		active_colors = {
			require_color(globals.border_scrolling_start, "border_scrolling_start"),
			require_color(globals.border_scrolling_end, "border_scrolling_end"),
		}
	else
		active_colors = {
			require_color(globals.border_dwindle_start, "border_dwindle_start"),
			require_color(globals.border_dwindle_end, "border_dwindle_end"),
		}
	end

	hl.config({
		general = {
			col = {
				active_border = {
					colors = active_colors,
					angle = 45,
				},

				inactive_border = require_color(globals.border_inactive, "border_inactive"),
			},
		},
	})
end

local function update_active_workspace_border_colors()
	local ws = hl.get_active_workspace()

	if ws and ws.tiled_layout then
		update_border_colors(ws.tiled_layout)
	end
end

hl.on("workspace.active", function(ws)
	if ws and ws.tiled_layout then
		update_border_colors(ws.tiled_layout)
	end
end)

hl.on("hyprland.start", update_active_workspace_border_colors)
hl.on("config.reloaded", update_active_workspace_border_colors)

update_active_workspace_border_colors()

hl.bind(globals.main_mod .. " + CTRL + T", function()
	local ws = hl.get_active_workspace()

	if not ws then
		return
	end

	local new_layout = ws.tiled_layout == "dwindle" and "scrolling" or "dwindle"

	hl.workspace_rule({

		workspace = tostring(ws.id),

		layout = new_layout,
	})

	update_border_colors(new_layout)

	hl.notification.create({

		text = " 󱂬 Workspace layout set to " .. new_layout,

		timeout = 3000,

		icon = 5,
	})
end)
