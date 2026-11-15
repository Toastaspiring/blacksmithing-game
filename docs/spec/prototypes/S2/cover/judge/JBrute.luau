--!nocheck
-- The judge's third reading, written apart from A and B: the baseline polyhedral model built again from the task's text,
-- and what shows of each facet by brute force on that model. Per facet and hider, the two pieces (buried or coincident,
-- probe) are the facet clipped in 3D by the hider's moved half-spaces (Sutherland-Hodgman on world points, the same
-- plane test as the point oracle); their union's area is integrated exactly by vertical slabs in the facet's plane: every
-- piece vertex and every crossing of two piece edges is an event, and between events the union's length along the slab
-- is linear, so the midpoint rule is exact. No tolerance anywhere but the event dedupe (exact equality).
local Shapes = require("./repo/src/shared/Physics/Shapes")
local Sampling = require("./repo/src/shared/Physics/Sampling")
local Balance = require("./repo/src/shared/Definitions/Balance")
local Geo = Balance.Geometry
local EPS, DELTA = Geo.EPS_GEOM, Geo.HIDE_OFFSET
local REACH = DELTA + 2 * EPS
local sqrt, abs, min, max = math.sqrt, math.abs, math.min, math.max
local COS, SIN = Sampling.COS, Sampling.SIN

local J = {}

local function newell(v)
	local n = #v / 3
	local ax, ay, az = 0, 0, 0
	for i = 0, n - 1 do
		local j = (i + 1) % n
		local x0, y0, z0 = v[3 * i + 1], v[3 * i + 2], v[3 * i + 3]
		local x1, y1, z1 = v[3 * j + 1], v[3 * j + 2], v[3 * j + 3]
		ax += (y0 - y1) * (z0 + z1)
		ay += (z0 - z1) * (x0 + x1)
		az += (x0 - x1) * (y0 + y1)
	end
	return ax, ay, az
end

local function centroid(v)
	local n = #v / 3
	local cx, cy, cz = 0, 0, 0
	for i = 0, n - 1 do
		cx, cy, cz = cx + v[3 * i + 1], cy + v[3 * i + 2], cz + v[3 * i + 3]
	end
	return cx / n, cy / n, cz / n
end

local function reversed(v)
	local n = #v / 3
	local out = table.create(3 * n)
	for i = 1, n do
		local s = n - i
		out[3 * i - 2], out[3 * i - 1], out[3 * i] = v[3 * s + 1], v[3 * s + 2], v[3 * s + 3]
	end
	return out
end

