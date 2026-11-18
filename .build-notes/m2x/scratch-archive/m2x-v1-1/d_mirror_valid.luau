--!nocheck
local L = require("./lib")
local Worst = require("./repo/docs/spec/prototypes/S2/cover/worst_designs")
local fmt = string.format
for _, k in ipairs({ 2, 3, 4 }) do
	local parts = L.renumber(L.copyParts(Worst.valid[k].parts))
	for _, plane in ipairs({ "none", "X", "Z" }) do
		local ps = parts
		if plane ~= "none" then
			ps = {}
			for i, p in ipairs(parts) do ps[i] = L.Mirror.reflect(p, plane) end
			L.renumber(ps)
		end
		local core = { schema = 1, name = "x", type = "Sword", parts = L.copyParts(ps) }
		local ok = L.Canonical.isCanonical(core)
		local r = L.Analyze.run(core)
		local e = L.Sampling.exposure(L.prep(ps))
		print(fmt("worst valid %d, mirror %s: canonical %s, units %.1f, valid %s %s", k, plane, tostring(ok), e.verdictWork, tostring(r.validation.ok), L.codes(r)))
	end
end
