--!nocheck
-- m2r5: the truth about a part's visible share under §4.4's hiding rule. The same hide test per point as Sampling (buried, on a surface with
-- a lower index, probe inside), on a fine low-discrepancy lattice per face, area-weighted, no budgets, against all parts but exact copies
-- and Dust. It shares no grid with Sampling: rank-1 golden-ratio lattices on each face (axis-aligned boundaries err by one lattice step of
-- the axis, not by a grid row), a Fibonacci lattice on a ball, an (angle, axis) lattice on a cylinder's side, written from Shapes.faces.
local Shapes = require("./tree/src/shared/Physics/Shapes")
local Balance = require("./tree/src/shared/Definitions/Balance")
local Limits = require("./tree/src/shared/Definitions/Limits")

local sd, aabbContains, aabbOverlap, toWorld = Shapes.sd, Shapes.aabbContains, Shapes.aabbOverlap, Shapes.toWorld
local sqrt, cos, sin, ceil, floor, max = math.sqrt, math.cos, math.sin, math.ceil, math.floor, math.max
local Geo = Balance.Geometry
local EPS, DELTA = Geo.EPS_GEOM, Geo.HIDE_OFFSET
local TWO_PI = 2 * 3.141592653589793
local GOLD = 0.6180339887498949
local GA = 2.399963229728653 -- the golden angle

local O = {}

O.SPACING = 0.0075
O.MIN_POINTS = 40000
O.COARSE_POINTS = 4000
O.COARSE_ACCEPT = 0.30

-- which parts hide: not exact copies of a lower index, not Dust
function O.flags(parts)
	local N = #parts
	local isCopy, isDust, hider = table.create(N, false), table.create(N, false), table.create(N, false)
	for i = 1, N do
		isDust[i] = parts[i].volume < Geo.MIN_PART_VOLUME
		for j = 1, i - 1 do
			if Shapes.sameSolid(parts[i], parts[j]) then
				isCopy[i] = true
				break
			end
		end
		hider[i] = not isCopy[i] and not isDust[i]
	end
	return isCopy, isDust, hider
end

