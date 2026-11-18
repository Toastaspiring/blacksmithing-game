--!nocheck
local S = require("./sets")
local Shapes = require("./repo/src/shared/Physics/Shapes")
local Sv = require("./v/newV_base/Sampling")
local fmt = string.format
local base = S.json("out/climb_4.json")[1].parts
local function units(parts)
	local P = {}
	for i, p in ipairs(parts) do P[i] = Shapes.prepare(p, i) end
	local u = 0
	Sv.exposure(P, function(n) u += n end)
	return u
end
print("stored order", units(base))
local seedv = 7
for r = 1, 6 do
	local perm = {}
	for i = 1, #base do perm[i] = base[i] end
	for i = #perm, 2, -1 do
		seedv = (seedv * 1103515245 + 12345) % 2147483648
		local j = 1 + seedv % i
		perm[i], perm[j] = perm[j], perm[i]
	end
	print("permutation", r, units(perm))
end
