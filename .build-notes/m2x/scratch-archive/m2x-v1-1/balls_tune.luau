--!nocheck
-- ball clusters tuned just under VERDICT_WORK_MAX, then timed against the slowest worst valid design (same conditions)
local L = require("./lib")
local T = require("./tsets")
local SV = require("./tim/SamplingV")
local Worst = require("./repo/docs/spec/prototypes/S2/cover/worst_designs")
local fmt = string.format
local function med(t) table.sort(t) return t[(#t + 1) // 2] end
local found = {}
for _, d in ipairs({ 0.58, 0.54, 0.5, 0.46 }) do
	for _, ax in ipairs({ 0.2, 0.1, 0.25 }) do
		-- bisection on dy for units just under the cap
		local lo, hi = 0.05, 0.2
		local bestParts, bestUnits = nil, 0
		for _ = 1, 22 do
			local dy = (lo + hi) / 2
			local parts = T.cluster(d, dy, ax, 0.3)
			local P = L.prep(parts)
			local e = SV.exposure(P)
			if e.capped then lo = dy else
				hi = dy
				if e.verdictWork > bestUnits then bestUnits, bestParts = e.verdictWork, parts end
			end
		end
		if bestParts then
			local r = L.run(L.copyParts(bestParts), { measureInvalid = false })
			table.insert(found, { name = fmt("d %.2f ax %.2f dy %.5f", d, ax, hi), parts = bestParts, units = bestUnits, valid = r.validation.ok })
		end
	end
end
local designs = { { name = "worst valid 1", parts = L.copyParts(Worst.valid[1].parts) }, { name = "worst valid 3", parts = L.copyParts(Worst.valid[3].parts) } }
for _, f in ipairs(found) do if f.valid then table.insert(designs, f) end end
for _, d in ipairs(designs) do
	local parts = L.renumber(d.parts)
	local core = { schema = 1, name = "x", type = "Sword", parts = parts }
	local P = L.prep(parts)
	local tv, te, tr = {}, {}, {}
	local units
	for k = 1, 15 do
		local a = os.clock(); local e = SV.exposure(P); tv[k] = (os.clock() - a) * 1000; units = e.verdictWork
		a = os.clock(); L.Sampling.exposure(P); te[k] = (os.clock() - a) * 1000
		a = os.clock(); L.Analyze.run(core, { measureInvalid = false }); tr[k] = (os.clock() - a) * 1000
	end
	print(fmt("%-28s units %9.0f verdict med %6.2f best %6.2f (%.1f ns/unit)  exposure %6.2f  run %6.2f", d.name, units, med(table.clone(tv)), math.min(table.unpack(tv)), med(table.clone(tv)) / units * 1e6, med(te), med(tr)))
end
