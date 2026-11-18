--!nocheck
-- units of worst_designs.luau's valid designs, P1–P5 and C09 on this tree (L.units, the cap lifted)
local L = require("./lib")
local Worst = require("./repo/docs/spec/prototypes/S2/cover/worst_designs")
local fmt = string.format
for _, d in ipairs(Worst.valid) do
	local parts = L.renumber(L.copyParts(d.parts))
	print(fmt("%-40s units %12.3f (file %12.3f)%s", string.sub(d.name, 1, 40), L.units(L.prep(parts)), d.units,
		if L.units(L.prep(parts)) > L.Geo.VERDICT_WORK_MAX then "  PAST THE CAP" else ""))
end
for _, n in ipairs({ "P1", "P2", "P3", "P4", "P5", "C09" }) do
	local parts = L.renumber(L.fixture(n))
	print(fmt("%-40s units %12.3f", n, L.units(L.prep(parts))))
end
