--!nocheck
-- honest swords near the cap: every part kept (none hidden), canonical, valid; a climb on the verdict's units from rod
-- bundles, bead chains and mixes: lune run c_honest -- <seed> <evals>
local process = require("@lune/process")
local L = require("./lib")
local TestRng = require("./repo/tests/lib/TestRng")
local serde = require("@lune/serde")
local fmt = string.format
local seed, evals = tonumber(process.args[1]) or 1, tonumber(process.args[2]) or 300
local rng = TestRng.new(seed)
local CAP = L.Geo.VERDICT_WORK_MAX
local function evaluate(parts)
	L.renumber(parts)
	if not L.canonical(L.copyParts(parts)) then return -1, "noncanonical" end
	local P = L.prep(parts)
	local u = L.units(P)
	local r = L.run(L.copyParts(parts), { measureInvalid = true })
	local codes = L.codes(r)
	local onlyCap = (codes == "TooComplex")
	if not r.validation.ok and not onlyCap then return -1, codes end
	if onlyCap then
		-- past the cap: are all parts visible? read every verdict without the cap
		local models = L.models(P)
		for i = 1, #P do
			if not models[i] or L.readOf(P, i, models) < 0.02 then return -1, "hidden past cap" end
		end
		return u, "TooComplex"
	end
	if #r.cleaned > 0 then return -1, "cleaned " .. #r.cleaned end
	return u, "ok"
end
local function start()
	local kind = rng:int(1, 3)
	local parts = {}
	if kind == 1 then -- rods
		local d = rng:range(0.06, 0.12)
		local step = d * rng:range(0.5, 0.95)
		for i = 1, 6 do table.insert(parts, L.part("Grip", "Cylinder", { (i - 3.5) * step, 0.65, 0 }, L.Z90, { 0.9, d, d })) end
		for i = 1, 6 do table.insert(parts, L.part("Guard", "Cylinder", { 0, 1.15 + (i - 3.5) * step, 0 }, L.I, { 1.0, d, d })) end
		for i = 1, 12 do table.insert(parts, L.part("Blade", "Cylinder", { (i - 6.5) * step, 2.5, 0 }, L.Z90, { 2.6, d, d })) end
	elseif kind == 2 then -- beads
		local d = rng:range(0.14, 0.24)
		local step = d * rng:range(0.3, 0.6)
		for i = 1, 4 do table.insert(parts, L.part("Pommel", "Ball", { (i - 2.5) * step, 0.1 + d / 2, 0 }, L.I, { d, d, d })) end
		for i = 1, 6 do table.insert(parts, L.part("Grip", "Ball", { 0, 0.1 + d / 2 + i * step, 0 }, L.I, { d, d, d })) end
		local gy = 0.1 + d / 2 + 7 * step
		for i = 1, 8 do table.insert(parts, L.part("Guard", "Ball", { (i - 4.5) * step, gy, 0 }, L.I, { d, d, d })) end
		table.insert(parts, L.part("Blade", "Block", { 0, gy + 1.3, 0 }, L.I, { 0.16, 2.5, 0.06 }))
		for i = 1, 5 do table.insert(parts, L.part("Blade", "Ball", { 0, gy + i * step, 0 }, L.I, { d, d, d })) end
	else -- a rod blade under a ball grip and a rod guard
		local d = rng:range(0.07, 0.12)
		local step = d * rng:range(0.5, 0.9)
		for i = 1, 6 do table.insert(parts, L.part("Grip", "Ball", { 0, 0.25 + i * 0.13, 0 }, L.I, { 0.16, 0.16, 0.16 })) end
		for i = 1, 6 do table.insert(parts, L.part("Guard", "Cylinder", { 0, 1.15 + (i - 3.5) * step, 0 }, L.I, { 1.0, d, d })) end
		for i = 1, 12 do table.insert(parts, L.part("Blade", "Cylinder", { (i - 6.5) * step, 2.5, 0 }, L.Z90, { 2.6, d, d })) end
	end
	return parts
end
local function mutate(parts)
	local out = L.copyParts(parts)
	local k = rng:int(1, #out)
	local p = out[k]
	local m = rng:int(1, 4)
	if m == 1 then
		local a = rng:int(1, 3)
		p.pos[a] += rng:normal(0, 0.02)
	elseif m == 2 then
		local s = rng:range(0.9, 1.1)
		if p.shape == "Ball" then
			for a = 1, 3 do p.size[a] = math.max(0.02, math.min(6, p.size[1] * s)) end
		elseif p.shape == "Cylinder" then
			p.size[2] = math.max(0.02, math.min(6, p.size[2] * s)); p.size[3] = p.size[2]
		else
			local a = rng:int(1, 3)
			p.size[a] = math.max(0.02, math.min(6, p.size[a] * s))
		end
	elseif m == 3 then
		local q = L.Quat.mul(p.rot, L.axisAngle(rng:normal(0, 1), rng:normal(0, 1), rng:normal(0, 1), rng:normal(0, 8)))
		local r = L.Quat.hemisphere(L.Quat.normalize(q))
		p.rot = { r[1], r[2], r[3], r[4] }
	else
		local j = rng:int(1, #out)
		local q = out[j]
		p.pos = { q.pos[1] + rng:normal(0, 0.03), q.pos[2] + rng:normal(0, 0.03), q.pos[3] + rng:normal(0, 0.01) }
	end
	return out
end
local best, bestU = nil, -1
local tries = 0
while best == nil and tries < 50 do
	tries += 1
	local s = start()
	local u, why = evaluate(s)
	if u > 0 then best, bestU = s, u end
end
print(fmt("seed %d start %.1f", seed, bestU))
local pastCap = nil
for e = 1, evals do
	local c = mutate(best)
	local u, why = evaluate(c)
	if u > bestU then
		best, bestU = c, u
		if u > CAP and pastCap == nil then
			pastCap = L.copyParts(c)
			print(fmt("  eval %d: PAST THE CAP with every part visible: %.1f units", e, u))
		end
	end
	if e % 50 == 0 then print(fmt("  eval %d best %.1f", e, bestU)) end
end
print(fmt("seed %d: best honest design %.1f units (%.2f × under the cap)", seed, bestU, CAP / bestU))
print("BEST " .. serde.encode("json", best))
if pastCap then print("PASTCAP " .. serde.encode("json", pastCap)) end
