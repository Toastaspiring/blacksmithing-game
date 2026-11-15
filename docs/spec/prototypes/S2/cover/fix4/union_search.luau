--!nocheck
-- fix-4: V1's script (m2x-v1-4) on a named tree: TREE=<name> (lab.luau; default "now").
local TREE = require("@lune/process").env.TREE or "now"
-- V1 (m2x, round 4): round filler in the union of a round part and another part, truly hidden or nearly, that the
-- build reads at 2 % or more. Random placements; the build's reading (Cover, as Sampling hands the hiders over) first,
-- the truth (VisibleOracle) only where the build keeps the filler.
--   lune run union_search -- <family> <seed> <count>
-- families:
--   pg   F5 with its pommel a Ball 0.6 across, the grip Block entering it from y 0.3: a Ball filler at the crease
--   pgc  the same pommel, a grip Cylinder r 0.08 entering it: a Ball filler at the crease (two round hiders)
--   pgr  the same pommel and grip Block: a rod (Cylinder) filler at the crease
--   gb   a grip Cylinder r 0.1 crossed by a guard Block: a Ball or a rod filler at their crease
--   bb   two pommel Balls r 0.2 overlapping: a Ball filler on their crease (two round hiders)
local process = require("@lune/process")
local L = require("./lab").tree(TREE)
local TestRng = require(L.root .. "/tests/lib/TestRng")
local fmt = string.format
local fam, seed, count = process.args[1] or "pg", tonumber(process.args[2]) or 1, tonumber(process.args[3]) or 200
local ZERO = tonumber(process.args[4]) or 0.02 -- report only fillers truly under this share
local rng = TestRng.new(seed)

local function unit(x, y, z)
	local l = math.sqrt(x * x + y * y + z * z)
	return { x / l, y / l, z / l }
end

local function rotX(u)
	local c = u[1]
	local ay, az = -u[3], u[2]
	local s = math.sqrt(ay * ay + az * az)
	if s < 1e-12 then
		return if c > 0 then L.I else { 0, 0, 1, 0 }
	end
	return L.axisAngle(0, ay, az, math.deg(math.atan2(s, c)))
end

local R = 0.3
local PC = { 0, R, 0 }

local function base()
	local f5 = L.repoFixture("F5")
	f5[1] = L.part("Pommel", "Ball", PC, L.I, { 2 * R, 2 * R, 2 * R })
	return f5
end

