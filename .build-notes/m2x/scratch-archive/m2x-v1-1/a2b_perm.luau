--!nocheck
-- A2b: the same solid described another way: a Block's size permuted with a quarter turn, a Cylinder spun about its axis or
-- turned end for end, a Ball turned; in the Guard or as Pommel, against a Blade part. Which one keeps the faces?
local L = require("./lib")
local Quat = L.Quat
local fmt = string.format
local function analyse(parts)
	L.renumber(parts)
	local P = L.prep(parts)
	local e = L.Sampling.exposure(P)
	local cl = {}
	for _, c in ipairs(e.cleaned) do table.insert(cl, c.partId) end
	return e, table.concat(cl, " ")
end
local base = L.repoFixture("F3")
local R0 = L.emu(L.copyParts(base))
local blade = base[6] -- 0.07 x 3.4 x 0.035, identity
local variants = {
	-- size (x,y,z) -> rotate so that the world solid is the same
	{ "size (0.035, 3.4, 0.07), 90° about Y", { 0.035, 3.4, 0.07 }, L.axisAngle(0, 1, 0, 90) },
	{ "size (3.4, 0.07, 0.035), 90° about Z", { 3.4, 0.07, 0.035 }, L.axisAngle(0, 0, 1, 90) },
	{ "size (0.035, 3.4, 0.07), -90° about Y", { 0.035, 3.4, 0.07 }, L.axisAngle(0, 1, 0, -90) },
	{ "size (3.4, 0.035, 0.07), 90° about X then Z", { 3.4, 0.035, 0.07 }, Quat.hemisphere(Quat.normalize(Quat.mul(L.axisAngle(0, 0, 1, 90), L.axisAngle(1, 0, 0, 90)))) },
}
for _, v in ipairs(variants) do
	local parts = L.copyParts(base)
	local c = L.copyPart(blade)
	c.slot, c.size, c.rot = "Guard", { v[2][1], v[2][2], v[2][3] }, v[3]
	table.insert(parts, c)
	local P = L.prep(L.renumber(L.copyParts(parts)))
	local a, b = P[6], P[8]
	local same = math.abs(a.minx - b.minx) + math.abs(a.maxx - b.maxx) + math.abs(a.miny - b.miny) + math.abs(a.maxy - b.maxy) + math.abs(a.minz - b.minz) + math.abs(a.maxz - b.maxz)
	local e, cl = analyse(parts)
	local R = L.emu(L.copyParts(parts))
	local d, t = L.dDiff(R0, R)
	print(fmt("%-44s box diff %.1e vol %.17g vs %.17g  cleaned {%s}  %s  |dD| %.4f flip %s", v[1], same, a.volume, b.volume, cl, L.dline(R), d, tostring(t)))
end
-- round parts: the F3 grip (Cylinder along Y) spun, as Pommel; F3's pommel Ball turned, as Guard
local function roundCopy(idx, slot, rot, what)
	local parts = L.copyParts(base)
	local c = L.copyPart(base[idx])
	c.slot, c.rot = slot, rot
	table.insert(parts, c)
	local e, cl = analyse(parts)
	local R = L.emu(L.copyParts(parts))
	local d, t = L.dDiff(R0, R)
	print(fmt("%-44s cleaned {%s}  %s  |dD| %.4f flip %s", what, cl, L.dline(R), d, tostring(t)))
end
roundCopy(2, "Pommel", Quat.hemisphere(Quat.normalize(Quat.mul(base[2].rot, L.axisAngle(1, 0, 0, 37)))), "grip spun 37° as Pommel")
roundCopy(1, "Guard", L.axisAngle(1, 2, 3, 77), "pommel Ball turned 77° as Guard")
roundCopy(1, "Blade", L.axisAngle(1, 2, 3, 77), "pommel Ball turned 77° as Blade")
