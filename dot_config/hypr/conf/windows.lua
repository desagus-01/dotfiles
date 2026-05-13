local globals = require("hypr_globals")
hl.config({
	general = {
		gaps_in = 5,
		gaps_out = 7,
		border_size = 3,
		layout = "dwindle",
		resize_on_border = true,
		col = {
			active_border = globals.primary_fixed,
			inactive_border = globals.on_secondary_color,
		},
	},
})
