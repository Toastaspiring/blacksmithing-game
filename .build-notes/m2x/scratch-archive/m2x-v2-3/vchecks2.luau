--!nocheck
local R = "C:/Users/louis/AppData/Local/Temp/claude/C--Users-louis-Documents-RANDOM-ROBLOX/93ae48b4-72b9-4dc1-aa5d-451af1abf9a0/scratchpad/m2x-v2-3/repo"
local H = require(R .. "/tests/Physics/PhysicsHelpers")
local fmt = string.format
local design = H.f("F5")
local blade = design.parts[4]
for k = 1, 6 do
	table.insert(design.parts, H.part(10 + k, "Blade", "Block", "Iron", { blade.pos[1], blade.pos[2], k * 0.002 }, H.I, blade.size))
end
local list = H.prepared(design)
local sx, sy, sz = blade.size[1], blade.size[2], blade.size[3]
local area = 2 * (sx * sy + sx * sz + sy * sz)
for k = 1, 5 do
	local i = #design.parts - 6 + k
	local share = H.reads(list, i)
	local closed = (2 * sy + sx) * 0.002 / area
	print(fmt("copy %d: %.17g closed form (2L + w)·0.002/area %.17g diff %.3e (old pin, (2L + w)(0.002 − EPS)/area: diff %.3e)", k, share, closed, share - closed, share - (2 * sy + sx) * (0.002 - 1e-7) / area))
end
