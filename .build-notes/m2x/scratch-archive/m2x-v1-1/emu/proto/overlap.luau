--!strict
-- S2 prototype v2: overlap volume and first moment for owned volumes (R4a-07).
--  * polyhedra (Block, Wedge, CornerWedge) against up to MAX_EXACT higher-priority polyhedra: exact convex clipping,
--    inclusion-exclusion over the subsets, volume and first moment by tetrahedra (+ - * / only, no trig)
--  * anything involving a Ball or Cylinder, or more overlapping parts: refined midpoint sampling of the overlap box
--    in the lower-priority part's own frame
local Shapes = require("./shapes")

local sqrt, max, min, ceil = math.sqrt, math.max, math.min, math.ceil

local Overlap = {}
Overlap.MAX_EXACT = 3
local EPS = 1e-12
local DEDUPE2 = 1e-18

local function pang(x: number, y: number): number
	-- monotone pseudo-angle in [0, 4) ("diamond angle"), no trig
	if x == 0 and y == 0 then
		return 0
	end
	if y >= 0 then
		if x >= 0 then
			return y / (x + y)
		end
		return 1 - x / (-x + y)
	end
	if x < 0 then
		return 2 - y / (-x - y)
	end
	return 3 + x / (x - y)
end

-- clip a closed convex polyhedron (list of CCW-outward face polygons) to n.x <= d
local function clip(faces: { { number } }, nx: number, ny: number, nz: number, d: number): { { number } }
	local cut = false
	for _, poly in ipairs(faces) do
		for i = 1, #poly, 3 do
			if nx * poly[i] + ny * poly[i + 1] + nz * poly[i + 2] - d > EPS then
				cut = true
				break
			end
		end
		if cut then
			break
		end
	end
	if not cut then
		return faces
	end
	local out = {}
	local cap = {}
	for _, poly in ipairs(faces) do
		local m = #poly // 3
		local res = {}
		for i = 0, m - 1 do
			local j = (i + 1) % m
			local ax, ay, az = poly[3 * i + 1], poly[3 * i + 2], poly[3 * i + 3]
			local bx, by, bz = poly[3 * j + 1], poly[3 * j + 2], poly[3 * j + 3]
			local da = nx * ax + ny * ay + nz * az - d
			local db = nx * bx + ny * by + nz * bz - d
			if da <= EPS then
				table.insert(res, ax)
				table.insert(res, ay)
				table.insert(res, az)
				if da >= -EPS then
					table.insert(cap, ax)
					table.insert(cap, ay)
					table.insert(cap, az)
				end
			end
			if (da < -EPS and db > EPS) or (da > EPS and db < -EPS) then
				local t = da / (da - db)
				local px, py, pz = ax + t * (bx - ax), ay + t * (by - ay), az + t * (bz - az)
				table.insert(res, px)
				table.insert(res, py)
				table.insert(res, pz)
				table.insert(cap, px)
				table.insert(cap, py)
				table.insert(cap, pz)
			end
		end
		if #res >= 9 then
			table.insert(out, res)
		end
	end
	-- cap polygon on the plane: dedupe, order by pseudo-angle around the centroid (CCW about +n)
	local ux, uy, uz, cnt = {}, {}, {}, 0
	for i = 1, #cap, 3 do
		local x, y, z = cap[i], cap[i + 1], cap[i + 2]
		local dup = false
		for k = 1, cnt do
			local dx, dy, dz = ux[k] - x, uy[k] - y, uz[k] - z
			if dx * dx + dy * dy + dz * dz <= DEDUPE2 then
				dup = true
				break
			end
		end
		if not dup then
			cnt += 1
			ux[cnt], uy[cnt], uz[cnt] = x, y, z
		end
	end
	if cnt >= 3 then
		local cx, cy, cz = 0, 0, 0
		for k = 1, cnt do
			cx, cy, cz = cx + ux[k], cy + uy[k], cz + uz[k]
		end
		cx, cy, cz = cx / cnt, cy / cnt, cz / cnt
		-- in-plane basis e1 (perpendicular to n), e2 = n x e1
		local ax, ay, az
		if math.abs(nx) <= math.abs(ny) and math.abs(nx) <= math.abs(nz) then
			ax, ay, az = 0, -nz, ny
		elseif math.abs(ny) <= math.abs(nz) then
			ax, ay, az = -nz, 0, nx
		else
			ax, ay, az = -ny, nx, 0
		end
		local l = sqrt(ax * ax + ay * ay + az * az)
		ax, ay, az = ax / l, ay / l, az / l
		local bx, by, bz = ny * az - nz * ay, nz * ax - nx * az, nx * ay - ny * ax
		local ang, ord = {}, {}
		for k = 1, cnt do
			local dx, dy, dz = ux[k] - cx, uy[k] - cy, uz[k] - cz
			ang[k] = pang(dx * ax + dy * ay + dz * az, dx * bx + dy * by + dz * bz)
			ord[k] = k
		end
		table.sort(ord, function(i: number, j: number): boolean
			if ang[i] ~= ang[j] then
				return ang[i] < ang[j]
			end
			return i < j
		end)
		local poly = {}
		for _, k in ipairs(ord) do
			table.insert(poly, ux[k])
			table.insert(poly, uy[k])
			table.insert(poly, uz[k])
		end
		table.insert(out, poly)
	end
	return out
end

