--!nocheck
-- tangles: Cover.shown on Sampling's hiders against the brute force with every part a hider and no box test
local process = require("@lune/process")
local L = require("./lab")
local H, Cover, Shapes, Quat, Sampling = L.H, L.Cover, L.Shapes, L.Quat, L.Sampling
local NB = L.Brute
local first, count = tonumber(process.args[1]) or 1, tonumber(process.args[2]) or 100
local EXACT, TIE = 1e-9, 1e-11
local SHAPES = { "Block", "Block", "Block", "Wedge", "CornerWedge", "Cylinder", "Ball" }
local OFFSETS = { 0, 0, 0, 1e-7, -1e-7, 2e-7, -2e-7, 1e-8, -1e-8, 1.5e-8, -1.5e-8, 3e-8, -3e-8, 1e-9, -1e-9, 1e-6, -1e-6, 1e-5, -1e-5,
	0.012, -0.012, 0.0119999, 0.0120001, 0.012 + 1e-7, 0.012 - 1e-7, 0.001, -0.001, 0.05 }
local R = 0.70710678118654757
local AXIS_ROTS = { { 0, 0, 0, 1 }, { 0, 0, R, R }, { 0, R, 0, R }, { R, 0, 0, R }, { 0, 0, 1, 0 }, { 0.5, 0.5, 0.5, 0.5 } }
local function sized(shape, s)
	if shape == "Ball" then local m = math.min(s[1], s[2], s[3]) return { m, m, m }
	elseif shape == "Cylinder" then local m = math.min(s[2], s[3]) return { s[1], m, m } end
	return s
