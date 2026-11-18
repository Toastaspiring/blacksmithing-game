--!nocheck
-- verdict (SamplingV, cut after the verdict), whole exposure and Analyze.run: median of RUNS and best, units, ns a unit
local process = require("@lune/process")
local L = require("./lib")
local T = require("./tsets")
local SV = require("./tim/SamplingV")
local fmt = string.format
local RUNS = tonumber(process.args[1]) or 15
local which = process.args[2] or "perf"
local function med(t) table.sort(t) return t[(#t + 1) // 2] end
print(fmt("%-34s %9s %8s %8s %8s %8s %8s %8s", "design", "units", "V med", "V best", "ns/unit", "Exp med", "Run med", "valid"))
for _, d in ipairs(T.sets(which)) do
	local parts = L.renumber(d.parts)
	local core = { schema = 1, name = "x", type = "Sword", parts = parts }
	local P = L.prep(parts)
	local units = 0
	local tv, te, tr = {}, {}, {}
	local res
	for k = 1, RUNS do
		local a = os.clock()
		local e = SV.exposure(P)
		tv[k] = (os.clock() - a) * 1000
		units = e.verdictWork
		a = os.clock()
		L.Sampling.exposure(P)
		te[k] = (os.clock() - a) * 1000
		a = os.clock()
		res = L.Analyze.run(core, { measureInvalid = false })
		tr[k] = (os.clock() - a) * 1000
	end
	local best = math.huge
	for _, v in ipairs(tv) do best = math.min(best, v) end
	local mv = med(table.clone(tv))
	print(fmt("%-34s %9.0f %8.2f %8.2f %8.1f %8.2f %8.2f %s", string.sub(d.name, 1, 34), units, mv, best, mv / units * 1e6, med(table.clone(te)), med(table.clone(tr)), if res.validation.ok then "valid" else L.codes(res)))
end
