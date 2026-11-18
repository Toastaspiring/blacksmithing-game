--!nocheck
-- the cap's mirror boundary: worst_designs.luau's valid designs and P1–P5, their X and Z images (canonicalized): units and
-- validity
local L = require("./lib")
local Worst = require("./repo/docs/spec/prototypes/S2/cover/worst_designs")
local fmt = string.format
local CAP = L.Geo.VERDICT_WORK_MAX
local function image(parts, plane)
	local out = {}
	for i, p in ipairs(parts) do
		out[i] = L.Mirror.reflect(L.copyPart(p), plane)
	end
	local core = { schema = 1, name = "x", type = "Sword", parts = out }
	local ok, c = pcall(L.Canonical.canonicalize, core)
	if ok and c then
		return c.parts or out
	end
	return out
end
print("Canonical API:", (function() local t = {} for k in pairs(L.Canonical) do table.insert(t, k) end table.sort(t) return table.concat(t, " ") end)())
local designs = {}
for _, d in ipairs(Worst.valid) do table.insert(designs, { d.name, d.parts }) end
for _, pre in ipairs({ "P1", "P2", "P3", "P4", "P5" }) do
	local parts, name = L.fixture(pre)
	table.insert(designs, { name, parts })
end
for _, d in ipairs(designs) do
	local parts = L.renumber(L.copyParts(d[2]))
	local u0 = L.units(L.prep(parts))
	local row = { fmt("%-44s %10.3f", string.sub(d[1], 1, 44), u0) }
	for _, plane in ipairs({ "X", "Z" }) do
		local im = L.renumber(L.copyParts(image(parts, plane)))
		local ok = L.canonical(L.copyParts(im))
		local u = L.units(L.prep(im))
		local r = L.run(L.copyParts(im), { measureInvalid = false })
		table.insert(row, fmt("%s %10.3f (%+.1f%%) %s%s", plane, u, 100 * (u / u0 - 1), u > CAP and "PAST" or "under", r.validation.ok and "" or (" " .. L.codes(r))))
	end
	print(table.concat(row, " | "))
end
