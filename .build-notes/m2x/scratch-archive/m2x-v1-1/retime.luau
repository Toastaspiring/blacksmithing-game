--!nocheck
local L = require("./lib")
local T = require("./tsets")
local SV = require("./tim/SamplingV")
local Worst = require("./repo/docs/spec/prototypes/S2/cover/worst_designs")
local fmt = string.format
local function med(t) table.sort(t) return t[(#t + 1) // 2] end
local designs = {
	{ name = "worst valid 1", parts = L.copyParts(Worst.valid[1].parts) },
	{ name = "worst valid 2", parts = L.copyParts(Worst.valid[2].parts) },
	{ name = "worst valid 3", parts = L.copyParts(Worst.valid[3].parts) },
	{ name = "P1", parts = L.fixture("P1") },
}
for k = 1, 4 do
	local ok, parts = pcall(require, "./out/climb_v1_" .. k)
	if ok then table.insert(designs, { name = "V1 climb " .. k, parts = L.copyParts(parts) }) end
end
table.insert(designs, { name = "V1 cluster d0.54 ax0.25", parts = T.cluster(0.54, 0.05803, 0.25, 0.3) })
for _, d in ipairs(designs) do
	local parts = L.renumber(d.parts)
	local core = { schema = 1, name = "x", type = "Sword", parts = parts }
	local P = L.prep(parts)
	local tv, te, tr = {}, {}, {}
	local units, res
	for k = 1, 15 do
		local a = os.clock(); local e = SV.exposure(P); tv[k] = (os.clock() - a) * 1000; units = e.verdictWork
		a = os.clock(); L.Sampling.exposure(P); te[k] = (os.clock() - a) * 1000
		a = os.clock(); res = L.Analyze.run(core, { measureInvalid = false }); tr[k] = (os.clock() - a) * 1000
	end
	local ok = L.canonical(L.copyParts(parts))
	print(fmt("%-24s units %9.0f verdict med %6.2f best %6.2f (%.1f ns/unit)  exposure %6.2f  run %6.2f  %s canonical %s", d.name, units, med(table.clone(tv)), math.min(table.unpack(tv)), med(table.clone(tv)) / units * 1e6, med(te), med(tr), if res.validation.ok then "valid" else L.codes(res), tostring(ok)))
end
