--!nocheck
local S = require("./sets")
local Shapes = require("./repo/src/shared/Physics/Shapes")
local Sv = require("./v/newV_base/Sampling")
local fmt = string.format
local function units(parts)
	local P = {}
	for i, p in ipairs(parts) do P[i] = Shapes.prepare(p, i) end
	local u = 0
	local e = Sv.exposure(P, function(n) u += n end)
	local k = {}
	for i = 1, #P do k[i] = e.kept[i] and "1" or "0" end
	return u, table.concat(k)
end
local target = S.json("out/climb_4.json")[1].parts
print("fresh", units(target))
-- warm the process with many other designs, then again
local others = {}
for _, d in ipairs(S.climbed()) do table.insert(others, d) end
for _, d in ipairs(S.protoFixtures()) do table.insert(others, d) end
for k = 1, #others do units(others[k].parts) end
print("after", #others, "other designs", units(target))
for r = 1, 3 do print("again", units(target)) end
