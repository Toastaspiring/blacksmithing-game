--!nocheck
-- V2 round 3: a Block turned corner-down (its body diagonal along world Y) over a round part's top facet, its corner
-- `beyond` along the facet's normal from a point of the facet: Cover.shown against CoverBrute (no box test). Where the
-- probe's spread grows the Block's 3 half-spaces at its corner, the grown corner reaches √3 × (spread + EPS) below it,
-- past the Block's box by more than the facet's margin (probe + spread + 2·EPS_GEOM) allows for.
local W = "C:/Users/louis/AppData/Local/Temp/claude/C--Users-louis-Documents-RANDOM-ROBLOX/93ae48b4-72b9-4dc1-aa5d-451af1abf9a0/scratchpad/m2x-v2-3"
local R = W .. "/repo"
local Shapes = require(R .. "/src/shared/Physics/Shapes")
local Sampling = require(R .. "/src/shared/Physics/Sampling")
local Cover = require(R .. "/src/shared/Physics/Cover")
local Brute = require(R .. "/tests/Physics/CoverBrute")
local fmt = string.format

local th = math.acos(1 / math.sqrt(3))
local ax = { -1 / math.sqrt(2), 0, 1 / math.sqrt(2) }
local Q = { ax[1] * math.sin(th / 2), ax[2] * math.sin(th / 2), ax[3] * math.sin(th / 2), math.cos(th / 2) } -- (1,1,1)/√3 → +Y

local function run(shape, size, rot, a, wa, wb)
	local P = Shapes.prepare({ id = 1, slot = "Blade", shape = shape, material = "Iron", pos = { 0, 2, 0 }, rot = rot, size = size }, 1)
	local pm = Cover.model(P)
	-- the facet whose normal is nearest +Y
	local f, best = 1, -2
	for k = 1, pm.n do
		if pm.ny[k] > best then
			f, best = k, pm.ny[k]
		end
	end
	local poly = pm.poly[f]
	local nv = #poly / 3
	local cx = poly[1] + wa * (poly[4] - poly[1]) + wb * (poly[3 * nv - 2] - poly[1])
	local cy = poly[2] + wa * (poly[5] - poly[2]) + wb * (poly[3 * nv - 1] - poly[2])
	local cz = poly[3] + wa * (poly[6] - poly[3]) + wb * (poly[3 * nv] - poly[3])
	local nx, ny, nz = pm.nx[f], pm.ny[f], pm.nz[f]
	local probe, spread = 0.012 + pm.sag[f], pm.spread[f]
	local found = 0
	local rows = {}
	for step = 0, 40 do
		local beyond = probe + spread * (step / 20)
		local t = { cx + beyond * nx, cy + beyond * ny, cz + beyond * nz }
		local B = Shapes.prepare({ id = 2, slot = "Guard", shape = "Block", material = "Iron", pos = { t[1], t[2] + a * math.sqrt(3) / 2, t[3] }, rot = Q, size = { a, a, a } }, 2)
		local qm = Cover.model(B)
		local bp, bq = Brute.fromCover(pm), Brute.fromCover(qm)
		local fb = 6 * (f - 1)
		local margin = probe + spread + 2e-7
		local boxGap = math.max(B.minx - (pm.box[fb + 4] + margin), B.miny - (pm.box[fb + 5] + margin), B.minz - (pm.box[fb + 6] + margin),
			(pm.box[fb + 1] - margin) - B.maxx, (pm.box[fb + 2] - margin) - B.maxy, (pm.box[fb + 3] - margin) - B.maxz)
		for _, higher in ipairs({ false }) do
			local whole = Cover.shown(pm, { qm }, { higher }, math.huge, math.huge)
			local b = 0
			for k = 1, pm.n do
				b += Brute.facetShown(bp, k, { bq }, { higher }) or 0
			end
			-- and the exposure's own hand-over: is the Block a hider of the round part at all?
			local handed = Shapes.aabbOverlap(P, B, pm.reach + qm.over + 2e-7)
			local diff = whole - b
			if math.abs(diff) > 1e-12 * pm.total then
				found += 1
			end
			table.insert(rows, fmt("  beyond probe + %.2f spread: box gap past margin %+.6f, handed %s; Cover %.9e brute %.9e diff %+.3e (%.4f %% of the part)",
				step / 20, boxGap, tostring(handed), whole, b, diff, 100 * diff / pm.total))
		end
	end
	print(fmt("%s %s: facet %d (normal y %.4f, spread %.5f, probe %.5f): %d of 41 placements differ", shape, table.concat(size, "×"), f, best, spread, probe, found))
	for _, r in ipairs(rows) do
		print(r)
	end
end

run("Cylinder", { 0.6, 0.2, 0.2 }, { 0, 0, 0, 1 }, 0.2, 0.02, 0.5)
run("Ball", { 0.2, 0.2, 0.2 }, { 0, 0, 0, 1 }, 0.2, 0.05, 0.05)