-- volume and first moment (world) of a closed polyhedron given as CCW-outward faces
local function volMoment(faces: { { number } }): (number, number, number, number)
	if #faces == 0 then
		return 0, 0, 0, 0
	end
	local f1 = faces[1]
	local ox, oy, oz = f1[1], f1[2], f1[3]
	local V, Mx, My, Mz = 0, 0, 0, 0
	for _, poly in ipairs(faces) do
		local m = #poly // 3
		local ax, ay, az = poly[1] - ox, poly[2] - oy, poly[3] - oz
		for i = 1, m - 2 do
			local bx, by, bz = poly[3 * i + 1] - ox, poly[3 * i + 2] - oy, poly[3 * i + 3] - oz
			local cx, cy, cz = poly[3 * i + 4] - ox, poly[3 * i + 5] - oy, poly[3 * i + 6] - oz
			local det = ax * (by * cz - bz * cy) - ay * (bx * cz - bz * cx) + az * (bx * cy - by * cx)
			local v = det / 6
			V += v
			Mx += v * (ax + bx + cx) / 4
			My += v * (ay + by + cy) / 4
			Mz += v * (az + bz + cz) / 4
		end
	end
	if V <= 0 then
		return 0, 0, 0, 0
	end
	return V, Mx + V * ox, My + V * oy, Mz + V * oz
end

local function intersect(p: any, qs: { any }): (number, number, number, number)
	local faces = Shapes.faces(p)
	for _, q in ipairs(qs) do
		for _, pl in ipairs(Shapes.planes(q)) do
			faces = clip(faces, pl[1], pl[2], pl[3], pl[4])
			if #faces == 0 then
				return 0, 0, 0, 0
			end
		end
	end
	return volMoment(faces)
end
Overlap.intersect = intersect

-- exact V(p ∩ (q1 ∪ ... ∪ qk)) and its first moment by inclusion-exclusion (all polyhedra, k <= MAX_EXACT)
function Overlap.exact(p: any, H: { any }, tick: ((number) -> ())?): (number, number, number, number)
	local k = #H
	local V, Mx, My, Mz = 0, 0, 0, 0
	for mask = 1, bit32.lshift(1, k) - 1 do
		if tick then
			tick(150)
		end
		local qs, bits = {}, 0
		for i = 1, k do
			if bit32.band(mask, bit32.lshift(1, i - 1)) ~= 0 then
				table.insert(qs, H[i])
				bits += 1
			end
		end
		local v, mx, my, mz = intersect(p, qs)
		local s = if bits % 2 == 1 then 1 else -1
		V, Mx, My, Mz = V + s * v, Mx + s * mx, My + s * my, Mz + s * mz
	end
	return max(0, V), Mx, My, Mz
end

-- refined midpoint sampling of the overlap box (in p's frame); returns (V, Mx, My, Mz, cells)
function Overlap.boxOf(p: any, H: { any }): ({ number }, { number })
	local lo = { math.huge, math.huge, math.huge }
	local hi = { -math.huge, -math.huge, -math.huge }
	for _, q in ipairs(H) do
		local qlo = { math.huge, math.huge, math.huge }
		local qhi = { -math.huge, -math.huge, -math.huge }
		for c = 0, 7 do
			local x = if bit32.band(c, 1) ~= 0 then q.maxx else q.minx
			local y = if bit32.band(c, 2) ~= 0 then q.maxy else q.miny
			local z = if bit32.band(c, 4) ~= 0 then q.maxz else q.minz
			local a, b, d = Shapes.toLocal(p, x, y, z)
			qlo[1], qlo[2], qlo[3] = min(qlo[1], a), min(qlo[2], b), min(qlo[3], d)
			qhi[1], qhi[2], qhi[3] = max(qhi[1], a), max(qhi[2], b), max(qhi[3], d)
		end
		local hh = { p.hx, p.hy, p.hz }
		for k = 1, 3 do
			lo[k] = min(lo[k], max(-hh[k], qlo[k]))
			hi[k] = max(hi[k], min(hh[k], qhi[k]))
		end
	end
	return lo, hi
end

function Overlap.cellsFor(lo: { number }, hi: { number }, h: number, nmin: number, nmax: number): (number, number, number)
	local n = {}
	for k = 1, 3 do
		local ext = hi[k] - lo[k]
		n[k] = if ext <= 0 then 0 else max(nmin, min(nmax, ceil(ext / h)))
	end
	return n[1], n[2], n[3]
end

function Overlap.sampled(p: any, H: { any }, lo: { number }, hi: { number }, nx: number, ny: number, nz: number, tick: (number) -> ()): (number, number, number, number)
	if nx == 0 or ny == 0 or nz == 0 then
		return 0, 0, 0, 0
	end
	local dx, dy, dz = (hi[1] - lo[1]) / nx, (hi[2] - lo[2]) / ny, (hi[3] - lo[3]) / nz
	local cv = dx * dy * dz
	local V, Mx, My, Mz = 0, 0, 0, 0
	for i = 0, nx - 1 do
		local lx = lo[1] + (i + 0.5) * dx
		for j = 0, ny - 1 do
			local ly = lo[2] + (j + 0.5) * dy
			for k = 0, nz - 1 do
				local lz = lo[3] + (k + 0.5) * dz
				if Shapes.sdLocal(p, lx, ly, lz) < -1e-9 then
					local x, y, z = Shapes.toWorld(p, lx, ly, lz)
					for _, q in ipairs(H) do
						if Shapes.aabbContains(q, x, y, z, 0) and Shapes.sd(q, x, y, z) < -1e-9 then
							V += cv
							Mx += cv * x
							My += cv * y
							Mz += cv * z
							break
						end
					end
				end
			end
			tick(nz * (1 + #H))
		end
	end
	return V, Mx, My, Mz
end

return Overlap
