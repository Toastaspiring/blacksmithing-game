--!nocheck
-- V1 (m2x, round 2) tangles, independent of Cover.spec's: every shape, sizes from MIN_DIM to MAX_DIM, odd turns, faces
-- against faces at hairlines 1e-12…1e-5, EPS and HIDE_OFFSET ± EPS ties (and their sagitta-shifted twins for round parts),
-- near-coplanar tilts, side-by-side hiders with hairline gaps (fragmentation), copies exact / turned / nudged / described
-- another way, Dust, every part in a random slot.
local L = require("./lib")
local Quat = L.Quat
local T = {}

local SHAPES = { "Block", "Block", "Wedge", "CornerWedge", "Cylinder", "Ball" }
local SLOTS = { "Blade", "Guard", "Grip", "Pommel" }
local EPS, D = 1e-7, 0.012
local OFFS = { 0, 0, 1e-12, -1e-12, 1e-11, -1e-11, 1e-10, -1e-10, 1e-9, -1e-9, 1e-8, -1e-8, EPS, -EPS, 2 * EPS, -2 * EPS,
	EPS + 1e-12, EPS - 1e-12, 1e-6, -1e-6, 1e-5, -1e-5, D, -D, D + EPS, D - EPS, D + EPS + 1e-12, D + EPS - 1e-12, D + 2 * EPS,
	D - 1e-9, D + 1e-9, 0.002, -0.002, 0.03 }
local S45 = 0.70710678118654757
local ROTS = { { 0, 0, 0, 1 }, { 0, 0, S45, S45 }, { 0, S45, 0, S45 }, { S45, 0, 0, S45 }, { 0, 0, 1, 0 },
	{ 0.5, 0.5, 0.5, 0.5 }, { 0, 0, 0.38268343236508978, 0.92387953251128674 } }

local function rq(rng)
	local x, y, z, w = rng:normal(0, 1), rng:normal(0, 1), rng:normal(0, 1), rng:normal(0, 1)
	return Quat.hemisphere(Quat.normalize({ x, y, z, w }))
end

local function sized(shape, s)
	if shape == "Ball" then
		local m = math.min(s[1], s[2], s[3])
		return { m, m, m }
	elseif shape == "Cylinder" then
		local m = math.min(s[2], s[3])
		return { s[1], m, m }
	end
	return s
end

local function rsize(rng)
	local function one()
		local r = rng:float()
		if r < 0.15 then
			return 0.02
		elseif r < 0.2 then
			return 6.0
		elseif r < 0.5 then
			return rng:range(0.02, 0.12)
		end
		return rng:range(0.1, 1.2)
	end
	return { one(), one(), one() }
end