-- visible weight of part p for about `total` points
local function measure(p, cand, total)
	local nc = #cand
	local pIndex = p.index
	local e2 = 2 * EPS

	local function hiddenAt(x, y, z, nx, ny, nz)
		local ox, oy, oz = x + DELTA * nx, y + DELTA * ny, z + DELTA * nz
		for c = 1, nc do
			local q = cand[c]
			local hit = false
			if aabbContains(q, x, y, z, e2) then
				local d0 = sd(q, x, y, z)
				hit = d0 < -EPS or (q.index < pIndex and d0 <= EPS)
			end
			if not hit and aabbContains(q, ox, oy, oz, e2) then
				hit = sd(q, ox, oy, oz) <= EPS
			end
			if hit then
				if c > 1 then
					cand[c], cand[1] = cand[1], q -- the same OR, found sooner next time
				end
				return true
			end
		end
		return false
	end

	local visible, points = 0, 0
	local area = p.area
	if p.code == Shapes.BALL then
		local n = max(total, 16)
		local r = p.r
		local w = area / n
		for i = 0, n - 1 do
			local lz = 1 - 2 * (i + 0.5) / n
			local rho = sqrt(max(0, 1 - lz * lz))
			local a = i * GA
			local lx, ly = rho * cos(a), rho * sin(a)
			local x, y, z = toWorld(p, r * lx, r * ly, r * lz)
			local nx = lx * p.ux + ly * p.vx + lz * p.wx
			local ny = lx * p.uy + ly * p.vy + lz * p.wy
			local nz = lx * p.uz + ly * p.vz + lz * p.wz
			if not hiddenAt(x, y, z, nx, ny, nz) then
				visible += w
			end
		end
		points = n
	elseif p.code == Shapes.CYLINDER then
		local r, hx = p.r, p.hx
		local sideArea = TWO_PI * r * 2 * hx
		local capArea = TWO_PI * r * r / 2
		local ns = max(ceil(total * sideArea / area), 64)
		local w = sideArea / ns
		local nS = 1 / ns
		for i = 0, ns - 1 do
			local u = (i + 0.5) * nS
			local v = (i * GOLD + 0.5) % 1
			local a = TWO_PI * v
			local ca, sa = cos(a), sin(a)
			local x, y, z = toWorld(p, -hx + 2 * hx * u, r * ca, r * sa)
			local nx = ca * p.vx + sa * p.wx
			local ny = ca * p.vy + sa * p.wy
			local nz = ca * p.vz + sa * p.wz
			if not hiddenAt(x, y, z, nx, ny, nz) then
				visible += w
			end
		end
		points += ns
		local ncap = max(ceil(total * capArea / area), 64)
		for side = -1, 1, 2 do
			-- a lattice on the bounding square, kept inside the disk: equal weights
			local nq = ceil(ncap * 1.2732395447351628)
			local count, vis = 0, 0
			local snx, sny, snz = side * p.ux, side * p.uy, side * p.uz
			for i = 0, nq - 1 do
				local ly = -r + 2 * r * (i + 0.5) / nq
				local lz = -r + 2 * r * ((i * GOLD + 0.25) % 1)
				if ly * ly + lz * lz <= r * r then
					count += 1
					local x, y, z = toWorld(p, side * hx, ly, lz)
					if not hiddenAt(x, y, z, snx, sny, snz) then
						vis += 1
					end
				end
			end
			if count > 0 then
				visible += capArea * vis / count
			end
			points += count
		end
	else
		for _, poly in ipairs(Shapes.faces(p)) do
			local v0x, v0y, v0z = poly[1], poly[2], poly[3]
			local ax, ay, az = poly[4] - v0x, poly[5] - v0y, poly[6] - v0z
			local tri = #poly == 9
			local bx, by, bz
			if tri then
				bx, by, bz = poly[7] - v0x, poly[8] - v0y, poly[9] - v0z
			else
				assert(#poly == 12, "a face of 3 or 4 vertices")
				bx, by, bz = poly[10] - v0x, poly[11] - v0y, poly[12] - v0z
			end
			local cx, cy, cz = ay * bz - az * by, az * bx - ax * bz, ax * by - ay * bx
			local l = sqrt(cx * cx + cy * cy + cz * cz)
			local nx, ny, nz = cx / l, cy / l, cz / l
			local fa = if tri then l / 2 else l
			local n = max(ceil(total * fa / area), 64)
			local w = fa / n
			local nS = 1 / n
			for i = 0, n - 1 do
				local u = (i + 0.5) * nS
				local v = (i * GOLD + 0.5) % 1
				if tri and u + v > 1 then
					u, v = 1 - u, 1 - v
				end
				local x, y, z = v0x + u * ax + v * bx, v0y + u * ay + v * by, v0z + u * az + v * bz
				if not hiddenAt(x, y, z, nx, ny, nz) then
					visible += w
				end
			end
			points += n
		end
	end
	return visible / area, points
end

-- the true share of parts[i]
function O.share(parts, i, hider, opts)
	local o = opts or {}
	local p = parts[i]
	local cand = {}
	for j = 1, #parts do
		if j ~= i and hider[j] and aabbOverlap(p, parts[j], DELTA + 2 * EPS) then
			table.insert(cand, parts[j])
		end
	end
	local spacing = o.spacing or O.SPACING
	local fine = max(o.minPoints or O.MIN_POINTS, ceil(p.area / (spacing * spacing)))
	if #cand == 0 then
		return 1, 0, "alone"
	end
	if not o.noCoarse then
		local s, n = measure(p, cand, O.COARSE_POINTS)
		if s >= O.COARSE_ACCEPT then
			return s, n, "coarse"
		end
	end
	local s, n = measure(p, cand, fine)
	return s, n, "fine"
end

-- every part: share per part (nil for Dust and exact copies), with flags
function O.all(parts, opts)
	local isCopy, isDust, hider = O.flags(parts)
	local out = table.create(#parts)
	local level = table.create(#parts)
	for i = 1, #parts do
		if isCopy[i] then
			out[i], level[i] = false, "copy"
		elseif isDust[i] then
			out[i], level[i] = false, "dust"
		else
			local s, _, lv = O.share(parts, i, hider, opts)
			out[i], level[i] = s, lv
		end
	end
	return out, level
end

return O
