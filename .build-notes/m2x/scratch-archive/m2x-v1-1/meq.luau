--!nocheck
-- the measure against the tree before (the line reading), bit for bit, where the kept rows agree
local L = require("./lib")
local OS = require("./old/repo/src/shared/Physics/Sampling")
local OSh = require("./old/repo/src/shared/Physics/Shapes")
local Attacks = require("./repo/tests/Physics/CoverAttacks")
local fmt = string.format
local T = require("./tsets")
local designs = T.sets("real")
for _, d in ipairs(Attacks) do table.insert(designs, { name = d.name, parts = L.copyParts(d.parts) }) end
local agree, same, differ, rowsDiffer = 0, 0, 0, 0
for _, d in ipairs(designs) do
	local parts = L.renumber(d.parts)
	local P = L.prep(parts)
	local Q = {}
	for i, p in ipairs(parts) do Q[i] = OSh.prepare(p, i) end
	local a, b = L.Sampling.exposure(P), OS.exposure(Q)
	local rows = true
	for i = 1, #parts do if a.kept[i] ~= b.kept[i] then rows = false end end
	if rows then
		agree += 1
		local bit = a.hSurf == b.hSurf and a.surfSamples == b.surfSamples and a.subSampled == b.subSampled
		for i = 1, #parts do
			if a.exposedKept[i] ~= b.exposedKept[i] then bit = false end
			for j = 1, #parts do if a.contact[i][j] ~= b.contact[i][j] then bit = false end end
		end
		if bit then same += 1 else differ += 1; print("differs: " .. d.name) end
	else
		rowsDiffer += 1
	end
end
print(fmt("%d designs: kept rows agree on %d (measure bit-identical %d, differs %d); rows differ on %d", #designs, agree, same, differ, rowsDiffer))