function T.tangle(rng)
	local parts = {}
	local function add(shape, pos, rot, size, slot)
		table.insert(parts, L.part(slot or rng:pick(SLOTS), shape, pos, rot, sized(shape, size)))
	end
	local n = rng:int(3, 9)
	for k = 1, n do
		local mode = rng:int(1, 12)
		local shape = rng:pick(SHAPES)
		if k == 1 or mode <= 2 then
			local rot = if rng:float() < 0.5 then rng:pick(ROTS) else rq(rng)
			add(shape, { rng:range(-0.3, 0.3), rng:range(-0.3, 0.3), rng:range(-0.3, 0.3) }, rot, rsize(rng))
		elseif mode <= 6 then -- a face against a face of an earlier part, its turn or a tilt off it
			local host = rng:pick(parts)
			local axis = rng:int(1, 3)
			local side = if rng:float() < 0.5 then -1 else 1
			local size = sized(shape, rsize(rng))
			local off = rng:pick(OFFS)
			local d = side * (host.size[axis] / 2 + size[axis] / 2 + off)
			if rng:float() < 0.3 then
				d = side * (host.size[axis] / 2 - size[axis] / 2 + off)
			end
			local l = { 0, 0, 0 }
			l[axis] = d
			for a = 1, 3 do
				if a ~= axis then
					l[a] = if rng:float() < 0.4 then (if rng:float() < 0.5 then -1 else 1) * (host.size[a] / 2 - size[a] / 2) + rng:pick(OFFS)
						else (rng:float() - 0.5) * host.size[a]
				end
			end
			local w = Quat.rotate(host.rot, l)
			local rot = table.clone(host.rot)
			if rng:float() < 0.2 then
				local ang = rng:pick({ 1e-9, 1e-7, 1e-6, 1e-5, 1e-3, 0.5, 37 })
				rot = Quat.hemisphere(Quat.normalize(Quat.mul(host.rot, L.axisAngle(rng:normal(0, 1), rng:normal(0, 1), rng:normal(0, 1), ang))))
			end
			add(shape, { host.pos[1] + w[1], host.pos[2] + w[2], host.pos[3] + w[3] }, rot, size)
		elseif mode <= 8 then -- two hiders side by side over a face, a hairline between them
			local host = rng:pick(parts)
			local axis = rng:int(1, 3)
			local side = if rng:float() < 0.5 then -1 else 1
			local along = (axis % 3) + 1
			local gap = rng:pick({ 0, 1e-12, 1e-11, 1e-10, 1e-9, 1e-8, EPS, 2 * EPS, 1e-6, 1e-5 })
			local th = rng:pick({ 0.02, 0.03, 0.05 })
			local off = rng:pick(OFFS)
			for s = -1, 1, 2 do
				local size = { host.size[1] + 0.04, host.size[2] + 0.04, host.size[3] + 0.04 }
				size[axis] = th
				size[along] = host.size[along] / 2 + 0.02
				local l = { 0, 0, 0 }
				l[axis] = side * (host.size[axis] / 2 + th / 2 + off)
				l[along] = s * (size[along] / 2 + gap / 2)
				local w = Quat.rotate(host.rot, l)
				add("Block", { host.pos[1] + w[1], host.pos[2] + w[2], host.pos[3] + w[3] }, table.clone(host.rot), size)
			end
		elseif mode == 9 then -- a copy: exact, turned about its symmetry, nudged, or a Block described another way
			local host = rng:pick(parts)
			local rot, pos, size = table.clone(host.rot), table.clone(host.pos), table.clone(host.size)
			local r = rng:float()
			if r < 0.3 and (host.shape == "Cylinder" or host.shape == "Ball") then
				rot = Quat.hemisphere(Quat.normalize(Quat.mul(host.rot, L.axisAngle(1, 0, 0, rng:range(0, 180)))))
				if host.shape == "Ball" and rng:float() < 0.5 then
					rot = rq(rng)
				end
			elseif r < 0.5 and host.shape == "Block" then
				rot = Quat.hemisphere(Quat.normalize(Quat.mul(host.rot, { 0, 0, S45, S45 })))
				size = { host.size[2], host.size[1], host.size[3] }
			elseif r < 0.75 then
				local a = rng:int(1, 3)
				pos[a] += rng:pick(OFFS)
			end
			table.insert(parts, L.part(rng:pick(SLOTS), host.shape, pos, rot, size))
		elseif mode == 10 then -- a Dust speck on a face
			local host = rng:pick(parts)
			add("Block", { host.pos[1] + host.size[1] / 2, host.pos[2], host.pos[3] }, L.I, { 0.05, 0.05, 0.05 })
		else -- a thin sheet over a face
			local host = rng:pick(parts)
			local axis = rng:int(1, 3)
			local size = { host.size[1] * rng:range(0.3, 1.3), host.size[2] * rng:range(0.3, 1.3), host.size[3] * rng:range(0.3, 1.3) }
			for a = 1, 3 do
				size[a] = math.min(math.max(size[a], 0.02), 6)
			end
			size[axis] = rng:pick({ 0.02, 0.021, 0.03 })
			local l = { 0, 0, 0 }
			l[axis] = host.size[axis] / 2 + size[axis] / 2 + rng:pick(OFFS)
			local w = Quat.rotate(host.rot, l)
			add("Block", { host.pos[1] + w[1], host.pos[2] + w[2], host.pos[3] + w[3] }, table.clone(host.rot), size)
		end
	end
	return L.renumber(parts)
end

return T
