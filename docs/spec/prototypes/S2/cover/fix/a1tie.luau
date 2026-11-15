--!nocheck
-- V1's a1_tie.luau on the build: two Cylinders 0.6 × 0.24 × 0.24 in the Blade, one spun about its own axis on the other,
-- at axes whose two smallest components tie; the lower of their 2 readings, and how often both are kept
local L = require("./lab")
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
	local ax, ay, az = 0, -dz, dy
	return axisAngle(ax, ay, az, math.deg(math.acos(dx)))
end
local cases = { { "(1,1,1)", toDir(1, 1, 1) }, { "(1,1,2)", toDir(1, 1, 2) }, { "(2,1,1)", toDir(2, 1, 1) },
	{ "two 45 snaps", Quat.hemisphere(Quat.normalize(Quat.mul(axisAngle(1, 0, 0, 45), axisAngle(0, 0, 1, 45)))) } }
for _, c in ipairs(cases) do
	local q = c[2]
	local worst, worstAng, n, both = 0, 0, 0, 0
	for ang = 1, 359, 2 do
		local spun = Quat.hemisphere(Quat.normalize(Quat.mul(q, axisAngle(1, 0, 0, ang))))
		local parts = { { id = 1, slot = "Blade", shape = "Cylinder", material = "Iron", pos = { 0, 2, 0 }, rot = q, size = { 0.6, 0.24, 0.24 } },
			{ id = 2, slot = "Blade", shape = "Cylinder", material = "Iron", pos = { 0, 2, 0 }, rot = spun, size = { 0.6, 0.24, 0.24 } } }
		local P = L.prepared(parts)
		local lo = math.min((L.H.reads(P, 1)), (L.H.reads(P, 2)))
		n += 1
		if lo > worst then worst, worstAng = lo, ang end
		local e = L.Sampling.exposure(P)
		if e.kept[1] and e.kept[2] then both += 1 end
	end
	print(fmt("%-14s spins %d: the lower reading at worst %.3f%% (spin %d), both kept in %d", c[1], n, 100 * worst, worstAng, both))
end
