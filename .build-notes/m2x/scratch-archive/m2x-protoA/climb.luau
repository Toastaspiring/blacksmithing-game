--!nocheck
-- M5's climb: hill climbing for the worst verdict cost of Physics/Cover, scored on its own work units (vertex-against-line tests,
-- deterministic, no clock), as the verifiers' d_climb.luau does on counted shape queries: the same families (rod bundles, near
-- copies of a block, wedges, thin plates, a mix) plus ball clusters, the same mutations (plus Ball). A mutation is kept only if it
-- scores higher and the design stays valid (Analyze: canonical sizes, slots, hitbox, connected, V4). Starts from the given JSON
-- files 70 % of the time. args: seed evals out model [start json...]
local process = require("@lune/process")
local fs = require("@lune/fs")
local serde = require("@lune/serde")
local Shapes = require("./repo/src/shared/Physics/Shapes")
local Quat = require("./repo/src/shared/Blueprint/Quat")
local Analyze = require("./repo/src/shared/Physics/Analyze")
local Canonical = require("./repo/src/shared/Blueprint/Canonical")
local fmt = string.format

local seed = tonumber(process.args[1]) or 1
local EVALS = tonumber(process.args[2]) or 10000
local OUT = process.args[3] or ("out/climb_" .. seed .. ".json")
local modelName = process.args[4] or "base"
local Sv = require(({ base = "./v/newV_base/Sampling", canon = "./v/newV_canon/Sampling", fine = "./v/newV_fine/Sampling" })[modelName])

-- xorshift, as b_sets.luau
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
local R = rng(seed * 7919 + 13)
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

local function score(parts)
	local P = {}
	for i, p in ipairs(parts) do P[i] = Shapes.prepare(p, i) end
	local units = 0
	Sv.exposure(P, function(n) units += n end)
	return units
end

local function valid(parts)
	for i, p in ipairs(parts) do p.id = i end
	local core = { schema = 1, name = "climb", type = "Sword", parts = parts }
	local ok, r = pcall(Analyze.quick, core, { connectivity = true })
	if not ok or not r.ok then return false end
	local ok2, c = pcall(Canonical.isCanonical, core)
	return not ok2 or c ~= false
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
		else -- a ball cluster
			local d = R.range(0.1, 0.58)
			shape, size = "Ball", { d, d, d }
			pos = { R.range(-0.15, 0.15), R.range(1.0, 4.0), R.range(-0.02, 0.02) }
			q = tiny(180)
		end
		local p = { id = i, slot = SLOTS[i], shape = shape, material = "Iron", pos = pos, rot = Quat.hemisphere(Quat.normalize(q)), size = size }
		canonSize(p)
		local guard = 0
		while not fits(p) and guard < 40 do
			p.size = { math.max(0.02, p.size[1] * 0.95), math.max(0.02, p.size[2] * 0.95), math.max(0.02, p.size[3] * 0.95) }
			canonSize(p)
			guard += 1
		end
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
			canonSize(p)
		end
		canonSize(p)
		if not fits(p) then return nil end
	end
	return q
end

local starts = {}
for a = 5, #process.args do
	for _, d in ipairs(serde.decode("json", fs.readFile(process.args[a]))) do
		if d.parts and #d.parts <= 24 then
			local ps = copyParts(d.parts)
			for _, p in ipairs(ps) do canonSize(p) end
			table.insert(starts, ps)
		end
	end
end

local keep = {}
local evals, best = 0, 0
local t0 = os.clock()
while evals < EVALS do
	local parts
	if #starts > 0 and R.u() < 0.7 then
		parts = copyParts(starts[R.int(1, #starts)])
	else
		parts = family(R.int(1, 6))
	end
	for i, p in ipairs(parts) do p.id = i end
	if valid(parts) then
		local s = score(parts)
		evals += 1
		local stale = 0
		while stale < 300 and evals < EVALS do
			local q = mutate(parts)
			if q then
				evals += 1
				local s2 = score(q)
				if s2 > s and valid(q) then
					parts, s = q, s2
					stale = 0
				else
					stale += 1
				end
				if evals % 100 == 0 then
					-- progress: the climb so far, the current design among the kept ones
					local snap = {}
					for _, kk in ipairs(keep) do table.insert(snap, kk) end
					table.insert(snap, { score = s, parts = parts, current = true })
					table.sort(snap, function(a, b) return a.score > b.score end)
					fs.writeFile(OUT, serde.encode("json", snap))
					print(fmt("seed %d evals %d: current %.0f, best so far %.0f units (%.0f s)", seed, evals, s, math.max(best, s), os.clock() - t0))
				end
			else
				stale += 1
			end
		end
		table.insert(keep, { score = s, parts = parts })
		if s > best then
			best = s
			print(fmt("seed %d evals %d: best %.0f units (%.0f s)", seed, evals, best, os.clock() - t0))
		end
		table.sort(keep, function(a, b) return a.score > b.score end)
		while #keep > 5 do table.remove(keep) end
		fs.writeFile(OUT, serde.encode("json", keep))
	end
end
print(fmt("seed %d done: %d evals, best %.0f units, %.0f s", seed, evals, best, os.clock() - t0))
