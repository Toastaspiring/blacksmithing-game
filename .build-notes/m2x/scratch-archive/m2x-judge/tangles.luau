--!nocheck
-- A fuzz corpus of tangles: small clusters of overlapping parts of every shape, with coincident faces, faces EPS and
-- LINE-tolerance apart, hairline gaps from 1e-9 to 1e-5, the probe distance and its neighbours, exact copies, turned
-- copies of round parts, Dust. Not valid designs (no slots, no hilt): the reading must be exact on any set of parts.
local Quat = require("./repo/src/shared/Blueprint/Quat")
local Random = require("./rng")

local T = {}

local SHAPES = { "Block", "Block", "Block", "Wedge", "CornerWedge", "Cylinder", "Ball" }
local OFFSETS = { 0, 0, 0, 1e-7, -1e-7, 2e-7, -2e-7, 1e-8, -1e-8, 1.5e-8, -1.5e-8, 3e-8, -3e-8, 1e-9, -1e-9, 1e-6, -1e-6,
	1e-5, -1e-5, 0.012, -0.012, 0.0119999, 0.0120001, 0.012 + 1e-7, 0.012 - 1e-7, 0.001, -0.001, 0.05 }
local R = 0.70710678118654757
local AXIS_ROTS = { { 0, 0, 0, 1 }, { 0, 0, R, R }, { 0, R, 0, R }, { R, 0, 0, R }, { 0, 0, 1, 0 }, { 0.5, 0.5, 0.5, 0.5 } }

local function randRot(rng)
	local x, y, z, w = rng:NextNumber() - 0.5, rng:NextNumber() - 0.5, rng:NextNumber() - 0.5, rng:NextNumber() - 0.5
	local l = math.sqrt(x * x + y * y + z * z + w * w)
	return Quat.hemisphere({ x / l, y / l, z / l, w / l })
end

local function axisAngle(ax, ay, az, deg)
	local h = math.rad(deg) / 2
	local n = math.sqrt(ax * ax + ay * ay + az * az)
	return Quat.hemisphere(Quat.normalize({ ax / n * math.sin(h), ay / n * math.sin(h), az / n * math.sin(h), math.cos(h) }))
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

