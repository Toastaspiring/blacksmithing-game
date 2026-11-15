--!strict
-- tests/Physics/CoverBrute.luau — a brute force for Cover.spec (SPEC §4.4, E-S2.12): the polyhedral model built again
-- from §4.4's words, and what shows of each facet by brute force on it. Not a spec (the runner loads *.spec.luau only),
-- and it shares nothing with Physics/Cover but Shapes' faces, planes, signed distance and support and the 32
-- directions. A round part that a round hider holds shows nothing (a Cylinder's cap rims against a Cylinder hider's
-- axis by dense sampling with a bound on what it misses, which brackets the decision), and a round facet whose true
-- patch it holds is hidden whole. Otherwise, per facet and hider, the two pieces (buried or coincident, probe) are the
-- facet clipped in 3D by the hider's moved half-spaces (Sutherland–Hodgman on world points; the buried piece's moved
-- out to a round hider's true solid for a polyhedron's facet, the probe's always and grown by the facet's spread), or
-- for a flat facet (a polyhedron's or a cap) against a Ball by the 32 sides, half-spaces across its plane, of the
-- 32-gon round the circle that its plane (the probe's) cuts from the sphere, in a frame from its normal by arithmetic
-- of its own; their union's area is integrated exactly by vertical slabs in the facet's plane: every piece vertex and
-- every crossing of two piece edges is an event, and between events the union's length along the slab is linear, so the
-- midpoint rule is exact. No box test anywhere: every part that hides is clipped against every facet, so the hide test
-- alone decides what a piece is. `shift` moves every moved half-space out by that much, and grows a Ball's sphere for a
-- flat facet's circle by as much: a reading between the shifts +1e-11 and −1e-11 is right up to a tie, a face that lies
-- on the hide test's boundary to within rounding (E-S2.12).
--   model(P)                                  the model: facets with their spread, half-spaces with their sag, areas, boxes
--   fromCover(m)                              Physics/Cover's model geometry, as the brute force's
--   facetShown(m, f, hiders, higher, shift?)  what shows of facet f (its area if no piece), or nil past MAX_EDGES
--   hiders(parts, i)                          every part that hides, but i: indices in rank order, and whether each ranks
--                                             higher
--   standsOut(P, Q)                           how far round P's true solid stands out of round Q's at most: (below,
--                                             above), a bracket (equal but for a Cylinder in a Cylinder)

local Balance = require("../../src/shared/Definitions/Balance")
local Sampling = require("../../src/shared/Physics/Sampling")
local Shapes = require("../../src/shared/Physics/Shapes")

type Prepared = Shapes.Prepared

export type Model = {
	part: Prepared,
	round: boolean,
	facets: { { number } }, -- world polygons, flat x, y, z, counter-clockwise seen from outside
	nx: { number },
	ny: { number },
	nz: { number },
	area: { number },
	box: { { number } },
	total: number,
	planes: { { number } }, -- { nx, ny, nz, d }: n·x ≤ d
	sag: { number }, -- per plane: the true solid's support less d
	spread: { number }, -- per facet: HIDE_OFFSET × sin of the largest angle between its normal and the true ones at its vertices
}

local Geo = Balance.Geometry
local EPS, DELTA = Geo.EPS_GEOM, Geo.HIDE_OFFSET
local sqrt, abs, min, max = math.sqrt, math.abs, math.min, math.max
local COS, SIN = Sampling.COS, Sampling.SIN
local AXIS_TIE = 1e-9 -- §4.4: a unit normal's components this close tie for the frame of a circle's 32-gon

local Brute = {}

Brute.MAX_EDGES = 600 -- edges in one facet's union, past which facetShown gives up (the crossings are O(edges²))

local function newell(v: { number }): (number, number, number)
	local n = #v // 3
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

-- The polygon turned counter-clockwise seen from outside: away from the solid's centre c.
local function oriented(v: { number }, cx: number, cy: number, cz: number): { number }
	local ax, ay, az = newell(v)
	local n = #v // 3
	local fx, fy, fz = 0, 0, 0
	for i = 0, n - 1 do
		fx, fy, fz = fx + v[3 * i + 1], fy + v[3 * i + 2], fz + v[3 * i + 3]
	end
	if ax * (fx / n - cx) + ay * (fy / n - cy) + az * (fz / n - cz) >= 0 then
		return v
	end
	local out: { number } = table.create(#v, 0)
	for i = 1, n do
		local s = n - i
		out[3 * i - 2], out[3 * i - 1], out[3 * i] = v[3 * s + 1], v[3 * s + 2], v[3 * s + 3]
	end
	return out
end

-- §4.4's model, in the frames the world fixes: a Ball's octahedron grid on the world axes, a Cylinder's 32-gon from the
-- world axis most across its own (Y, then X, then Z).
function Brute.model(P: Prepared): Model
	local facets: { { number } } = {}
	local planes: { { number } } = {}
	local round = P.code == Shapes.CYLINDER or P.code == Shapes.BALL
	if P.code == Shapes.CYLINDER then
		local ux, uy, uz = P.ux, P.uy, P.uz
		local e = { 0, 0, 0 }
		local a = { abs(ux), abs(uy), abs(uz) }
		if a[2] <= a[1] and a[2] <= a[3] then
			e[2] = 1
		elseif a[1] <= a[3] then
			e[1] = 1
		else
			e[3] = 1
		end
		local d = e[1] * ux + e[2] * uy + e[3] * uz
		local rx, ry, rz = e[1] - d * ux, e[2] - d * uy, e[3] - d * uz
		local l = sqrt(rx * rx + ry * ry + rz * rz)
		rx, ry, rz = rx / l, ry / l, rz / l
		local wx, wy, wz = uy * rz - uz * ry, uz * rx - ux * rz, ux * ry - uy * rx
		local function W(lx: number, ly: number, lz: number): (number, number, number)
			return P.cx + lx * ux + ly * rx + lz * wx, P.cy + lx * uy + ly * ry + lz * wy, P.cz + lx * uz + ly * rz + lz * wz
		end
		local hx, r = P.hx, P.r
		for k = 1, 32 do
			local k1 = k % 32 + 1
			local x1, y1, z1 = W(-hx, r * COS[k], r * SIN[k])
			local x2, y2, z2 = W(hx, r * COS[k], r * SIN[k])
			local x3, y3, z3 = W(hx, r * COS[k1], r * SIN[k1])
			local x4, y4, z4 = W(-hx, r * COS[k1], r * SIN[k1])
			table.insert(facets, oriented({ x1, y1, z1, x2, y2, z2, x3, y3, z3, x4, y4, z4 }, P.cx, P.cy, P.cz))
		end
		for s = -1, 1, 2 do
			local v: { number } = {}
			for k = 1, 32 do
				local x, y, z = W(s * hx, r * COS[k], r * SIN[k])
				table.insert(v, x)
				table.insert(v, y)
				table.insert(v, z)
			end
			table.insert(facets, oriented(v, P.cx, P.cy, P.cz))
		end
	elseif P.code == Shapes.BALL then
		local r, n = P.r, Geo.COVER_BALL_GRID
		for _, sx in ipairs({ 1, -1 }) do
			for _, sy in ipairs({ 1, -1 }) do
				for _, sz in ipairs({ 1, -1 }) do
					-- grid point (i, j): (n − i − j)·A + i·B + j·C over n, pushed out to radius r
					local function G(i: number, j: number): (number, number, number)
						local lx, ly, lz = sx * (n - i - j), sy * i, sz * j
						local l = sqrt(lx * lx + ly * ly + lz * lz)
						return P.cx + r * lx / l, P.cy + r * ly / l, P.cz + r * lz / l
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
	else
		facets = Shapes.faces(P)
		for _, pl in ipairs(Shapes.planes(P)) do
			table.insert(planes, { pl[1], pl[2], pl[3], pl[4] })
		end
	end
	local m: Model = { part = P, round = round, facets = facets, planes = planes, nx = {}, ny = {}, nz = {}, area = {}, box = {}, total = 0, sag = {},
		spread = {} }
	for f, v in ipairs(facets) do
		local ax, ay, az = newell(v)
		local l = sqrt(ax * ax + ay * ay + az * az)
		m.nx[f], m.ny[f], m.nz[f] = ax / l, ay / l, az / l
		m.area[f] = l / 2
		m.total += l / 2
		-- the spread: the true normal at a vertex is a Ball's radius, a Cylinder side's radius from its axis; a cap's is its own
		m.spread[f] = 0
		if P.code == Shapes.BALL or (P.code == Shapes.CYLINDER and f <= 32) then
			for i = 1, #v, 3 do
				local rx, ry, rz = v[i] - P.cx, v[i + 1] - P.cy, v[i + 2] - P.cz
				if P.code == Shapes.CYLINDER then
					local t = rx * P.ux + ry * P.uy + rz * P.uz
					rx, ry, rz = rx - t * P.ux, ry - t * P.uy, rz - t * P.uz
				end
				local rl = sqrt(rx * rx + ry * ry + rz * rz)
				local cx, cy, cz = (m.ny[f] * rz - m.nz[f] * ry) / rl, (m.nz[f] * rx - m.nx[f] * rz) / rl, (m.nx[f] * ry - m.ny[f] * rx) / rl
				m.spread[f] = max(m.spread[f], DELTA * sqrt(cx * cx + cy * cy + cz * cz))
			end
		end
		local x0, y0, z0, x1, y1, z1 = math.huge, math.huge, math.huge, -math.huge, -math.huge, -math.huge
		for i = 1, #v, 3 do
			x0, y0, z0 = min(x0, v[i]), min(y0, v[i + 1]), min(z0, v[i + 2])
			x1, y1, z1 = max(x1, v[i]), max(y1, v[i + 1]), max(z1, v[i + 2])
		end
		m.box[f] = { x0, y0, z0, x1, y1, z1 }
		if round then
			local d = 0
			for i = 1, #v, 3 do
				d += m.nx[f] * v[i] + m.ny[f] * v[i + 1] + m.nz[f] * v[i + 2]
			end
			table.insert(planes, { m.nx[f], m.ny[f], m.nz[f], d / (#v // 3) })
		end
	end
	for i, pl in ipairs(planes) do
		local own = pl[4] - (pl[1] * P.cx + pl[2] * P.cy + pl[3] * P.cz)
		local support = own
		if P.code == Shapes.BALL then
			support = P.r
		elseif P.code == Shapes.CYLINDER then -- hx·|n·u| + r·|n − (n·u)·u|
			local a = pl[1] * P.ux + pl[2] * P.uy + pl[3] * P.uz
			local px, py, pz = pl[1] - a * P.ux, pl[2] - a * P.uy, pl[3] - a * P.uz
			support = P.hx * abs(a) + P.r * sqrt(px * px + py * py + pz * pz)
		end
		m.sag[i] = max(0, support - own)
	end
	return m
end

-- Physics/Cover's own model geometry, taken over as it is: the brute force then checks the subtraction alone.
function Brute.fromCover(cm: any): Model
	local m: Model = { part = cm.part, round = cm.round, facets = {}, planes = {}, nx = {}, ny = {}, nz = {}, area = {}, box = {}, total = cm.total, sag = {},
		spread = {} }
	for f = 1, cm.n do
		m.facets[f] = cm.poly[f]
		m.nx[f], m.ny[f], m.nz[f] = cm.nx[f], cm.ny[f], cm.nz[f]
		m.area[f] = cm.area[f]
		m.spread[f] = cm.spread[f]
		local b = 6 * (f - 1)
		m.box[f] = { cm.box[b + 1], cm.box[b + 2], cm.box[b + 3], cm.box[b + 4], cm.box[b + 5], cm.box[b + 6] }
	end
	for i = 1, cm.np do
		m.planes[i] = { cm.planes[4 * i - 3], cm.planes[4 * i - 2], cm.planes[4 * i - 1], cm.planes[4 * i] }
		m.sag[i] = cm.sag[i]
	end
	return m
end

-- Sutherland–Hodgman in 3D: keeps n·x − c ≤ 0.
local function clip3(v: { number }, nx: number, ny: number, nz: number, c: number): { number }
	local n = #v // 3
	if n == 0 then
		return v
	end
	local s: { number } = table.create(n, 0)
	local anyOut, anyIn = false, false
	for i = 0, n - 1 do
		local val = nx * v[3 * i + 1] + ny * v[3 * i + 2] + nz * v[3 * i + 3] - c
		s[i + 1] = val
		if val > 0 then
			anyOut = true
		else
			anyIn = true
		end
	end
	if not anyOut then
		return v
	elseif not anyIn then
		return {}
	end
	local out: { number } = {}
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
			table.insert(out, xi + t * (v[3 * j + 1] - xi))
			table.insert(out, yi + t * (v[3 * j + 2] - yi))
			table.insert(out, zi + t * (v[3 * j + 3] - zi))
		end
	end
	return out
end

type Flat = { u: { number }, v: { number } }

-- The exact area of a union of convex polygons in a plane, by vertical slabs between events; nil past MAX_EDGES.
local function unionArea(polys: { Flat }): number?
	local events: { number } = {}
	local E: { { number } } = {} -- u0, v0, u1, v1, polygon
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
	if ne > Brute.MAX_EDGES then
		return nil
	end
	for a = 1, ne do
		local ea = E[a]
		local au0, av0, au1, av1 = ea[1], ea[2], ea[3], ea[4]
		local aumin, aumax, avmin, avmax = min(au0, au1), max(au0, au1), min(av0, av1), max(av0, av1)
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
	local ev: { number } = {}
	for _, x in ipairs(events) do
		if #ev == 0 or x ~= ev[#ev] then
			table.insert(ev, x)
		end
	end
	local pu0: { number }, pu1: { number } = {}, {}
	for p, poly in ipairs(polys) do
		local a, b = math.huge, -math.huge
		for _, u in ipairs(poly.u) do
			a, b = min(a, u), max(b, u)
		end
		pu0[p], pu1[p] = a, b
	end
	local total = 0
	local los: { number }, his: { number } = {}, {}
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
					if ((u0 <= um and um <= u1) or (u1 <= um and um <= u0)) and u0 ~= u1 then
						local v = vs[i] + (um - u0) / (u1 - u0) * (vs[j] - vs[i])
						lo, hi = min(lo, v), max(hi, v)
					end
				end
				if hi > lo then
					cnt += 1
					los[cnt], his[cnt] = lo, hi
				end
			end
		end
		if cnt > 0 then
			for i = 2, cnt do -- by where they start
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

-- How far a circle of Cylinder P (centre c, P's radius, in the plane of its local Y and Z: v, w) stands from Cylinder
-- Q's axis at most, by sampling with a bound on what it misses: the angle of its best point found, and a bound above.
-- Its point x(φ) = c + r·(cos φ·v + sin φ·w) stands D off the axis, D² = |(x(φ) − Q's centre)⊥|², a trigonometric
-- polynomial of degree 2 in φ whose second derivative is at most M = 2r·|m| + 4r² in size (m the centre's offset across
-- the axis), so on an arc of length h between points where D² is a and b, D² is at most max(a, b) + M·h²/8. 720 points
-- (math.cos, math.sin), then every arc whose bound reaches the best point found halved, 40 times, or until that bound is
-- rounding or 4,000 arcs are left: above is the root of the largest bound, + rounding.
local function rimBracket(P: Prepared, Q: Prepared, cx: number, cy: number, cz: number): (number, number)
	local function d2(phi: number): number
		local c, s = math.cos(phi), math.sin(phi)
		local x, y, z = cx + P.r * (c * P.vx + s * P.wx), cy + P.r * (c * P.vy + s * P.wy), cz + P.r * (c * P.vz + s * P.wz)
		local ox, oy, oz = x - Q.cx, y - Q.cy, z - Q.cz
		local a = ox * Q.ux + oy * Q.uy + oz * Q.uz
		ox, oy, oz = ox - a * Q.ux, oy - a * Q.uy, oz - a * Q.uz
		return ox * ox + oy * oy + oz * oz
	end
	local ox, oy, oz = cx - Q.cx, cy - Q.cy, cz - Q.cz
	local a = ox * Q.ux + oy * Q.uy + oz * Q.uz
	ox, oy, oz = ox - a * Q.ux, oy - a * Q.uy, oz - a * Q.uz
	local mm = sqrt(ox * ox + oy * oy + oz * oz)
	local M = 2 * P.r * mm + 4 * P.r * P.r
	local slack = 1e-15 * (mm + P.r) * (mm + P.r) -- rounding in D² at a point
	local n = 720
	local h = 2 * math.pi / n
	local first = d2(0)
	local best, bestPhi = first, 0
	-- live arcs, 3 numbers each: start, D² at its start, D² at its end
	local arcs: { number } = {}
	local prev = first
	for k = 1, n do
		local v = if k == n then first else d2(k * h)
		if v > best then
			best, bestPhi = v, k * h
		end
		table.insert(arcs, (k - 1) * h)
		table.insert(arcs, prev)
		table.insert(arcs, v)
		prev = v
	end
	for _ = 1, 40 do
		local bound = M * h * h / 8
		local live: { number } = {}
		for i = 1, #arcs, 3 do
			if max(arcs[i + 1], arcs[i + 2]) + bound >= best then
				table.insert(live, arcs[i])
				table.insert(live, arcs[i + 1])
				table.insert(live, arcs[i + 2])
			end
		end
		arcs = live
		if #live > 3 * 4000 or bound < slack then
			break
		end
		h /= 2
		arcs = {}
		for i = 1, #live, 3 do
			local mid = d2(live[i] + h)
			if mid > best then
				best, bestPhi = mid, live[i] + h
			end
			for _, x in ipairs({ live[i], live[i + 1], mid, live[i] + h, mid, live[i + 2] }) do
				table.insert(arcs, x)
			end
		end
	end
	local top = best
	for i = 1, #arcs, 3 do
		top = max(top, max(arcs[i + 1], arcs[i + 2]) + M * h * h / 8)
	end
	return bestPhi, sqrt(top + slack)
end

-- How far round P's true solid stands out of round Q's at most, (below, above), equal but for a Cylinder in a Cylinder:
-- Shapes.sd of Q at the points of P that stand farthest out. A Ball's: its centre moved r away from a Ball hider's
-- centre, or along a Cylinder hider's axis both ways and away from it. A Cylinder's: in a Ball hider, the point of each
-- cap circle farthest from its centre; in a Cylinder hider, its support points along the axis both ways, and each cap
-- circle's point farthest from the axis by rimBracket: below, Shapes.sd at the best point it found; above, its bound
-- less Q's radius.
local function standsOutOnce(P: Prepared, Q: Prepared): (number, number)
	-- (ax, ay, az) made a unit, or (fx, fy, fz) when it is rounding: a point on the axis line leaves a part across it of
	-- about 1e-17, whose direction is noise and need not even lie across the axis
	local function away(ax: number, ay: number, az: number, fx: number, fy: number, fz: number): (number, number, number)
		local l = sqrt(ax * ax + ay * ay + az * az)
		if l <= 1e-9 then
			return fx, fy, fz
		end
		return ax / l, ay / l, az / l
	end
	local most = -math.huge
	local function at(x: number, y: number, z: number)
		most = max(most, Shapes.sd(Q, x, y, z))
	end
	if P.code == Shapes.BALL then
		local dx, dy, dz = P.cx - Q.cx, P.cy - Q.cy, P.cz - Q.cz
		if Q.code == Shapes.BALL then
			local wx, wy, wz = away(dx, dy, dz, 1, 0, 0)
			at(P.cx + P.r * wx, P.cy + P.r * wy, P.cz + P.r * wz)
		else
			local a = dx * Q.ux + dy * Q.uy + dz * Q.uz
			local wx, wy, wz = away(dx - a * Q.ux, dy - a * Q.uy, dz - a * Q.uz, Q.vx, Q.vy, Q.vz)
			at(P.cx + P.r * wx, P.cy + P.r * wy, P.cz + P.r * wz)
			at(P.cx + P.r * Q.ux, P.cy + P.r * Q.uy, P.cz + P.r * Q.uz)
			at(P.cx - P.r * Q.ux, P.cy - P.r * Q.uy, P.cz - P.r * Q.uz)
		end
		return most, most
	end
	local above = -math.huge
	for s = -1, 1, 2 do
		local mx, my, mz = P.cx + s * P.hx * P.ux, P.cy + s * P.hx * P.uy, P.cz + s * P.hx * P.uz
		local dx, dy, dz = mx - Q.cx, my - Q.cy, mz - Q.cz
		if Q.code == Shapes.BALL then
			local a = dx * P.ux + dy * P.uy + dz * P.uz
			local wx, wy, wz = away(dx - a * P.ux, dy - a * P.uy, dz - a * P.uz, P.vx, P.vy, P.vz)
			at(mx + P.r * wx, my + P.r * wy, mz + P.r * wz)
		else
			at(Shapes.support(P, s * Q.ux, s * Q.uy, s * Q.uz))
			local phi, top = rimBracket(P, Q, mx, my, mz)
			local c, sn = math.cos(phi), math.sin(phi)
			at(mx + P.r * (c * P.vx + sn * P.wx), my + P.r * (c * P.vy + sn * P.wy), mz + P.r * (c * P.vz + sn * P.wz))
			above = max(above, top - Q.r)
		end
	end
	return most, max(most, above)
end

-- standsOut, memoized per pair (facetShown asks once a facet)
local known: { [Prepared]: { [Prepared]: { number } } } = setmetatable({}, { __mode = "k" }) :: any
function Brute.standsOut(P: Prepared, Q: Prepared): (number, number)
	local row = known[P]
	if row == nil then
		row = setmetatable({}, { __mode = "k" }) :: any
		known[P] = row
	end
	local seen = (row :: any)[Q]
	if seen == nil then
		local lo, hi = standsOutOnce(P, Q)
		seen = { lo, hi };
		(row :: any)[Q] = seen
	end
	return seen[1], seen[2]
end

-- What shows of facet f of m against the hiders (models, rank order), higher[k] whether hiders[k] ranks above m's part.
function Brute.facetShown(m: Model, f: number, hiders: { Model }, higher: { boolean }, shift: number?): number?
	local t = shift or 0
	local v = m.facets[f]
	local nfx, nfy, nfz = m.nx[f], m.ny[f], m.nz[f]
	local ox, oy, oz = v[1], v[2], v[3]
	local ex, ey, ez = v[4] - ox, v[5] - oy, v[6] - oz
	local el = sqrt(ex * ex + ey * ey + ez * ez)
	ex, ey, ez = ex / el, ey / el, ez / el
	local gx, gy, gz = nfy * ez - nfz * ey, nfz * ex - nfx * ez, nfx * ey - nfy * ex
	local gl = sqrt(gx * gx + gy * gy + gz * gz)
	gx, gy, gz = gx / gl, gy / gl, gz / gl
	local function flat(w: { number }): Flat
		local us: { number }, vs: { number } = {}, {}
		for i = 1, #w, 3 do
			local dx, dy, dz = w[i] - ox, w[i + 1] - oy, w[i + 2] - oz
			table.insert(us, dx * ex + dy * ey + dz * ez)
			table.insert(vs, dx * gx + dy * gy + dz * gz)
		end
		return { u = us, v = vs }
	end
	local fsag, spread = if m.round then m.sag[f] else 0, m.spread[f]
	-- a round part whose true solid lies in a round hider's, buried or coincident by its signed distance, shows nothing
	-- (standsOut's bracket: its point found when the shift hides more, its bound when it hides less); nor does a round
	-- facet whose true patch does: the patch lies in the frustum from the facet to its vertices pushed out, from the
	-- centre (a Ball), the axis (a Cylinder's side) or the cap's centre, by r over the facet's own offset (a cap's: side
	-- 1's, the apothem), so it is enough that every corner of the frustum is
	if m.round then
		local P = m.part
		for h, q in ipairs(hiders) do
			if q.round then
				local below, above = Brute.standsOut(P, q.part)
				local s = if t < 0 then above else below
				if (if higher[h] then s <= EPS + t else s < -EPS + t) then
					return 0
				end
			end
		end
		local corners: { number } = {}
		for j = 1, #v, 3 do
			local x, y, z = v[j], v[j + 1], v[j + 2]
			local cx, cy, cz = P.cx, P.cy, P.cz
			local pl = m.planes[f]
			if P.code == Shapes.CYLINDER then
				local s = (x - P.cx) * P.ux + (y - P.cy) * P.uy + (z - P.cz) * P.uz
				cx, cy, cz = P.cx + s * P.ux, P.cy + s * P.uy, P.cz + s * P.uz
				if f > 32 then
					pl = m.planes[1]
				end
			end
			local k = P.r / (pl[4] - (pl[1] * P.cx + pl[2] * P.cy + pl[3] * P.cz))
			for _, w in ipairs({ x, y, z, cx + (x - cx) * k, cy + (y - cy) * k, cz + (z - cz) * k }) do
				table.insert(corners, w)
			end
		end
		for h, q in ipairs(hiders) do
			if q.round then
				local inside = true
				for j = 1, #corners, 3 do
					local s = Shapes.sd(q.part, corners[j], corners[j + 1], corners[j + 2])
					inside = inside and (if higher[h] then s <= EPS + t else s < -EPS + t)
				end
				if inside then
					return 0
				end
			end
		end
	end
	-- a flat facet (a polyhedron's face, a cap) against a Ball reads the sphere: the frame of its 32-gons, by its own
	-- arithmetic, the world axis most across n by §4.4's rule, v = n × that made a unit, u = v × n
	local onFlat = not m.round or (m.part.code == Shapes.CYLINDER and f > 32)
	local fa = { abs(nfx), abs(nfy), abs(nfz) }
	local fe = { 0, 0, 0 }
	if fa[2] <= fa[1] + AXIS_TIE and fa[2] <= fa[3] + AXIS_TIE then
		fe[2] = 1
	elseif fa[1] <= fa[3] + AXIS_TIE then
		fe[1] = 1
	else
		fe[3] = 1
	end
	local wvx, wvy, wvz = nfy * fe[3] - nfz * fe[2], nfz * fe[1] - nfx * fe[3], nfx * fe[2] - nfy * fe[1]
	local wvl = sqrt(wvx * wvx + wvy * wvy + wvz * wvz)
	wvx, wvy, wvz = wvx / wvl, wvy / wvl, wvz / wvl
	local wux, wuy, wuz = wvy * nfz - wvz * nfy, wvz * nfx - wvx * nfz, wvx * nfy - wvy * nfx
	local pieces: { Flat } = {}
	for h, q in ipairs(hiders) do
		if onFlat and q.part.code == Shapes.BALL then
			-- each piece: the facet within the 32-gon round the circle that its plane (the probe's: δ + its sag along n) cuts
			-- from the sphere, R grown by EPS_GEOM if the Ball ranks higher, else shrunk (the probe's grown); none where the
			-- plane misses it. Its sides are half-spaces across the plane, w·x ≤ w·C + ρ, w = COS·u + SIN·v
			local Q = q.part
			for kind = 1, 2 do
				local R = Q.r + (if kind == 2 or higher[h] then EPS else -EPS) + t
				local s = nfx * (ox - Q.cx) + nfy * (oy - Q.cy) + nfz * (oz - Q.cz) + (if kind == 2 then DELTA + fsag else 0)
				if s * s < R * R then
					local rho = sqrt(R * R - s * s)
					local w = v
					for k = 1, 32 do
						local wx, wy, wz = COS[k] * wux + SIN[k] * wvx, COS[k] * wuy + SIN[k] * wvy, COS[k] * wuz + SIN[k] * wvz
						w = clip3(w, wx, wy, wz, wx * Q.cx + wy * Q.cy + wz * Q.cz + rho)
						if #w == 0 then
							break
						end
					end
					if #w >= 9 then
						table.insert(pieces, flat(w))
					end
				end
			end
		else
			for kind = 1, 2 do
				local w = v
				for i, pl in ipairs(q.planes) do
					local c
					if kind == 1 then -- buried or coincident: the hider's half-spaces, moved out to its true solid for a polyhedron's facet
						c = pl[4] + (if m.round then 0 else q.sag[i]) + (if higher[h] then EPS else -EPS) + t
					else -- the probe: the facet's sag further, the hider's half-spaces moved out to the true solid, grown by its spread
						c = pl[4] + q.sag[i] + spread + EPS - (DELTA + fsag) * (pl[1] * nfx + pl[2] * nfy + pl[3] * nfz) + t
					end
					w = clip3(w, pl[1], pl[2], pl[3], c)
					if #w == 0 then
						break
					end
				end
				if #w >= 9 then
					table.insert(pieces, flat(w))
				end
			end
		end
	end
	if #pieces == 0 then
		return m.area[f]
	end
	local covered = unionArea(pieces)
	if covered == nil then
		return nil
	end
	return m.area[f] - covered
end

-- Every part that hides, but i: no exact copy of a part above it, no Dust, however far, in rank order.
function Brute.hiders(parts: { Prepared }, i: number): ({ number }, { boolean })
	local rank, order = Sampling.ranked(parts)
	local out: { number }, higher: { boolean } = {}, {}
	for r = 1, #order do
		local q = order[r]
		local copy = false
		for t = 1, r - 1 do
			copy = copy or Shapes.sameSolid(q, order[t])
		end
		if q.index ~= i and not copy and q.volume >= Geo.MIN_PART_VOLUME then
			table.insert(out, q.index)
			table.insert(higher, r < rank[i])
		end
	end
	return out, higher
end

return table.freeze(Brute)
