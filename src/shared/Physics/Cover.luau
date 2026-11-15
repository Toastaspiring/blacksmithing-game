--!strict
-- Physics/Cover (SPEC §4.1, §4.4, §4.9; owner S2): the Enclosed verdict's reading, exact on a polyhedral model of each
-- part. Pure; §4.1's determinism rules apply: + − × ÷ and sqrt, abs, min, max only, numeric loops, no sort, no
-- module-level state.
--
--   model   a part's polyhedron in world space: its facets (convex polygons, counter-clockwise seen from outside, unit
--           outward normals, areas, boxes, how far their probes spread, a round facet's hull of its true patch), its
--           half-spaces n·x ≤ d with their sag, its inner ball, how far its probes reach and its probe's half-spaces
--           stand past its box (for choosing hiders), and the work of building it
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
--   buried or coincident  n_i·x ≤ d_i + c_i + EPS_GEOM for all i if q ranks higher, else n_i·x < d_i + c_i − EPS_GEOM
--   probe                 n_i·(x + (HIDE_OFFSET + sag_f)·n) ≤ d_i + sag_i + spread_f + EPS_GEOM for all i
-- with c_i = sag_i for a polyhedron's facet and 0 for a round model's (its caps' too). Each is a convex piece of f: f
-- clipped by q's half-spaces moved in f's plane. An inscribed facet lies inside the true surface by its sag (the true
-- solid's support along its normal less its own offset: the sagitta on a round model's facets, 0 on a polyhedron and a
-- cap), so a round part's facets probe that much further, and a round hider's half-spaces move out to the true surface
-- for the probe, and for a polyhedron's buried piece: a face against a round hider's true surface lies between its
-- inscribed facets and the true surface, buried, where the inscribed half-spaces leave it showing. Against a Ball a
-- flat facet (a polyhedron's or a cap: Model.flat) reads the true sphere instead (its moved half-spaces stand up to
-- 0.0452 r past it): each piece is f within the 32-gon round the circle that f's plane, the probe's moved HIDE_OFFSET
-- along n, cuts from the sphere, R grown by EPS_GEOM if q ranks higher, else shrunk (the probe's grown), about the foot
-- of its centre, on the 32 directions in a frame n and the world fix (`across`), 32 lines charged as half-spaces; no
-- piece where the plane misses the sphere. The 32-gon holds the circle, so the inner ball's too, and stands at most
-- R·(sec(π/32) − 1) = 0.0048 R past the sphere (through its centre; far less near its surface), within OVER_BALL. The
-- price, both ways the band errs (§17.1 O9): a flat face that stands out of a round hider's true surface by less than
-- its model stands past it there is buried, where the truth shows it (anywhere on a Cylinder's side, its prism up to
-- 0.0048 r past it at its 32-gon's corners, y²/2r at y from a side's middle, so a thin plate lying on the side can be
-- cleaned showing nearly half its surface; on a Ball near a corner of the 32-gon a face's plane cuts, up to 0.0048 R
-- past the sphere). A round facet's buried piece keeps the inscribed half-spaces, so that a round copy coinciding with
-- q, or a round part round it, still counts its faces once; against a round hider the true solids decide instead: a
-- round part whose true solid lies in q's, as the buried or coincident piece asks (its farthest point within EPS_GEOM
-- of q's surface if q ranks higher, else deeper than EPS_GEOM; exact at any tilt: `lies`), shows nothing, and a round
-- facet whose hull (its vertices, each also pushed out onto the plane parallel to it that the true solid touches; a
-- cap's onto its circumscribed 32-gon) so lies in q's is hidden whole. The probe is conservative but for a hider that
-- ends within a facet's sag past the true probe (a Wedge's thin edge). A round facet probes along its normal, but the
-- true points of its patch along their own (a Ball's radii, a Cylinder side's radii from its axis), so their probes
-- land up to its spread beside it: HIDE_OFFSET × the sine of the largest angle between the facet's normal and the true
-- normals at its vertices (0 on a polyhedron and a cap), by which its probe piece grows. Without them a round filler
-- sealed by flat walls a gap just under HIDE_OFFSET away, or caged by walls beside its facets, truly hidden, reads as
-- showing.
--
-- Subtraction. What a facet shows is a list of disjoint convex polygons in its plane (2D coordinates along its first
-- edge and n × that), at first the facet itself. Each piece C, hiders in rank order, the buried piece before the
-- probe's, replaces every polygon U whose box meets C's by U − C: for each of C's lines in turn (the half-spaces that
-- cut the facet), the part of U outside it is a new polygon, and U keeps the part inside; what is left at the end lies
-- in C and is dropped. Every area is a polygon's own, so rounding stays local: no edge has to meet another's. Shortcuts
-- that change no area beyond rounding: a hider whose box, grown by its `over`, misses the facet's box grown by the
-- facet's probe and spread makes no piece; a facet within q's inner ball, or whose probe is, lies wholly in that piece;
-- a piece that is all of the facet leaves nothing at once; a line no vertex of the facet crosses is skipped; a piece
-- inside its sibling adds nothing; a polygon that a line of C or one of its own edges separates from C is kept whole.
-- So Sampling hands over every part whose box comes within the part's `reach` + the hider's `over` + 2·EPS_GEOM: no
-- piece of the hide test is left out, however far a round part's facets probe, but for the slivers the spread adds
-- round a hider's corners and edges (its half-spaces, grown by the spread, stand up to √3 × the spread past its box at
-- a Block's corner), which neither box test asks for.
--
-- Work. One unit is about one shape query's time (§4.9): a vertex against a line (a half-space's or a circle's line's
-- projection counts as one), a point of a hull or a round part against a round hider's true solid UNITS_PER_TEST, a box
-- against a box UNITS_PER_BOX (a hider against a facet, a shown polygon against a piece, a polygon summed), a polygon
-- made UNITS_PER_POLYGON on top of its vertices, a model facet built UNITS_PER_FACET on top of its vertices, a cap
-- circle's farthest point from a Cylinder hider's axis searched UNITS_PER_RIM (its 60 halvings take about 28 units' time,
-- so a round part's own test searches only where two bounds leave it open). The weights are dyadic, so a sum comes out
-- the same in any order, and a part's work depends only on the part and its hiders. They are the cap's units as well as
-- the checkpoints': the reading stops at the first report past `budget` and reports nothing after it, and Sampling makes
-- the design TooComplex (VERDICT_WORK_MAX). The cap never changes a verdict, but where it falls moves with a weight, so
-- the weights are part of the outcome and move with BALANCE_VERSION. Reported through `spend` once SPEND_EVERY units have
-- built up, at the next facet built, half-space projected, line clipped or split, line or edge tested, polygon, piece or
-- hider, never inside a comparator. A test that ends early charges what it skipped with its last step, so that the units
-- do not depend on which line decides: that charge is the one report much past SPEND_EVERY.
--
-- Numeric guards, not tunables: a polygon under AREA_NIL of its facet is rounding and is dropped (a split along a line
-- that grazes a vertex leaves one); the inner-ball shortcut takes INNER_SAFE of the radius, so that rounding cannot put a
-- vertex on the far side of a half-space it tested inside; components of a normal within AXIS_TIE tie for the circle's
-- frame, so that its last bits (another writing of the solid, its image) cannot pick the axis (two 45° snaps tie two),
-- but for components AXIS_TIE apart to within rounding, where they still do (any rule for the frame has such a tie).

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
local AXIS_TIE = 1e-9 -- numeric guard, not a tunable: a unit normal's components this close tie for the circle's frame
-- Numeric bounds, not tunables, × r: how far a round model's half-spaces moved out by their sag (the probe's) stand past
-- the part's box. A Ball's at COVER_BALL_GRID 4: 0.0260 r, where the 4 facets round an axis meet; a Cylinder's sec(π/32)
-- − 1 = 0.0048 r. Cover.spec (e) measures them on the models.
local OVER_BALL, OVER_CYLINDER = 0.03, 0.005

