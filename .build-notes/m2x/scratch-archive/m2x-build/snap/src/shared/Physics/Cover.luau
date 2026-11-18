--!strict
-- Physics/Cover (SPEC §4.1, §4.4, §4.9; owner S2): the Enclosed verdict's reading, exact on a polyhedral model of each
-- part. Pure; §4.1's determinism rules apply: + − × ÷ and sqrt, abs, min, max only, numeric loops, no sort, no
-- module-level state.
--
--   model   a part's polyhedron in world space: its facets (convex polygons, counter-clockwise seen from outside, unit
--           outward normals, areas, boxes), its half-spaces n·x ≤ d with their sag, its inner ball, and the work of
--           building it
--   shown   what shows of a part's model against its hiders' models: Σ over its facets, in model order, of the facet's
--           area less what the hiders hide on it, returned once it reaches `need`; the work done, and whether the work
--           passed the budget (then it stopped at once, and the area is no answer)
--
-- The model. Block, Wedge, CornerWedge: exact (Shapes.faces, Shapes.planes). Cylinder (axis local X, r = min(hy, hz)):
-- the prism over the inscribed 32-gon of the unit circle below; facets the 32 side rectangles, k = 1…32, then the +X cap,
-- then the −X cap. Ball (r = min(hx, hy, hz)): the octahedron with each face split by a triangular grid of
-- COVER_BALL_GRID steps (4: 16 triangles a face, 128 in all), every grid vertex (i·A + j·B + k·C)/n pushed out to length
-- r; octants in the order (+ + +), (+ + −), (+ − +), (+ − −), (− + +), …, in each the rows t = 0…n−1 from the corner
-- A = (±1, 0, 0), a row's triangles alternating up and down. Both stand in frames the world fixes, never the part's: a
-- Ball's octahedron on the world axes; a Cylinder's circle starts from the world axis most across its own (Y, then X,
-- then Z on a tie), made square to it. So a round part spun or turned about its own symmetry has its original's model
-- (to the ulps of its axis), where the part's own frame would turn the polygon with it and leave the copy showing; and
-- the model of a mirror image (Blueprint/Mirror) is the mirror image of the model, to the ulps of the table. A round part
-- that hides uses the same polyhedron, one half-space per facet, in facet order.
--
-- The hide test of §4.4 on a point x of facet f of p (outward normal n), against hider q's half-spaces (n_i, d_i):
--   buried or coincident  n_i·x ≤ d_i + EPS_GEOM for all i if q ranks higher than p, else n_i·x < d_i − EPS_GEOM
--   probe                 n_i·(x + (HIDE_OFFSET + sag_f)·n) ≤ d_i + sag_i + EPS_GEOM for all i
-- Each is a convex piece of f: f clipped by q's half-spaces moved in f's plane. The probe is the conservative one. An
-- inscribed facet lies inside the true surface by its sag (the true solid's support along its normal less its own
-- offset: the sagitta on a round model's facets, 0 on a polyhedron and a cap), so a round part's facets probe that much
-- further, and a round hider's half-spaces move out to the true surface for the probe alone. Without it a round filler
-- sealed by flat walls a gap just under HIDE_OFFSET away, truly hidden, reads as showing. The buried or coincident piece
-- keeps the inscribed half-spaces, so that a coincident copy still counts its faces once.
--
-- Subtraction. What a facet shows is a list of disjoint convex polygons in its plane (2D coordinates along its first
-- edge and n × that), at first the facet itself. Each piece C, hiders in rank order, the buried piece before the
-- probe's, replaces every polygon U whose box meets C's by U − C: for each of C's lines in turn (the half-spaces that cut
-- the facet), the part of U outside it is a new polygon, and U keeps the part inside; what is left at the end lies in C
-- and is dropped. Every area is a polygon's own, so rounding stays local: no edge has to meet another's. Shortcuts that
-- change no area beyond rounding: a facet within q's inner ball, or whose probe is, lies wholly in that piece; a piece
-- that is all of the facet leaves nothing at once; a line no vertex of the facet crosses is skipped; a piece inside its
-- sibling adds nothing; a polygon that a line of C or one of its own edges separates from C is kept whole.
--
-- Work. One unit is about one shape query's time (§4.9): a vertex against a line UNITS_PER_TEST, a box against a box
-- UNITS_PER_BOX (a hider against a facet, a shown polygon against a piece, a polygon summed), a polygon made
-- UNITS_PER_POLYGON on top of its vertices, a model facet built UNITS_PER_FACET on top of its vertices. The weights are
-- dyadic, so a sum comes out the same in any order, and a part's work depends only on the part and its hiders. They are
-- the cap's units as well as the checkpoints': past `budget` the reading stops at the next report, and Sampling makes the
-- design TooComplex (VERDICT_WORK_MAX). The cap never changes a verdict, but where it falls moves with a weight, so the
-- weights are part of the outcome and move with BALANCE_VERSION. Reported through `spend` at least every SPEND_EVERY
-- units, between polygons, never inside a comparator.
--
-- Numeric guards, not tunables: a polygon under AREA_NIL of its facet is rounding and is dropped (a split along a line
-- that grazes a vertex leaves one); the inner-ball shortcut takes INNER_SAFE of the radius, so that rounding cannot put a
-- vertex on the far side of a half-space it tested inside.

