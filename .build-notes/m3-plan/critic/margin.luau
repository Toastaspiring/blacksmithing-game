--!nocheck
local Fx = require("../proto/fixtures")
local Shapes = require("../proto/shapes")
for _, b in ipairs(Fx.calibration()) do
	if string.sub(b.name, 1, 3) == "C08" then
		local m = math.huge
		for i, raw in ipairs(b.parts) do
			local p = Shapes.prepare(raw, i)
			m = math.min(m, p.minx + 0.8, 0.8 - p.maxx, p.miny, 5.0 - p.maxy, p.minz + 0.3, 0.3 - p.maxz)
		end
		print(string.format("C08 margin %.17g (>= 0.02: %s)", m, tostring(m >= 0.02)))
	end
end
