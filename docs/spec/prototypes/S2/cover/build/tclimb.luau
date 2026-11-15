--!nocheck
-- The builder's TIME climb under a unit cap (the judge's jclimb_time.luau, on the build's Cover): hill climbing on the
-- verdict's wall time (SamplingV, median of 3) over canonical designs that pass Analyze.quick with connectivity (V1–V3) and
-- whose verdict stays within CAP units (over it: rejected). Every candidate goes through Canonical.draft first, so what it
-- keeps is canonical. Families: the judge's (rod bundles, near copies of a block, wedges, thin plates, a mix, ball clusters,
-- grilles, balls on a plate, rod lattices); restarts from the climbed and hostile designs on record.
-- args: seed evals out cap startMode   startMode = none | worst | all
local process = require("@lune/process")
local fs = require("@lune/fs")
local serde = require("@lune/serde")
local L = require("./lib")
local fmt = string.format
local Shapes, Quat, Analyze, Canonical, Sv = L.Shapes, L.Quat, L.Analyze, L.Canonical, L.SamplingV

local seed = tonumber(process.args[1]) or 1
local EVALS = tonumber(process.args[2]) or 4500
local OUT = process.args[3] or ("../out/tclimb_" .. seed .. ".json")
local CAP = tonumber(process.args[4] or "700000") or 700000
local startMode = process.args[5] or "all"