local Balance = require("../Definitions/Balance")
local Shapes = require("./Shapes")

type Prepared = Shapes.Prepared

local sqrt, abs, min, max = math.sqrt, math.abs, math.min, math.max

local Geo = Balance.Geometry
local EPS = Geo.EPS_GEOM
local DELTA = Geo.HIDE_OFFSET
local BALL_N = Geo.COVER_BALL_GRID

local CYLINDER, BALL = Shapes.CYLINDER, Shapes.BALL

local AREA_NIL = 1e-12 -- numeric guard, not a tunable: a polygon under this share of its facet is rounding
local INNER_SAFE = 1 - 1e-12 -- numeric guard, not a tunable: the inner-ball shortcut stays clear of rounding

local UNITS_PER_TEST = 0.5 -- a vertex against a line; a half-space's projection counts as one
local UNITS_PER_BOX = 0.125 -- a box against a box
local UNITS_PER_POLYGON = 1 -- a polygon made, on top of its vertices
local UNITS_PER_FACET = 8 -- a model facet built, with its half-space and sag, on top of its vertices
local SPEND_EVERY = 256 -- units between reports to spend (checkpoints, and where the cap can stop)

-- The unit circle in 32 directions, k = 0…31 (§4.1: literal constants, 17 significant digits, never trigonometry).
-- The S2 prototype's values bit for bit, so k = 8 is 6.1e-17 and not 0; Sampling reads them from here. T-PHY checks
-- them against math.cos and math.sin.
local COS: { number } = table.freeze({
	1, 0.98078528040323043, 0.92387953251128674, 0.83146961230254524,
	0.70710678118654757, 0.55557023301960229, 0.38268343236508984, 0.19509032201612833,
	6.123233995736766e-17, -0.19509032201612819, -0.38268343236508973, -0.55557023301960196,
	-0.70710678118654746, -0.83146961230254535, -0.92387953251128674, -0.98078528040323043,
	-1, -0.98078528040323043, -0.92387953251128685, -0.83146961230254546,
	-0.70710678118654768, -0.55557023301960218, -0.38268343236509034, -0.19509032201612866,
	-1.8369701987210297e-16, 0.1950903220161283, 0.38268343236509, 0.55557023301960184,
	0.70710678118654735, 0.83146961230254524, 0.92387953251128652, 0.98078528040323032,
})
local SIN: { number } = table.freeze({
	0, 0.19509032201612825, 0.38268343236508978, 0.55557023301960218,
	0.70710678118654757, 0.83146961230254524, 0.92387953251128674, 0.98078528040323043,
	1, 0.98078528040323043, 0.92387953251128674, 0.83146961230254535,
	0.70710678118654757, 0.55557023301960218, 0.38268343236508989, 0.19509032201612861,
	1.2246467991473532e-16, -0.19509032201612836, -0.38268343236508967, -0.55557023301960196,
	-0.70710678118654746, -0.83146961230254524, -0.92387953251128652, -0.98078528040323032,
	-1, -0.98078528040323043, -0.92387953251128663, -0.83146961230254546,
	-0.70710678118654768, -0.55557023301960218, -0.38268343236509039, -0.19509032201612872,
})

export type Spend = (units: number) -> ()

export type Model = {
	part: Prepared,
	round: boolean, -- a Cylinder or a Ball: facet f is half-space f
	n: number, -- facets
	poly: { { number } }, -- per facet: world polygon, flat x, y, z, counter-clockwise seen from outside
	nx: { number }, -- per facet: unit outward normal
	ny: { number },
	nz: { number },
	area: { number }, -- per facet
	box: { number }, -- 6 per facet: min x, y, z, max x, y, z
	total: number, -- the model's area: Σ facet areas, in facet order
	np: number, -- half-spaces
	planes: { number }, -- 4 per half-space: nx, ny, nz, d with n·x ≤ d, unit n
	sag: { number }, -- per half-space: how far the true solid reaches past it (0 on a polyhedron and a cap)
	inner: number, -- the largest ball about the part's centre inside every half-space (0 when the centre is on one)
	work: number, -- units: building it
}

