--!nocheck
-- the hovering Ball over a window: the plate's reading with and without the Ball, now and on the base
local R = "C:/Users/louis/Documents/RANDOM/ROBLOX/Blacksmithing Game"
local B = "C:/Users/louis/AppData/Local/Temp/claude/C--Users-louis-Documents-RANDOM-ROBLOX/93ae48b4-72b9-4dc1-aa5d-451af1abf9a0/scratchpad/m2x-r4-base/repo"
for _, root in ipairs({ R, B }) do
	local H = require(root .. "/tests/Physics/PhysicsHelpers")
	local c, w, r, gap = 0.0625, 0.1052, 0.4, 0.015
	local x0, x1, FAR = c - w / 2, c + w / 2, 0.5
	local lids = { { -FAR, x0, -FAR, FAR }, { x1, FAR, -FAR, FAR }, { x0, x1, -FAR, x0 }, { x0, x1, x1, FAR } }
	local parts = H.partsUnder(lids)
	local P0 = H.prepared({ parts = parts })
	table.insert(parts, H.solid(#parts + 1, "Ball", { c, r + gap, c }, H.I, { 2 * r, 2 * r, 2 * r }))
	local P = H.prepared({ parts = parts })
	print(root == R and "now " or "base", string.format("without Ball %.12f %%, with %.12f %%, closed form %.12f %%", 100 * H.reads(P0, 1), 100 * H.reads(P, 1),
		100 * (w - 2e-9) ^ 2 / H.PLATE_AREA))
end
