--!nocheck
-- Climbs against the verdict with a score that does not lie: shape queries counted, no clock. args: seed evals out [start json...]
local process = require("@lune/process")
local fs = require("@lune/fs")
local serde = require("@lune/serde")
local V = require("./v1")
local C = require("./count/Sampling")
local Sets = require("./b_sets")
local Quat = V.Quat
local fmt = string.format
local I = V.I
local COUNT = C.COUNT

local seed = tonumber(process.args[1]) or 1
local EVALS = tonumber(process.args[2]) or 20000
local OUT = process.args[3] or ("out/d_climb_" .. seed .. ".json")
local R = Sets.rng(seed * 7919 + 13)
local SLOTS = { "Pommel", "Pommel", "Grip", "Grip", "Guard", "Guard", "Guard", "Guard", "Guard", "Guard", "Guard", "Guard", "Blade", "Blade", "Blade", "Blade", "Blade", "Blade", "Blade", "Blade", "Blade", "Blade", "Blade", "Blade" }
local AABB_W = 0.25 -- an AABB test against sd's cost, near enough for a climb

local function score(parts)
	local P = V.prep(parts)
	COUNT.sd, COUNT.aabb = 0, 0
	C.FORCE.verdictOnly = true
	C.exposure(P)
	C.FORCE.verdictOnly = nil
	return COUNT.sd + AABB_W * COUNT.aabb
end

local function fits(p)
	for k = 1, 3 do
		if p.size[k] < 0.02 or p.size[k] > 6 then return false end
	end
	return Sets.inBox(p)
end

local function tiny(deg)
	return V.axisAngle(R.range(-1, 1), R.range(-1, 1), R.range(-1, 1), R.range(-deg, deg))
end

local function family(kind)
	local parts = {}
	for i = 1, 24 do
		local shape, size, pos, q
		if kind == 1 then -- a bundle of rods
			local d = R.range(0.03, 0.2)
			shape, size = "Cylinder", { R.range(2, 4.8), d, d }
			pos = { R.range(-0.03, 0.03), 2.5, R.range(-0.03, 0.03) }
			q = Quat.mul(tiny(1), V.Z90)
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
		else -- a mix
			shape = R.pick({ "Block", "Wedge", "CornerWedge", "Cylinder" })
			size = { R.range(0.2, 1.3), R.range(0.5, 4), R.range(0.1, 0.5) }
			if shape == "Cylinder" then
				local d = R.range(0.05, 0.4)
				size = { R.range(0.5, 4.5), d, d }
			end
			pos = { R.range(-0.1, 0.1), R.range(1.5, 3.5), R.range(-0.05, 0.05) }
			q = if shape == "Cylinder" then Quat.mul(tiny(6), V.Z90) else tiny(6)
		end
		parts[i] = V.part("x", shape, SLOTS[i], pos, Quat.hemisphere(Quat.normalize(q)), size)
		parts[i].id = i
		local guard = 0
		while not fits(parts[i]) and guard < 30 do
			local p = parts[i]
			p.size = { math.max(0.02, p.size[1] * 0.95), math.max(0.02, p.size[2] * 0.95), math.max(0.02, p.size[3] * 0.95) }
			guard += 1
		end
	end
	return parts
end

local function mutate(parts)
	local q = V.copyParts(parts)
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
				local slot, id = p.slot, p.id
				local c = V.copyPart(other)
				p.shape, p.pos, p.rot, p.size = c.shape, { c.pos[1] + R.range(-0.02, 0.02), c.pos[2] + R.range(-0.02, 0.02), c.pos[3] + R.range(-0.02, 0.02) }, c.rot, c.size
			end
		else
			p.shape = R.pick({ "Block", "Wedge", "CornerWedge", "Cylinder" })
			if p.shape == "Cylinder" then
				local d = math.min(p.size[2], p.size[3])
				p.size = { p.size[1], d, d }
			end
		end
		if not fits(p) then return nil end
	end
	return q
end

local starts = {}
for a = 4, #process.args do
	for _, d in ipairs(serde.decode("json", fs.readFile(process.args[a]))) do
		table.insert(starts, d.parts)
	end
end

local keep = {}
local evals = 0
local best = 0
while evals < EVALS do
	local parts
	if #starts > 0 and R.u() < 0.7 then
		parts = V.copyParts(starts[R.int(1, #starts)])
	else
		parts = family(R.int(1, 5))
	end
	V.renumber(parts)
	local s = score(parts)
	local stale = 0
	while stale < 300 and evals < EVALS do
		local q = mutate(parts)
		if q then
			evals += 1
			local s2 = score(q)
			if s2 > s then
				parts, s = q, s2
				stale = 0
			else
				stale += 1
			end
		else
			stale += 1
		end
	end
	table.insert(keep, { score = s, parts = parts })
	if s > best then
		best = s
		print(fmt("seed %d evals %d: best score %.0f", seed, evals, best))
	end
	table.sort(keep, function(a, b) return a.score > b.score end)
	while #keep > 5 do table.remove(keep) end
	fs.writeFile(OUT, serde.encode("json", keep))
end
print(fmt("seed %d done: %d evals, best %.0f", seed, evals, best))