local function noSpend(_: number) end

local Cover = {}

Cover.COS, Cover.SIN = COS, SIN
Cover.UNITS_PER_BOX = UNITS_PER_BOX

-- ── the model ─────────────────────────────────────────────────────────────────────────────────────────────────────

-- Appends a world facet: Newell normal, area, box.
local function addFacet(m: Model, poly: { number })
	local n = #poly / 3
	local ax, ay, az = 0, 0, 0
	local minx, miny, minz = math.huge, math.huge, math.huge
	local maxx, maxy, maxz = -math.huge, -math.huge, -math.huge
	for i = 0, n - 1 do
		local j = if i == n - 1 then 0 else i + 1
		local x0, y0, z0 = poly[3 * i + 1], poly[3 * i + 2], poly[3 * i + 3]
		local x1, y1, z1 = poly[3 * j + 1], poly[3 * j + 2], poly[3 * j + 3]
		ax += (y0 - y1) * (z0 + z1)
		ay += (z0 - z1) * (x0 + x1)
		az += (x0 - x1) * (y0 + y1)
		minx, miny, minz = min(minx, x0), min(miny, y0), min(minz, z0)
		maxx, maxy, maxz = max(maxx, x0), max(maxy, y0), max(maxz, z0)
	end
	local l = sqrt(ax * ax + ay * ay + az * az)
	local f = m.n + 1
	m.n = f
	m.poly[f] = poly
	m.nx[f], m.ny[f], m.nz[f] = ax / l, ay / l, az / l
	m.area[f] = l / 2
	m.total += l / 2
	m.work += UNITS_PER_FACET + n * UNITS_PER_TEST
	local b = 6 * (f - 1)
	m.box[b + 1], m.box[b + 2], m.box[b + 3] = minx, miny, minz
	m.box[b + 4], m.box[b + 5], m.box[b + 6] = maxx, maxy, maxz
end

-- A frame: centre, then the world directions of its local X, Y, Z (12 numbers).
type Frame = { number }

-- A facet from local vertices (flat x, y, z) in frame F, already counter-clockwise seen from outside, and its half-space.
local function addLocal(m: Model, F: Frame, lv: { number })
	local n = #lv / 3
	local poly: { number } = table.create(3 * n, 0)
	local cx, cy, cz = F[1], F[2], F[3]
	local ux, uy, uz, vx, vy, vz, wx, wy, wz = F[4], F[5], F[6], F[7], F[8], F[9], F[10], F[11], F[12]
	for i = 1, 3 * n, 3 do
		local lx, ly, lz = lv[i], lv[i + 1], lv[i + 2]
		poly[i] = cx + lx * ux + ly * vx + lz * wx
		poly[i + 1] = cy + lx * uy + ly * vy + lz * wy
		poly[i + 2] = cz + lx * uz + ly * vz + lz * wz
	end
	addFacet(m, poly)
	local f = m.n
	local nx, ny, nz = m.nx[f], m.ny[f], m.nz[f]
	local d = 0
	for i = 1, 3 * n, 3 do
		d += nx * poly[i] + ny * poly[i + 1] + nz * poly[i + 2]
	end
	local k = 4 * m.np
	m.np += 1
	m.planes[k + 1], m.planes[k + 2], m.planes[k + 3], m.planes[k + 4] = nx, ny, nz, d / n
end

-- The ball's grid vertex (i, j, k), i + j + k = BALL_N, in octant (sx, sy, sz), at length r: flat into out.
local function ballVertex(out: { number }, r: number, sx: number, sy: number, sz: number, i: number, j: number,
	k: number)
	local l = r / sqrt(i * i + j * j + k * k)
	table.insert(out, sx * i * l)
	table.insert(out, sy * j * l)
	table.insert(out, sz * k * l)
end

