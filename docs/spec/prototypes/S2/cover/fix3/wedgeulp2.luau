--!nocheck
local Lab = require("./lab")
local N = Lab.tree("now")
local fmt = string.format
local found = 0
for _, sx in ipairs({ 0.1, 0.2, 0.3, 0.37, 0.5, 1 }) do
	for a = 30, 300, 7 do
		for b = 21, 300, 11 do
			local hy, hz = a / 2000, b / 2000
			local v1 = 4 * (sx / 2) * hy * hz
			local v2 = 4 * (sx / 2) * hz * hy
			if v2 > v1 and v1 > 0.0002 and found < 6 then
				found += 1
				print(fmt("Wedge %.3f x %.4f x %.4f: %.17g, as %.3f x %.4f x %.4f: %.17g", sx, 2 * hy, 2 * hz, v1, sx, 2 * hz, 2 * hy, v2))
			end
		end
	end
end
