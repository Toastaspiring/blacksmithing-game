--!nocheck
-- V2 round 3: does the facet box test (Cover: a hider whose box, grown by its over, misses the facet's box grown by its
-- probe and spread makes no piece) leave out a piece of the hide test? A round part (a Ball or a Cylinder) with a turned
-- Block's corner (or a Wedge's edge) just past its facets' probe: Cover.shown against CoverBrute (no box test), facet by
-- facet, the Block above and below the round part in rank.
--   lune run corner_probe -- <trials> [seed]
local process = require("@lune/process")
local W = "C:/Users/louis/AppData/Local/Temp/claude/C--Users-louis-Documents-RANDOM-ROBLOX/93ae48b4-72b9-4dc1-aa5d-451af1abf9a0/scratchpad/m2x-v2-3"
local R = W .. "/repo"
local Shapes = require(R .. "/src/shared/Physics/Shapes")
local Cover = require(R .. "/src/shared/Physics/Cover")
local Brute = require(R .. "/tests/Physics/CoverBrute")
local fmt = string.format
local trials = tonumber(process.args[1]) or 2000
local seed = tonumber(process.args[2]) or 1

local s = seed
local function rnd()
	s = (s * 1103515245 + 12345) % 2147483648
	return s / 2147483648
end
local function quat()
	local u1, u2, u3 = rnd(), rnd(), rnd()
	local a, b = math.sqrt(1 - u1), math.sqrt(u1)
	local q = { a * math.sin(2 * math.pi * u2), a * math.cos(2 * math.pi * u2), b * math.sin(2 * math.pi * u3), b * math.cos(2 * math.pi * u3) }
	if q[4] < 0 then
		q = { -q[1], -q[2], -q[3], -q[4] }
	end
	return q
end
local function rotate(q, v)
	local x, y, z, w = q[1], q[2], q[3], q[4]
	local tx, ty, tz = 2 * (y * v[3] - z * v[2]), 2 * (z * v[1] - x * v[3]), 2 * (x * v[2] - y * v[1])
	return { v[1] + w * tx + (y * tz - z * ty), v[2] + w * ty + (z * tx - x * tz), v[3] + w * tz + (x * ty - y * tx) }
end

local function oneFacet(m, f)
	local b = 6 * (f - 1)
	return {
		part = m.part, round = m.round, n = 1, poly = { m.poly[f] }, nx = { m.nx[f] }, ny = { m.ny[f] }, nz = { m.nz[f] },
		area = { m.area[f] }, box = { m.box[b + 1], m.box[b + 2], m.box[b + 3], m.box[b + 4], m.box[b + 5], m.box[b + 6] },
		spread = { m.spread[f] }, total = m.area[f], np = 0, planes = {}, sag = { if m.round then m.sag[f] else 0 }, inner = 0,
		reach = m.reach, over = m.over, work = 0,
	}
end

local worst, worstWhat, hits = 0, "", 0
for trial = 1, trials do
	local round = if rnd() < 0.6 then "Ball" else "Cylinder"
	local r = 0.05 + 0.25 * rnd()
	local size = if round == "Ball" then { 2 * r, 2 * r, 2 * r } else { 0.2 + rnd(), 2 * r, 2 * r }
	local P = Shapes.prepare({ id = 1, slot = "Blade", shape = round, material = "Iron", pos = { 0, 2, 0 }, rot = if round == "Ball" then { 0, 0, 0, 1 } else quat(), size = size }, 1)
	local pm = Cover.model(P)
	-- a facet, and a turned Block whose nearest vertex stands in front of it, past its probe by 0…1.8 of its spread
	local f = 1 + math.floor(rnd() * pm.n)
	local poly = pm.poly[f]
	local nv = #poly / 3
	local wa, wb = rnd(), rnd()
	if wa + wb > 1 then
		wa, wb = 1 - wa, 1 - wb
	end
	local cx = poly[1] + wa * (poly[4] - poly[1]) + wb * (poly[3 * nv - 2] - poly[1])
	local cy = poly[2] + wa * (poly[5] - poly[2]) + wb * (poly[3 * nv - 1] - poly[2])
	local cz = poly[3] + wa * (poly[6] - poly[3]) + wb * (poly[3 * nv] - poly[3])
	local nx, ny, nz = pm.nx[f], pm.ny[f], pm.nz[f]
	local probe = 0.012 + pm.sag[f]
	local spread = pm.spread[f]
	local beyond = probe + spread * (0.9 + 0.9 * rnd()) + 2e-7
	local q = quat()
	local a = 0.1 + 0.3 * rnd()
	-- the Block's corner (−a/2, −a/2, −a/2) in its frame goes to the target; its centre is then the corner + R·(a/2, a/2, a/2)
	local tx, ty, tz = cx + beyond * nx, cy + beyond * ny, cz + beyond * nz
	local off = rotate(q, { a / 2, a / 2, a / 2 })
	-- turn the Block so its body diagonal points along the facet's normal: q maps (1,1,1)/√3 near n
	local d = { off[1], off[2], off[3] }
	local l = math.sqrt(d[1] * d[1] + d[2] * d[2] + d[3] * d[3])
	-- reject turns whose diagonal points back into the round part
	if (d[1] * nx + d[2] * ny + d[3] * nz) / l > 0.5 then
		local B = Shapes.prepare({ id = 2, slot = "Guard", shape = "Block", material = "Iron", pos = { tx + off[1], ty + off[2], tz + off[3] }, rot = q, size = { a, a, a } }, 2)
		local qm = Cover.model(B)
		local bp, bq = Brute.fromCover(pm), Brute.fromCover(qm)
		for _, higher in ipairs({ true, false }) do
			local c = Cover.shown(oneFacet(pm, f), { qm }, { higher }, math.huge, math.huge)
			local b = Brute.facetShown(bp, f, { bq }, { higher })
			if b then
				local diff = math.abs(c - b) / pm.area[f]
				if diff > 1e-9 then
					hits += 1
				end
				if diff > worst then
					worst = diff
					worstWhat = fmt("%s r %.3f facet %d (spread %.5f) Block a %.3f corner %.5f past the probe, higher %s: Cover %.6e Brute %.6e of %.6e",
						round, r, f, spread, a, beyond - probe, tostring(higher), c, b, pm.area[f])
				end
			end
		end
	end
end
print(fmt("%d trials: facets where Cover and the brute force differ by > 1e-9 of the facet: %d; worst %.3e", trials, hits, worst))
print(worstWhat)
