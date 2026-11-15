--!nocheck
-- fix-4: the reading against CoverBrute (the repo's, every part that hides, no box test) on random clusters round Balls:
-- 2–8 Balls r 0.05–0.4 and 2–10 Blocks, Wedges, CornerWedges and Cylinders cutting them at random, at faces' offsets of
-- 0, ±EPS_GEOM, ±1e-9 and HIDE_OFFSET ± EPS_GEOM from a Ball's surface, both ranks; per part |Cover − brute| / its area,
-- outside a tie (the brute force with the sphere and half-spaces grown and shrunk by 1e-11 brackets each facet).
--   lune run exactc -- <count> <seed>
local process = require("@lune/process")
local R = "C:/Users/louis/Documents/RANDOM/ROBLOX/Blacksmithing Game"
local Shapes = require(R .. "/src/shared/Physics/Shapes")
local Sampling = require(R .. "/src/shared/Physics/Sampling")
local Cover = require(R .. "/src/shared/Physics/Cover")
local Brute = require(R .. "/tests/Physics/CoverBrute")
local H = require(R .. "/tests/Physics/PhysicsHelpers")
local TestRng = require(R .. "/tests/lib/TestRng")
local Geo = require(R .. "/src/shared/Definitions/Balance").Geometry
local fmt = string.format
local COUNT, SEED = tonumber(process.args[1]) or 200, tonumber(process.args[2]) or 1
local rng = TestRng.new(SEED)
local OFFS = { 0, 0, Geo.EPS_GEOM, -Geo.EPS_GEOM, 1e-9, -1e-9, Geo.HIDE_OFFSET + Geo.EPS_GEOM, Geo.HIDE_OFFSET - Geo.EPS_GEOM, 1e-6, -1e-6 }
local worst, worstWhat, checked, ties, tieWorst, past, outside = 0, "", 0, 0, 0, 0, 0
for n = 1, COUNT do
	local parts = {}
	for _ = 1, rng:int(2, 8) do
		local r = rng:range(0.05, 0.4)
		table.insert(parts, H.solid(#parts + 1, "Ball", { rng:range(-0.3, 0.3), rng:range(-0.3, 0.3), rng:range(-0.3, 0.3) }, H.I, { 2 * r, 2 * r, 2 * r }))
	end
	local balls = #parts
	for _ = 1, rng:int(2, 10) do
		local shape = rng:pick({ "Block", "Block", "Wedge", "CornerWedge", "Cylinder" })
		local s = { rng:range(0.03, 0.6), rng:range(0.03, 0.6), rng:range(0.03, 0.6) }
		if shape == "Cylinder" then
			s[3] = s[2]
		end
		local q = H.randomQuat(rng)
		local b = parts[rng:int(1, balls)]
		local br = b.size[1] / 2
		-- a face's plane at a chosen offset from the Ball's surface, or anywhere through it
		local x, y, z = rng:normal(0, 1), rng:normal(0, 1), rng:normal(0, 1)
		local l = math.sqrt(x * x + y * y + z * z)
		local d = if rng:float() < 0.5 then br + rng:pick(OFFS) else rng:range(0, br)
		local P0 = Shapes.prepare(H.solid(1, shape, { 0, 0, 0 }, q, s), 1)
		-- its lowest point along (x, y, z) at d from the Ball's centre
		local ux, uy, uz = x / l, y / l, z / l
		local sx, sy, sz = Shapes.support(P0, -ux, -uy, -uz)
		local lo = sx * ux + sy * uy + sz * uz
		local k = d - lo
		table.insert(parts, H.solid(#parts + 1, shape, { b.pos[1] + k * ux, b.pos[2] + k * uy, b.pos[3] + k * uz }, q, s, rng:pick({ "Blade", "Guard" })))
	end
	local P = {}
	for i, p in ipairs(parts) do
		P[i] = Shapes.prepare(p, i)
	end
	local _, order = Sampling.ranked(P)
	local m, b = {}, {}
	for rr = 1, #order do
		local q = order[rr]
		local copy = false
		for t = 1, rr - 1 do
			copy = copy or Shapes.sameSolid(q, order[t])
		end
		if not copy and q.volume >= Geo.MIN_PART_VOLUME then
			m[q.index] = Cover.model(q)
			b[q.index] = Brute.fromCover(m[q.index])
		end
	end
	for i = 1, #P do
		if m[i] then
			local _, higher, hm = H.hidersOf(P, i, m)
			local all, above = Brute.hiders(P, i)
			local bh = {}
			for kk, j in ipairs(all) do
				bh[kk] = b[j]
			end
			local brute = 0
			for f = 1, m[i].n do
				local s = Brute.facetShown(b[i], f, bh, above)
				if s == nil then
					brute = nil
					break
				end
				brute += s
			end
			if brute == nil then
				past += 1
			else
				checked += 1
				local shown = Cover.shown(m[i], hm, higher, math.huge, math.huge)
				local dev = math.abs(shown - brute) / m[i].total
				if dev > 1e-9 then
					ties += 1
					for f = 1, m[i].n do
						local lo2 = Brute.facetShown(b[i], f, bh, above, 1e-11)
						local hi2 = Brute.facetShown(b[i], f, bh, above, -1e-11)
						local one = { part = m[i].part, round = m[i].round, n = 1, poly = { m[i].poly[f] }, nx = { m[i].nx[f] }, ny = { m[i].ny[f] }, nz = { m[i].nz[f] },
							area = { m[i].area[f] }, box = { table.unpack(m[i].box, 6 * f - 5, 6 * f) }, spread = { m[i].spread[f] }, flat = { m[i].flat[f] }, hull = { m[i].hull[f] },
							total = m[i].area[f], np = 0, planes = {}, sag = { if m[i].round then m[i].sag[f] else 0 }, inner = 0, reach = m[i].reach, over = m[i].over, work = 0 }
						local c = Cover.shown(one, hm, higher, math.huge, math.huge)
						local tol = 1e-11 * m[i].area[f] + 1e-15
						if lo2 and hi2 and not (c >= lo2 - tol and c <= hi2 + tol) then
							outside += 1
						end
					end
					tieWorst = math.max(tieWorst, dev)
				elseif dev > worst then
					worst, worstWhat = dev, fmt("design %d part %d (%s)", n, i, P[i].shape)
				end
			end
		end
	end
end
print(fmt("seed %d: %d designs, %d parts checked, %d past the edge limit; outside a tie the worst %.3g of a part (%s); %d settled by the bracket (up to %.3g), %d facets outside it",
	SEED, COUNT, checked, past, worst, worstWhat, ties, tieWorst, outside))