-- A triangle of the ball's grid, turned counter-clockwise seen from outside (its plane misses the centre).
local function ballTriangle(m: Model, F: Frame, r: number, sx: number, sy: number, sz: number, a: { number },
	b: { number }, c: { number })
	local lv: { number } = {}
	ballVertex(lv, r, sx, sy, sz, a[1], a[2], a[3])
	ballVertex(lv, r, sx, sy, sz, b[1], b[2], b[3])
	ballVertex(lv, r, sx, sy, sz, c[1], c[2], c[3])
	local ux, uy, uz = lv[4] - lv[1], lv[5] - lv[2], lv[6] - lv[3]
	local vx, vy, vz = lv[7] - lv[1], lv[8] - lv[2], lv[9] - lv[3]
	local cx, cy, cz = uy * vz - uz * vy, uz * vx - ux * vz, ux * vy - uy * vx
	if cx * (lv[1] + lv[4] + lv[7]) + cy * (lv[2] + lv[5] + lv[8]) + cz * (lv[3] + lv[6] + lv[9]) < 0 then
		lv[4], lv[5], lv[6], lv[7], lv[8], lv[9] = lv[7], lv[8], lv[9], lv[4], lv[5], lv[6]
	end
	addLocal(m, F, lv)
end

local OCTANTS: { number } = table.freeze({ 1, 1, 1, 1, 1, -1, 1, -1, 1, 1, -1, -1, -1, 1, 1, -1, 1, -1, -1, -1, 1, -1, -1, -1 })

function Cover.model(P: Prepared): Model
	local m: Model = {
		part = P,
		round = false,
		n = 0,
		poly = {},
		nx = {},
		ny = {},
		nz = {},
		area = {},
		box = {},
		total = 0,
		np = 0,
		planes = {},
		sag = {},
		inner = 0,
		work = 0,
	}
	local code = P.code
	if code == CYLINDER then
		-- the world axis most across the cylinder's, then its part square to the axis: the same for either sense of it
		local hx, r = P.hx, P.r
		local ux, uy, uz = P.ux, P.uy, P.uz
		local ax, ay, az = abs(ux), abs(uy), abs(uz)
		local ex, ey, ez = 0, 0, 0
		if ay <= ax and ay <= az then
			ey = 1
		elseif ax <= az then
			ex = 1
		else
			ez = 1
		end
		local d = ex * ux + ey * uy + ez * uz
		local rx, ry, rz = ex - d * ux, ey - d * uy, ez - d * uz
		local l = sqrt(rx * rx + ry * ry + rz * rz)
		rx, ry, rz = rx / l, ry / l, rz / l
		local F: Frame = { P.cx, P.cy, P.cz, ux, uy, uz, rx, ry, rz, uy * rz - uz * ry, uz * rx - ux * rz, ux * ry - uy * rx }
		for k = 1, 32 do
			local k1 = if k == 32 then 1 else k + 1
			local y0, z0, y1, z1 = r * COS[k], r * SIN[k], r * COS[k1], r * SIN[k1]
			addLocal(m, F, { -hx, y0, z0, -hx, y1, z1, hx, y1, z1, hx, y0, z0 })
		end
		local plus: { number } = table.create(96, 0)
		local minus: { number } = table.create(96, 0)
		for k = 1, 32 do
			plus[3 * k - 2], plus[3 * k - 1], plus[3 * k] = hx, r * COS[k], r * SIN[k]
			local s = 33 - k
			minus[3 * k - 2], minus[3 * k - 1], minus[3 * k] = -hx, r * COS[s], r * SIN[s]
		end
		addLocal(m, F, plus)
		addLocal(m, F, minus)
		m.round = true
	elseif code == BALL then
		local r, n = P.r, BALL_N
		local F: Frame = { P.cx, P.cy, P.cz, 1, 0, 0, 0, 1, 0, 0, 0, 1 }
		for o = 1, 24, 3 do
			local sx, sy, sz = OCTANTS[o], OCTANTS[o + 1], OCTANTS[o + 2]
			for t = 0, n - 1 do
				local top, low = n - t, n - t - 1
				for j = 0, t do
					ballTriangle(m, F, r, sx, sy, sz, { top, j, t - j }, { low, j + 1, t - j }, { low, j, t - j + 1 })
					if j < t then
						ballTriangle(m, F, r, sx, sy, sz, { top, j, t - j }, { top, j + 1, t - j - 1 }, { low, j + 1, t - j })
					end
				end
			end
		end
		m.round = true
	else
		local faces = Shapes.faces(P)
		for f = 1, #faces do
			addFacet(m, faces[f])
		end
		local planes = Shapes.planes(P)
		for i = 1, #planes do
			local pl = planes[i]
			local k = 4 * m.np
			m.np += 1
			m.planes[k + 1], m.planes[k + 2], m.planes[k + 3], m.planes[k + 4] = pl[1], pl[2], pl[3], pl[4]
		end
	end
	-- the true solid's support along each half-space's normal, less the half-space's own offset (about the centre): the
	-- sagitta on a round model's facets (Ball r; Cylinder hx·|n·u| + r·|n − (n·u)·u|, the latter not 1 − (n·u)², which
	-- rounding leaves at 1e-16 on a cap), 0 on a polyhedron and a cap
	local pl = m.planes
	local inner = math.huge
	for i = 1, m.np do
		local nx, ny, nz = pl[4 * i - 3], pl[4 * i - 2], pl[4 * i - 1]
		local own = pl[4 * i] - (nx * P.cx + ny * P.cy + nz * P.cz)
		local sag = 0
		if code == BALL then
			sag = max(0, P.r - own)
		elseif code == CYLINDER then
			local a = nx * P.ux + ny * P.uy + nz * P.uz
			local px, py, pz = nx - a * P.ux, ny - a * P.uy, nz - a * P.uz
			sag = max(0, P.hx * abs(a) + P.r * sqrt(px * px + py * py + pz * pz) - own)
		end
		m.sag[i] = sag
		inner = min(inner, own)
	end
	m.inner = max(0, inner)
	return m
