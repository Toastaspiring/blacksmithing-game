--!nocheck
local L = require("./lib")
for _, b in ipairs(L.Fx.perf()) do
	if string.sub(b.name, 1, 2) == "P4" then
		for i, p in ipairs(b.parts) do
			print(i, p.slot, p.shape, string.format("%.4f %.4f %.4f", p.pos[1], p.pos[2], p.pos[3]), string.format("%.4f", p.size[1]))
		end
	end
end
