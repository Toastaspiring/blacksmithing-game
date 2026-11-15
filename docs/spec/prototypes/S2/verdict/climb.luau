--!nocheck
-- V-A (d): the worst design for the M2 path + M3's share under the kept-only ladder. Hill climbing from families of 24 large overlapping
-- parts inside the hitbox. Score = Analyze.run (measureInvalid, min of 3) + the prototype's edge + factor times on the build's exposure.
-- args: seed, seconds, out file
local process = require("@lune/process")
local fs = require("@lune/fs")
local serde = require("@lune/serde")
local Analyze = require("./tree/src/shared/Physics/Analyze")
local Shapes = require("./tree/src/shared/Physics/Shapes")
local Quat = require("./tree/src/shared/Blueprint/Quat")
local Emu = require("./proto/analyze_build")
local L = require("./lib")
local fmt = string.format

local Sampling = require("./tree/src/shared/Physics/Sampling")
local V = require("./variants")
local VARIANT = process.env.VARIANT or "A"
V.apply(Sampling, VARIANT)
local seed = tonumber(process.args[1]) or 1
local SECONDS = tonumber(process.args[2]) or 120
local OUT = process.args[3] or ("out/d_search_" .. seed .. ".json")
local MAX_EVALS = tonumber(process.env.MAX_EVALS or "") or math.huge
local rng = L.rng(seed * 7919 + 13)
local SLOTS = { "Pommel", "Pommel", "Grip", "Grip", "Guard", "Guard", "Guard", "Guard", "Guard", "Guard", "Guard", "Guard", "Blade", "Blade", "Blade", "Blade", "Blade", "Blade", "Blade", "Blade", "Blade", "Blade", "Blade", "Blade" }

local function clampPos(p)
	return p
end

local function family(kind)
	local parts = {}
	for i = 1, 24 do
		local shape, size
		local tilt = rng.smallTilt(if kind == 5 then 40 else 10)
		local pos = { rng.range(-0.1, 0.1), rng.range(1.6, 3.2), rng.range(-0.03, 0.03) }
		if kind == 1 then -- P1's blocks
			shape = "Block"
			size = { rng.range(0.8, 1.3), rng.range(2.5, 4.4), rng.range(0.25, 0.5) }
		elseif kind == 2 then -- wedges and corner wedges
			shape = if i % 2 == 0 then "Wedge" else "CornerWedge"
			size = { rng.range(0.8, 1.3), rng.range(2.5, 4.4), rng.range(0.25, 0.5) }
		elseif kind == 3 then -- cylinders along Y
			shape = "Cylinder"
			local d = rng.range(0.2, 0.5)
			size = { rng.range(2.5, 4.4), d, d }
			tilt = Quat.mul(tilt, { 0, 0, 0.70710678118654757, 0.70710678118654757 })
		elseif kind == 4 then -- balls
			shape = "Ball"
			local d = rng.range(0.3, 0.58)
			size = { d, d, d }
			pos = { rng.range(-0.3, 0.3), rng.range(0.4, 4.4), rng.range(-0.01, 0.01) }
		else -- a mix
			shape = rng.pick({ "Block", "Wedge", "CornerWedge", "Cylinder", "Block" })
			size = { rng.range(0.3, 1.2), rng.range(0.5, 3), rng.range(0.15, 0.45) }
			pos = { rng.range(-0.3, 0.3), rng.range(0.8, 4), rng.range(-0.05, 0.05) }
			if shape == "Cylinder" then
				local d = rng.range(0.15, 0.45)
				size = { rng.range(0.5, 2.5), d, d }
			end
		end
		parts[i] = { id = i, slot = SLOTS[i], shape = shape, material = "Iron", pos = pos, rot = Quat.hemisphere(Quat.normalize(tilt)), size = size }
	end
	return parts
end

local function shrinkToFit(p)
	for _ = 1, 20 do
		if L.inHitbox(p) then
			return true
		end
		p.size = { p.size[1] * 0.93, p.size[2] * 0.93, p.size[3] * 0.93 }
		if p.pos[2] - 0.5 * p.size[2] < 0 then p.pos[2] += 0.1 end
		if p.pos[2] + 0.5 * p.size[2] > 5 then p.pos[2] -= 0.1 end
	end
	return false
end

local function fit(parts)
	for _, p in ipairs(parts) do
		if not shrinkToFit(p) then
			return false
		end
	end
	return true
end

