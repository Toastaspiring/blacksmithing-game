--!nocheck
-- V-A (a): bit-identity of the kept-only ladder. Any design D: with K = D's kept set, exposedKept and kept-pair contact must equal K
-- alone's pass 1 to the bit; ownership, volume probes and the difficulty frame likewise; and the emulated D per step.
-- The limit case is counted apart: a part of the design before the filler whose verdict the filler changed.
-- args: seed trials
local process = require("@lune/process")
local Sampling = require("./tree/src/shared/Physics/Sampling")
local Shapes = require("./tree/src/shared/Physics/Shapes")
local MassProps = require("./tree/src/shared/Physics/MassProps")
local Analyze = require("./tree/src/shared/Physics/Analyze")
local EmuReal = require("./proto/analyze_build")
local Emu = { run = function(a, b)
	Sampling.CFG.verdictOnly = false
	local R = EmuReal.run(a, b)
	Sampling.CFG.verdictOnly = true
	return R
end }
local L = require("./lib")
local fmt = string.format

local seed = tonumber(process.args[1]) or 1
local TRIALS = tonumber(process.args[2]) or 300
local V = require("./variants")
local VARIANT = process.args[3] or "A"
V.apply(Sampling, VARIANT)
Sampling.CFG.verdictOnly = true
local rng = L.rng(seed)
local SHAPES = { "Block", "Wedge", "CornerWedge", "Cylinder", "Ball" }
local fixtures = L.fixtures()

local limitCases = {}
local stats = { withCleaned = 0, trials = 0, exact = 0, keptDiffers = 0, aloneCleans = 0, skipped = 0, mismatch = 0, emu = 0, analyze = 0, finerGrid = 0, coarser = 0, straddle = 0, lowIndex = 0, full24 = 0, subRationed = 0, swap = 0 }
local byFam = {}

local function randomHost(id)
	local shape = rng.pick(SHAPES)
	local size
	local big = rng.float() < 0.5
	if big then
		size = { rng.range(0.2, 1.2), rng.range(0.3, 3), rng.range(0.1, 0.5) }
	else
		size = { rng.range(0.1, 0.5), rng.range(0.1, 0.8), rng.range(0.1, 0.4) }
	end
	if shape == "Ball" then
		local d = rng.range(0.15, 0.55)
		size = { d, d, d }
	elseif shape == "Cylinder" then
		local d = rng.range(0.1, 0.5)
		size = { rng.range(0.2, 2.5), d, d }
	end
	local rot = if rng.float() < 0.3 then L.I else (if rng.float() < 0.5 then rng.smallTilt(25) else rng.quat())
	return { id = id, slot = "Blade", shape = shape, material = "Iron", pos = { rng.range(-0.25, 0.25), rng.range(0.6, 4.2), rng.range(-0.05, 0.05) }, rot = rot, size = size }
end