-- one tangle of n parts (seeded)
function T.tangle(seed, n)
	local rng = Random.new(seed)
	local parts = {}
	local function add(shape, pos, rot, size)
		table.insert(parts, { id = #parts + 1, shape = shape, slot = "Blade", material = "Iron", pos = pos, rot = rot,
			size = sized(shape, size) })
	end
	local function rsize()
		return { 0.02 + rng:NextNumber() * 0.8, 0.02 + rng:NextNumber() * 0.8, 0.02 + rng:NextNumber() * 0.8 }
	end
	for k = 1, n do
		local mode = rng:NextInteger(1, 10)
		local shape = SHAPES[rng:NextInteger(1, #SHAPES)]
		if k == 1 or mode <= 3 or #parts == 0 then
			-- free part
			local rot = if rng:NextNumber() < 0.6 then AXIS_ROTS[rng:NextInteger(1, #AXIS_ROTS)] else randRot(rng)
			add(shape, { rng:NextNumber() * 0.6 - 0.3, rng:NextNumber() * 0.6 - 0.3, rng:NextNumber() * 0.6 - 0.3 }, rot, rsize())
		elseif mode <= 7 then
			-- a face against a face of an earlier part (same rotation), offset from the list
			local host = parts[rng:NextInteger(1, #parts)]
			local axis = rng:NextInteger(1, 3)
			local side = if rng:NextNumber() < 0.5 then -1 else 1
			local size = rsize()
			size = sized(shape, size)
			local off = OFFSETS[rng:NextInteger(1, #OFFSETS)]
			-- local offset along the host's axis
			local d = side * (host.size[axis] / 2 + size[axis] / 2 + off)
			-- sometimes overlap a lot instead
			if rng:NextNumber() < 0.25 then
				d = side * (host.size[axis] / 2 - size[axis] / 2 + off)
			end
			local lx, ly, lz = 0, 0, 0
			if axis == 1 then lx = d elseif axis == 2 then ly = d else lz = d end
			-- slide along the face, sometimes flush with an edge
			local function slide(a)
				local r = rng:NextNumber()
				if r < 0.3 then
					local s2 = if rng:NextNumber() < 0.5 then -1 else 1
					return s2 * (host.size[a] / 2 - size[a] / 2) + OFFSETS[rng:NextInteger(1, #OFFSETS)]
				end
				return (rng:NextNumber() - 0.5) * host.size[a]
			end
			if axis ~= 1 then lx = slide(1) end
			if axis ~= 2 then ly = slide(2) end
			if axis ~= 3 then lz = slide(3) end
			local ux, vx, wx, uy, vy, wy, uz, vz, wz = Quat.toMatrix(host.rot)
			local pos = { host.pos[1] + lx * ux + ly * vx + lz * wx, host.pos[2] + lx * uy + ly * vy + lz * wy,
				host.pos[3] + lx * uz + ly * vz + lz * wz }
			add(shape, pos, { host.rot[1], host.rot[2], host.rot[3], host.rot[4] }, size)
		elseif mode == 8 then
			-- exact copy, or a turned copy of a round part, or a copy nudged by a tiny offset
			local host = parts[rng:NextInteger(1, #parts)]
			local r = rng:NextNumber()
			local rot = { host.rot[1], host.rot[2], host.rot[3], host.rot[4] }
			local pos = { host.pos[1], host.pos[2], host.pos[3] }
			if r < 0.3 and (host.shape == "Cylinder" or host.shape == "Ball") then
				local spin = axisAngle(1, 0, 0, rng:NextNumber() * 90)
				rot = Quat.hemisphere(Quat.normalize(Quat.mul(host.rot, spin)))
			elseif r < 0.6 then
				local a = rng:NextInteger(1, 3)
				pos[a] += OFFSETS[rng:NextInteger(1, #OFFSETS)]
			end
			table.insert(parts, { id = #parts + 1, shape = host.shape, slot = "Blade", material = "Iron", pos = pos, rot = rot,
				size = { host.size[1], host.size[2], host.size[3] } })
		elseif mode == 9 then
			-- Dust speck on a part's face
			local host = parts[rng:NextInteger(1, #parts)]
			add("Block", { host.pos[1] + host.size[1] / 2, host.pos[2], host.pos[3] }, { 0, 0, 0, 1 }, { 0.05, 0.05, 0.05 })
		else
			-- a thin sheet / hairline slab over a part's face
			local host = parts[rng:NextInteger(1, #parts)]
			local axis = rng:NextInteger(1, 3)
			local th = ({ 0.02, 0.013, 0.012, 0.011, 0.03 })[rng:NextInteger(1, 5)]
			local size = { host.size[1] * (0.3 + rng:NextNumber()), host.size[2] * (0.3 + rng:NextNumber()),
				host.size[3] * (0.3 + rng:NextNumber()) }
			size[axis] = math.max(th, 0.02)
			local d = host.size[axis] / 2 + size[axis] / 2 + OFFSETS[rng:NextInteger(1, #OFFSETS)]
			local lx, ly, lz = 0, 0, 0
			if axis == 1 then lx = d elseif axis == 2 then ly = d else lz = d end
			local ux, vx, wx, uy, vy, wy, uz, vz, wz = Quat.toMatrix(host.rot)
			add("Block", { host.pos[1] + lx * ux + ly * vx + lz * wx, host.pos[2] + lx * uy + ly * vy + lz * wy,
				host.pos[3] + lx * uz + ly * vz + lz * wz }, { host.rot[1], host.rot[2], host.rot[3], host.rot[4] }, size)
		end
	end
	return parts
end

function T.corpus(seed0, count, nMin, nMax)
	local out = {}
	local rng = Random.new(seed0)
	for k = 1, count do
		local n = rng:NextInteger(nMin or 3, nMax or 12)
		table.insert(out, { name = "tangle " .. seed0 .. "#" .. k, parts = T.tangle(seed0 * 100003 + k, n) })
	end
	return out
end

return T
