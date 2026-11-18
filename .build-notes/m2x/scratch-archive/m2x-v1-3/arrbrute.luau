--!nocheck
-- V1 (m2x, round 2; round 3: the probe grown by the facet's spread) brute force for Cover.shown, independent of Physics/Cover's subtraction and of tests/Physics/
-- CoverBrute's slabs (and of V1's round-1 inclusion–exclusion): §4.4's hide test alone. In the facet's plane (origin its
-- vertex centroid, u along its longest edge, v = n × u), each hider's two pieces (buried or coincident; probe) are sets of
-- half-planes a·u + b·v ≤ c; the facet is cut by every line that bounds an edge of a piece into the cells of their
-- arrangement, and a cell shows iff its vertex centroid lies in no piece (tested against every line of the piece that
-- cuts the facet). Every hider given is asked, with no box test. Reads Cover's model geometry only (polygons, normals,
-- planes, sag), so a difference is the reading's, not the model's.
local AB = {}
AB.MAX_CELLS = 80000

local EPS, DELTA

function AB.init(Geo)
	EPS, DELTA = Geo.EPS_GEOM, Geo.HIDE_OFFSET
end

local function area2(p)
	local n = #p
	local s = 0
	local pu, pv = p[n - 1], p[n]
	for i = 1, n, 2 do
		local u, v = p[i], p[i + 1]
		s += pu * v - u * pv
		pu, pv = u, v
	end
	return s
end
AB.area2 = area2

-- p split by a·u + b·v = c: (inside ≤, outside ≥); a side is nil when empty; p itself when the line misses it
local function cut(p, a, b, c)
	local n = #p // 2
	local s = table.create(n)
	local anyIn, anyOut = false, false
	for i = 1, n do
		local x = a * p[2 * i - 1] + b * p[2 * i] - c
		s[i] = x
		if x < 0 then
			anyIn = true
		elseif x > 0 then
			anyOut = true
		end
	end
	if not anyOut then
		return p, nil
	elseif not anyIn then
		return nil, p
	end
	local inside, outside = {}, {}
	for i = 1, n do
		local j = i % n + 1
		local si, sj = s[i], s[j]
		local u, v = p[2 * i - 1], p[2 * i]
		if si <= 0 then
			table.insert(inside, u)
			table.insert(inside, v)
		end
		if si >= 0 then
			table.insert(outside, u)
			table.insert(outside, v)
		end
		if (si < 0 and sj > 0) or (si > 0 and sj < 0) then
			local t = si / (si - sj)
			local x, y = u + t * (p[2 * j - 1] - u), v + t * (p[2 * j] - v)
			table.insert(inside, x)
			table.insert(inside, y)
			table.insert(outside, x)
			table.insert(outside, y)
		end
	end
	if #inside < 6 then
		inside = nil
	end
	if #outside < 6 then
		outside = nil
	end
	return inside, outside
end