local UNITS_PER_TEST = 0.5 -- a vertex against a line; a half-space's projection counts as one
local UNITS_PER_BOX = 0.125 -- a box against a box
local UNITS_PER_POLYGON = 1 -- a polygon made, on top of its vertices
local UNITS_PER_FACET = 8 -- a model facet built, with its half-space, sag and spread, on top of its vertices
local UNITS_PER_RIM = 28 -- a cap circle's farthest point from a Cylinder's axis searched: its 60 halvings
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
	spread: { number }, -- per facet: how far beside its probe its patch's true probes land (0 on a polyhedron and a cap)
	flat: { boolean }, -- per facet: its true surface is its plane (a polyhedron's face, a cap): it reads a Ball's sphere
	hull: { { number } }, -- per facet of a round model: points whose hull holds the facet's true patch (flat x, y, z)
	total: number, -- the model's area: Σ facet areas, in facet order
	np: number, -- half-spaces
	planes: { number }, -- 4 per half-space: nx, ny, nz, d with n·x ≤ d, unit n
	sag: { number }, -- per half-space: how far the true solid reaches past it (0 on a polyhedron and a cap)
	inner: number, -- the largest ball about the part's centre inside every half-space (0 when the centre is on one)
	reach: number, -- the longest probe of its facets past its box: HIDE_OFFSET, + the largest sag and spread on a round model
	over: number, -- how far its half-spaces moved out by their sag can stand past its box, at most (0 on a polyhedron)
	work: number, -- units: building it
}

