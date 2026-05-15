local colors = require("colors")
local globals = {}

globals.vertical_monitor_name = "HDMI-A-1"
globals.horizontal_monitor_name = "DP-2"

globals.primary_fixed = colors.primary_fixed
globals.on_secondary_color = colors.on_secondary

-- Border colors
-- Scrolling layout: primary_fixed (bright vivid blue) → tertiary (warm contrasting accent)
-- These two are always from different hue families, so they stay distinct across any wallpaper
globals.border_scrolling_start = colors.primary_fixed
globals.border_scrolling_end = colors.tertiary
-- Dwindle layout: inverse_primary (richer saturated blue) → secondary_fixed (light cool-grey)
-- inverse_primary is always more vivid than primary; secondary_fixed is always lighter/cooler
globals.border_dwindle_start = colors.inverse_primary
globals.border_dwindle_end = colors.secondary_fixed
-- Inactive: outline_variant is the Material Design semantic for surface separators
globals.border_inactive = colors.outline_variant

globals.main_mod = "SUPER"

return globals