end

-- ── a facet's plane: polygons as flat u, v ────────────────────────────────────────────────────────────────────────

-- Twice the signed area (counter-clockwise > 0) and the box.
local function measure(poly: { number }): (number, number, number, number, number)
	local n = #poly
	local s = 0
	local pu, pv = poly[n - 1], poly[n]
	local u0, u1, v0, v1 = pu, pu, pv, pv
	for i = 1, n, 2 do
		local u, v = poly[i], poly[i + 1]
		s += pu * v - u * pv
		pu, pv = u, v
		if u < u0 then
			u0 = u
		elseif u > u1 then
			u1 = u
		end
		if v < v0 then
			v0 = v
		elseif v > v1 then
			v1 = v
		end
	end
	return s, u0, u1, v0, v1
end

-- The polygon split by the line a·u + b·v = c: (inside, a·u + b·v ≤ c; outside), either nil when empty. A vertex on the
-- line goes to both; sv holds the signed values. The polygon itself comes back when the line misses it.
local function split(poly: { number }, a: number, b: number, c: number, sv: { number }): ({ number }?, { number }?)
	local n = #poly
	local m = 0
	local hasIn, hasOut = false, false
	for i = 1, n, 2 do
		local s = a * poly[i] + b * poly[i + 1] - c
		m += 1
		sv[m] = s
		if s < 0 then
			hasIn = true
		elseif s > 0 then
			hasOut = true
		end
	end
	if not hasOut then
		return poly, nil
	elseif not hasIn then
		return nil, poly
	end
	local inside: { number } = table.create(n + 2) -- a convex polygon cut once has at most one vertex more
	local outside: { number } = table.create(n + 2)
	local ni, no = 0, 0
	for k = 1, m do
		local k1 = if k == m then 1 else k + 1
		local s0, s1 = sv[k], sv[k1]
		local u0, v0 = poly[2 * k - 1], poly[2 * k]
		if s0 <= 0 then
			inside[ni + 1], inside[ni + 2] = u0, v0
			ni += 2
		end
		if s0 >= 0 then
			outside[no + 1], outside[no + 2] = u0, v0
			no += 2
		end
		if (s0 < 0 and s1 > 0) or (s0 > 0 and s1 < 0) then
			local t = s0 / (s0 - s1)
			local x, y = u0 + t * (poly[2 * k1 - 1] - u0), v0 + t * (poly[2 * k1] - v0)
			inside[ni + 1], inside[ni + 2] = x, y
			outside[no + 1], outside[no + 2] = x, y
			ni += 2
			no += 2
		end
	end
	return inside, outside
end

-- The polygon clipped to a·u + b·v ≤ c: (what is left or nil, whether the line cut it).
local function clip(poly: { number }, a: number, b: number, c: number, sv: { number }): ({ number }?, boolean)
	local n = #poly
	local m = 0
	local hasIn, hasOut = false, false
	for i = 1, n, 2 do
		local s = a * poly[i] + b * poly[i + 1] - c
		m += 1
		sv[m] = s
		if s < 0 then
			hasIn = true
		elseif s > 0 then
			hasOut = true
		end
	end
	if not hasOut then
		return poly, false
	elseif not hasIn then
		return nil, true
	end
	local inside: { number } = table.create(n + 2)
	local ni = 0
	for k = 1, m do
		local k1 = if k == m then 1 else k + 1
		local s0, s1 = sv[k], sv[k1]
		local u0, v0 = poly[2 * k - 1], poly[2 * k]
		if s0 <= 0 then
			inside[ni + 1], inside[ni + 2] = u0, v0
			ni += 2
		end
		if (s0 < 0 and s1 > 0) or (s0 > 0 and s1 < 0) then
			local t = s0 / (s0 - s1)
			inside[ni + 1], inside[ni + 2] = u0 + t * (poly[2 * k1 - 1] - u0), v0 + t * (poly[2 * k1] - v0)
			ni += 2
		end
	end
	return inside, true
