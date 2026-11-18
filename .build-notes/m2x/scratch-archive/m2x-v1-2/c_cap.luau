--!nocheck
-- the cap on worst_designs.luau: units (Sampling's verdictWork and the uncapped loop), validity, units in 20 random
-- orders, the X and Z mirror images
local L = require("./lib")
local Worst = require("./repo/docs/spec/prototypes/S2/cover/worst_designs")
local TestRng = require("./repo/tests/lib/TestRng")
local fmt = string.format
local CAP = L.Geo.VERDICT_WORK_MAX
local rng = TestRng.new(5)
local function shuffled(list)
	local out = table.clone(list)
	for i = #out, 2, -1 do
		local j = rng:int(1, i)
		out[i], out[j] = out[j], out[i]
	end
	return out
end
local function mirror(parts, axis)
	local core = { schema = 1, name = "x", type = "Sword", parts = L.copyParts(parts) }
	local m = L.Mirror.design and L.Mirror.design(core, axis) or nil
	return m
end
print("Mirror API:", (function() local t = {} for k in pairs(L.Mirror) do table.insert(t, k) end table.sort(t) return table.concat(t, " ") end)())
for _, set in ipairs({ "valid", "tooComplex" }) do
	for _, d in ipairs(Worst[set]) do
		local parts = L.copyParts(d.parts)
		L.renumber(parts)
		local P = L.prep(parts)
		local e = L.Sampling.exposure(P)
		local u = L.units(P)
		local r = L.run(L.copyParts(parts), { measureInvalid = false })
		local same = true
		local orders = 0
		for k = 1, (set == "valid" and 20 or 3) do
			local sp = shuffled(parts)
			local Ps = L.prep(L.renumber(L.copyParts(sp)))
			local es = L.Sampling.exposure(Ps)
			local us = L.units(Ps)
			orders += 1
			if us ~= u or es.capped ~= e.capped or (not e.capped and es.verdictWork ~= e.verdictWork) then
				same = false
				print(fmt("   ORDER DIFFERS: %s %.3f vs %.3f, capped %s vs %s", d.name, us, u, tostring(es.capped), tostring(e.capped)))
			end
		end
		print(fmt("%s %-48s stated %10.3f  uncapped %10.3f  verdictWork %10.3f capped %-5s valid %-5s %s; %d orders same %s",
			set, string.sub(d.name, 1, 48), d.units, u, e.verdictWork, tostring(e.capped), tostring(r.validation.ok), L.codes(r), orders, tostring(same)))
	end
end
