--!strict
-- tests/Physics/VisibleOracle.luau — the truth about how much of a part shows, for VerdictPrecision.spec (E-S2.11). Not a spec
-- (the runner loads *.spec.luau only). The same hide test per point as §4.4 (buried, on a surface with a higher rank, probe
-- inside), against all parts but exact copies and Dust, with no budget, on a fine low-discrepancy lattice per face: rank-1
-- golden-ratio lattices on polygons (an axis-aligned boundary errs by one lattice step of the axis, not by a grid row), a
-- Fibonacci lattice on a ball, (axis, angle) on a cylinder's side. It shares no grid with Physics/Sampling, only its rank.
--   flags(parts)                     per part: an exact copy of a higher rank, Dust, and so whether it hides
--   measure(parts, i, hider, total)  the share of parts[i] that shows, on about `total` points
--   share(parts, i, hider)           the same on SPACING or MIN_POINTS, whichever is finer; 4,000 points settle a share over 30 %

local Balance = require("../../src/shared/Definitions/Balance")
local Sampling = require("../../src/shared/Physics/Sampling")
local Shapes = require("../../src/shared/Physics/Shapes")

type Prepared = Shapes.Prepared

local sd, aabbContains, aabbOverlap, toWorld = Shapes.sd, Shapes.aabbContains, Shapes.aabbOverlap, Shapes.toWorld
local sqrt, cos, sin, ceil, max = math.sqrt, math.cos, math.sin, math.ceil, math.max
local Geo = Balance.Geometry
local EPS, DELTA = Geo.EPS_GEOM, Geo.HIDE_OFFSET
local TWO_PI = 2 * math.pi
local GOLD = 0.6180339887498949
local GOLDEN_ANGLE = 2.399963229728653

local Oracle = {}

Oracle.SPACING = 0.0075
Oracle.MIN_POINTS = 40000
Oracle.COARSE_POINTS = 4000
Oracle.COARSE_ACCEPT = 0.30

-- Which parts hide: not exact copies of a higher rank, not Dust.
function Oracle.flags(parts: { Prepared }): ({ boolean }, { boolean }, { boolean })
	local N = #parts
	local _, order = Sampling.ranked(parts)
	local isCopy, isDust, hider = table.create(N, false), table.create(N, false), table.create(N, false)
	for r = 1, N do
		local i = order[r].index
		isDust[i] = parts[i].volume < Geo.MIN_PART_VOLUME
		for t = 1, r - 1 do
			if Shapes.sameSolid(order[r], order[t]) then
				isCopy[i] = true
				break
			end
		end
		hider[i] = not isCopy[i] and not isDust[i]
	end
	return isCopy, isDust, hider
end