local function randomK()
	-- a design that is not a sword about it: hosts along Y, overlapping at will, inside the hitbox
	local n = rng.int(2, 18)
	local out = {}
	local counts = { Blade = 0, Guard = 0, Grip = 0, Pommel = 0 }
	local tries = 0
	while #out < n and tries < 400 do
		tries += 1
		local p = randomHost(#out + 1)
		if #out > 0 and rng.float() < 0.7 then
			-- near an earlier part
			local q = out[rng.int(1, #out)]
			p.pos = { q.pos[1] + rng.range(-0.25, 0.25), q.pos[2] + rng.range(-0.6, 0.6), q.pos[3] + rng.range(-0.08, 0.08) }
		end
		if L.inHitbox(p) then
			local want = if #out == 0 then "Grip" elseif #out == 1 then "Blade" else nil
			local slot = L.freeSlot(counts, want or rng.pick({ "Blade", "Blade", "Guard", "Grip", "Pommel" }), rng)
			if slot then
				p.slot = slot
				counts[slot] += 1
				table.insert(out, p)
			end
		end
	end
	return out
end

local function fixtureK()
	local b = fixtures[rng.int(1, #fixtures)]
	local out = L.copyParts(b.parts)
	if string.sub(b.name, 1, 1) == "P" and rng.float() < 0.8 then
		local drop = rng.int(1, 12)
		for _ = 1, drop do
			if #out > 3 then
				table.remove(out, rng.int(1, #out))
			end
		end
	end
	return out, b.name
end

-- one filler part for K, or nil; kind tells which
local function fillerPart(K, kind, slot)
	if kind == "inside" then
		local host = K[rng.int(1, #K)]
		local f = if rng.float() < 0.5 then rng.range(0.1, 0.6) else rng.range(0.6, 0.97)
		return L.shrunk(host, f, 0, slot)
	elseif kind == "ball" then
		local host = K[rng.int(1, #K)]
		local P = Shapes.prepare(host, 1)
		local d = math.min(host.size[1], host.size[2], host.size[3]) * rng.range(0.2, 0.9) * 0.5
		return { id = 0, slot = slot, shape = "Ball", material = "Iron", pos = { P.gx, P.gy, P.gz }, rot = L.I, size = { d, d, d } }
	elseif kind == "block" then
		-- a turned block deep inside a host
		local host = K[rng.int(1, #K)]
		local P = Shapes.prepare(host, 1)
		local d = math.min(host.size[1], host.size[2], host.size[3]) * rng.range(0.15, 0.4)
		return { id = 0, slot = slot, shape = rng.pick({ "Block", "Wedge", "CornerWedge", "Cylinder" }), material = "Iron", pos = { P.gx, P.gy, P.gz }, rot = rng.quat(), size = { d, d, d } }
	elseif kind == "straddle" then
		-- across two or three parts that overlap: at a point inside their union, near the seam
		for _ = 1, 12 do
			local a, b = K[rng.int(1, #K)], K[rng.int(1, #K)]
			if a ~= b then
				local A, B = Shapes.prepare(a, 1), Shapes.prepare(b, 2)
				if Shapes.aabbOverlap(A, B, -0.02) then
					local t = rng.range(0.2, 0.8)
					local x, y, z = A.gx + t * (B.gx - A.gx), A.gy + t * (B.gy - A.gy), A.gz + t * (B.gz - A.gz)
					local d = math.min(a.size[1], a.size[2], a.size[3], b.size[1], b.size[2], b.size[3]) * rng.range(0.25, 0.8)
					local len = rng.range(1, 3)
					local rot = if rng.float() < 0.5 then a.rot else rng.smallTilt(20)
					return { id = 0, slot = slot, shape = rng.pick({ "Block", "Block", "Cylinder", "Ball", "Wedge", "CornerWedge" }), material = "Iron", pos = { x, y, z }, rot = rot, size = { d, d * len, d } }, true
				end
			end
		end
		return nil
	elseif kind == "dust" then
		local d = rng.range(0.02, 0.0575)
		local where = rng.float()
		local pos
		if where < 0.3 then
			pos = { rng.range(-0.7, 0.7), rng.range(0.1, 4.9), rng.range(-0.25, 0.25) }
		else
			local host = K[rng.int(1, #K)]
			local P = Shapes.prepare(host, 1)
			pos = { P.gx + rng.range(-1, 1) * host.size[1] / 2, P.gy + rng.range(-1, 1) * host.size[2] / 2, P.gz + rng.range(-1, 1) * host.size[3] / 2 }
		end
		return { id = 0, slot = slot, shape = rng.pick({ "Block", "Ball", "Wedge", "Cylinder" }), material = "Iron", pos = pos, rot = rng.quat(), size = { d, d, d } }
	elseif kind == "copy" then
		local host = K[rng.int(1, #K)]
		local p = L.copyPart(host)
		p.slot = slot
		return p
	elseif kind == "near" then
		local host = K[rng.int(1, #K)]
		return L.shrunk(host, rng.range(0.999, 0.99999), 0, slot)
	end
end

local KINDS = { "inside", "inside", "ball", "block", "straddle", "straddle", "dust", "dust", "copy", "near" }

local function sameArray(a, b, n)
	for i = 1, n do
		if a[i] ~= b[i] then
			return false, i
		end
	end
	return true
end

local function report(what, name, D, Kidx, extra)
	stats.mismatch += 1
	print(fmt("MISMATCH %s on %s (%d parts, %d kept) %s", what, name, #D, #Kidx, extra or ""))
end

local start = os.clock()
for trial = 1, TRIALS do
	local K, name
	local fam = rng.float()
	if fam < 0.55 then
		K, name = fixtureK()
	else
		K, name = randomK(), "random"
	end
	L.renumber(K)
	local famName = string.sub(name, 1, 3)
	byFam[famName] = byFam[famName] or { trials = 0, exact = 0, keptDiffers = 0 }
	local fam2 = byFam[famName]

	-- the filler
	local counts = L.slotCounts(K)
	local want = rng.pick({ 1, 2, 3, 6, 9, 12, 18, 24 })
	local F = {}
	local anyStraddle = false
	local tries = 0
	while #K + #F < 24 and #F < want and tries < 200 do
		tries += 1
		local slot = L.freeSlot(counts, rng.pick({ "Blade", "Blade", "Guard", "Grip", "Pommel" }), rng)
		if slot == nil then break end
		local kind = rng.pick(KINDS)
		local p, st = fillerPart(K, kind, slot)
		if p and L.inHitbox(p) then
			counts[slot] += 1
			if st then anyStraddle = true end
			table.insert(F, p)
		end
	end

	-- the interleaving: all filler first (every index shifts), at random, or all after. K keeps its relative order. Copies go wherever
	-- they land: a copy ahead of its original swaps the roles, and the claim below is about whatever is kept.
	local mode = rng.int(1, 3)
	local total = #K + #F
	local entries = table.create(total)
	if mode == 1 then
		for _, p in ipairs(F) do table.insert(entries, { part = p, k = nil }) end
		for i, p in ipairs(K) do table.insert(entries, { part = p, k = i }) end
	elseif mode == 2 then
		local isK = {}
		local all = {}
		for i = 1, total do all[i] = i end
		for i = total, 2, -1 do
			local j = rng.int(1, i)
			all[i], all[j] = all[j], all[i]
		end
		for i = 1, #K do isK[all[i]] = true end
		local ki, fi = 1, 1
		for pos = 1, total do
			if isK[pos] then
				table.insert(entries, { part = K[ki], k = ki })
				ki += 1
			else
				table.insert(entries, { part = F[fi], k = nil })
				fi += 1
			end
		end
	else
		for i, p in ipairs(K) do table.insert(entries, { part = p, k = i }) end
		for _, p in ipairs(F) do table.insert(entries, { part = p, k = nil }) end
	end

	local nonCanonical = rng.float() < 0.33
	local function partsOf(list)
		local out = table.create(#list)
		for i, e in ipairs(list) do
			local p = L.copyPart(e.part)
			p.id = i
			out[i] = p
		end
		return out
	end
	-- visible filler is no filler: drop what stays kept, then the design is K + hidden parts
	local both, PD, Dparts
	for _ = 1, 6 do
		Dparts = partsOf(entries)
		PD = L.prep(Dparts)
		both = Sampling.exposure(PD)
		local dropped = false
		for i = #entries, 1, -1 do
			if entries[i].k == nil and both.kept[i] then
				table.remove(entries, i)
				dropped = true
			end
		end
		if not dropped then break end
	end
	Dparts = partsOf(entries)
	if nonCanonical then
		for _, p in ipairs(Dparts) do
			if rng.float() < 0.5 then
				p.rot = { -p.rot[1], -p.rot[2], -p.rot[3], -p.rot[4] }
			end
			p.id = rng.int(1, 100000)
		end
	end
	PD = L.prep(Dparts)
	both = Sampling.exposure(PD)
	total = #Dparts
	stats.trials += 1
	fam2.trials += 1

	-- THE LIMIT: a part of K that K alone keeps and D cleans, or that K alone cleans and D keeps
	do
		local base = L.copyParts(K)
		L.renumber(base)
		local alone0 = Sampling.exposure(L.prep(base))
		local flips = 0
		for pos, e in ipairs(entries) do
			if e.k and both.kept[pos] ~= alone0.kept[e.k] then
				flips += 1
			end
		end
		if flips > 0 then
			stats.keptDiffers += 1
			fam2.keptDiffers += 1
			if L.quickValid(base) and L.quickValid(Dparts) then
				local eK = Emu.run({ name = "k", parts = base }, { measureInvalid = true, build = true })
				local eD = Emu.run({ name = "d", parts = Dparts }, { measureInvalid = true, build = true })
				local worst, step0 = 0, ""
				local tier = false
				for s, step in ipairs(eK.steps or {}) do
					local other = eD.steps[s]
					local dd = math.abs(step.d - other.d)
					if dd > worst then
						worst, step0 = dd, step.step
					end
					if step.tier ~= other.tier then tier = true end
				end
				table.insert(limitCases, { name = name, worst = worst, step = step0, flips = flips, hSurf = both.hSurf, hAlone = alone0.hSurf, tier = tier, parts = #Dparts })
			end
		end
	end
end

table.sort(limitCases, function(a, b) return a.worst > b.worst end)
local tierCount = 0
for _, c in ipairs(limitCases) do
	if c.tier then tierCount += 1 end
end
print(fmt("%s seed %d: %d designs in %.0f s; a part of K flipped by the filler: %d designs, measured %d, tier flips %d", VARIANT, seed, stats.trials, os.clock() - start, stats.keptDiffers, #limitCases, tierCount))
for i = 1, math.min(12, #limitCases) do
	local c = limitCases[i]
	print(fmt("  flip: %-40s parts %2d, %d parts of K flip: worst |dD| %.4f (%s)%s", string.sub(c.name, 1, 40), c.parts, c.flips, c.worst, c.step, if c.tier then " TIER" else ""))
end
