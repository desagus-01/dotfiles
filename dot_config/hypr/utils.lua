local M = {}

function M.get_runtime_dir()
	return os.getenv("XDG_RUNTIME_DIR") or "/tmp"
end

function M.get_layout_state_path(workspace_id)
	return M.get_runtime_dir() .. "/hypr-layout-ws-" .. tostring(workspace_id)
end

function M.write_layout_state(workspace_id, layout)
	local file = io.open(M.get_layout_state_path(workspace_id), "w")

	if file then
		file:write(layout)
		file:close()
	end
end

function M.signal_waybar_layout_module()
	os.execute("pkill -RTMIN+8 waybar")
end

return M
