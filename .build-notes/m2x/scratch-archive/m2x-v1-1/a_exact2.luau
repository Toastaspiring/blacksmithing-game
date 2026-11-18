--!nocheck
-- (a) Cover.shown against V1's own brute force (mybrute: 3D clip + inclusion–exclusion), on degenerate tangles: faces at
-- EPS and HIDE_OFFSET + EPS (and ±1e-12 about them), coplanar and near-coplanar faces (tilts 1e-12…1e-6 rad), hairlines and
-- gaps 1e-12…1e-5 between hiders, strips (fragmentation), MIN_DIM and MAX_DIM parts, turned copies of one solid, exact
-- copies, Dust, every shape at odd rotations. Args: seed count
local process = require("@lune/process")
local L = require("./lib")
local MB = require("./mybrute")
local Cover, Shapes, Quat = L.Cover, L.Shapes, L.Quat
local Geo = L.Geo
MB.init(Geo)
local fmt = string.format
local seed = tonumber(process.args[1]) or 1
local count = tonumber(process.args[2]) or 200

local state = seed * 2654435761 % 4294967296
local function rnd()
	-- xorshift32
	state = bit32.bxor(state, bit32.lshift(state, 13))
	state = bit32.bxor(state, bit32.rshift(state, 17))
	state = bit32.bxor(state, bit32.lshift(state, 5))
	return (state % 4294967296) / 4294967296
