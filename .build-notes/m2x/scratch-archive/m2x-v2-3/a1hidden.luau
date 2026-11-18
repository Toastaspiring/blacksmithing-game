--!nocheck
-- V2 round 3: fix/a1tie.luau's tie-axis rods, the reading of the copy the rank puts second (the one that truly shows
-- nothing: it coincides with the other, which ranks higher), not the lower of the two readings.
local L = require("./repo/docs/spec/prototypes/S2/cover/fix/lab")
local Quat = L.Quat
local fmt = string.format
local function axisAngle(ax, ay, az, deg)
	local h = math.rad(deg) / 2
	local n = math.sqrt(ax * ax + ay * ay + az * az)
	return Quat.hemisphere(Quat.normalize({ ax / n * math.sin(h), ay / n * math.sin(h), az / n * math.sin(h), math.cos(h) }))
end
local function toDir(dx, dy, dz)
	local n = math.sqrt(dx * dx + dy * dy + dz * dz)
	dx, dy, dz = dx / n, dy / n, dz / n
	return axisAngle(0, -dz, dy, math.deg(math.acos(dx)))
end
local cases = { { "(1,1,1)", toDir(1, 1, 1) }, { "(1,1,2)", toDir(1, 1, 2) }, { "(2,1,1)", toDir(2, 1, 1) },
	{ "two 45 snaps", Quat.hemisphere(Quat.normalize(Quat.mul(axisAngle(1, 0, 0, 45), axisAngle(0, 0, 1, 45)))) } }
for _, c in ipairs(cases) do
	local q = c[2]
	local worstHidden, worstMin, at, keptHidden = 0, 0, 0, 0
	for ang = 1, 359, 2 do
		local spun = Quat.hemisphere(Quat.normalize(Quat.mul(q, axisAngle(1, 0, 0, ang))))
		local parts = { { id = 1, slot = "Blade", shape = "Cylinder", material = "Iron", pos = { 0, 2, 0 }, rot = q, size = { 0.6, 0.24, 0.24 } },
			{ id = 2, slot = "Blade", shape = "Cylinder", material = "Iron", pos = { 0, 2, 0 }, rot = spun, size = { 0.6, 0.24, 0.24 } } }
		local P = L.prepared(parts)
		local rank = L.Sampling.ranked(P)
		local hidden = if rank[1] > rank[2] then 1 else 2
		local h = L.H.reads(P, hidden)
		local m = math.min((L.H.reads(P, 1)), (L.H.reads(P, 2)))
		if h > worstHidden then
			worstHidden, at = h, ang
		end
		worstMin = math.max(worstMin, m)
		if L.Sampling.exposure(P).kept[hidden] then
			keptHidden += 1
		end
	end
	print(fmt("%-14s the lower-ranked copy reads at worst %.3f%% (spin %d), the lower of the 2 readings %.3f%%; it is kept in %d of 180", c[1], 100 * worstHidden, at, 100 * worstMin, keptHidden))
end