end

-- ── the reading ───────────────────────────────────────────────────────────────────────────────────────────────────

-- What shows of model pm against its hiders, the candidate models in rank order (none of them pm, an exact copy or Dust),
-- higher[k] whether hiders[k] ranks above pm's part: Σ over the facets in order, returned once it reaches `need`. Also the
-- work done, in units, and whether it passed `budget`: then the reading stopped at once and the area is no answer.
function Cover.shown(pm: Model, hiders: { Model }, higher: { boolean }, need: number, budget: number,
	spend: Spend?): (number, number, boolean)
	local work = spend or noSpend
	local nh = #hiders
	if nh == 0 then
		return pm.total, 0, budget < 0
	end
	local margin = DELTA + 2 * EPS
	-- per call: the projected half-spaces of one hider (la·u + lb·v ≤ lbase + the piece's offset), their extremes over the
	-- facet's vertices, each piece's offsets and cutting lines, signed values, the shown lists
	local la: { number }, lb: { number }, lbase: { number } = {}, {}, {}
	local shi: { number }, slo: { number } = {}, {}
	local cA: { number }, cB: { number } = {}, {}
	local actA: { number }, actB: { number } = {}, {}
	local sv: { number } = {}
	local cur: { { number } }, nxt: { { number } } = {}, {}
	local curA: { number }, nxtA: { number } = {}, {}
	local curB: { number }, nxtB: { number } = {}, {} -- 4 per polygon: u0, u1, v0, v1
	local done, pending = 0, 0
	local over = false
	local shown = 0
	local count = 0
	local tiny = 0

	-- Reports the pending units; over once the work has passed the budget.
	local function settle()
		if pending > 0 then
			work(pending)
			done += pending
			pending = 0
		end
		over = done > budget
	end

	-- The piece of the facet fp where every line i with c[i] holds: (polygon or nil, number of cutting lines in act,
	-- whole facet). A line no vertex of the facet crosses cuts no part of it and is skipped.
	local function piece(fp: { number }, np: number, c: { number }, act: { number }): ({ number }?, number, boolean)
		local nact = 0
		for i = 1, np do
			if slo[i] > c[i] then
				return nil, 0, false -- the whole facet lies outside this line
			elseif shi[i] > c[i] then
				nact += 1
				act[nact] = i
			end
		end
		if nact == 0 then
			return fp, 0, true
		end
		local C: { number }? = fp
		for j = 1, nact do
			local i = act[j]
			local before = C :: { number }
			local cut
			C, cut = clip(before, la[i], lb[i], c[i] + lbase[i], sv)
			pending += UNITS_PER_TEST * #before / 2
			if C == nil then
				return nil, 0, false
			elseif cut then
				pending += UNITS_PER_POLYGON + UNITS_PER_TEST * #C / 2
			end
		end
		return C, nact, false
	end

	-- Does every vertex of polygon P satisfy the nact lines in act with offsets c?
	local function within(P: { number }, c: { number }, act: { number }, nact: number): boolean
		pending += UNITS_PER_TEST * nact * #P / 2
		for j = 1, nact do
			local i = act[j]
			local a, b, d = la[i], lb[i], c[i] + lbase[i]
			for k = 1, #P, 2 do
				if a * P[k] + b * P[k + 1] > d then
					return false
				end
			end
		end
		return true
	end

	-- Are convex polygons U and C (both counter-clockwise) disjoint? A separating edge of either decides (C's lines are
	-- its cutting lines; U's are its own edges).
	local function apart(U: { number }, C: { number }, c: { number }, act: { number }, nact: number): boolean
		pending += UNITS_PER_TEST * (nact * #U / 2 + #U * #C / 4)
		for j = 1, nact do
			local i = act[j]
			local a, b, d = la[i], lb[i], c[i] + lbase[i]
			local out = true
			for k = 1, #U, 2 do
				if a * U[k] + b * U[k + 1] <= d then
					out = false
					break
				end
			end
			if out then
				return true
			end
		end
		local n = #U
		local pu, pv = U[n - 1], U[n]
		for k = 1, n, 2 do
			local u, v = U[k], U[k + 1]
			-- outward normal of edge (pu, pv) → (u, v) of a counter-clockwise polygon: (dv, −du)
			local a, b = v - pv, pu - u
			local d = a * u + b * v
			local out = true
			for m = 1, #C, 2 do
				if a * C[m] + b * C[m + 1] <= d then
					out = false
					break
				end
			end
			if out then
				return true
			end
			pu, pv = u, v
		end
		return false
	end

	-- The shown list less piece C (cutting lines act, offsets c; box cu0…cv1); stops at once when the work passes the
	-- budget.
	local function subtract(C: { number }, cu0: number, cu1: number, cv0: number, cv1: number, c: { number },
		act: { number }, nact: number)
		local nn = 0
		for u = 1, count do
			local U = cur[u]
			local b = 4 * (u - 1)
			local uu0, uu1, uv0, uv1 = curB[b + 1], curB[b + 2], curB[b + 3], curB[b + 4]
			pending += UNITS_PER_BOX
			if uu0 <= cu1 and cu0 <= uu1 and uv0 <= cv1 and cv0 <= uv1 and not apart(U, C, c, act, nact) then
				local rest: { number }? = U
				for j = 1, nact do
					local i = act[j]
					local R = rest :: { number }
					pending += UNITS_PER_TEST * #R / 2
					local inside, outside = split(R, la[i], lb[i], c[i] + lbase[i], sv)
					if inside ~= nil and outside ~= nil then
						pending += 2 * UNITS_PER_POLYGON + UNITS_PER_TEST * (#inside + #outside) / 2
					end
					if outside ~= nil then
						if outside == U then
							nn += 1
							nxt[nn], nxtA[nn] = U, curA[u]
							local nb = 4 * (nn - 1)
							nxtB[nb + 1], nxtB[nb + 2], nxtB[nb + 3], nxtB[nb + 4] = uu0, uu1, uv0, uv1
						else
							local os, ou0, ou1, ov0, ov1 = measure(outside)
							if os > 2 * tiny then
								nn += 1
								nxt[nn], nxtA[nn] = outside, os / 2
								local nb = 4 * (nn - 1)
								nxtB[nb + 1], nxtB[nb + 2], nxtB[nb + 3], nxtB[nb + 4] = ou0, ou1, ov0, ov1
							end
						end
					end
					rest = inside
					if inside == nil then
						break
					end
				end
				if pending >= SPEND_EVERY then
					settle()
					if over then
						return
					end
				end
			else
				nn += 1
				nxt[nn], nxtA[nn] = U, curA[u]
				local nb = 4 * (nn - 1)
				nxtB[nb + 1], nxtB[nb + 2], nxtB[nb + 3], nxtB[nb + 4] = uu0, uu1, uv0, uv1
			end
		end
		cur, nxt = nxt, cur
		curA, nxtA = nxtA, curA
		curB, nxtB = nxtB, curB
		count = nn
	end

	-- What shows of the facet: the shown list less the piece, if the piece is more than rounding; whether nothing is left.
	local function less(C: { number }, c: { number }, act: { number }, nact: number): boolean
		local s, cu0, cu1, cv0, cv1 = measure(C)
		pending += UNITS_PER_TEST * #C / 2
		if s > 2 * tiny then
			subtract(C, cu0, cu1, cv0, cv1, c, act, nact)
		end
		return count == 0
	end

	for f = 1, pm.n do
		local fa = pm.area[f]
		local poly3 = pm.poly[f]
		local fb = 6 * (f - 1)
		local bx0, by0, bz0 = pm.box[fb + 1] - margin, pm.box[fb + 2] - margin, pm.box[fb + 3] - margin
		local bx1, by1, bz1 = pm.box[fb + 4] + margin, pm.box[fb + 5] + margin, pm.box[fb + 6] + margin
		local nx, ny, nz = pm.nx[f], pm.ny[f], pm.nz[f]
		local probe = DELTA + (if pm.round then pm.sag[f] else 0)
		-- the facet's plane: origin its first vertex, e along its first edge, g = n × e
		local ox, oy, oz = poly3[1], poly3[2], poly3[3]
		local ex, ey, ez = poly3[4] - ox, poly3[5] - oy, poly3[6] - oz
		local el = sqrt(ex * ex + ey * ey + ez * ez)
		ex, ey, ez = ex / el, ey / el, ez / el
		local gx, gy, gz = ny * ez - nz * ey, nz * ex - nx * ez, nx * ey - ny * ex
		local gl = sqrt(gx * gx + gy * gy + gz * gz)
		gx, gy, gz = gx / gl, gy / gl, gz / gl
		local nv = #poly3 / 3
		local fp: { number } = table.create(2 * nv, 0)
		for i = 0, nv - 1 do
			local dx, dy, dz = poly3[3 * i + 1] - ox, poly3[3 * i + 2] - oy, poly3[3 * i + 3] - oz
			fp[2 * i + 1] = dx * ex + dy * ey + dz * ez
			fp[2 * i + 2] = dx * gx + dy * gy + dz * gz
		end
		tiny = AREA_NIL * fa
		local fs, fu0, fu1, fv0, fv1 = measure(fp)
		pending += UNITS_PER_POLYGON + 2 * UNITS_PER_TEST * nv
		count = 1
		cur[1], curA[1] = fp, fs / 2
		curB[1], curB[2], curB[3], curB[4] = fu0, fu1, fv0, fv1
		local gone = false
		for k = 1, nh do
			local q = hiders[k]
			local Q = q.part
			pending += UNITS_PER_BOX
			if bx0 <= Q.maxx and Q.minx <= bx1 and by0 <= Q.maxy and Q.miny <= by1 and bz0 <= Q.maxz and Q.minz <= bz1 then
				local np, pl, qsag = q.np, q.planes, q.sag
				local coincident = if higher[k] then EPS else -EPS
				-- a facet within q's inner ball (the buried test), or whose probe is, lies wholly in that piece
				local rA, rB = (q.inner + coincident) * INNER_SAFE, (q.inner + EPS) * INNER_SAFE
				if rA > 0 then
					local qx, qy, qz = Q.cx, Q.cy, Q.cz
					local inA, inB = true, true
					for j = 1, 3 * nv, 3 do
						local dx, dy, dz = poly3[j] - qx, poly3[j + 1] - qy, poly3[j + 2] - qz
						if dx * dx + dy * dy + dz * dz > rA * rA then
							inA = false
						end
						dx, dy, dz = dx + probe * nx, dy + probe * ny, dz + probe * nz
						if dx * dx + dy * dy + dz * dz > rB * rB then
							inB = false
						end
					end
					pending += 2 * UNITS_PER_TEST * nv
					if inA or inB then
						gone = true
						break
					end
				end
				-- q's half-spaces in the facet's plane, how far the facet's vertices stand past each, and the pieces' offsets:
				-- buried or coincident on the hider's own (inscribed) half-space, the probe on it moved out to the true solid
				for i = 1, np do
					local px, py, pz, d = pl[4 * i - 3], pl[4 * i - 2], pl[4 * i - 1], pl[4 * i]
					local a, b = px * ex + py * ey + pz * ez, px * gx + py * gy + pz * gz
					local base = d + qsag[i] - (px * ox + py * oy + pz * oz)
					la[i], lb[i], lbase[i] = a, b, base
					local hi, lo = -math.huge, math.huge
					for j = 1, 2 * nv, 2 do
						local s = a * fp[j] + b * fp[j + 1] - base
						if s > hi then
							hi = s
						end
						if s < lo then
							lo = s
						end
					end
					shi[i], slo[i] = hi, lo
					cA[i] = coincident - qsag[i]
					cB[i] = EPS - probe * (px * nx + py * ny + pz * nz)
				end
				pending += UNITS_PER_TEST * np * (1 + nv)
				local A, nA, wholeA = piece(fp, np, cA, actA)
				local B, nB, wholeB = nil, 0, false
				if not wholeA then
					B, nB, wholeB = piece(fp, np, cB, actB)
				end
				if wholeA or wholeB then
					gone = true
				else
					-- a piece inside the other adds nothing to the union
					if A ~= nil and B ~= nil then
						if within(B, cA, actA, nA) then
							B = nil
						elseif within(A, cB, actB, nB) then
							A = nil
						end
					end
					if A ~= nil then
						gone = less(A, cA, actA, nA)
					end
					if not over and not gone and B ~= nil then
						gone = less(B, cB, actB, nB)
					end
				end
				if not over and pending >= SPEND_EVERY then
					settle()
				end
				if over then
					return shown, done, true
				end
				if gone then
					break
				end
			end
		end
		if not gone then
			local s = 0
			for u = 1, count do
				s += curA[u]
			end
			shown += s
			pending += UNITS_PER_BOX * count
			if shown >= need then
				break
			end
		end
		if pending >= SPEND_EVERY then
			settle()
			if over then
				return shown, done, true
			end
		end
	end
	settle()
	return shown, done, over
end

return table.freeze(Cover)