end
local function int(a, b) return a + math.floor(rnd() * (b - a + 1)) end
local function pick(t) return t[int(1, #t)] end
local function range(a, b) return a + (b - a) * rnd() end

local EPS, D = Geo.EPS_GEOM, Geo.HIDE_OFFSET
local OFFS = { 0, 0, 0, 1e-12, -1e-12, 1e-11, -1e-11, 1e-10, -1e-10, 1e-9, -1e-9, 1e-8, -1e-8, 5e-8, -5e-8, EPS, -EPS, EPS + 1e-12,
	EPS - 1e-12, -EPS + 1e-12, -EPS - 1e-12, 2 * EPS, -2 * EPS, 1e-6, -1e-6, 1e-5, -1e-5, D, D + EPS, D - EPS, D + EPS + 1e-12,
	D + EPS - 1e-12, D - 1e-9, D + 1e-9, D + 2 * EPS, 0.001, -0.001, 0.0119, 0.0121 }
local GAPS = { 1e-12, 1e-11, 1e-10, 1e-9, 1e-8, 1e-7, 2e-7, 1e-6, 1e-5, 0, -1e-12, -1e-9 }
local SHAPES = { "Block", "Block", "Wedge", "CornerWedge", "Cylinder", "Ball" }

local function randomQuat()
	local x, y, z, w = range(-1, 1), range(-1, 1), range(-1, 1), range(-1, 1)
	local n = math.sqrt(x * x + y * y + z * z + w * w)
	return Quat.hemisphere({ x / n, y / n, z / n, w / n })
end
local R = 0.70710678118654757
local AXIS_ROTS = { { 0, 0, 0, 1 }, { 0, 0, R, R }, { 0, R, 0, R }, { R, 0, 0, R }, { 0, 0, 1, 0 }, { 0, 1, 0, 0 }, { 1, 0, 0, 0 }, { 0.5, 0.5, 0.5, 0.5 } }
local function sized(shape, s)
	if shape == "Ball" then
		local m = math.min(s[1], s[2], s[3]); return { m, m, m }
	elseif shape == "Cylinder" then
		local m = math.min(s[2], s[3]); return { s[1], m, m }
	end
	return s
end
local function rsize()
	local function one()
		local r = rnd()
		if r < 0.1 then return 0.02 elseif r < 0.15 then return range(4.0, 4.4) elseif r < 0.3 then return range(0.02, 0.06) end
		return range(0.06, 1.2)
	end
	return { one(), one(), one() }
end

local function tangle()
	local parts = {}
	local function add(shape, pos, rot, size)
		local p = L.part("Blade", shape, pos, rot, sized(shape, size))
		p.id = #parts + 1
		table.insert(parts, p)
		return p
	end
	local n = int(3, 9)
	for k = 1, n do
		local mode = int(1, 12)
		local shape = pick(SHAPES)
		if k == 1 or mode <= 2 then
			local rot = if rnd() < 0.5 then pick(AXIS_ROTS) else randomQuat()
			add(shape, { range(-0.3, 0.3), range(-0.3, 0.3), range(-0.3, 0.3) }, rot, rsize())
		elseif mode <= 7 then -- face against face, the host's turn (or tilted by a hair), an offset of the list; side faces flush
			local host = pick(parts)
			local axis = int(1, 3)
			local side = if rnd() < 0.5 then -1 else 1
			local size = sized(shape, rsize())
			local off = pick(OFFS)
			local d = side * (host.size[axis] / 2 + size[axis] / 2 + off)
			if rnd() < 0.3 then d = side * (host.size[axis] / 2 - size[axis] / 2 + off) end
			local l = { 0, 0, 0 }
			l[axis] = d
			for a = 1, 3 do
				if a ~= axis then
					local r = rnd()
					if r < 0.4 then
						l[a] = (if rnd() < 0.5 then -1 else 1) * (host.size[a] / 2 - size[a] / 2) + pick(GAPS) * (if rnd() < 0.5 then -1 else 1)
					elseif r < 0.6 then
						l[a] = (if rnd() < 0.5 then -1 else 1) * (host.size[a] / 2 + size[a] / 2) + pick(GAPS) * (if rnd() < 0.5 then -1 else 1)
					else
						l[a] = (rnd() - 0.5) * host.size[a]
					end
				end
			end
			local w = Quat.rotate(host.rot, l)
			local rot = table.clone(host.rot)
			if rnd() < 0.25 then
				local tilt = pick({ 1e-12, 1e-10, 1e-9, 1e-8, 1e-7, 1e-6 })
				rot = Quat.hemisphere(Quat.normalize(Quat.mul(rot, L.axisAngle(rnd(), rnd(), rnd(), math.deg(tilt)))))
			end
			add(shape, { host.pos[1] + w[1], host.pos[2] + w[2], host.pos[3] + w[3] }, rot, size)
		elseif mode <= 9 then -- strips across a face with hairline gaps (fragmentation)
			local host = pick(parts)
			local axis = int(1, 3)
			local along = (axis % 3) + 1
			local other = 6 - axis - along
			local ns = int(2, 5)
			local g = pick(GAPS)
			local w = (host.size[along] - (ns - 1) * g) / ns
			if w > 0.02 then
				for s = 1, ns do
					if #parts >= 14 then break end
					local size = { 0, 0, 0 }
					size[axis] = pick({ 0.02, 0.03, 0.05 })
					size[along] = w
					size[other] = host.size[other] * range(0.9, 1.1)
					local l = { 0, 0, 0 }
					l[axis] = (host.size[axis] / 2 + size[axis] / 2 + pick({ 0, 0, EPS, -EPS, 1e-9, D - 0.02 })) * (if rnd() < 0.5 then -1 else 1)
					l[along] = -host.size[along] / 2 + w / 2 + (s - 1) * (w + g)
					local ww = Quat.rotate(host.rot, l)
					add("Block", { host.pos[1] + ww[1], host.pos[2] + ww[2], host.pos[3] + ww[3] }, table.clone(host.rot), size)
				end
			end
		elseif mode == 10 then -- the same solid in another frame, or an exact copy, or a nudged one
			local host = pick(parts)
			local rot = table.clone(host.rot)
			local pos = table.clone(host.pos)
			local r = rnd()
			if r < 0.4 then
				if host.shape == "Cylinder" or host.shape == "Ball" then
					rot = Quat.hemisphere(Quat.normalize(Quat.mul(host.rot, L.axisAngle(1, 0, 0, range(0, 360)))))
				elseif host.shape == "Block" then
					rot = Quat.hemisphere(Quat.normalize(Quat.mul(host.rot, pick({ { 0, 1, 0, 0 }, { 1, 0, 0, 0 }, { 0, 0, 1, 0 } }))))
				end
			elseif r < 0.7 then
				local a = int(1, 3)
				pos[a] += pick(GAPS)
			end
			local p = add(host.shape, pos, rot, table.clone(host.size))
			p.size = table.clone(host.size)
		elseif mode == 11 then -- Dust on a face
			local host = pick(parts)
			add("Block", { host.pos[1] + host.size[1] / 2, host.pos[2], host.pos[3] }, L.I, { 0.05, 0.05, 0.05 })
		else -- a thin sheet over a face at a probe-boundary offset
			local host = pick(parts)
			local axis = int(1, 3)
			local size = { host.size[1] * range(0.5, 1.2), host.size[2] * range(0.5, 1.2), host.size[3] * range(0.5, 1.2) }
			size[axis] = 0.02
			local l = { 0, 0, 0 }
			l[axis] = host.size[axis] / 2 + size[axis] / 2 + pick(OFFS)
			local w = Quat.rotate(host.rot, l)
			add("Block", { host.pos[1] + w[1], host.pos[2] + w[2], host.pos[3] + w[3] }, table.clone(host.rot), size)
		end
		if #parts >= 14 then break end
	end
	return parts
end

local function oneFacet(m, f)
	local b = 6 * (f - 1)
	return { part = m.part, round = m.round, n = 1, poly = { m.poly[f] }, nx = { m.nx[f] }, ny = { m.ny[f] }, nz = { m.nz[f] },
		area = { m.area[f] }, box = { m.box[b + 1], m.box[b + 2], m.box[b + 3], m.box[b + 4], m.box[b + 5], m.box[b + 6] },
		total = m.area[f], np = 0, planes = {}, sag = { if m.round then m.sag[f] else 0 }, inner = 0, work = 0 }
end

local checked, ties, past, bad, nonfinite = 0, 0, 0, 0, 0
local worstRel, worstOut = 0, 0
local worstInfo = ""
local smallByShape, smallCount = {}, 0
for t = 1, count do
	local parts = tangle()
	local P = L.prep(parts)
	local _, order = L.Sampling.ranked(P)
	local isCopy = {}
	for r = 2, #order do
		isCopy[order[r].index] = Shapes.sameSolid(order[r], order[r - 1])
	end
	local models = {}
	for i = 1, #P do
		if not isCopy[i] and P[i].volume >= Geo.MIN_PART_VOLUME then
			models[i] = Cover.model(P[i])
		end
	end
	for i = 1, #P do
		if models[i] then
			local index, higher = L.hidersOf(P, i)
			local hm = {}
			for k, j in ipairs(index) do hm[k] = models[j] end
			local m = models[i]
			local shown = Cover.shown(m, hm, higher, math.huge, math.huge)
			if shown ~= shown or shown == math.huge or shown == -math.huge then
				nonfinite += 1
				print("NONFINITE", seed, t, i)
			end
			local brute = 0
			for f = 1, m.n do
				local s = MB.facetShown(m, f, hm, higher)
				if s == nil then brute = nil; break end
				brute += s
			end
			if brute == nil then
				past += 1
			else
				checked += 1
				local rel = math.abs(shown - brute) / m.total
				if rel > 1e-9 then
					-- bracket facet by facet
					local outside = 0
					for f = 1, m.n do
						local lo = MB.facetShown(m, f, hm, higher, 1e-11)
						local hi = MB.facetShown(m, f, hm, higher, -1e-11)
						if lo and hi then
							local c = Cover.shown(oneFacet(m, f), hm, higher, math.huge, math.huge)
							local tol = 1e-11 * m.area[f] + 1e-15
							if c < lo - tol then outside += (lo - c) elseif c > hi + tol then outside += (c - hi) end
						end
					end
					if outside > 0 then
						bad += 1
						if outside / m.total > worstOut then
							worstOut = outside / m.total
							worstInfo = fmt("seed %d tangle %d part %d (%s): cover %.6g brute %.6g, outside the bracket by %.3g of its area", seed, t, i, parts[i].shape, shown, brute, outside / m.total)
						end
					else
						ties += 1
					end
				elseif rel > worstRel then
					worstRel = rel
				end
				if rel > 1e-12 and rel <= 1e-9 then
					smallByShape[parts[i].shape] = math.max(smallByShape[parts[i].shape] or 0, rel)
					smallCount += 1
				end
			end
		end
	end
end
print(fmt("seed %d: %d tangles, %d parts checked, %d ties (bracketed), %d outside the bracket, %d past the limit, %d non-finite; worst agreement outside ties %.3g; worst outside %.3g", seed, count, checked, ties, bad, past, nonfinite, worstRel, worstOut))
if worstInfo ~= "" then print("  " .. worstInfo) end
local t = {}
for k, v in pairs(smallByShape) do table.insert(t, k .. " " .. string.format("%.2g", v)) end
print("  parts between 1e-12 and 1e-9:", smallCount, table.concat(t, ", "))
