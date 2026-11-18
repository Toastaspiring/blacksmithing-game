--!nocheck
-- V1's wall-time climb on the verdict (SamplingV, median of 3) under VERDICT_WORK_MAX, from dense ball clusters and the
-- builder's worst valid designs; canonical, V1–V3 valid. args: seed evals start(balls|worst|mix) out
local process = require("@lune/process")
local fs = require("@lune/fs")
local L = require("./lib")
local T = require("./tsets")
local SV = require("./tim/SamplingV")
local Worst = require("./repo/docs/spec/prototypes/S2/cover/worst_designs")
local fmt = string.format
local seed = tonumber(process.args[1]) or 1
local EVALS = tonumber(process.args[2]) or 800
local start = process.args[3] or "balls"
local OUT = process.args[4] or ("out/climb_v1_" .. seed .. ".luau")
math.randomseed(seed)
local CAP = L.Geo.VERDICT_WORK_MAX
local function med3(P)
	local t = {}
	local units
	for k = 1, 3 do
		local a = os.clock()
		local e = SV.exposure(P)
		t[k] = (os.clock() - a) * 1000
		units = e.verdictWork
		if e.capped then return -1, units end
	end
	table.sort(t)
	return t[2], units
end
local function valid(parts)
	L.renumber(parts)
	local core = { schema = 1, name = "c", type = "Sword", parts = parts }
	local ok, c = pcall(L.Canonical.isCanonical, core)
	if not ok or not c then return false end
	local ok2, r = pcall(L.Analyze.quick, core, { connectivity = true })
	return ok2 and r.ok
end
local function fits(p)
	local mn, mx = L.Shapes.aabb(p)
	return mn[1] >= -0.8 and mx[1] <= 0.8 and mn[2] >= 0 and mx[2] <= 5 and mn[3] >= -0.3 and mx[3] <= 0.3
end
local starts = {}
if start == "balls" or start == "mix" then
	for _, cfg in ipairs({ { 0.54, 0.25, 0.05803 }, { 0.54, 0.10, 0.08969 }, { 0.50, 0.20, 0.06098 }, { 0.58, 0.10, 0.09689 } }) do
		table.insert(starts, T.cluster(cfg[1], cfg[3], cfg[2], 0.3))
	end
end
if start == "worst" or start == "mix" then
	for k = 1, 4 do table.insert(starts, L.copyParts(Worst.valid[k].parts)) end
end
local function mutate(parts)
	local q = L.copyParts(parts)
	for _ = 1, math.random(1, 3) do
		local p = q[math.random(1, #q)]
		local u = math.random()
		if u < 0.45 then
			local k = math.random(1, 3)
			p.pos[k] += (math.random() - 0.5) * (if k == 3 then 0.02 else 0.06)
		elseif u < 0.75 then
			local f = 1 + (math.random() - 0.5) * 0.12
			if p.shape == "Ball" then
				local d = math.min(0.6, p.size[1] * f)
				p.size = { d, d, d }
			else
				local k = math.random(1, 3)
				p.size[k] = math.max(0.02, p.size[k] * f)
				if p.shape == "Cylinder" and k > 1 then p.size[2], p.size[3] = p.size[k], p.size[k] end
			end
		else
			local o = q[math.random(1, #q)]
			if o ~= p then
				p.pos = { o.pos[1] + (math.random() - 0.5) * 0.1, o.pos[2] + (math.random() - 0.5) * 0.1, o.pos[3] + (math.random() - 0.5) * 0.02 }
			end
		end
		if not fits(p) then return nil end
	end
	return q
end
local bestAll, bestParts, bestUnits = 0, nil, 0
local evals = 0
local t0 = os.clock()
while evals < EVALS do
	local parts = L.copyParts(starts[math.random(1, #starts)])
	local s, u = med3(L.prep(L.renumber(parts)))
	evals += 1
	local stale = 0
	while stale < 120 and evals < EVALS do
		local q = mutate(parts)
		if q and valid(q) then
			local s2, u2 = med3(L.prep(q))
			evals += 1
			if s2 > s then parts, s, u, stale = q, s2, u2, 0 else stale += 1 end
		else
			stale += 1
		end
	end
	if s > bestAll then bestAll, bestParts, bestUnits = s, parts, u end
	print(fmt("seed %d evals %d: run best %.2f ms (%.0f units); overall %.2f ms (%.0f units) (%.0f s)", seed, evals, s, u, bestAll, bestUnits, os.clock() - t0))
end
local lines = { "return {" }
for _, p in ipairs(bestParts) do
	table.insert(lines, fmt("\t{ id = %d, slot = %q, shape = %q, material = %q, pos = { %.17g, %.17g, %.17g }, rot = { %.17g, %.17g, %.17g, %.17g }, size = { %.17g, %.17g, %.17g } },",
		p.id, p.slot, p.shape, p.material, p.pos[1], p.pos[2], p.pos[3], p.rot[1], p.rot[2], p.rot[3], p.rot[4], p.size[1], p.size[2], p.size[3]))
end
table.insert(lines, "}")
fs.writeFile(OUT, table.concat(lines, "\n"))
print("saved " .. OUT)
