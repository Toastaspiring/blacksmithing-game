--!nocheck
-- every Block of a design described another way (its X and Y sizes swapped, a quarter turn about its own Z): the same
-- solids; the verdicts, and the units against the cap
local L = require("./lib")
local Worst = require("./repo/docs/spec/prototypes/S2/cover/worst_designs")
local fmt = string.format
local Quat = L.Quat
local function redescribe(parts)
	local out = L.copyParts(parts)
	for _, p in ipairs(out) do
		if p.shape == "Block" then
			local q = Quat.hemisphere(Quat.normalize(Quat.mul(p.rot, L.Z90)))
			p.rot = { q[1], q[2], q[3], q[4] }
			p.size = { p.size[2], p.size[1], p.size[3] }
		end
	end
	return out
end
local designs = {}
for _, d in ipairs(Worst.valid) do table.insert(designs, { d.name, d.parts }) end
for _, pre in ipairs({ "P1", "P3", "C09", "C05" }) do
	local parts, name = L.fixture(pre)
	table.insert(designs, { name, parts })
end
for _, id in ipairs({ "F1", "F5" }) do table.insert(designs, { id, L.repoFixture(id) }) end
for _, d in ipairs(designs) do
	local a = L.renumber(L.copyParts(d[2]))
	local b = L.renumber(redescribe(a))
	local Pa, Pb = L.prep(a), L.prep(b)
	local ua, ub = L.units(Pa), L.units(Pb)
	local ea, eb = L.Sampling.exposure(Pa), L.Sampling.exposure(Pb)
	local vd = 0
	for i = 1, #a do if ea.kept[i] ~= eb.kept[i] then vd += 1 end end
	local okb = L.canonical(L.copyParts(b))
	print(fmt("%-44s units %10.3f -> %10.3f (%+.2f%%), verdicts differing %d, canonical %s", string.sub(d[1], 1, 44), ua, ub, 100 * (ub / ua - 1), vd, tostring(okb)))
end