local function score(parts, reps)
	local core = { schema = 1, name = "x", type = "Sword", parts = parts }
	local times = {}
	local a
	for r = 1, reps do
		collectgarbage("collect")
		local t0 = os.clock()
		a = Analyze.run(core, { measureInvalid = true })
		times[r] = (os.clock() - t0) * 1000
	end
	local best = L.median(times)
	collectgarbage("collect")
	local R = Emu.run({ name = "x", parts = parts }, { measureInvalid = true, build = true })
	local m3 = 1000 * ((R.T.edge or 0) + (R.T.factors or 0))
	return best + m3, best, m3, a, R
end

local function mutate(parts)
	local q = L.copyParts(parts)
	local count = rng.int(1, 4)
	for _ = 1, count do
		local p = q[rng.int(1, #q)]
		local r = rng.float()
		if r < 0.35 then
			local k = rng.int(1, 3)
			p.size[k] *= rng.range(0.8, 1.3)
			if p.shape == "Ball" then
				p.size = { p.size[k], p.size[k], p.size[k] }
			elseif p.shape == "Cylinder" and k ~= 1 then
				p.size[2], p.size[3] = p.size[k], p.size[k]
			end
		elseif r < 0.6 then
			local k = rng.int(1, 3)
			p.pos[k] += rng.range(-0.15, 0.15)
		elseif r < 0.8 then
			p.rot = Quat.hemisphere(Quat.normalize(Quat.mul(rng.smallTilt(8), p.rot)))
		elseif r < 0.9 then
			local shape = rng.pick({ "Block", "Wedge", "CornerWedge", "Cylinder", "Ball" })
			p.shape = shape
			if shape == "Ball" then
				local d = math.min(p.size[1], p.size[2], p.size[3])
				p.size = { d, d, d }
			elseif shape == "Cylinder" then
				local d = math.min(p.size[2], p.size[3])
				p.size = { p.size[1], d, d }
			end
		else
			-- swap with a hidden copy-like: shrink into another part so it is cleaned
			local host = q[rng.int(1, #q)]
			if host ~= p then
				local f = rng.range(0.5, 0.95)
				local s = L.shrunk(host, f, p.id, p.slot)
				p.shape, p.pos, p.rot, p.size = s.shape, s.pos, s.rot, s.size
			end
		end
	end
	if not fit(q) then
		return nil
	end
	return q
end

local start = os.clock()
local best, bestScore, bestM2, bestM3 = nil, 0, 0, 0
local evals = 0
local globalBest = {}
while os.clock() - start < SECONDS and evals < MAX_EVALS do
	-- a restart
	local parts
	if process.args[4] then
		local data = serde.decode("json", fs.readFile(process.args[rng.int(4, #process.args)]))
		parts = L.copyParts(data[rng.int(1, math.min(3, #data))].parts)
	elseif rng.float() < 0.5 then
		local Fx = require("./proto/fixtures")
		parts = L.copyParts(Fx.perf()[rng.int(1, 4)].parts)
		L.renumber(parts)
	else
		parts = family(rng.int(1, 5))
	end
	if fit(parts) then
		local s, m2, m3 = score(parts, 3)
		local stale = 0
		while stale < 80 and os.clock() - start < SECONDS and evals < MAX_EVALS do
			local q = mutate(parts)
			if q then
				evals += 1
				local s2, m22, m32 = score(q, 3)
				if s2 > s * 1.01 then
					s2, m22, m32 = score(q, 7)
				end
				if s2 > s * 1.01 then
					parts, s, m2, m3 = q, s2, m22, m32
					stale = 0
				else
					stale += 1
				end
			else
				stale += 1
			end
		end
		table.insert(globalBest, { score = s, m2 = m2, m3 = m3, parts = parts })
		if s > bestScore then
			best, bestScore, bestM2, bestM3 = parts, s, m2, m3
			print(fmt("t=%.0f evals %d: new best %.1f ms (M2 %.1f + M3 %.1f)", os.clock() - start, evals, s, m2, m3))
		end
	end
end
table.sort(globalBest, function(a, b) return a.score > b.score end)
local keep = {}
for i = 1, math.min(5, #globalBest) do
	keep[i] = globalBest[i]
end
fs.writeFile(OUT, serde.encode("json", keep))
print(VARIANT, "wrote", OUT, "evals", evals, "best", fmt("%.2f", bestScore), "M2", fmt("%.2f", bestM2), "M3", fmt("%.2f", bestM3))