-- orient a facet counter-clockwise seen from outside (outward = away from the solid's centre c)
local function oriented(v, cx, cy, cz)
	local ax, ay, az = newell(v)
	local fx, fy, fz = centroid(v)
	if ax * (fx - cx) + ay * (fy - cy) + az * (fz - cz) < 0 then
		return reversed(v)
	end
	return v
end

-- The model: { facets = { {flat world xyz} }, nx, ny, nz, area (per facet), planes = { {nx, ny, nz, d} }, total }
function J.model(P, opts)
	local facets, planes = {}, {}
	local code = P.code
	local canon = opts and opts.canon
	if P.poly then
		facets = Shapes.faces(P)
		for _, pl in ipairs(Shapes.planes(P)) do table.insert(planes, { pl[1], pl[2], pl[3], pl[4] }) end
	elseif code == Shapes.CYLINDER then
		local hx, r = P.hx, P.r
		local cs, sn = COS, SIN
		local N = #cs
		local function W(lx, ly, lz) return Shapes.toWorld(P, lx, ly, lz) end
		for k = 1, N do
			local k1 = k % N + 1
			local x1, y1, z1 = W(-hx, r * cs[k], r * sn[k])
			local x2, y2, z2 = W(hx, r * cs[k], r * sn[k])
			local x3, y3, z3 = W(hx, r * cs[k1], r * sn[k1])
			local x4, y4, z4 = W(-hx, r * cs[k1], r * sn[k1])
			table.insert(facets, oriented({ x1, y1, z1, x2, y2, z2, x3, y3, z3, x4, y4, z4 }, P.cx, P.cy, P.cz))
		end
		for s = -1, 1, 2 do
			local v = {}
			for k = 1, N do
				local x, y, z = W(s * hx, r * cs[k], r * sn[k])
				table.insert(v, x)
				table.insert(v, y)
				table.insert(v, z)
			end
			table.insert(facets, oriented(v, P.cx, P.cy, P.cz))
		end
	else
		local r, n = P.r, 4
		local signs = { 1, -1 }
		for _, sx in ipairs(signs) do
			for _, sy in ipairs(signs) do
				for _, sz in ipairs(signs) do
					-- grid point (i, j): (n − i − j)·A + i·B + j·C over n, A = sx·X, B = sy·Y, C = sz·Z, pushed to radius r
					local function G(i, j)
						local a = n - i - j
						local lx, ly, lz = sx * a / n, sy * i / n, sz * j / n
						local l = sqrt(lx * lx + ly * ly + lz * lz)
						return Shapes.toWorld(P, r * lx / l, r * ly / l, r * lz / l)
					end
					for i = 0, n - 1 do
						for j = 0, n - 1 - i do
							local x1, y1, z1 = G(i, j)
							local x2, y2, z2 = G(i + 1, j)
							local x3, y3, z3 = G(i, j + 1)
							table.insert(facets, oriented({ x1, y1, z1, x2, y2, z2, x3, y3, z3 }, P.cx, P.cy, P.cz))
							if i + j <= n - 2 then
								local x4, y4, z4 = G(i + 1, j + 1)
								table.insert(facets, oriented({ x2, y2, z2, x4, y4, z4, x3, y3, z3 }, P.cx, P.cy, P.cz))
							end
						end
					end
				end
			end
		end
	end
	local m = { part = P, facets = facets, planes = planes, nx = {}, ny = {}, nz = {}, area = {}, box = {}, total = 0 }
	for f, v in ipairs(facets) do
		local ax, ay, az = newell(v)
		local l = sqrt(ax * ax + ay * ay + az * az)
		m.nx[f], m.ny[f], m.nz[f] = ax / l, ay / l, az / l
		m.area[f] = l / 2
		m.total += l / 2
		local x0, y0, z0, x1, y1, z1 = math.huge, math.huge, math.huge, -math.huge, -math.huge, -math.huge
		for i = 1, #v, 3 do
			x0, y0, z0 = min(x0, v[i]), min(y0, v[i + 1]), min(z0, v[i + 2])
			x1, y1, z1 = max(x1, v[i]), max(y1, v[i + 1]), max(z1, v[i + 2])
		end
		m.box[f] = { x0, y0, z0, x1, y1, z1 }
		if not P.poly then
			local cx, cy, cz = centroid(v)
			table.insert(planes, { m.nx[f], m.ny[f], m.nz[f], m.nx[f] * cx + m.ny[f] * cy + m.nz[f] * cz })
		end
	end
	return m
end

-- Sutherland-Hodgman in 3D: keep n·x − c ≤ 0
local function clip3(v, nx, ny, nz, c)
	local n = #v / 3
	if n == 0 then return v end
	local s = table.create(n)
	local anyOut, anyIn = false, false
	for i = 0, n - 1 do
		local val = nx * v[3 * i + 1] + ny * v[3 * i + 2] + nz * v[3 * i + 3] - c
		s[i + 1] = val
		if val > 0 then anyOut = true else anyIn = true end
	end
	if not anyOut then return v end
	if not anyIn then return {} end
	local out = {}
	for i = 0, n - 1 do
		local j = (i + 1) % n
		local si, sj = s[i + 1], s[j + 1]
		local xi, yi, zi = v[3 * i + 1], v[3 * i + 2], v[3 * i + 3]
		if si <= 0 then
			table.insert(out, xi)
			table.insert(out, yi)
			table.insert(out, zi)
		end
		if (si < 0 and sj > 0) or (si > 0 and sj < 0) then
			local t = si / (si - sj)
			local xj, yj, zj = v[3 * j + 1], v[3 * j + 2], v[3 * j + 3]
			table.insert(out, xi + t * (xj - xi))
			table.insert(out, yi + t * (yj - yi))
			table.insert(out, zi + t * (zj - zi))
		end
	end
	return out
end

-- the exact area of a union of convex polygons in the plane (us, vs per polygon): vertical slabs between events
local function unionArea(polys, limit)
	local events = {}
	local E = {} -- edges: u0, v0, u1, v1, poly
	for p, poly in ipairs(polys) do
		local us, vs = poly.u, poly.v
		local n = #us
		for i = 1, n do
			table.insert(events, us[i])
			local j = i % n + 1
			table.insert(E, { us[i], vs[i], us[j], vs[j], p })
		end
	end
	local ne = #E
	if limit and ne > limit then return nil end
	-- crossings of edges of different polygons
	for a = 1, ne do
		local ea = E[a]
		local au0, av0, au1, av1 = ea[1], ea[2], ea[3], ea[4]
		local aumin, aumax = min(au0, au1), max(au0, au1)
		local avmin, avmax = min(av0, av1), max(av0, av1)
		for b = a + 1, ne do
			local eb = E[b]
			if eb[5] ~= ea[5] then
				local bu0, bv0, bu1, bv1 = eb[1], eb[2], eb[3], eb[4]
				if max(bu0, bu1) >= aumin and min(bu0, bu1) <= aumax and max(bv0, bv1) >= avmin and min(bv0, bv1) <= avmax then
					local du1, dv1 = au1 - au0, av1 - av0
					local du2, dv2 = bu1 - bu0, bv1 - bv0
					local den = du1 * dv2 - dv1 * du2
					if den ~= 0 then
						local t = ((bu0 - au0) * dv2 - (bv0 - av0) * du2) / den
						local s = ((bu0 - au0) * dv1 - (bv0 - av0) * du1) / den
						if t >= -1e-12 and t <= 1 + 1e-12 and s >= -1e-12 and s <= 1 + 1e-12 then
							table.insert(events, au0 + t * du1)
						end
					end
				end
			end
		end
	end
	table.sort(events)
	local ev = {}
	for _, x in ipairs(events) do
		if #ev == 0 or x ~= ev[#ev] then table.insert(ev, x) end
	end
	-- per polygon u-range
	local pu0, pu1 = {}, {}
	for p, poly in ipairs(polys) do
		local a, b = math.huge, -math.huge
		for _, u in ipairs(poly.u) do a, b = min(a, u), max(b, u) end
		pu0[p], pu1[p] = a, b
	end
	local total = 0
	local los, his = {}, {}
	for k = 1, #ev - 1 do
		local ua, ub = ev[k], ev[k + 1]
		local um = (ua + ub) / 2
		local cnt = 0
		for p, poly in ipairs(polys) do
			if pu0[p] < um and pu1[p] > um then
				local us, vs = poly.u, poly.v
				local n = #us
				local lo, hi = math.huge, -math.huge
				for i = 1, n do
					local j = i % n + 1
					local u0, u1 = us[i], us[j]
					if (u0 <= um and um <= u1) or (u1 <= um and um <= u0) then
						if u0 ~= u1 then
							local t = (um - u0) / (u1 - u0)
							local v = vs[i] + t * (vs[j] - vs[i])
							lo, hi = min(lo, v), max(hi, v)
						end
					end
				end
				if hi > lo then
					cnt += 1
					los[cnt], his[cnt] = lo, hi
				end
			end
		end
		if cnt > 0 then
			-- union of intervals: insertion sort by lo
			for i = 2, cnt do
				local lo, hi = los[i], his[i]
				local j = i - 1
				while j >= 1 and los[j] > lo do
					los[j + 1], his[j + 1] = los[j], his[j]
					j -= 1
				end
				los[j + 1], his[j + 1] = lo, hi
			end
			local covered, lo, hi = 0, los[1], his[1]
			for i = 2, cnt do
				if los[i] > hi then
					covered += hi - lo
					lo, hi = los[i], his[i]
				elseif his[i] > hi then
					hi = his[i]
				end
			end
			covered += hi - lo
			total += (ub - ua) * covered
		end
	end
	return total
end
J.unionArea = unionArea

-- What shows of facet f of model m against hiders (models, in rank order) with higher flags: (shown, pieces) or nil when
-- the facet's union is over the edge limit.
function J.facetShown(m, f, hms, higher, limit, shift)
	local t = shift or 0 -- every moved half-space moved out by t (t > 0: pieces grow): brackets a tie
	local v = m.facets[f]
	local nfx, nfy, nfz = m.nx[f], m.ny[f], m.nz[f]
	local b = m.box[f]
	local x0, y0, z0 = b[1] - REACH, b[2] - REACH, b[3] - REACH
	local x1, y1, z1 = b[4] + REACH, b[5] + REACH, b[6] + REACH
	-- frame: origin first vertex, e along the first edge, g = n × e
	local ox, oy, oz = v[1], v[2], v[3]
	local ex, ey, ez = v[4] - ox, v[5] - oy, v[6] - oz
	local el = sqrt(ex * ex + ey * ey + ez * ez)
	ex, ey, ez = ex / el, ey / el, ez / el
	local gx, gy, gz = nfy * ez - nfz * ey, nfz * ex - nfx * ez, nfx * ey - nfy * ex
	local gl = sqrt(gx * gx + gy * gy + gz * gz)
	gx, gy, gz = gx / gl, gy / gl, gz / gl
	local function to2(w)
		local us, vs = {}, {}
		for i = 1, #w, 3 do
			local dx, dy, dz = w[i] - ox, w[i + 1] - oy, w[i + 2] - oz
			table.insert(us, dx * ex + dy * ey + dz * ez)
			table.insert(vs, dx * gx + dy * gy + dz * gz)
		end
		return { u = us, v = vs }
	end
	local fp = to2(v)
	local area = 0
	do
		local n = #fp.u
		for i = 1, n do
			local j = i % n + 1
			area += fp.u[i] * fp.v[j] - fp.v[i] * fp.u[j]
		end
		area /= 2
	end
	local fsag = if m.sag and #m.planes == #m.facets then m.sag[f] else 0
	local pieces = {}
	for h, q in ipairs(hms) do
		local Q = q.part
		if Q.minx <= x1 and Q.maxx >= x0 and Q.miny <= y1 and Q.maxy >= y0 and Q.minz <= z1 and Q.maxz >= z0 then
			for kind = 1, 2 do
				local w = v
				for pi, pl in ipairs(q.planes) do
					local c
					if kind == 1 then
						c = pl[4] + (if higher[h] then EPS else -EPS) + t
					else
						-- the conservative-probe option (m.sag present): the target facet probes its sagitta further, the
						-- hider's half-space moves out to the true solid's support for the probe only
						local qs = if q.sag then q.sag[pi] else 0
						c = pl[4] + qs + EPS - (DELTA + fsag) * (pl[1] * nfx + pl[2] * nfy + pl[3] * nfz) + t
					end
					w = clip3(w, pl[1], pl[2], pl[3], c)
					if #w == 0 then break end
				end
				if #w >= 9 then
					table.insert(pieces, to2(w))
				end
			end
		end
	end
	if #pieces == 0 then
		return area, 0, area
	end
	J.lastPieces, J.lastFacet = pieces, fp
	local covered = unionArea(pieces, limit)
	if covered == nil then return nil, #pieces, area end
	local shown = area - covered
	return shown, #pieces, area
end

-- shown per part (full, no early stop): list of {shown, area} for hiders, nil for Dust/copies. limit: max edges per facet
-- union (nil = no limit); a facet over it makes the part's entry {skipped = true}.
function J.readAll(P, flags, cands, opts, limit, shift)
	local rank, byRank, isCopy, dust, hider = table.unpack(flags)
	local models = {}
	for i = 1, #P do
		if hider[i] then models[i] = J.model(P[i], opts) end
	end
	local out = {}
	for i = 1, #P do
		if hider[i] then
			local idx, higher = cands(P, i, rank, byRank, hider)
			local hm = {}
			for k, j in ipairs(idx) do hm[k] = models[j] end
			local m = models[i]
			local s, skipped = 0, false
			local per = {}
			for f = 1, #m.facets do
				local sf = J.facetShown(m, f, hm, higher, limit, shift)
				if sf == nil then
					skipped = true
					break
				end
				per[f] = sf
				s += sf
			end
			out[i] = { shown = s, area = m.total, skipped = skipped, per = per }
		end
	end
	return out, models
end

-- A literal point lattice on facet f (n × n grid on the facet's bounding parallelogram of its first two edges, kept
-- inside the polygon), each point tested against every hider's model planes in 3D: the shown fraction of the facet.
function J.facetLattice(m, f, hms, higher, n)
	local v = m.facets[f]
	local nfx, nfy, nfz = m.nx[f], m.ny[f], m.nz[f]
	local b = m.box[f]
	local x0, y0, z0 = b[1] - REACH, b[2] - REACH, b[3] - REACH
	local x1, y1, z1 = b[4] + REACH, b[5] + REACH, b[6] + REACH
	local hs = {}
	for h, q in ipairs(hms) do
		local Q = q.part
		if Q.minx <= x1 and Q.maxx >= x0 and Q.miny <= y1 and Q.maxy >= y0 and Q.minz <= z1 and Q.maxz >= z0 then
			table.insert(hs, h)
		end
	end
	local nv = #v / 3
	-- points: fan triangles from vertex 1, each with a lattice of barycentric points weighted by area
	local shownW, totalW = 0, 0
	for t = 2, nv - 1 do
		local ax, ay, az = v[1], v[2], v[3]
		local bx, by, bz = v[3 * t - 2], v[3 * t - 1], v[3 * t]
		local cx, cy, cz = v[3 * t + 1], v[3 * t + 2], v[3 * t + 3]
		local ux, uy, uz = bx - ax, by - ay, bz - az
		local wx, wy, wz = cx - ax, cy - ay, cz - az
		local crx, cry, crz = uy * wz - uz * wy, uz * wx - ux * wz, ux * wy - uy * wx
		local tri = sqrt(crx * crx + cry * cry + crz * crz) / 2
		local cnt, sh = 0, 0
		for i = 0, n - 1 do
			for j = 0, n - 1 - i do
				local s1, s2 = (i + 1 / 3) / n, (j + 1 / 3) / n
				local px, py, pz = ax + s1 * ux + s2 * wx, ay + s1 * uy + s2 * wy, az + s1 * uz + s2 * wz
				local hidden = false
				for _, h in ipairs(hs) do
					local q = hms[h]
					local inA, inB = true, true
					for _, pl in ipairs(q.planes) do
						local s = pl[1] * px + pl[2] * py + pl[3] * pz - pl[4]
						if higher[h] then
							if s > EPS then inA = false end
						else
							if not (s < -EPS) then inA = false end
						end
						local sp = s + DELTA * (pl[1] * nfx + pl[2] * nfy + pl[3] * nfz)
						if sp > EPS then inB = false end
						if not inA and not inB then break end
					end
					if inA or inB then
						hidden = true
						break
					end
				end
				cnt += 1
				if not hidden then sh += 1 end
			end
		end
		shownW += tri * sh / cnt
		totalW += tri
	end
	return shownW, totalW
end

return J
