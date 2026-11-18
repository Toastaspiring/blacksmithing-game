--!nocheck
-- a Block and itself described another way (sizes z, y, x, a quarter turn about Y): sizes where 8·hx·hy·hz differs by an
-- ulp between the two and the two orders disagree: the rank by given extents (smaller hx first) and by Shapes' volume
local L = require("./lib")
local found = 0
for i = 1, 300 do
	for j = 1, 300 do
		local a, b, c = 0.02 + i * 0.0031, 0.37, 0.02 + j * 0.0047
		local v1 = 8 * (a / 2) * (b / 2) * (c / 2)
		local v2 = 8 * (c / 2) * (b / 2) * (a / 2)
		if v1 ~= v2 and a < c and v1 < v2 then
			print(string.format("sizes %.17g × %.17g × %.17g: volumes %.17g / %.17g", a, b, c, v1, v2))
			found += 1
			if found >= 2 then break end
		end
	end
	if found >= 2 then break end
end
