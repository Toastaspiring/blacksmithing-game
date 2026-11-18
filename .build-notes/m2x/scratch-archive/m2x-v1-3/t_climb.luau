--!nocheck
-- a climb on Analyze.run's wall time (median of 3) under VERDICT_WORK_MAX: canonical, valid designs only; starts from
-- worst_designs.luau's valid designs and the rod bundle; mutations move, resize, turn, reslot or reshape a part, or copy one
-- next to another. lune run t_climb -- <seed> <evals>
local process = require("@lune/process")
local L = require("./lib")
local Worst = require("./repo/docs/spec/prototypes/S2/cover/worst_designs")
local TestRng = require("./repo/tests/lib/TestRng")
local serde = require("@lune/serde")
local fmt = string.format
local seed, evals = tonumber(process.args[1]) or 1, tonumber(process.args[2]) or 300
local rng = TestRng.new(seed)
local CAP = L.Geo.VERDICT_WORK_MAX
local SHAPES = { "Block", "Wedge", "CornerWedge", "Cylinder", "Ball" }
local SLOTS = { "Blade", "Guard", "Grip", "Pommel" }
local function timeRun(core, n)
	local ts = {}
	for k = 1, n do
		local t0 = os.clock()
		L.Analyze.run(core)
		table.insert(ts, os.clock() - t0)
	end
	table.sort(ts)
	return ts[(n + 1) // 2] * 1000
end
local function evaluate(parts)
	L.renumber(parts)
	if not L.canonical(L.copyParts(parts)) then return -1 end
	local P = L.prep(parts)
	local u = L.units(P)
	if u > CAP then return -1 end
	local core = { schema = 1, name = "x", type = "Sword", parts = parts }
	local r = L.Analyze.run(core)
	if not r.validation.ok then return -1 end
	return timeRun(core, 5), u
end
local function fix(p)
	for a = 1, 3 do p.size[a] = math.max(0.02, math.min(6, p.size[a])) end
	if p.shape == "Ball" then
		local m = math.min(p.size[1], p.size[2], p.size[3])
		p.size = { m, m, m }
	elseif p.shape == "Cylinder" then
		local m = math.min(p.size[2], p.size[3])
		p.size[2], p.size[3] = m, m
	end
end
local function mutate(parts)
	local out = L.copyParts(parts)
	local p = out[rng:int(1, #out)]
	local m = rng:int(1, 7)
	if m == 1 then
		p.pos[rng:int(1, 3)] += rng:normal(0, 0.03)
	elseif m == 2 then
		local a = rng:int(1, 3)
		p.size[a] *= rng:range(0.85, 1.15)
	elseif m == 3 then
		local q = L.Quat.mul(p.rot, L.axisAngle(rng:normal(0, 1), rng:normal(0, 1), rng:normal(0, 1), rng:normal(0, 15)))
		local r = L.Quat.hemisphere(L.Quat.normalize(q))
		p.rot = { r[1], r[2], r[3], r[4] }
	elseif m == 4 then
		p.slot = rng:pick(SLOTS)
	elseif m == 5 then
		p.shape = rng:pick(SHAPES)
	elseif m == 6 then
		local q = out[rng:int(1, #out)]
		p.pos = { q.pos[1] + rng:normal(0, 0.04), q.pos[2] + rng:normal(0, 0.04), q.pos[3] + rng:normal(0, 0.02) }
	else
		for _, x in ipairs(out) do x.pos[2] += 0 end
		p.size = { p.size[1] * rng:range(0.9, 1.1), p.size[2] * rng:range(0.9, 1.1), p.size[3] * rng:range(0.9, 1.1) }
	end
	fix(p)
	for a = 1, 3 do p.pos[a] = math.max(-15, math.min(15, p.pos[a])) end
	return out
end
local starts = {}
for _, d in ipairs(Worst.valid) do table.insert(starts, L.copyParts(d.parts)) end
local start = starts[(seed - 1) % #starts + 1]
if seed >= 10 then
	start = starts[1]
end
local best = L.copyParts(start)
local bestT, bestU = evaluate(best)
print(fmt("seed %d start %.2f ms, %.0f units", seed, bestT, bestU or 0))
-- paired: the candidate and the current best timed alternately, 4 runs each, so that load drifts out of the comparison
local function core(parts) return { schema = 1, name = "x", type = "Sword", parts = parts } end
for e = 1, evals do
	local c = mutate(best)
	local t, u = evaluate(c)
	if t > 0 then
		local a, b = {}, {}
		local ca, cb = core(c), core(best)
		for k = 1, 4 do
			local t0 = os.clock(); L.Analyze.run(ca); local t1 = os.clock(); L.Analyze.run(cb); local t2 = os.clock()
			table.insert(a, t1 - t0); table.insert(b, t2 - t1)
		end
		table.sort(a); table.sort(b)
		if (a[2] + a[3]) > 1.02 * (b[2] + b[3]) then
			best, bestU = c, u
			bestT = (a[2] + a[3]) / 2 * 1000
		end
	end
	if e % 50 == 0 then print(fmt("  eval %d best %.2f ms (%.0f units)", e, bestT, bestU)) end
end
print(fmt("seed %d: best %.2f ms Analyze.run (median of 3, under load), %.0f units", seed, bestT, bestU))
print("BEST " .. serde.encode("json", best))
-- re-time the best alone: the verdict (a copy of Sampling that returns after it), the whole exposure, Analyze.run;
-- median of 15
local SV = require("./vonly/src/shared/Physics/SamplingV")
local function med(f)
	local ts = {}
	for k = 1, 15 do
		local t0 = os.clock()
		f()
		table.insert(ts, os.clock() - t0)
	end
	table.sort(ts)
	return ts[8] * 1000
end
L.renumber(best)
local P = L.prep(best)
local core = { schema = 1, name = "x", type = "Sword", parts = best }
local vms = med(function() SV.exposure(P) end)
local ems = med(function() L.Sampling.exposure(P) end)
local ams = med(function() L.Analyze.run(core) end)
print(fmt("seed %d re-timed (median of 15): verdict %.2f ms, exposure %.2f, Analyze.run %.2f; %.0f units", seed, vms, ems, ams, bestU))