local function rng(sd)
	local s = (sd * 2654435761 + 97) % 4294967296
	if s == 0 then s = 88172645 end
	local R = {}
	function R.u()
		s = bit32.bxor(s, bit32.lshift(s, 13))
		s = bit32.bxor(s, bit32.rshift(s, 17))
		s = bit32.bxor(s, bit32.lshift(s, 5))
		return s / 4294967296
	end
	function R.range(a, b) return a + (b - a) * R.u() end
	function R.int(a, b) return a + math.floor(R.u() * (b - a + 1)) end
	function R.pick(t) return t[R.int(1, #t)] end
	return R
end
local R = rng(seed * 104729 + 7)
local I = { 0, 0, 0, 1 }
local Z90 = { 0, 0, 0.70710678118654757, 0.70710678118654757 }
local SLOTS = { "Pommel", "Pommel", "Grip", "Grip", "Guard", "Guard", "Guard", "Guard", "Guard", "Guard", "Guard", "Guard", "Blade", "Blade", "Blade", "Blade", "Blade", "Blade", "Blade", "Blade", "Blade", "Blade", "Blade", "Blade" }

local function axisAngle(ax, ay, az, deg)
	local h = math.rad(deg) / 2
	local n = math.sqrt(ax * ax + ay * ay + az * az)
	if n == 0 then return I end
	return Quat.hemisphere(Quat.normalize({ ax / n * math.sin(h), ay / n * math.sin(h), az / n * math.sin(h), math.cos(h) }))
end
local function tiny(deg) return axisAngle(R.range(-1, 1), R.range(-1, 1), R.range(-1, 1), R.range(-deg, deg)) end
local function copyPart(p)
	return { id = p.id, slot = p.slot, shape = p.shape, material = p.material or "Iron", pos = { p.pos[1], p.pos[2], p.pos[3] },
		rot = { p.rot[1], p.rot[2], p.rot[3], p.rot[4] }, size = { p.size[1], p.size[2], p.size[3] } }
end
local function copyParts(parts) local o = {} for i, p in ipairs(parts) do o[i] = copyPart(p) end return o end

local function canonSize(p)
	if p.shape == "Ball" then
		local d = math.min(p.size[1], p.size[2], p.size[3])
		p.size = { d, d, d }
	elseif p.shape == "Cylinder" then
		local d = math.min(p.size[2], p.size[3])
		p.size = { p.size[1], d, d }
	end
end
local function inBox(p)
	local mn, mx = Shapes.aabb(p)
	return mn[1] >= -0.8 and mx[1] <= 0.8 and mn[2] >= 0 and mx[2] <= 5 and mn[3] >= -0.3 and mx[3] <= 0.3
end
local function fits(p)
	for k = 1, 3 do
		if p.size[k] < 0.02 or p.size[k] > 6 then return false end
	end
	return inBox(p)
end

-- the canonical design (Canonical.draft), or nil
local function canonical(parts)
	for i, p in ipairs(parts) do p.id = i end
	local r = Canonical.draft({ schema = 1, name = "climb", type = "Sword", parts = parts })
	if not r.ok then return nil end
	return r.value.parts
end

local lastMs, lastUnits = 0, 0
local function score(parts)
	local P = {}
	for i, p in ipairs(parts) do P[i] = Shapes.prepare(p, i) end
	local t0 = os.clock()
	local e = Sv.exposure(P, nil)
	local t1 = os.clock()
	lastUnits = e.verdictWork
	if lastUnits > CAP then
		lastMs = (t1 - t0) * 1000
		return -1
	end
	local ts = { (t1 - t0) * 1000 }
	for k = 2, 3 do
		local a = os.clock()
		Sv.exposure(P, nil)
		ts[k] = (os.clock() - a) * 1000
	end
	table.sort(ts)
	lastMs = ts[2]
	return ts[2] * 1000 -- microseconds
end

local function valid(parts)
	local core = { schema = 1, name = "climb", type = "Sword", parts = parts }
	local ok, r = pcall(Analyze.quick, core, { connectivity = true })
	if not ok or not r.ok then return false end
	local ok2, c = pcall(Canonical.isCanonical, core)
	return ok2 and c == true
end

local function shrinkToFit(p)
	canonSize(p)
	local guard = 0
	while not fits(p) and guard < 40 do
		p.size = { math.max(0.02, p.size[1] * 0.95), math.max(0.02, p.size[2] * 0.95), math.max(0.02, p.size[3] * 0.95) }
		canonSize(p)
		guard += 1
	end
end

local function family(kind)
	local parts = {}
	for i = 1, 24 do
		local shape, size, pos, q
		if kind == 1 then -- a bundle of rods
			local d = R.range(0.03, 0.2)
			shape, size = "Cylinder", { R.range(2, 4.8), d, d }
			pos = { R.range(-0.03, 0.03), 2.5, R.range(-0.03, 0.03) }
			q = Quat.mul(tiny(1), Z90)
		elseif kind == 2 then -- near copies of a block
			shape, size = "Block", { 1.2 + R.range(-0.05, 0.05), 4 + R.range(-0.05, 0.05), 0.4 + R.range(-0.05, 0.05) }
			pos = { R.range(-0.05, 0.05), 2.5 + R.range(-0.05, 0.05), R.range(-0.05, 0.05) }
			q = tiny(2)
		elseif kind == 3 then -- wedges
			shape = if i % 2 == 0 then "Wedge" else "CornerWedge"
			size = { R.range(0.8, 1.3), R.range(2.5, 4.4), R.range(0.25, 0.5) }
			pos = { R.range(-0.1, 0.1), R.range(1.6, 3.2), R.range(-0.03, 0.03) }
			q = tiny(10)
		elseif kind == 4 then -- thin plates, all near
			shape, size = "Block", { R.range(0.8, 1.5), R.range(3, 4.8), R.range(0.02, 0.2) }
			pos = { R.range(-0.05, 0.05), 2.5, R.range(-0.1, 0.1) }
			q = tiny(3)
		elseif kind == 5 then -- a mix
			shape = R.pick({ "Block", "Wedge", "CornerWedge", "Cylinder", "Ball" })
			size = { R.range(0.2, 1.3), R.range(0.5, 4), R.range(0.1, 0.5) }
			if shape == "Cylinder" then
				local d = R.range(0.05, 0.4)
				size = { R.range(0.5, 4.5), d, d }
			end
			pos = { R.range(-0.1, 0.1), R.range(1.5, 3.5), R.range(-0.05, 0.05) }
			q = if shape == "Cylinder" then Quat.mul(tiny(6), Z90) else tiny(6)
		elseif kind == 6 then -- a ball cluster
			local d = R.range(0.1, 0.58)
			shape, size = "Ball", { d, d, d }
			pos = { R.range(-0.15, 0.15), R.range(1.0, 4.0), R.range(-0.02, 0.02) }
			q = tiny(180)
		elseif kind == 7 then -- a grille: a plate crossed by thin strips in two directions, on both faces
			if i == 1 then
				shape, size, pos, q = "Block", { 1.4, 4.6, 0.1 }, { 0, 2.5, 0 }, I
			else
				local ang = if i % 2 == 0 then R.range(-40, -20) else R.range(20, 40)
				shape, size = "Block", { R.range(0.02, 0.05), R.range(3, 4.8), R.range(0.02, 0.06) }
				pos = { R.range(-0.6, 0.6), 2.5 + R.range(-0.2, 0.2), (if i % 4 < 2 then 1 else -1) * R.range(0.04, 0.07) }
				q = axisAngle(0, 0, 1, ang)
			end
		elseif kind == 8 then -- small balls piled on a plate
			if i == 1 then
				shape, size, pos, q = "Block", { 1.2, 4.4, 0.12 }, { 0, 2.5, 0 }, I
			else
				local d = R.range(0.08, 0.3)
				shape, size = "Ball", { d, d, d }
				pos = { R.range(-0.5, 0.5), R.range(0.5, 4.5), R.range(-0.06, 0.06) }
				q = tiny(180)
			end
		else -- rods woven in a lattice in the blade plane
			local d = R.range(0.03, 0.12)
			shape, size = "Cylinder", { R.range(1.0, 4.6), d, d }
			pos = { R.range(-0.4, 0.4), R.range(1.5, 3.5), R.range(-0.04, 0.04) }
			q = axisAngle(0, 0, 1, R.pick({ 90, 60, 120, 30, 150, 0 }) + R.range(-3, 3))
		end
		local p = { id = i, slot = SLOTS[i], shape = shape, material = "Iron", pos = pos, rot = Quat.hemisphere(Quat.normalize(q)), size = size }
		shrinkToFit(p)
		parts[i] = p
	end
	return parts
end

local function mutate(parts)
	local q = copyParts(parts)
	for _ = 1, R.int(1, 4) do
		local p = q[R.int(1, #q)]
		local u = R.u()
		if u < 0.3 then
			local k = R.int(1, 3)
			p.size[k] *= R.range(0.85, 1.2)
			if p.shape == "Ball" then
				p.size = { p.size[k], p.size[k], p.size[k] }
			elseif p.shape == "Cylinder" and k ~= 1 then
				p.size[2], p.size[3] = p.size[k], p.size[k]
			end
		elseif u < 0.55 then
			local k = R.int(1, 3)
			p.pos[k] += R.range(-0.1, 0.1) * R.u()
		elseif u < 0.8 then
			p.rot = Quat.hemisphere(Quat.normalize(Quat.mul(tiny(if R.u() < 0.5 then 1 else 6), p.rot)))
		elseif u < 0.9 then
			local other = q[R.int(1, #q)]
			if other ~= p then
				local c = copyPart(other)
				p.shape, p.pos, p.rot, p.size = c.shape, { c.pos[1] + R.range(-0.02, 0.02), c.pos[2] + R.range(-0.02, 0.02), c.pos[3] + R.range(-0.02, 0.02) }, c.rot, c.size
			end
		else
			p.shape = R.pick({ "Block", "Wedge", "CornerWedge", "Cylinder", "Ball" })
		end
		canonSize(p)
		if not fits(p) then return nil end
	end
	return canonical(q)
end

local starts = {}
local function addStarts(list)
	for _, d in ipairs(list) do
		if #d.parts <= 24 then
			local ps = copyParts(d.parts)
			for i, p in ipairs(ps) do
				canonSize(p)
				p.slot = p.slot or SLOTS[i]
			end
			ps = canonical(ps)
			if ps then table.insert(starts, ps) end
		end
	end
end
if startMode ~= "none" then
	addStarts(L.worstP())
	addStarts(L.climbed())
	addStarts(L.judgeWorst())
	addStarts(L.judgeTime())
	if startMode == "all" then
		addStarts(L.climbA())
		addStarts(L.climbB())
	end
end

local keep = {}
local evals, best = 0, 0
local worstRate, worstRateUnits, worstRateMs = 0, 0, 0
local t0 = os.clock()
local function note(s)
	if s > 0 and lastUnits > 0 then
		local rate = lastMs / lastUnits * 1e6
		if lastUnits > 100000 and rate > worstRate then worstRate, worstRateUnits, worstRateMs = rate, lastUnits, lastMs end
	end
end
local function save()
	local rows = {}
	for _, k in ipairs(keep) do
		local lits = {}
		for i, p in ipairs(k.parts) do lits[i] = L.partLiteral(p) end
		table.insert(rows, { score = k.score, units = k.units, parts = k.parts, lua = table.concat(lits, ",\n") })
	end
	fs.writeFile(OUT, serde.encode("json", rows))
end
while evals < EVALS do
	local parts
	if #starts > 0 and R.u() < 0.6 then
		parts = copyParts(starts[R.int(1, #starts)])
	else
		parts = canonical(family(R.int(1, 9)))
	end
	if parts and valid(parts) then
		local s = score(parts)
		local su = lastUnits
		note(s)
		evals += 1
		local stale = 0
		while stale < 300 and evals < EVALS do
			local q = mutate(parts)
			if q then
				evals += 1
				local s2 = score(q)
				note(s2)
				if s2 > s and valid(q) then
					parts, s, su = q, s2, lastUnits
					stale = 0
				else
					stale += 1
				end
				if evals % 250 == 0 then
					print(fmt("seed %d evals %d: current %.0f us (%.0f units), best so far %.0f us; worst rate at >100k units %.1f ns/unit (%.0f units, %.1f ms) (%.0f s)",
						seed, evals, s, su, math.max(best, s), worstRate, worstRateUnits, worstRateMs, os.clock() - t0))
				end
			else
				stale += 1
			end
		end
		table.insert(keep, { score = s, units = su, parts = parts })
		if s > best then
			best = s
			print(fmt("seed %d evals %d: best %.0f us at %.0f units (%.0f s)", seed, evals, best, su, os.clock() - t0))
		end
		table.sort(keep, function(a, b) return a.score > b.score end)
		while #keep > 6 do table.remove(keep) end
		save()
	end
end
save()
print(fmt("seed %d done: %d evals, best %.0f us, worst rate at >100k units %.1f ns/unit (%.0f units, %.1f ms), %.0f s", seed, evals, best,
	worstRate, worstRateUnits, worstRateMs, os.clock() - t0))
