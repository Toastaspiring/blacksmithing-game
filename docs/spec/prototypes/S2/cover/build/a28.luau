--!nocheck
local L = require("./lib")
local Analyze = require("../snapcap/src/shared/Physics/Analyze")
local Z90 = { 0, 0, 0.70710678118654757, 0.70710678118654757 }
local parts = {}
for i = 1, 24 do
	local slot, y = "Blade", 2.55
	if i > 12 and i <= 18 then slot, y = "Guard", 2.5 elseif i > 18 then slot, y = "Grip", 2.45 end
	parts[i] = { id = i, shape = "Cylinder", slot = slot, material = "Iron", pos = { 0.004 * ((i - 1) % 8), y, 0.01 * ((i - 1) // 8) }, rot = Z90, size = { 1.2, 0.02, 0.02 } }
end
local core = { schema = 1, name = "A28", type = "Sword", parts = parts }
local res = L.Canonical.draft(core)
print("canonical", res.ok, L.Canonical.isCanonical(core))
local P = L.prep(parts)
local e = L.SamplingV.exposure(P, nil)
print("units", e.verdictWork)
local t0 = os.clock()
local run = Analyze.run(core)
print("ms", (os.clock() - t0) * 1000)
for _, er in ipairs(run.validation.errors) do print(er.code, er.partId, er.slot, er.reason) end
print("quick", Analyze.quick(core, { connectivity = true }).ok)
