local globals = require("hypr_globals")
hl.config({
	general = {
		gaps_in = 4,
		gaps_out = 5,
		border_size = 3,
		layout = "dwindle",
		resize_on_border = true,
		col = {
			active_border = globals.secondary_color,
			inactive_border = globals.on_secondary_color,
		},
	},
})
