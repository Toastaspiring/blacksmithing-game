--!nocheck
-- V1's own brute force for Cover.shown (independent of tests/Physics/CoverBrute and of Cover's subtraction): per facet of
-- the part's model and per hider, the two pieces of §4.4 (buried or coincident; probe) by clipping the facet in 3D against
-- the hider's moved half-spaces; the union of all pieces by inclusion–exclusion over the pieces that meet (depth-first,
-- pruned where an intersection has no area: every superset then has none either). Shown = facet area − union area.
-- It reads Cover's model geometry only (polygons, normals, planes, sag), so a difference is the reading's, not the model's.
local MB = {}
MB.LIMIT = 400000 -- intersections per facet past which facetShown gives up (nil)

local EPS, DELTA

function MB.init(Geo)
	EPS, DELTA = Geo.EPS_GEOM, Geo.HIDE_OFFSET
end

-- clip a 3D polygon (flat x,y,z) to n·x <= rhs
local function clip3(poly, nx, ny, nz, rhs)
	local n = #poly // 3
	local out = {}
	local any_out = false
	local s = table.create(n)
	for i = 1, n do
		local x, y, z = poly[3 * i - 2], poly[3 * i - 1], poly[3 * i]
		s[i] = nx * x + ny * y + nz * z - rhs
		if s[i] > 0 then any_out = true end
	end
	if not any_out then return poly end
	for i = 1, n do
		local j = i % n + 1
		local si, sj = s[i], s[j]
		local x0, y0, z0 = poly[3 * i - 2], poly[3 * i - 1], poly[3 * i]
		if si <= 0 then
			table.insert(out, x0); table.insert(out, y0); table.insert(out, z0)
		end
		if (si < 0 and sj > 0) or (si > 0 and sj < 0) then
			local t = si / (si - sj)
			local x1, y1, z1 = poly[3 * j - 2], poly[3 * j - 1], poly[3 * j]
			table.insert(out, x0 + t * (x1 - x0)); table.insert(out, y0 + t * (y1 - y0)); table.insert(out, z0 + t * (z1 - z0))
		end
	end
	if #out < 9 then return nil end
	return out
end

-- 2D convex polygon (flat u,v; ccw) clipped by another convex ccw polygon Q
local function area2(p)
	local n = #p // 2
	local s = 0
	for i = 1, n do
		local j = i % n + 1
		s += p[2 * i - 1] * p[2 * j] - p[2 * j - 1] * p[2 * i]
	end
	return s / 2
end
MB.area2 = area2

local function clip2(p, a, b, c) -- keep a*u + b*v <= c
	local n = #p // 2
	local s = table.create(n)
	local anyOut, anyIn = false, false
	for i = 1, n do
		s[i] = a * p[2 * i - 1] + b * p[2 * i] - c
		if s[i] > 0 then anyOut = true elseif s[i] < 0 then anyIn = true end
	end
	if not anyOut then return p end
	if not anyIn then return nil end
	local out = {}
	for i = 1, n do
		local j = i % n + 1
		local si, sj = s[i], s[j]
		if si <= 0 then
			table.insert(out, p[2 * i - 1]); table.insert(out, p[2 * i])
		end
		if (si < 0 and sj > 0) or (si > 0 and sj < 0) then
			local t = si / (si - sj)
			table.insert(out, p[2 * i - 1] + t * (p[2 * j - 1] - p[2 * i - 1]))
			table.insert(out, p[2 * i] + t * (p[2 * j] - p[2 * i]))
		end
	end
	if #out < 6 then return nil end
	return out
end

local function intersect(P, Q)
	local R = P
	local n = #Q // 2
	for i = 1, n do
		local j = i % n + 1
		local u0, v0, u1, v1 = Q[2 * i - 1], Q[2 * i], Q[2 * j - 1], Q[2 * j]
		-- inside of a ccw edge: left side; outward normal (dv, -du)
		local a, b = v1 - v0, -(u1 - u0)
		local c = a * u0 + b * v0
		R = clip2(R, a, b, c)
		if R == nil then return nil end
	end
	return R
end

-- union area of convex polygons (2D) by inclusion–exclusion with pruning; nil past LIMIT
local function unionArea(pieces, tiny)
	local m = #pieces
	local total = 0
	local count = 0
	local function rec(i, cur, sign)
		count += 1
		if count > MB.LIMIT then return false end
		total += sign * area2(cur)
		for j = i + 1, m do
			local nxt = intersect(cur, pieces[j])
			if nxt ~= nil and area2(nxt) > tiny then
				if not rec(j, nxt, -sign) then return false end
			end
		end
		return true
	end
	for i = 1, m do
		if not rec(i, pieces[i], 1) then return nil, count end
	end
	return total, count
end
MB.unionArea = unionArea

-- what shows of facet f of model pm against hider models (rank order) with higher flags; shift moves every moved
-- half-space out by that much (a bracket for ties)
function MB.facetShown(pm, f, hiders, higher, shift)
	shift = shift or 0
	local poly = pm.poly[f]
	local nx, ny, nz = pm.nx[f], pm.ny[f], pm.nz[f]
	local probe = DELTA + (if pm.round then pm.sag[f] else 0)
	local ox, oy, oz = poly[1], poly[2], poly[3]
	local ex, ey, ez = poly[4] - ox, poly[5] - oy, poly[6] - oz
	local el = math.sqrt(ex * ex + ey * ey + ez * ez)
	ex, ey, ez = ex / el, ey / el, ez / el
	local gx, gy, gz = ny * ez - nz * ey, nz * ex - nx * ez, nx * ey - ny * ex
	local gl = math.sqrt(gx * gx + gy * gy + gz * gz)
	gx, gy, gz = gx / gl, gy / gl, gz / gl
	local function to2(p3)
		local out = table.create(2 * (#p3 // 3))
		for i = 1, #p3 // 3 do
			local dx, dy, dz = p3[3 * i - 2] - ox, p3[3 * i - 1] - oy, p3[3 * i] - oz
			out[2 * i - 1] = dx * ex + dy * ey + dz * ez
			out[2 * i] = dx * gx + dy * gy + dz * gz
		end
		return out
	end
	local F2 = to2(poly)
	local fa = area2(F2)
	local tiny = 1e-15 * fa
	local pieces = {}
	for k, q in ipairs(hiders) do
		local pl, sag = q.planes, q.sag
		local cA = if higher[k] then EPS else -EPS
		local A, B = poly, poly
		for i = 1, q.np do
			local px, py, pz, d = pl[4 * i - 3], pl[4 * i - 2], pl[4 * i - 1], pl[4 * i]
			if A then A = clip3(A, px, py, pz, d + cA + shift) end
			if B then
				-- n_i·(x + probe·n) <= d_i + sag_i + EPS
				B = clip3(B, px, py, pz, d + sag[i] + EPS + shift - probe * (px * nx + py * ny + pz * nz))
			end
			if A == nil and B == nil then break end
		end
		if A then
			local a2 = to2(A)
			if area2(a2) > tiny then table.insert(pieces, a2) end
		end
		if B then
			local b2 = to2(B)
			if area2(b2) > tiny then table.insert(pieces, b2) end
		end
	end
	if #pieces == 0 then return fa, 0 end
	local u, count = unionArea(pieces, tiny)
	if u == nil then return nil, count end
	return fa - u, count
end

return MB