local function noSpend(_: number) end

-- The frame of the 32-gon round a circle in a plane of unit normal n: u the world axis most across n (Y, then X, then Z
-- on a tie, components within AXIS_TIE tying, so that n's last bits cannot pick it), made square to n; v = n × u. Only
-- n and the world fix it, so every writing of a solid has its polygon, and the image across X or Z the image of it (the
-- 32 directions keep their set under either reflection of the frame).
local function across(nx: number, ny: number, nz: number): (number, number, number, number, number, number)
	local ax, ay, az = abs(nx), abs(ny), abs(nz)
	local ex, ey, ez = 0, 0, 0
	if ay <= ax + AXIS_TIE and ay <= az + AXIS_TIE then
		ey = 1
	elseif ax <= az + AXIS_TIE then
		ex = 1
	else
		ez = 1
	end
	local d = ex * nx + ey * ny + ez * nz
	local ux, uy, uz = ex - d * nx, ey - d * ny, ez - d * nz
	local l = sqrt(ux * ux + uy * uy + uz * uz)
	ux, uy, uz = ux / l, uy / l, uz / l
	return ux, uy, uz, ny * uz - nz * uy, nz * ux - nx * uz, nx * uy - ny * ux
end

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
	m.spread[f] = 0
	m.flat[f] = true
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

-- The model of P; its work is reported through `spend` as it is built, once SPEND_EVERY units have built up, and in all.
function Cover.model(P: Prepared, spend: Spend?): Model
	local work = spend or noSpend
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
		spread = {},
		flat = {},
		hull = {},
		total = 0,
		np = 0,
		planes = {},
		sag = {},
		inner = 0,
		reach = DELTA,
		over = 0,
		work = 0,
	}
	local reported = 0
	-- reports the work since the last report once SPEND_EVERY units have built up, or, at the end, whatever is left
	local function report(all: boolean)
		local pending = m.work - reported
		if pending >= SPEND_EVERY or (all and pending > 0) then
			work(pending)
			reported = m.work
		end
	end
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
			report(false)
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
		m.over = OVER_CYLINDER * r
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
					report(false)
				end
			end
		end
		m.round = true
		m.over = OVER_BALL * r
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
	-- rounding leaves at 1e-16 on a cap), 0 on a polyhedron and a cap; a facet's probe reaches HIDE_OFFSET + its sag. On a
	-- round model half-space i is facet i, and a facet's spread is HIDE_OFFSET × the sine of the largest angle between its
	-- normal and the true normals at its vertices: a Ball's radii, a Cylinder side's radii from its axis (facets 1…32; a
	-- cap's true normal is its own). A round facet's hull: its vertices, and each pushed out by r over the facet's own
	-- offset (a cap's: the sides' apothem) from the centre (a Ball), the axis (a Cylinder's side) or the cap's centre,
	-- onto the plane parallel to the facet that the true solid touches (on a cap, the circumscribed 32-gon): their hull
	-- holds the true patch
	local pl = m.planes
	local apothem = if code == CYLINDER then pl[4] - (pl[1] * P.cx + pl[2] * P.cy + pl[3] * P.cz) else 0
	local inner = math.huge
	local reach = DELTA
	for i = 1, m.np do
		local nx, ny, nz = pl[4 * i - 3], pl[4 * i - 2], pl[4 * i - 1]
		local own = pl[4 * i] - (nx * P.cx + ny * P.cy + nz * P.cz)
		local sag, spread = 0, 0
		if code == BALL then
			sag = max(0, P.r - own)
		elseif code == CYLINDER then
			local a = nx * P.ux + ny * P.uy + nz * P.uz
			local px, py, pz = nx - a * P.ux, ny - a * P.uy, nz - a * P.uz
			sag = max(0, P.hx * abs(a) + P.r * sqrt(px * px + py * py + pz * pz) - own)
		end
		if code == BALL or (code == CYLINDER and i <= 32) then
			local poly = m.poly[i]
			for j = 1, #poly, 3 do
				local rx, ry, rz = poly[j] - P.cx, poly[j + 1] - P.cy, poly[j + 2] - P.cz
				if code == CYLINDER then
					local t = rx * P.ux + ry * P.uy + rz * P.uz
					rx, ry, rz = rx - t * P.ux, ry - t * P.uy, rz - t * P.uz
				end
				local c = (rx * nx + ry * ny + rz * nz) / sqrt(rx * rx + ry * ry + rz * rz)
				spread = max(spread, DELTA * sqrt(max(0, 1 - c * c)))
			end
			m.spread[i] = spread
			m.flat[i] = false
		end
		if m.round then
			local poly = m.poly[i]
			local scale = P.r / (if code == CYLINDER and i > 32 then apothem else own)
			local hull: { number } = table.create(2 * #poly, 0)
			for j = 1, #poly, 3 do
				local x, y, z = poly[j], poly[j + 1], poly[j + 2]
				local ox, oy, oz = P.cx, P.cy, P.cz
				if code == CYLINDER then
					local t = (x - P.cx) * P.ux + (y - P.cy) * P.uy + (z - P.cz) * P.uz
					ox, oy, oz = P.cx + t * P.ux, P.cy + t * P.uy, P.cz + t * P.uz
				end
				hull[2 * j - 1], hull[2 * j], hull[2 * j + 1] = x, y, z
				hull[2 * j + 2], hull[2 * j + 3], hull[2 * j + 4] =
					ox + (x - ox) * scale, oy + (y - oy) * scale, oz + (z - oz) * scale
			end
			m.hull[i] = hull
		end
		m.sag[i] = sag
		inner = min(inner, own)
		reach = max(reach, DELTA + sag + spread)
	end
	m.inner = max(0, inner)
	m.reach = reach
	report(true)
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

-- Is s, the largest signed distance of a part's true solid from a hider's, buried or coincident as the hide test asks:
-- within EPS_GEOM if the hider ranks higher, else deeper than EPS_GEOM?
local function held(s: number, higher: boolean): boolean
	return if higher then s <= EPS else s < -EPS
end

-- How far from the axis u of a Cylinder a circle of radius r stands at most: its centre m off the axis (across it,
-- taken by its parts), its plane square to unit n. In a frame (a, e) of the plane with a = n × u made a unit (square to
-- the axis) and e = n × a, its point (c, s) = (cos φ, sin φ) stands D off the axis, with
--   D² = K + A·c + B·s − C·s²,  K = |m|² + r², A = 2r·m·a, B = 2r·m·e, C = r²·(e·u)² ≥ 0;
-- for each s the best c has A's sign, so D² at most is the largest over s in [−1, 1] of K + |A|·sqrt(1 − s²) + B·s −
-- C·s², a concave function: the sign of its derivative, that of (B − 2C·s)·sqrt(1 − s²) − |A|·s, turns from + to −
-- once, and 60 halvings find it, to rounding (V1's search). Axes within 1e-8 of parallel, where n × u is a few bits of
-- rounding: |m| + r, the circle all but square to the axis, r·(1 − cos) ≤ 5e-17·r above it.
local function rimFarthest(mx: number, my: number, mz: number, r: number, nx: number, ny: number, nz: number, ux: number,
	uy: number, uz: number): number
	local ax, ay, az = ny * uz - nz * uy, nz * ux - nx * uz, nx * uy - ny * ux
	local al = sqrt(ax * ax + ay * ay + az * az)
	if al <= 1e-8 then
		return sqrt(mx * mx + my * my + mz * mz) + r
	end
	ax, ay, az = ax / al, ay / al, az / al
	local ex, ey, ez = ny * az - nz * ay, nz * ax - nx * az, nx * ay - ny * ax
	local eu = ex * ux + ey * uy + ez * uz
	local K = mx * mx + my * my + mz * mz + r * r
	local A = 2 * r * abs(mx * ax + my * ay + mz * az)
	local B = 2 * r * (mx * ex + my * ey + mz * ez)
	local C = r * r * eu * eu
	local lo, hi = -1, 1
	for _ = 1, 60 do
		local s = (lo + hi) / 2
		if (B - 2 * C * s) * sqrt(max(0, 1 - s * s)) - A * s > 0 then
			lo = s
		else
			hi = s
		end
	end
	local s = (lo + hi) / 2
	return sqrt(max(0, K + A * sqrt(max(0, 1 - s * s)) + B * s - C * s * s))
end

-- Cap circle s (−1, +1) of Cylinder P against Cylinder Q's side: its centre's offset m across Q's axis, taken by its
-- parts, and whether its farthest point from the axis, D, is held (1), not (−1) or open (0) by two bounds. A point of
-- the circle r·w off its centre (w a unit of the cap's plane) stands |m + r·w⊥| off the axis, D² = |m|² + 2r·p·w +
-- r²·|w⊥|², p the offset in the cap's plane (on P's local Y and Z), so D ≤ sqrt(|m|² + 2r·|p| + r²), and D is at least
-- that of the circle's point toward p. They differ by r²·(p's direction along the axis)² in D², and agree when the axes
-- are parallel or the circle's plane holds Q's axis (a puck across a disk, tangent to its rim).
local function capBounds(P: Prepared, Q: Prepared, s: number, higher: boolean): (number, number, number, number)
	local ux, uy, uz = Q.ux, Q.uy, Q.uz
	local mx, my, mz = P.cx + s * P.hx * P.ux - Q.cx, P.cy + s * P.hx * P.uy - Q.cy, P.cz + s * P.hx * P.uz - Q.cz
	local t = mx * ux + my * uy + mz * uz
	mx, my, mz = mx - t * ux, my - t * uy, mz - t * uz
	local r = P.r
	local pv, pw = mx * P.vx + my * P.vy + mz * P.vz, mx * P.wx + my * P.wy + mz * P.wz
	local pl = sqrt(pv * pv + pw * pw)
	if held(sqrt(mx * mx + my * my + mz * mz + 2 * r * pl + r * r) - Q.r, higher) then
		return mx, my, mz, 1
	end
	local c, sn = 1, 0
	if pl > 0 then
		c, sn = pv / pl, pw / pl
	end
	local wx, wy, wz = c * P.vx + sn * P.wx, c * P.vy + sn * P.wy, c * P.vz + sn * P.wz
	local wu = wx * ux + wy * uy + wz * uz
	local qx, qy, qz = mx + r * (wx - wu * ux), my + r * (wy - wu * uy), mz + r * (wz - wu * uz)
	return mx, my, mz, if held(sqrt(qx * qx + qy * qy + qz * qz) - Q.r, higher) then 0 else -1
end

-- Does round P's true solid lie in round Q's, as the buried or coincident piece asks (held: its largest signed distance
-- from Q's true solid, Shapes.sd)? With its units. Exact for a Ball (its centre's, + r) and for a Cylinder in a Ball
-- (its cap circles' farthest point). A Cylinder in a Cylinder: along Q's axis P's support, and across it each cap
-- circle's farthest point from the axis, which capBounds holds or not from its bounds, and rimFarthest searches only
-- where they leave it open, UNITS_PER_RIM a cap circle; so the answer is the exact one, to rounding, at any tilt. A
-- test charges UNITS_PER_TEST, and, unless a cap's bounds put it out, the search of every open cap whichever decides,
-- so that the order of the caps (a writing's) moves no unit.
local function lies(P: Prepared, Q: Prepared, higher: boolean): (boolean, number)
	if P.code == BALL then
		return held(Shapes.sd(Q, P.cx, P.cy, P.cz) + P.r, higher), UNITS_PER_TEST
	elseif Q.code == BALL then
		-- the farthest point of either cap circle: across the axis by the cap centre's offset from Q's centre, taken by its
		-- parts (not sqrt(|d|² − a²), which on the axis line leaves the square root of rounding, about 1e-9)
		local best = 0
		for s = -1, 1, 2 do
			local dx, dy, dz = P.cx + s * P.hx * P.ux - Q.cx, P.cy + s * P.hx * P.uy - Q.cy, P.cz + s * P.hx * P.uz - Q.cz
			local a = dx * P.ux + dy * P.uy + dz * P.uz
			local px, py, pz = dx - a * P.ux, dy - a * P.uy, dz - a * P.uz
			local perp = sqrt(px * px + py * py + pz * pz) + P.r
			best = max(best, a * a + perp * perp)
		end
		return held(sqrt(best) - Q.r, higher), UNITS_PER_TEST
	end
	local ux, uy, uz = Q.ux, Q.uy, Q.uz
	local dx, dy, dz = P.cx - Q.cx, P.cy - Q.cy, P.cz - Q.cz
	local sx, sy, sz = P.uy * uz - P.uz * uy, P.uz * ux - P.ux * uz, P.ux * uy - P.uy * ux
	local along = abs(dx * ux + dy * uy + dz * uz) + P.hx * abs(P.ux * ux + P.uy * uy + P.uz * uz)
		+ P.r * sqrt(sx * sx + sy * sy + sz * sz) - Q.hx
	if not held(along, higher) then
		return false, UNITS_PER_TEST
	end
	local ax, ay, az, a = capBounds(P, Q, -1, higher)
	if a < 0 then
		return false, UNITS_PER_TEST
	end
	local bx, by, bz, b = capBounds(P, Q, 1, higher)
	if b < 0 then
		return false, UNITS_PER_TEST
	end
	local units = UNITS_PER_TEST + (if a == 0 then UNITS_PER_RIM else 0) + (if b == 0 then UNITS_PER_RIM else 0)
	if a == 0 and not held(rimFarthest(ax, ay, az, P.r, P.ux, P.uy, P.uz, ux, uy, uz) - Q.r, higher) then
		return false, units
	end
	return b ~= 0 or held(rimFarthest(bx, by, bz, P.r, P.ux, P.uy, P.uz, ux, uy, uz) - Q.r, higher), units
end

-- What shows of model pm against its hiders, the candidate models in rank order (none of them pm, an exact copy or Dust),
-- higher[k] whether hiders[k] ranks above pm's part: Σ over the facets in order, returned once it reaches `need`. Also the
-- work done, in units, and whether it passed `budget`: then the reading stopped at the report that passed it, reporting
-- nothing after it, and the area is no answer.
function Cover.shown(pm: Model, hiders: { Model }, higher: { boolean }, need: number, budget: number,
	spend: Spend?): (number, number, boolean)
	local work = spend or noSpend
	local nh = #hiders
	if nh == 0 then
		return pm.total, 0, budget < 0
	elseif budget < 0 then -- the work before it has passed the budget: nothing more is done or reported
		return 0, 0, true
	end
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

	-- Reports once SPEND_EVERY units have built up; whether the work has passed the budget.
	local function due(): boolean
		if pending >= SPEND_EVERY then
			settle()
		end
		return over
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
			if pending >= SPEND_EVERY then -- a piece cut by many lines (a cap by a Ball's) reports as it goes
				settle()
				if over then
					return nil, 0, false
				end
			end
		end
		return C, nact, false
	end

	-- Does every vertex of polygon P satisfy the nact lines in act with offsets c? Charged a line at a time, reporting
	-- between lines; a line that fails charges the lines left too, so the units are the same whichever decides.
	local function within(P: { number }, c: { number }, act: { number }, nact: number): boolean
		local each = UNITS_PER_TEST * #P / 2
		for j = 1, nact do
			pending += each
			local i = act[j]
			local a, b, d = la[i], lb[i], c[i] + lbase[i]
			for k = 1, #P, 2 do
				if a * P[k] + b * P[k + 1] > d then
					pending += each * (nact - j)
					return false
				end
			end
			if pending >= SPEND_EVERY then
				settle()
				if over then
					return false
				end
			end
		end
		return true
	end

	-- Are convex polygons U and C (both counter-clockwise) disjoint? A separating edge of either decides (C's lines are
	-- its cutting lines; U's are its own edges). Charged a line or an edge at a time, reporting between them; one that
	-- separates charges those left too, so the units are the same whichever decides.
	local function apart(U: { number }, C: { number }, c: { number }, act: { number }, nact: number): boolean
		local n = #U
		local perLine, perEdge = UNITS_PER_TEST * n / 2, UNITS_PER_TEST * #C / 2
		local left = nact * perLine + (n / 2) * perEdge
		for j = 1, nact do
			pending += perLine
			left -= perLine
			local i = act[j]
			local a, b, d = la[i], lb[i], c[i] + lbase[i]
			local out = true
			for k = 1, n, 2 do
				if a * U[k] + b * U[k + 1] <= d then
					out = false
					break
				end
			end
			if out then
				pending += left
				return true
			end
			if pending >= SPEND_EVERY then
				settle()
				if over then
					return true
				end
			end
		end
		local pu, pv = U[n - 1], U[n]
		for k = 1, n, 2 do
			pending += perEdge
			left -= perEdge
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
				pending += left
				return true
			end
			if pending >= SPEND_EVERY then
				settle()
				if over then
					return true
				end
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
			local meets = uu0 <= cu1 and cu0 <= uu1 and uv0 <= cv1 and cv0 <= uv1 and not apart(U, C, c, act, nact)
			if over then
				return
			end
			if meets then
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
					if pending >= SPEND_EVERY then -- a polygon split by many lines reports as it goes
						settle()
						if over then
							return
						end
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
				if pending >= SPEND_EVERY then -- a run of polygons kept whole reports too
					settle()
					if over then
						return
					end
				end
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

	-- a round part whose true solid lies in a round hider's, as the buried or coincident piece asks (its farthest point
	-- within EPS_GEOM of the hider's surface if the hider ranks higher, else deeper than EPS_GEOM), shows nothing: its
	-- model's facets, inscribed in both, cannot see that where it lies in the sagitta of the hider's facets
	if pm.round then
		for k = 1, nh do
			local q = hiders[k]
			if q.round then
				local inside, units = lies(pm.part, q.part, higher[k])
				pending += units
				if inside then
					settle()
					return 0, done, over
				end
				if due() then -- a run of rims searched reports too
					return 0, done, true
				end
			end
		end
	end
	for f = 1, pm.n do
		local fa = pm.area[f]
		local poly3 = pm.poly[f]
		local nx, ny, nz = pm.nx[f], pm.ny[f], pm.nz[f]
		local probe = DELTA + (if pm.round then pm.sag[f] else 0)
		local spread = pm.spread[f]
		local flat = pm.flat[f]
		-- the facet's box grown by its probe and spread: a hider whose box, grown by its `over`, misses it makes no piece
		local fb, margin = 6 * (f - 1), probe + spread + 2 * EPS
		local bx0, by0, bz0 = pm.box[fb + 1] - margin, pm.box[fb + 2] - margin, pm.box[fb + 3] - margin
		local bx1, by1, bz1 = pm.box[fb + 4] + margin, pm.box[fb + 5] + margin, pm.box[fb + 6] + margin
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
			local Q, o = q.part, q.over
			pending += UNITS_PER_BOX
			if bx0 <= Q.maxx + o and Q.minx - o <= bx1 and by0 <= Q.maxy + o and Q.miny - o <= by1 and bz0 <= Q.maxz + o
				and Q.minz - o <= bz1
			then
				local np, pl, qsag = q.np, q.planes, q.sag
				local coincident = if higher[k] then EPS else -EPS
				-- a round facet whose true patch lies in q's true solid as the buried or coincident piece asks (every point of its
				-- hull within EPS_GEOM of it if q ranks higher, else deeper than EPS_GEOM) is hidden whole: q's inscribed
				-- half-spaces leave it out where it lies past them, in the sagitta of q's facets
				if pm.round and q.round then
					local hull = pm.hull[f]
					local inside = true
					for j = 1, #hull, 3 do
						local s = Shapes.sd(Q, hull[j], hull[j + 1], hull[j + 2])
						if (if higher[k] then s > EPS else s >= -EPS) then
							inside = false
							break
						end
					end
					pending += UNITS_PER_TEST * #hull / 3
					if inside then
						gone = true
						break
					end
				end
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
				-- q's lines in the facet's plane, how far the facet's vertices stand past each, and the pieces' offsets. A flat
				-- facet against a Ball reads its true sphere: each piece is the facet within the 32-gon round the circle that the
				-- facet's plane (the probe's: moved its probe along n) cuts from the sphere, about the foot of its centre, on the
				-- 32 directions in the frame n and the world fix; the buried piece's sphere grown by EPS_GEOM if q ranks higher,
				-- else shrunk, the probe's grown; no piece where the plane misses it. Otherwise q's half-spaces: the probe on the
				-- hider's half-space moved out to its true solid and grown by the facet's spread; buried or coincident on it moved
				-- out too for a polyhedron's facet (a Cylinder's prism), on the hider's own (inscribed) one for a round model's
				-- facet, a cap's against a Cylinder too, so that a round copy coinciding with q, or a round part round it, keeps
				-- its faces
				local circle = flat and Q.code == BALL
				local lines = if circle then 32 else np
				local ue, ug, ve, vg, cu, cv, rhoA, rhoB = 0, 0, 0, 0, 0, 0, 0, 0
				if circle then
					local ux, uy, uz, vx, vy, vz = across(nx, ny, nz)
					ue, ug = ux * ex + uy * ey + uz * ez, ux * gx + uy * gy + uz * gz
					ve, vg = vx * ex + vy * ey + vz * ez, vx * gx + vy * gy + vz * gz
					local dx, dy, dz = Q.cx - ox, Q.cy - oy, Q.cz - oz
					cu, cv = dx * ex + dy * ey + dz * ez, dx * gx + dy * gy + dz * gz
					local h = dx * nx + dy * ny + dz * nz -- the centre's height over the plane: the probe's plane is probe − h off it
					local RA, RB = Q.r + coincident, Q.r + EPS
					rhoA = if h * h < RA * RA then sqrt(RA * RA - h * h) else -math.huge
					rhoB = if (probe - h) * (probe - h) < RB * RB then sqrt(RB * RB - (probe - h) * (probe - h)) else -math.huge
				end
				for i = 1, lines do
					local a, b, base
					if circle then
						a, b = COS[i] * ue + SIN[i] * ve, COS[i] * ug + SIN[i] * vg
						base = a * cu + b * cv
						cA[i], cB[i] = rhoA, rhoB
					else
						local px, py, pz, d = pl[4 * i - 3], pl[4 * i - 2], pl[4 * i - 1], pl[4 * i]
						a, b = px * ex + py * ey + pz * ez, px * gx + py * gy + pz * gz
						base = d + qsag[i] - (px * ox + py * oy + pz * oz)
						cA[i] = coincident - (if pm.round then qsag[i] else 0)
						cB[i] = EPS + spread - probe * (px * nx + py * ny + pz * nz)
					end
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
					pending += UNITS_PER_TEST * (1 + nv)
					if due() then
						return shown, done, true
					end
				end
				local A, nA, wholeA = piece(fp, lines, cA, actA)
				local B, nB, wholeB = nil, 0, false
				if not wholeA then
					if due() then
						return shown, done, true
					end
					B, nB, wholeB = piece(fp, lines, cB, actB)
				end
				if due() then
					return shown, done, true
				end
				if wholeA or wholeB then
					gone = true
				else
					-- a piece inside the other adds nothing to the union
					if A ~= nil and B ~= nil then
						if within(B, cA, actA, nA) then
							B = nil
						elseif not over and within(A, cB, actB, nB) then
							A = nil
						end
						if due() then
							return shown, done, true
						end
					end
					if A ~= nil then
						gone = less(A, cA, actA, nA)
					end
					if not over and not gone and B ~= nil then
						gone = less(B, cB, actB, nB)
					end
				end
				if due() then
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
