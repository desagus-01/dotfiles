hl.config({
	dwindle = { preserve_split = true },
	scrolling = { column_width = 1, direction = "down" },
	binds = {
		workspace_back_and_forth = true,
		allow_workspace_cycles = true,
	},
	general = { gaps_in = 5, gaps_out = 7, border_size = 4, resize_on_border = true },
})

local globals = require("hypr_globals")
local utils = require("utils")

local function is_valid_layout(layout)
	return layout == "dwindle" or layout == "scrolling"
end

local function update_waybar_layout_indicator(workspace_id, layout)
	if not workspace_id or not is_valid_layout(layout) then
		return
	end

	utils.write_layout_state(workspace_id, layout)
	utils.signal_waybar_layout_module()
end

local function require_color(value, name)
	if type(value) ~= "string" or value == "" then
		error("Missing or empty colour in hypr_globals: " .. name)
	end

	return value
end

local function update_border_colors(layout)
	if not is_valid_layout(layout) then
		return
	end

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

local function update_workspace_visuals(ws)
	if not ws or not ws.id or not ws.tiled_layout then
		return
	end

	local layout = ws.tiled_layout

	if not is_valid_layout(layout) then
		return
	end

	update_border_colors(layout)
	update_waybar_layout_indicator(ws.id, layout)
end

local function update_active_workspace_visuals()
	local ws = hl.get_active_workspace()
	update_workspace_visuals(ws)
end

hl.on("workspace.active", function(ws)
	update_workspace_visuals(ws)
end)

hl.on("hyprland.start", update_active_workspace_visuals)
hl.on("config.reloaded", update_active_workspace_visuals)

update_active_workspace_visuals()

hl.bind(globals.main_mod .. " + CTRL + T", function()
	local ws = hl.get_active_workspace()

	if not ws or not ws.id then
		return
	end

	local current_layout = ws.tiled_layout or "dwindle"
	local new_layout = current_layout == "dwindle" and "scrolling" or "dwindle"

	hl.workspace_rule({
		workspace = tostring(ws.id),
		layout = new_layout,
	})

	update_border_colors(new_layout)
	update_waybar_layout_indicator(ws.id, new_layout)
end)