-- one random design and the index of its filler
local function design()
	local parts
	if fam == "pg" or fam == "pgr" then
		parts = base()
		-- a point on the sphere near the grip's side (x or z = ±0.08) a little outside or inside the footprint
		local side = rng:int(1, 4)
		local off = rng:range(-0.03, 0.03)
		local along = rng:range(-0.08, 0.08)
		local x, z = 0.08 + off, along
		if side == 2 then
			x = -x
		elseif side == 3 then
			x, z = along, 0.08 + off
		elseif side == 4 then
			x, z = along, -(0.08 + off)
		end
		local y = PC[2] + math.sqrt(math.max(R * R - x * x - z * z, 0))
		local d = unit(x, y - PC[2], z)
		local p = rng:pick({ 1e-5, 1e-4, 5e-4, 1e-3, 2e-3, 5e-3, -1e-4, -1e-3 }) -- out of the sphere (< 0: inside)
		if fam == "pg" then
			local rho = rng:range(0.037, 0.1)
			local k = R - rho + p
			table.insert(parts, L.part("Blade", "Ball", { PC[1] + k * d[1], PC[2] + k * d[2], PC[3] + k * d[3] }, L.I, { 2 * rho, 2 * rho, 2 * rho }))
		else
			local rho = rng:range(0.02, 0.06)
			local hx = rng:range(0.03, 0.12)
			local u = if rng:float() < 0.5 then d else unit(rng:normal(0, 1), rng:normal(0, 1), rng:normal(0, 1))
			-- the largest k with maxDist ≤ R + p
			local lo, hi = -R, R
			for _ = 1, 60 do
				local k = (lo + hi) / 2
				local P0 = L.Shapes.prepare(L.part("Blade", "Cylinder", { PC[1] + k * d[1], PC[2] + k * d[2], PC[3] + k * d[3] }, rotX(u), { 2 * hx, 2 * rho, 2 * rho }), 1)
				if L.Shapes.maxDist(P0, PC[1], PC[2], PC[3]) <= R + p then
					lo = k
				else
					hi = k
				end
			end
			table.insert(parts, L.part("Blade", "Cylinder", { PC[1] + lo * d[1], PC[2] + lo * d[2], PC[3] + lo * d[3] }, rotX(u), { 2 * hx, 2 * rho, 2 * rho }))
		end
	elseif fam == "pgc" then
		parts = base()
		parts[2] = L.part("Grip", "Cylinder", { 0, 0.75, 0 }, L.Z90, { 0.9, 0.16, 0.16 })
		local a = rng:range(0, 2 * math.pi)
		local x, z = 0.08 * math.cos(a), 0.08 * math.sin(a)
		local off = rng:range(-0.03, 0.03)
		x, z = x * (1 + off / 0.08), z * (1 + off / 0.08)
		local y = PC[2] + math.sqrt(R * R - x * x - z * z)
		local d = unit(x, y - PC[2], z)
		local p = rng:pick({ 1e-5, 1e-4, 5e-4, 1e-3, 2e-3, 5e-3, -1e-4 })
		local rho = rng:range(0.037, 0.1)
		local k = R - rho + p
		table.insert(parts, L.part("Blade", "Ball", { PC[1] + k * d[1], PC[2] + k * d[2], PC[3] + k * d[3] }, L.I, { 2 * rho, 2 * rho, 2 * rho }))
	elseif fam == "gb" then
		parts = L.repoFixture("F5")
		parts[1] = L.part("Pommel", "Ball", { 0, 0.17, 0 }, L.I, { 0.26, 0.26, 0.26 })
		parts[2] = L.part("Grip", "Cylinder", { 0, 0.75, 0 }, L.Z90, { 0.9, 0.2, 0.2 })
		-- the guard Block 1.0 × 0.18 × 0.24 at y 1.29 overlaps the grip's top (y 1.2) by moving down
		parts[3] = L.part("Guard", "Block", { 0, 1.2, 0 }, L.I, { 1.0, 0.18, 0.24 })
		-- the crease: the grip's side (r 0.1) meets the guard's bottom face (y 1.11)
		local a = rng:range(0, 2 * math.pi)
		local w = { math.cos(a), 0, math.sin(a) }
		local p = rng:pick({ 1e-5, 1e-4, 5e-4, 1e-3, 2e-3, 5e-3, -1e-4 })
		if rng:float() < 0.5 then
			local rho = rng:range(0.037, 0.08)
			local y = 1.11 + rng:range(-rho, rho)
			local k = 0.1 - rho + p
			table.insert(parts, L.part("Blade", "Ball", { k * w[1], y, k * w[3] }, L.I, { 2 * rho, 2 * rho, 2 * rho }))
		else
			local rho = rng:range(0.02, 0.05)
			local len = rng:range(0.06, 0.4)
			local y = 1.11 + rng:range(-len / 2, len / 2)
			local k = 0.1 - rho + p
			table.insert(parts, L.part("Blade", "Cylinder", { k * w[1], y, k * w[3] }, L.Z90, { len, 2 * rho, 2 * rho }))
		end
	else -- bb
		parts = L.repoFixture("F5")
		local s = rng:range(0.08, 0.16)
		parts[1] = L.part("Pommel", "Ball", { -s, 0.2, 0 }, L.I, { 0.4, 0.4, 0.4 })
		table.insert(parts, L.part("Pommel", "Ball", { s, 0.2, 0 }, L.I, { 0.4, 0.4, 0.4 }))
		-- the crease circle at x = 0, radius sqrt(0.04 − s²), in the YZ plane about (0, 0.2, 0)
		local cr = math.sqrt(0.04 - s * s)
		local a = rng:range(0, 2 * math.pi)
		local p = rng:pick({ 1e-5, 1e-4, 5e-4, 1e-3, 2e-3, 5e-3, -1e-4, -1e-3 })
		local rho = rng:range(0.037, 0.09)
		local k = cr - rho + p + rng:range(-0.02, 0.02)
		table.insert(parts, L.part("Blade", "Ball", { rng:range(-0.03, 0.03), 0.2 + k * math.cos(a), k * math.sin(a) }, L.I, { 2 * rho, 2 * rho, 2 * rho }))
	end
	return L.renumber(parts), #parts
end

local t0 = os.clock()
local found, tried, keptN = {}, 0, 0
for n = 1, count do
	local parts, i = design()
	local P = L.prep(parts)
	local models = L.models(P)
	if models[i] then
		tried += 1
		local read = L.readOf(P, i, models)
		if read >= 0.02 then
			keptN += 1
			local _, _, hider = L.Oracle.flags(P)
			local truth = L.Oracle.share(P, i, hider)
			if truth < ZERO then
				table.insert(found, { n = n, read = read, truth = truth, parts = parts, i = i })
			end
		end
	end
end
table.sort(found, function(a, b)
	return a.read > b.read
end)
print(fmt("%s seed %d: %d placements read, %d kept, %d of them truly under %.4g %% (%.1f s)", fam, seed, tried, keptN, #found, 100 * ZERO, os.clock() - t0))
local serde = require("@lune/serde")
for k = 1, math.min(#found, 8) do
	local f = found[k]
	local p = f.parts[f.i]
	print(fmt("  #%d reads %.3f%% truth %.3f%%: %s %s pos (%.6f, %.6f, %.6f) size (%.5f, %.5f, %.5f) rot (%.6f, %.6f, %.6f, %.6f)", f.n, 100 * f.read, 100 * f.truth,
		p.shape, p.slot, p.pos[1], p.pos[2], p.pos[3], p.size[1], p.size[2], p.size[3], p.rot[1], p.rot[2], p.rot[3], p.rot[4]))
	if k <= 3 then
		print("    " .. serde.encode("json", f.parts))
	end
end
