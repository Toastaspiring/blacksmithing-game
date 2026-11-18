--!nocheck
-- timing (median of 15, every design once a round): the verdict (Sampling with a return after it), the whole exposure,
-- Analyze.run, and the median run's longest checkpoint gap (from the start, between checkpoints, to the end); units. lune run t_time -- <set>
local process = require("@lune/process")
local fs = require("@lune/fs")
local serde = require("@lune/serde")
local L = require("./lib")
local SV = require("./vonly/src/shared/Physics/SamplingV")
local Worst = require("./repo/docs/spec/prototypes/S2/cover/worst_designs")
local fmt = string.format
local set = process.args[1] or "fixtures"
local designs = {}
if set == "fixtures" then
	for _, id in ipairs(L.Blueprints.order) do table.insert(designs, { id, L.repoFixture(id) }) end
	for _, list in ipairs({ L.Fx.calibration(), L.Fx.perf() }) do
		for _, b in ipairs(list) do if b.parts then table.insert(designs, { b.name, L.copyParts(b.parts) }) end end
	end
	for _, b in ipairs(L.Fx.regression()) do
		local f = b.fixture
		if f and f.parts then table.insert(designs, { f.name, L.copyParts(f.parts) }) end
	end
elseif set == "worst" then
	for _, d in ipairs(Worst.valid) do table.insert(designs, { d.name, L.copyParts(d.parts) }) end
	for _, d in ipairs(Worst.tooComplex) do table.insert(designs, { d.name, L.copyParts(d.parts) }) end
else
	for _, f in ipairs(string.split(set, ",")) do
		local parts = serde.decode("json", fs.readFile(f))
		table.insert(designs, { f, parts })
	end
end
local rows = {}
for k, d in ipairs(designs) do
	local parts = L.renumber(L.copyParts(d[2]))
	local P = L.prep(parts)
	rows[k] = { name = d[1], parts = parts, P = P, core = { schema = 1, name = "x", type = "Sword", parts = parts }, v = {}, e = {}, a = {}, g = {} }
end
for round = 1, 15 do
	for _, r in ipairs(rows) do
		local t0 = os.clock()
		SV.exposure(r.P)
		local t1 = os.clock()
		local ex = L.Sampling.exposure(r.P)
		local t2 = os.clock()
		local last, worst = os.clock(), 0
		local t3 = os.clock()
		L.Analyze.run(r.core, { checkpoint = function()
			local now = os.clock()
			if now - last > worst then worst = now - last end
			last = now
		end })
		local t4 = os.clock()
		if t4 - last > worst then -- the stretch after the last checkpoint, to the run's end
			worst = t4 - last
		end
		table.insert(r.v, (t1 - t0) * 1000)
		table.insert(r.e, (t2 - t1) * 1000)
		table.insert(r.a, (t4 - t3) * 1000)
		table.insert(r.g, worst * 1000)
		r.units, r.capped = ex.verdictWork, ex.capped
	end
end
local function med(t) table.sort(t) return t[8] end
for _, r in ipairs(rows) do
	print(fmt("%-56s units %10.1f%s  verdict %6.2f  exposure %6.2f  run %6.2f  gap %.3f ms", string.sub(tostring(r.name), 1, 56), r.units, r.capped and " (cap)" or "", med(r.v), med(r.e), med(r.a), med(r.g)))
end
