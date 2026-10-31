--!strict
-- Studio-only test bridge (mapped by test.project.json only).
local bridge = Instance.new("BindableFunction")
bridge.Name = "BlacksmithTestBridge"
bridge.OnInvoke = function(req)
	if req.cmd == "ping" then return { ok = true, data = { studio = true } } end
	return { ok = false, err = "unknown cmd" }
end
bridge.Parent = game:GetService("ServerStorage")