-- What shows of facet f of model pm against the hider models (rank order; higher[k] whether hiders[k] ranks above pm's
-- part). shift moves every moved half-space out by that much. Returns the area, or nil past MAX_CELLS; and the cell count.
function AB.facetShown(pm, f, hiders, higher, shift)
	shift = shift or 0
	local poly = pm.poly[f]
	local nv = #poly // 3
	local nx, ny, nz = pm.nx[f], pm.ny[f], pm.nz[f]
	local probe = DELTA + (if pm.round then pm.sag[f] else 0)
	local spread = pm.spread[f] or 0
	local ox, oy, oz = 0, 0, 0
	for i = 1, nv do
		ox, oy, oz = ox + poly[3 * i - 2], oy + poly[3 * i - 1], oz + poly[3 * i]
	end
	ox, oy, oz = ox / nv, oy / nv, oz / nv
	local best, ex, ey, ez = -1, 0, 0, 0
	for i = 1, nv do
		local j = i % nv + 1
		local dx, dy, dz = poly[3 * j - 2] - poly[3 * i - 2], poly[3 * j - 1] - poly[3 * i - 1], poly[3 * j] - poly[3 * i]
		local l = dx * dx + dy * dy + dz * dz
		if l > best then
			best, ex, ey, ez = l, dx, dy, dz
		end
	end
	local el = math.sqrt(best)
	ex, ey, ez = ex / el, ey / el, ez / el
	local gx, gy, gz = ny * ez - nz * ey, nz * ex - nx * ez, nx * ey - ny * ex
	local gl = math.sqrt(gx * gx + gy * gy + gz * gz)
	gx, gy, gz = gx / gl, gy / gl, gz / gl
	local F = table.create(2 * nv)
	local diam = 0
	for i = 1, nv do
		local dx, dy, dz = poly[3 * i - 2] - ox, poly[3 * i - 1] - oy, poly[3 * i] - oz
		F[2 * i - 1] = dx * ex + dy * ey + dz * ez
		F[2 * i] = dx * gx + dy * gy + dz * gz
		diam = math.max(diam, math.abs(F[2 * i - 1]), math.abs(F[2 * i]))
	end
	local fa = area2(F) / 2
	local tol = 1e-9 * (diam + 1e-3)
	-- the pieces: lists of cutting lines {a, b, c}; edge lines collected for the arrangement
	local pieces = {}
	local edges = {}
	for k, q in ipairs(hiders) do
		local pl, sag = q.planes, q.sag
		for kind = 1, 2 do
			local lines = {}
			local empty = false
			for i = 1, q.np do
				local px, py, pz, d = pl[4 * i - 3], pl[4 * i - 2], pl[4 * i - 1], pl[4 * i]
				local D
				if kind == 1 then
					D = d + (if higher[k] then EPS else -EPS) + shift
				else
					D = d + sag[i] + spread + EPS + shift - probe * (px * nx + py * ny + pz * nz)
				end
				local a, b = px * ex + py * ey + pz * ez, px * gx + py * gy + pz * gz
				local c = D - (px * ox + py * oy + pz * oz)
				local smin, smax = math.huge, -math.huge
				for j = 1, nv do
					local s = a * F[2 * j - 1] + b * F[2 * j] - c
					smin, smax = math.min(smin, s), math.max(smax, s)
				end
				if smin > 0 then
					empty = true
					break
				elseif smax > 0 then
					table.insert(lines, { a, b, c })
				end
			end
			if not empty then
				if #lines == 0 then
					return 0, 1 -- a piece holds the whole facet
				end
				local P = F
				for _, L in ipairs(lines) do
					P = (cut(P, L[1], L[2], L[3]))
					if P == nil then
						break
					end
				end
				if P ~= nil and area2(P) > 0 then
					table.insert(pieces, lines)
					for _, L in ipairs(lines) do
						local on = 0
						for j = 1, #P, 2 do
							if math.abs(L[1] * P[j] + L[2] * P[j + 1] - L[3]) <= tol then
								on += 1
							end
						end
						if on >= 2 then
							table.insert(edges, L)
						end
					end
				end
			end
		end
	end
	if #pieces == 0 then
		return fa, 1
	end
	-- the arrangement
	local cells = { F }
	for _, L in ipairs(edges) do
		local a, b, c = L[1], L[2], L[3]
		local nxt = {}
		for _, C in ipairs(cells) do
			local inside, outside = cut(C, a, b, c)
			if inside ~= nil then
				table.insert(nxt, inside)
			end
			if outside ~= nil and outside ~= inside then
				table.insert(nxt, outside)
			end
		end
		cells = nxt
		if #cells > AB.MAX_CELLS then
			return nil, #cells
		end
	end
	local shown = 0
	for _, C in ipairs(cells) do
		local a2 = area2(C)
		if a2 > 0 then
			local cu, cv = 0, 0
			local m = #C // 2
			for j = 1, #C, 2 do
				cu, cv = cu + C[j], cv + C[j + 1]
			end
			cu, cv = cu / m, cv / m
			local covered = false
			for _, lines in ipairs(pieces) do
				local inside = true
				for _, L in ipairs(lines) do
					if L[1] * cu + L[2] * cv > L[3] then
						inside = false
						break
					end
				end
				if inside then
					covered = true
					break
				end
			end
			if not covered then
				shown += a2 / 2
			end
		end
	end
	return shown, #cells
end

-- What shows of model pm, Σ over its facets (nil past MAX_CELLS)
function AB.shown(pm, hiders, higher, shift)
	local s = 0
	local cells = 0
	for f = 1, pm.n do
		local x, c = AB.facetShown(pm, f, hiders, higher, shift)
		if x == nil then
			return nil, c
		end
		s += x
		cells = math.max(cells, c)
	end
	return s, cells
end

return AB
