local colors = require("colors")
local globals = {}

globals.vertical_monitor_name = "HDMI-A-1"
globals.horizontal_monitor_name = "DP-2"

globals.primary_fixed = colors.primary_fixed
globals.on_secondary_color = colors.on_secondary

-- Border colors
globals.border_scrolling_start = colors.primary_fixed
globals.border_scrolling_end = colors.tertiary
globals.border_dwindle_start = colors.inverse_primary
globals.border_dwindle_end = colors.secondary_fixed
globals.border_inactive = colors.outline_variant

globals.main_mod = "SUPER"

return globals