function Oracle.measure(parts: { Prepared }, i: number, hider: { boolean }, total: number): number
	local p = parts[i]
	local rank = Sampling.ranked(parts)
	local cand: { Prepared } = {}
	for j = 1, #parts do
		if j ~= i and hider[j] and aabbOverlap(p, parts[j], DELTA + 2 * EPS) then
			table.insert(cand, parts[j])
		end
	end
	if #cand == 0 then
		return 1
	end
	local function hidden(x: number, y: number, z: number, nx: number, ny: number, nz: number): boolean
		local ox, oy, oz = x + DELTA * nx, y + DELTA * ny, z + DELTA * nz
		for c = 1, #cand do
			local q = cand[c]
			local hit = false
			if aabbContains(q, x, y, z, 2 * EPS) then
				local d0 = sd(q, x, y, z)
				hit = d0 < -EPS or (rank[q.index] < rank[i] and d0 <= EPS)
			end
			if not hit and aabbContains(q, ox, oy, oz, 2 * EPS) then
				hit = sd(q, ox, oy, oz) <= EPS
			end
			if hit then
				cand[c], cand[1] = cand[1], q -- the same OR, found sooner next time
				return true
			end
		end
		return false
	end

	local area = p.area
	local visible = 0
	if p.code == Shapes.BALL then
		local n = max(total, 16)
		for k = 0, n - 1 do
			local lz = 1 - 2 * (k + 0.5) / n
			local rho = sqrt(max(0, 1 - lz * lz))
			local a = k * GOLDEN_ANGLE
			local lx, ly = rho * cos(a), rho * sin(a)
			local x, y, z = toWorld(p, p.r * lx, p.r * ly, p.r * lz)
			if not hidden(x, y, z, lx * p.ux + ly * p.vx + lz * p.wx, lx * p.uy + ly * p.vy + lz * p.wy,
				lx * p.uz + ly * p.vz + lz * p.wz) then
				visible += area / n
			end
		end
	elseif p.code == Shapes.CYLINDER then
		local r, hx = p.r, p.hx
		local sideArea = TWO_PI * r * 2 * hx
		local capArea = TWO_PI * r * r / 2
		local n = max(ceil(total * sideArea / area), 64)
		for k = 0, n - 1 do
			local a = TWO_PI * ((k * GOLD + 0.5) % 1)
			local ca, sa = cos(a), sin(a)
			local x, y, z = toWorld(p, -hx + 2 * hx * (k + 0.5) / n, r * ca, r * sa)
			if not hidden(x, y, z, ca * p.vx + sa * p.wx, ca * p.vy + sa * p.wy, ca * p.vz + sa * p.wz) then
				visible += sideArea / n
			end
		end
		-- a cap: a lattice on the bounding square, kept inside the disk
		local nCap = ceil(max(ceil(total * capArea / area), 64) * 4 / math.pi)
		for side = -1, 1, 2 do
			local count, shows = 0, 0
			for k = 0, nCap - 1 do
				local ly = -r + 2 * r * (k + 0.5) / nCap
				local lz = -r + 2 * r * ((k * GOLD + 0.25) % 1)
				if ly * ly + lz * lz <= r * r then
					count += 1
					local x, y, z = toWorld(p, side * hx, ly, lz)
					if not hidden(x, y, z, side * p.ux, side * p.uy, side * p.uz) then
						shows += 1
					end
				end
			end
			if count > 0 then
				visible += capArea * shows / count
			end
		end
	else
		for _, poly in ipairs(Shapes.faces(p)) do
			local ox, oy, oz = poly[1], poly[2], poly[3]
			local ax, ay, az = poly[4] - ox, poly[5] - oy, poly[6] - oz
			local tri = #poly == 9
			local bx, by, bz
			if tri then
				bx, by, bz = poly[7] - ox, poly[8] - oy, poly[9] - oz
			else
				bx, by, bz = poly[10] - ox, poly[11] - oy, poly[12] - oz
			end
			local cx, cy, cz = ay * bz - az * by, az * bx - ax * bz, ax * by - ay * bx
			local l = sqrt(cx * cx + cy * cy + cz * cz)
			local nx, ny, nz = cx / l, cy / l, cz / l
			local faceArea = if tri then l / 2 else l
			local n = max(ceil(total * faceArea / area), 64)
			for k = 0, n - 1 do
				local u, v = (k + 0.5) / n, (k * GOLD + 0.5) % 1
				if tri and u + v > 1 then
					u, v = 1 - u, 1 - v
				end
				if not hidden(ox + u * ax + v * bx, oy + u * ay + v * by, oz + u * az + v * bz, nx, ny, nz) then
					visible += faceArea / n
				end
			end
		end
	end
	return visible / area
end

function Oracle.share(parts: { Prepared }, i: number, hider: { boolean }): number
	local coarse = Oracle.measure(parts, i, hider, Oracle.COARSE_POINTS)
	if coarse >= Oracle.COARSE_ACCEPT then
		return coarse
	end
	return Oracle.measure(parts, i, hider, max(Oracle.MIN_POINTS, ceil(parts[i].area / (Oracle.SPACING * Oracle.SPACING))))
end

return table.freeze(Oracle)
