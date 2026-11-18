--!nocheck
-- units of a design and of its mirror images across X and Z, and in shuffled orders
local L = require("./lib")
local T = require("./tsets")
local Worst = require("./repo/docs/spec/prototypes/S2/cover/worst_designs")
local fmt = string.format
local designs = { { name = "P1", parts = L.fixture("P1") }, { name = "P4", parts = L.fixture("P4") }, { name = "C09", parts = L.fixture("C09") } }
for k, d in ipairs(Worst.valid) do table.insert(designs, { name = "worst valid " .. k, parts = L.copyParts(d.parts) }) end
table.insert(designs, { name = "V1 cluster", parts = T.cluster(0.54, 0.05803, 0.25, 0.3) })
math.randomseed(7)
for _, d in ipairs(designs) do
	local parts = L.renumber(d.parts)
	local u0 = L.Sampling.exposure(L.prep(parts)).verdictWork
	local out = {}
	for _, plane in ipairs({ "X", "Z" }) do
		local img = {}
		for i, p in ipairs(parts) do img[i] = L.Mirror.reflect(p, plane) end
		L.renumber(img)
		local e = L.Sampling.exposure(L.prep(img))
		table.insert(out, fmt("%s %+.1f", plane, e.verdictWork - u0))
	end
	local same = true
	for _ = 1, 5 do
		local sh = L.copyParts(parts)
		for i = #sh, 2, -1 do local j = math.random(1, i); sh[i], sh[j] = sh[j], sh[i] end
		L.renumber(sh)
		if L.Sampling.exposure(L.prep(sh)).verdictWork ~= u0 then same = false end
	end
	print(fmt("%-16s units %.1f; mirrors: %s; 5 shuffles the same units: %s", d.name, u0, table.concat(out, ", "), tostring(same)))
end
