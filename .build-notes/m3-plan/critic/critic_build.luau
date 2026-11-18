--!nocheck
-- Critic check on the M2 build (read-only): MassProps.difficultyFrame sums the kept Grip parts in blueprint order, so the
-- difficulty frame's point (EdgeProfile.gripPoint) can change bits when the same parts come in another order.
-- Run from the repo root: lune run <abs path>/critic_build.luau
local ROOT = "../../../../../../../../../Documents/RANDOM/ROBLOX/Blacksmithing Game/"
local Shapes = require(ROOT .. "src/shared/Physics/Shapes")
local MassProps = require(ROOT .. "src/shared/Physics/MassProps")
local Fx = require("../proto/fixtures")
local fmt = string.format

local c09
for _, b in ipairs(Fx.calibration()) do
	if string.sub(b.name, 1, 3) == "C09" then
		c09 = b
	end
end
local function prepared(list)
	local out, kept = {}, {}
	for i, p in ipairs(list) do
		out[i] = Shapes.prepare({ id = i, slot = p.slot, shape = p.shape, material = p.material, pos = p.pos, rot = p.rot, size = p.size }, i)
		kept[i] = true
	end
	return out, kept
end
local base = c09.parts
local grips = {}
for i, p in ipairs(base) do
	if p.slot == "Grip" then
		table.insert(grips, i)
	end
end
print(fmt("C09 has %d Grip parts", #grips))
local P0, K0 = prepared(base)
local ref = MassProps.difficultyFrame(P0, K0, "Grip")
local differ, tried = 0, 0
local worst = 0
-- every permutation of the grip parts' places (the other parts stay put)
local function permute(a, n, visit)
	if n <= 1 then
		visit(a)
		return
	end
	for i = 1, n do
		permute(a, n - 1, visit)
		local j = if n % 2 == 0 then i else 1
		a[j], a[n] = a[n], a[j]
	end
end
local order = table.clone(grips)
permute(order, #order, function(perm)
	tried += 1
	local list = table.clone(base)
	for k, slotIndex in ipairs(grips) do
		list[slotIndex] = base[perm[k]]
	end
	local P, K = prepared(list)
	local pt = MassProps.difficultyFrame(P, K, "Grip")
	for c = 1, 3 do
		if pt[c] ~= ref[c] then
			differ += 1
			worst = math.max(worst, math.abs(pt[c] - ref[c]))
			break
		end
	end
end)
print(fmt("difficultyFrame point: %d of %d orders of C09's grip parts differ in some bit (max |d| %.3g); reference y %.17g",
	differ, tried, worst, ref[2]))
