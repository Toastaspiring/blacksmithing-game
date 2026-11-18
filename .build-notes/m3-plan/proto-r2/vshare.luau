--!nocheck
-- m3-plan-r2: the verdict's share of Analyze.run (§4.9, §16.10's VERDICT_WORK_MAX row), cover/fix3/timing.luau's way:
-- the verdict alone (SamplingV: the snapshot's Sampling returning right after the verdict, made by sed from
-- proto/SamplingV.luau.txt and put beside Sampling in the repo copy for the run), the whole exposure, Analyze.run.
-- Medians of n rounds, every design once a round, forwards then backwards, collectgarbage before each timed call.
--   cp proto/SamplingV.luau.txt repo/src/shared/Physics/SamplingV.luau; lune run <abs>/proto/vshare.luau -- [rounds]
local L = require("./lib")
local process = require("@lune/process")
local Analyze = require("../repo/src/shared/Physics/Analyze")
local Sampling = require("../repo/src/shared/Physics/Sampling")
local SamplingV = require("../repo/src/shared/Physics/SamplingV")
local Shapes = require("../repo/src/shared/Physics/Shapes")
local Worst = require("../repo/docs/spec/prototypes/S2/cover/worst_designs")
local fmt = string.format

local ROUNDS = tonumber(process.args[1]) or 15
local list = {}
for _, id in ipairs({ "F5", "C02", "C05", "C09", "P1", "P2", "P3", "P4", "P5" }) do
	table.insert(list, { name = id, parts = L.find(id).parts })
end
for k, d in ipairs(Worst.valid) do
	table.insert(list, { name = fmt("valid %d %s", k, string.sub(d.name, 1, 16)), parts = d.parts })
end
for _, it in ipairs(list) do
	it.P = {}
	for i, p in ipairs(it.parts) do
		it.P[i] = Shapes.prepare(p, i)
	end
	it.core = { schema = 1, name = "x", type = "Sword", parts = it.parts }
	it.v, it.e, it.a = {}, {}, {}
	it.units = SamplingV.exposure(it.P).verdictWork
end
local function median(t)
	local c = table.clone(t)
	table.sort(c)
	return c[(#c + 1) // 2]
end
for r = 1, ROUNDS do
	local from, to, step = 1, #list, 1
	if r % 2 == 0 then
		from, to, step = #list, 1, -1
	end
	for i = from, to, step do
		local it = list[i]
		collectgarbage("collect")
		local t0 = os.clock()
		SamplingV.exposure(it.P)
		table.insert(it.v, (os.clock() - t0) * 1000)
		collectgarbage("collect")
		t0 = os.clock()
		Sampling.exposure(it.P)
		table.insert(it.e, (os.clock() - t0) * 1000)
		collectgarbage("collect")
		t0 = os.clock()
		Analyze.run(it.core)
		table.insert(it.a, (os.clock() - t0) * 1000)
	end
end
print(fmt("%d rounds, medians, ms Lune 0.8.9", ROUNDS))
print(fmt("%-28s %10s %8s %9s %8s", "design", "units", "verdict", "exposure", "run"))
for _, it in ipairs(list) do
	print(fmt("%-28s %10.1f %8.2f %9.2f %8.2f", it.name, it.units, median(it.v), median(it.e), median(it.a)))
end