end
local function tangle(rng)
	local parts = {}
	local function add(shape, pos, rot, size) table.insert(parts, H.solid(#parts + 1, shape, pos, rot, sized(shape, size))) end
	local function rsize() return { rng:range(0.02, 0.82), rng:range(0.02, 0.82), rng:range(0.02, 0.82) } end
	for k = 1, rng:int(3, 10) do
		local mode = rng:int(1, 10)
		local shape = rng:pick(SHAPES)
		if k == 1 or mode <= 3 then
			local rot = if rng:float() < 0.6 then rng:pick(AXIS_ROTS) else H.randomQuat(rng)
			add(shape, { rng:range(-0.3, 0.3), rng:range(-0.3, 0.3), rng:range(-0.3, 0.3) }, rot, rsize())
		elseif mode <= 7 then
			local host = rng:pick(parts)
			local axis = rng:int(1, 3)
			local side = if rng:float() < 0.5 then -1 else 1
			local size = sized(shape, rsize())
			local off = rng:pick(OFFSETS)
			local d = side * (host.size[axis] / 2 + size[axis] / 2 + off)
			if rng:float() < 0.25 then d = side * (host.size[axis] / 2 - size[axis] / 2 + off) end
			local l = { 0, 0, 0 }
			l[axis] = d
			for a = 1, 3 do
				if a ~= axis then
					l[a] = if rng:float() < 0.3 then (if rng:float() < 0.5 then -1 else 1) * (host.size[a] / 2 - size[a] / 2) + rng:pick(OFFSETS)
						else (rng:float() - 0.5) * host.size[a]
				end
			end
			local w = Quat.rotate(host.rot, l)
			add(shape, { host.pos[1] + w[1], host.pos[2] + w[2], host.pos[3] + w[3] }, table.clone(host.rot), size)
		elseif mode == 8 then
			local host = rng:pick(parts)
			local rot, pos = table.clone(host.rot), table.clone(host.pos)
			local r = rng:float()
			if r < 0.3 and (host.shape == "Cylinder" or host.shape == "Ball") then
				rot = Quat.hemisphere(Quat.normalize(Quat.mul(host.rot, H.axisAngle(1, 0, 0, rng:range(0, 90)))))
			elseif r < 0.6 then
				local a = rng:int(1, 3)
				pos[a] += rng:pick(OFFSETS)
			end
			table.insert(parts, H.solid(#parts + 1, host.shape, pos, rot, table.clone(host.size)))
		elseif mode == 9 then
			local host = rng:pick(parts)
			add("Block", { host.pos[1] + host.size[1] / 2, host.pos[2], host.pos[3] }, H.I, { 0.05, 0.05, 0.05 })
		else
			local host = rng:pick(parts)
			local axis = rng:int(1, 3)
			local size = { host.size[1] * rng:range(0.3, 1.3), host.size[2] * rng:range(0.3, 1.3), host.size[3] * rng:range(0.3, 1.3) }
			size[axis] = math.max(rng:pick({ 0.02, 0.013, 0.012, 0.011, 0.03 }), 0.02)
			local l = { 0, 0, 0 }
			l[axis] = host.size[axis] / 2 + size[axis] / 2 + rng:pick(OFFSETS)
			local w = Quat.rotate(host.rot, l)
			add("Block", { host.pos[1] + w[1], host.pos[2] + w[2], host.pos[3] + w[3] }, table.clone(host.rot), size)
		end
	end
	return parts
end
local function oneFacet(m, f)
	local b = 6 * (f - 1)
	return { part = m.part, round = m.round, n = 1, poly = { m.poly[f] }, nx = { m.nx[f] }, ny = { m.ny[f] }, nz = { m.nz[f] },
		area = { m.area[f] }, box = { m.box[b + 1], m.box[b + 2], m.box[b + 3], m.box[b + 4], m.box[b + 5], m.box[b + 6] },
		total = m.area[f], np = 0, planes = {}, sag = { if m.round then m.sag[f] else 0 }, inner = 0, reach = m.reach, over = m.over, work = 0 }
end
local function models(P)
	local _, order = L.Sampling.ranked(P)
	local m = {}
	for r = 1, #order do
		local q = order[r]
		local copy = false
		for t = 1, r - 1 do copy = copy or L.Shapes.sameSolid(q, order[t]) end
		if not copy and q.volume >= L.Geo.MIN_PART_VOLUME then m[q.index] = L.Cover.model(q) end
	end
	return m
end
local checked, ties, past, outside, worst, worstWhat = 0, 0, 0, 0, 0, ""
local byShape = {}
for seed = first, first + count - 1 do
	local rng = L.TestRng.new(seed)
	local parts = L.prepared(tangle(rng))
	local m = models(parts)
	local b = {}
	for i, mm in pairs(m) do b[i] = NB.fromCover(mm) end
	for i = 1, #parts do
		if m[i] then
			local _, higher, hm = H.hidersOf(parts, i, m)
			local all, above = NB.hiders(parts, i)
			local bh = {}
			for k, j in ipairs(all) do bh[k] = b[j] end
			local brute = 0
			for f = 1, m[i].n do
				local s = NB.facetShown(b[i], f, bh, above)
				if s == nil then brute = nil break end
				brute += s
			end
			if brute == nil then
				past += 1
			else
				checked += 1
				local shown = Cover.shown(m[i], hm, higher, math.huge, math.huge)
				if math.abs(shown - brute) > EXACT * m[i].total then
					ties += 1
					local bad = 0
					for f = 1, m[i].n do
						local lo = NB.facetShown(b[i], f, bh, above, TIE)
						local hi = NB.facetShown(b[i], f, bh, above, -TIE)
						if lo and hi then
							local c = Cover.shown(oneFacet(m[i], f), hm, higher, math.huge, math.huge)
							local tol = 1e-11 * m[i].area[f] + 1e-15
							if c < lo - tol then bad = math.max(bad, (lo - c) / m[i].total)
							elseif c > hi + tol then bad = math.max(bad, (c - hi) / m[i].total) end
						end
					end
					if bad > 0 then
						outside += 1
						local sh = parts[i].shape
						byShape[sh] = (byShape[sh] or 0) + 1
						if bad > worst then worst, worstWhat = bad, string.format("seed %d part %d %s", seed, i, sh) end
					end
				end
			end
		end
	end
end
local shapes = {}
for k, v in pairs(byShape) do table.insert(shapes, k .. " " .. v) end
print(string.format("seeds %d..%d: checked %d, off the exact %d, outside the bracket %d (%s), worst %.3g of the part (%s), past %d",
	first, first + count - 1, checked, ties, outside, table.concat(shapes, ", "), worst, worstWhat, past))
