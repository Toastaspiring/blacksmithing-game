--!strict
-- Physics/Cover (SPEC §4.1, §4.4; owner S2): the Enclosed verdict's reading, exact on a polyhedral model of every part.
-- Pure; §4.1's determinism rules apply: + − × ÷ and sqrt, abs, numeric loops, no sort, no module-level state.
--
--   context  the scratch arrays one exposure call shares between its parts, and the model's circle and ball grid
--   model    a part's polyhedral model: its facets (world polygons, counter-clockwise seen from outside, each with its
--            outward unit normal, a frame in its own plane and its area) and the same polyhedron's half-spaces n·x ≤ d
--   shown    the area of a part's model that shows past hiders given in rank order, stopping once it reaches `need`
--
-- The model. Block, Wedge and CornerWedge exactly (Shapes.faces, Shapes.planes). A Cylinder (axis = local X,
-- r = min(hy, hz)) is the prism over the inscribed polygon of the context's circle (Sampling's COS/SIN, 32 directions:
-- vertex k at (±hx, r·COS[k], r·SIN[k])): the side rectangles k = 1…32, then the +X cap, then the −X cap. A Ball
-- (r = min(hx, hy, hz)) is the octahedron with each face split by a triangular grid of the context's ballGrid (4: grid
-- point (i·A + j·B + k·C)/4, i + j + k = 4), every vertex pushed out to radius r: 8·16 = 128 triangles, octant by octant
-- (x, then y, then z sign, + before −), row by row from the X corner. Both lie inside the solid, by the sagitta:
-- r·(1 − cos π/32) ≈ 0.0048·r on a Cylinder, up to 0.057·r on a Ball. A Cylinder or a Ball hides as that polyhedron, one
-- half-space per facet.
--
-- The reading. A point s of facet f (outward unit normal n) is hidden by a hider q iff it is buried in q or on q's
-- surface when q ranks higher (n_q·s ≤ d_q + EPS_GEOM for every plane of q if q ranks higher, else n_q·s < d_q − EPS_GEOM:
-- a coincident face counts once), or its probe s + HIDE_OFFSET·n is in q (n_q·s ≤ d_q + EPS_GEOM − HIDE_OFFSET·n_q·n for
-- every plane). Each of the two is f clipped by q's half-spaces, moved: a convex polygon in f's plane, a piece. What shows
-- of f is its area less the area of the union of the pieces of every hider whose box comes within HIDE_OFFSET +
-- 2·EPS_GEOM of f's box; a piece that is all of f leaves nothing at once. The union's area is Green's theorem:
-- ½ Σ (x dy − y dx) over the union's boundary, which is made of the parts of the pieces' edges that lie outside every
-- other piece. A convex piece holds one interval of an edge, so an edge from a to b kept on intervals of total length
-- L ⊂ [0, 1] adds L·(a × b), in f's frame (origin at the facet's mean vertex). An edge on another piece's edge line,
-- within LINE_TOL and ANGLE_TOL: the same direction, the earlier piece keeps it (hiders in rank order, the buried piece
-- before the probe's); opposite directions, both drop it. That is the union of the pieces each grown by an infinitesimal
-- that shrinks along that order, so the boundary stays closed and the area is what the pieces cover, to the rounding.
-- Hiders come in rank order and facets in the model's order, so no id and no order of the parts can change a bit.
--
-- Shortcuts that change no area: a hider whose box or sphere cannot reach f is not asked; a vertex set inside the
-- sphere that every half-space of q holds hides all of f at once; a plane at least f's radius clear of f's mean vertex
-- on the inside cuts nothing, under minus that radius leaves nothing; a curved hider's planes are asked in runs of
-- BUCKET, and a run whose cone of normals keeps every plane clear of f is passed over; a piece inside another is
-- dropped before the union; an edge inside one other piece is boundary nowhere.
--
-- canonical (an option of the context, off in the baseline): a Cylinder's polygon and a Ball's octahedron take their
-- frame from the world (world Y off the axis, world Z for an axis within about 25° of Y; the world's axes) instead of
-- the part's turn, so a copy spun about its axis, a turned ball, or a coaxial or concentric part has the same or a
-- nested polyhedron, as the solids are: with the part's own frame two coincident curved parts interleave and each
-- shows through the other (§17.2's coincident face counts only when the surfaces are one).
--
-- Work: one unit per spend ≈ one shape query: UNIT_OPS elementary tests (a vertex against a plane, a plane's offset, an
-- edge against a piece's box or edge line) and MODEL_UNITS per facet built. Spent after every hider of a facet and every
-- piece of the union, so a checkpoint falls between them.

local Balance = require("../Definitions/Balance")
local Shapes = require("./Shapes")

type Prepared = Shapes.Prepared

local sqrt, abs = math.sqrt, math.abs

local Geo = Balance.Geometry
local EPS = Geo.EPS_GEOM
local DELTA = Geo.HIDE_OFFSET
local REACH = DELTA + 2 * EPS -- a hider's box farther than this from a facet's box cannot reach it

local ANGLE_TOL = 1e-9 -- numeric guard, not a tunable: two edge lines this close in direction (sine) …
local LINE_TOL = 2e-8 -- numeric guard: … and in offset are one line (well under the 2·EPS_GEOM that moved lines differ by)
local NEAR = 1e-6 -- numeric guard: an edge whose ends lie farther than this from a line is not on it under the tolerances above
local SLIVER = 1e-12 -- numeric guard: a piece under this share of its facet changes no union by more than that
local CONTAIN_TOL = 1e-12 -- numeric guard: a piece within this of the inside of another changes the union by no more
local UNIT_OPS = 4 -- elementary tests per work unit (one shape query, as Analyze counts them)
local BUCKET = 8 -- a curved hider's planes asked as one run first (Cover.model)
local CONE_MARGIN = 1e-9 -- numeric guard: a run skipped only this far clear of the facet
local MODEL_UNITS = 10 -- work units per facet a model builds (frame, area, box)

local BLOCK, WEDGE, CORNER, CYLINDER = Shapes.BLOCK, Shapes.WEDGE, Shapes.CORNER, Shapes.CYLINDER

export type Model = {
	nf: number, -- facets
	first: { number }, -- facet f's vertices are first[f] … first[f + 1] − 1
	px: { number }, -- the vertices in their facet's frame
	py: { number },
	wx: { number }, -- and in the world
	wy: { number },
	wz: { number },
	ox: { number }, -- per facet: the frame's origin (the mean vertex), world
	oy: { number },
	oz: { number },
	ux: { number }, -- the frame's first axis
	uy: { number },
	uz: { number },
	vx: { number }, -- the second, n × u
	vy: { number },
	vz: { number },
	nx: { number }, -- the outward unit normal
	ny: { number },
	nz: { number },
	area: { number },
	rho: { number }, -- per facet: the farthest vertex from the mean
	box: { number }, -- per facet: min x, y, z, max x, y, z
	total: number, -- the model's area
	sx: number, -- a sphere around the whole model: centre, radius
	sy: number,
	sz: number,
	sr: number,
	inr: number, -- the largest radius about the sphere's centre that every half-space holds
	nb: number, -- a curved model's half-spaces in runs of BUCKET (0: none, every plane is asked)
	bx: { number }, -- per run: the unit centre of its normals, the cosine and sine of their spread about it, the least
	by: { number }, -- offset of its planes from the sphere's centre
	bz: { number },
	bcos: { number },
	bsin: { number },
	binr: { number },
	np: number, -- half-spaces, n·x ≤ d, unit n, world
	hx: { number },
	hy: { number },
	hz: { number },
	hd: { number },
}

export type Context = {
	cos: { number }, -- the cylinder's circle, counter-clockwise from +Y toward +Z
	sin: { number },
	ballGrid: number,
	canonical: boolean, -- curved models in world-fixed frames (an option, not the baseline): see Cover.model
	-- scratch
	a: { number }, b: { number }, c0: { number }, dn: { number }, -- a hider's planes in a facet's frame
	stC: { number }, stD: { number }, stA: { number }, tok: number, -- which of them are known for this facet and hider
	s: { number }, -- a polygon's vertices against a line
	x1: { number }, y1: { number }, e1: { number }, -- polygons being clipped, ping-pong; e: each edge's line
	x2: { number }, y2: { number }, e2: { number },
	lx: { number }, ly: { number }, lc: { number }, -- the facet's lines: unit normal, offset (f's edges first)
	qx: { number }, qy: { number }, qe: { number }, -- the pieces' vertices and edge lines, flat
	qf: { number }, -- piece k's vertices are qf[k] … qf[k + 1] − 1
	bx0: { number }, bx1: { number }, by0: { number }, by1: { number }, -- the pieces' boxes
	t0: { number }, t1: { number }, -- an edge's covered intervals
	gone: { boolean }, live: { number }, -- pieces inside another, the pieces left
	gx: { number }, gy: { number }, gc: { number }, -- the live pieces' edge lines, flat like qx
}

local Cover = {}

Cover.ANGLE_TOL, Cover.LINE_TOL, Cover.SLIVER, Cover.UNIT_OPS = ANGLE_TOL, LINE_TOL, SLIVER, UNIT_OPS
Cover.MODEL_UNITS = MODEL_UNITS

-- cos, sin: the circle (Sampling.COS, Sampling.SIN or a finer one); ballGrid: the octahedron's split (4).
function Cover.context(cos: { number }, sin: { number }, ballGrid: number, canonical: boolean?): Context
	return {
		cos = cos,
		sin = sin,
		ballGrid = ballGrid,
		canonical = canonical == true,
		a = {}, b = {}, c0 = {}, dn = {},
		stC = {}, stD = {}, stA = {}, tok = 0,
		s = {},
		x1 = {}, y1 = {}, e1 = {},
		x2 = {}, y2 = {}, e2 = {},
		lx = {}, ly = {}, lc = {},
		qx = {}, qy = {}, qe = {},
		qf = {},
		bx0 = {}, bx1 = {}, by0 = {}, by1 = {},
		t0 = {}, t1 = {},
		gone = {}, live = {},
		gx = {}, gy = {}, gc = {},
	}
end

-- The circle doubled: the directions between each pair, by the half-angle formulas (cos(t/2) = sqrt((1 + cos t)/2)).
function Cover.halve(cos: { number }, sin: { number }): ({ number }, { number })
	local n = #cos
	local ch = sqrt((1 + cos[2]) / 2) -- the half step
	local sh = sqrt((1 - cos[2]) / 2)
	local c2: { number }, s2: { number } = table.create(2 * n, 0), table.create(2 * n, 0)
	for k = 1, n do
		c2[2 * k - 1], s2[2 * k - 1] = cos[k], sin[k]
		c2[2 * k] = cos[k] * ch - sin[k] * sh
		s2[2 * k] = sin[k] * ch + cos[k] * sh
	end
	return c2, s2
end

-- ── the model ─────────────────────────────────────────────────────────────────────────────────────────────────────

local function emptyModel(): Model
	return {
		nf = 0, first = { 1 },
		px = {}, py = {}, wx = {}, wy = {}, wz = {},
		ox = {}, oy = {}, oz = {},
		ux = {}, uy = {}, uz = {},
		vx = {}, vy = {}, vz = {},
		nx = {}, ny = {}, nz = {},
		area = {}, rho = {}, box = {},
		total = 0,
		sx = 0, sy = 0, sz = 0, sr = 0, inr = 0,
		nb = 0, bx = {}, by = {}, bz = {}, bcos = {}, bsin = {}, binr = {},
		np = 0, hx = {}, hy = {}, hz = {}, hd = {},
	}
end

-- A facet from its world vertices xs[1…n] (counter-clockwise seen from outside): Newell's normal, the frame along its
-- longest edge, the vertices in it, the shoelace area, the box.
local function addFacet(m: Model, xs: { number }, ys: { number }, zs: { number }, n: number)
	local cx, cy, cz = 0, 0, 0
	local nx, ny, nz = 0, 0, 0
	local best, bi = -1, 1
	for i = 1, n do
		local j = if i == n then 1 else i + 1
		local ax, ay, az = xs[i], ys[i], zs[i]
		local bx, by, bz = xs[j], ys[j], zs[j]
		cx, cy, cz = cx + ax, cy + ay, cz + az
		nx += (ay - by) * (az + bz)
		ny += (az - bz) * (ax + bx)
		nz += (ax - bx) * (ay + by)
		local dx, dy, dz = bx - ax, by - ay, bz - az
		local l2 = dx * dx + dy * dy + dz * dz
		if l2 > best then
			best, bi = l2, i
		end
	end
	cx, cy, cz = cx / n, cy / n, cz / n
	local ln = sqrt(nx * nx + ny * ny + nz * nz)
	nx, ny, nz = nx / ln, ny / ln, nz / ln
	local bj = if bi == n then 1 else bi + 1
	local ux, uy, uz = xs[bj] - xs[bi], ys[bj] - ys[bi], zs[bj] - zs[bi]
	local along = ux * nx + uy * ny + uz * nz
	ux, uy, uz = ux - along * nx, uy - along * ny, uz - along * nz
	local lu = sqrt(ux * ux + uy * uy + uz * uz)
	ux, uy, uz = ux / lu, uy / lu, uz / lu
	local vx, vy, vz = ny * uz - nz * uy, nz * ux - nx * uz, nx * uy - ny * ux
	local f = m.nf + 1
	m.nf = f
	local k0 = m.first[f]
	local px, py, wx, wy, wz = m.px, m.py, m.wx, m.wy, m.wz
	local x0, y0, z0, x1, y1, z1 = xs[1], ys[1], zs[1], xs[1], ys[1], zs[1]
	local rho2 = 0
	for i = 1, n do
		wx[k0 + i - 1], wy[k0 + i - 1], wz[k0 + i - 1] = xs[i], ys[i], zs[i]
		local dx, dy, dz = xs[i] - cx, ys[i] - cy, zs[i] - cz
		px[k0 + i - 1] = dx * ux + dy * uy + dz * uz
		py[k0 + i - 1] = dx * vx + dy * vy + dz * vz
		local d2 = dx * dx + dy * dy + dz * dz
		if d2 > rho2 then
			rho2 = d2
		end
		local x, y, z = xs[i], ys[i], zs[i]
		if x < x0 then
			x0 = x
		elseif x > x1 then
			x1 = x
		end
		if y < y0 then
			y0 = y
		elseif y > y1 then
			y1 = y
		end
		if z < z0 then
			z0 = z
		elseif z > z1 then
			z1 = z
		end
	end
	local area = 0
	for i = 0, n - 1 do
		local j = if i == n - 1 then 0 else i + 1
		area += px[k0 + i] * py[k0 + j] - py[k0 + i] * px[k0 + j]
	end
	area /= 2
	m.first[f + 1] = k0 + n
	m.ox[f], m.oy[f], m.oz[f] = cx, cy, cz
	m.ux[f], m.uy[f], m.uz[f] = ux, uy, uz
	m.vx[f], m.vy[f], m.vz[f] = vx, vy, vz
	m.nx[f], m.ny[f], m.nz[f] = nx, ny, nz
	m.area[f] = area
	m.rho[f] = sqrt(rho2)
	local b = 6 * (f - 1)
	m.box[b + 1], m.box[b + 2], m.box[b + 3], m.box[b + 4], m.box[b + 5], m.box[b + 6] = x0, y0, z0, x1, y1, z1
	m.total += area
end

-- Every facet's plane as a half-space (a Cylinder's or a Ball's hider): its normal through its mean vertex.
local function facetPlanes(m: Model)
	for f = 1, m.nf do
		m.hx[f], m.hy[f], m.hz[f] = m.nx[f], m.ny[f], m.nz[f]
		m.hd[f] = m.nx[f] * m.ox[f] + m.ny[f] * m.oy[f] + m.nz[f] * m.oz[f]
	end
	m.np = m.nf
end

function Cover.model(ctx: Context, P: Prepared): Model
	local m = emptyModel()
	m.sx, m.sy, m.sz, m.sr = P.cx, P.cy, P.cz, Shapes.maxDist(P, P.cx, P.cy, P.cz)
	local code = P.code
	local xs: { number }, ys: { number }, zs: { number } = {}, {}, {}
	if code == BLOCK or code == WEDGE or code == CORNER then
		local faces = Shapes.faces(P)
		for f = 1, #faces do
			local poly = faces[f]
			local n = #poly / 3
			for i = 1, n do
				xs[i], ys[i], zs[i] = poly[3 * i - 2], poly[3 * i - 1], poly[3 * i]
			end
			addFacet(m, xs, ys, zs, n)
		end
		local planes = Shapes.planes(P)
		for k = 1, #planes do
			local pl = planes[k]
			m.hx[k], m.hy[k], m.hz[k], m.hd[k] = pl[1], pl[2], pl[3], pl[4]
		end
		m.np = #planes
	elseif code == CYLINDER then
		local cos, sin = ctx.cos, ctx.sin
		local N = #cos
		local hx, r = P.hx, P.r
		local tx: { number }, ty: { number }, tz: { number } = table.create(N), table.create(N), table.create(N) -- +X ring
		local bx: { number }, by: { number }, bz: { number } = table.create(N), table.create(N), table.create(N) -- −X ring
		if ctx.canonical then
			-- the circle's frame from the world, not the part's turn about its axis: world Y off the axis (world Z for an
			-- axis within about 25° of Y), then axis × that, so a copy spun about its axis has the same polygon
			local ax, ay, az = P.ux, P.uy, P.uz
			local rx, ry, rz = 0, 1, 0
			if ay > 0.9 or ay < -0.9 then
				rx, ry, rz = 0, 0, 1
			end
			local d = rx * ax + ry * ay + rz * az
			local ex, ey, ez = rx - d * ax, ry - d * ay, rz - d * az
			local le = sqrt(ex * ex + ey * ey + ez * ez)
			ex, ey, ez = ex / le, ey / le, ez / le
			local fx, fy, fz = ay * ez - az * ey, az * ex - ax * ez, ax * ey - ay * ex
			for k = 1, N do
				local a, b = r * cos[k], r * sin[k]
				local ox, oy, oz = a * ex + b * fx, a * ey + b * fy, a * ez + b * fz
				tx[k], ty[k], tz[k] = P.cx + hx * ax + ox, P.cy + hx * ay + oy, P.cz + hx * az + oz
				bx[k], by[k], bz[k] = P.cx - hx * ax + ox, P.cy - hx * ay + oy, P.cz - hx * az + oz
			end
		else
			for k = 1, N do
				tx[k], ty[k], tz[k] = Shapes.toWorld(P, hx, r * cos[k], r * sin[k])
				bx[k], by[k], bz[k] = Shapes.toWorld(P, -hx, r * cos[k], r * sin[k])
			end
		end
		for k = 1, N do
			local j = if k == N then 1 else k + 1
			xs[1], ys[1], zs[1] = tx[k], ty[k], tz[k]
			xs[2], ys[2], zs[2] = bx[k], by[k], bz[k]
			xs[3], ys[3], zs[3] = bx[j], by[j], bz[j]
			xs[4], ys[4], zs[4] = tx[j], ty[j], tz[j]
			addFacet(m, xs, ys, zs, 4)
		end
		addFacet(m, tx, ty, tz, N)
		for k = 1, N do
			xs[k], ys[k], zs[k] = bx[N + 1 - k], by[N + 1 - k], bz[N + 1 - k]
		end
		addFacet(m, xs, ys, zs, N)
		facetPlanes(m)
	else
		local n = ctx.ballGrid
		local r = P.r
		-- grid point (b, c) of a face with corners A, B, C: ((n − b − c)·A + b·B + c·C)/n, pushed out to radius r
		local gx: { number }, gy: { number }, gz: { number } = {}, {}, {}
		for o = 0, 7 do
			local sx = if o == 1 or o == 3 or o == 5 or o == 7 then -1 else 1
			local sy = if o == 2 or o == 3 or o == 6 or o == 7 then -1 else 1
			local sz = if o >= 4 then -1 else 1
			-- corners A = sx·X, B = sy·Y, C = sz·Z, swapped to B = Z, C = Y when the octant turns the face inside out
			local swap = sx * sy * sz < 0
			for b = 0, n do
				for c = 0, n - b do
					local a = n - b - c
					local lx, ly, lz
					if swap then
						lx, ly, lz = sx * a / n, sy * c / n, sz * b / n
					else
						lx, ly, lz = sx * a / n, sy * b / n, sz * c / n
					end
					local l = sqrt(lx * lx + ly * ly + lz * lz)
					local g = b * (n + 1) + c + 1
					if ctx.canonical then -- the octahedron on the world's axes: a turned copy has the same one
						gx[g], gy[g], gz[g] = P.cx + r * lx / l, P.cy + r * ly / l, P.cz + r * lz / l
					else
						gx[g], gy[g], gz[g] = Shapes.toWorld(P, r * lx / l, r * ly / l, r * lz / l)
					end
				end
			end
			for b = 0, n - 1 do
				for c = 0, n - 1 - b do
					local g1, g2, g3 = b * (n + 1) + c + 1, (b + 1) * (n + 1) + c + 1, b * (n + 1) + c + 2
					xs[1], ys[1], zs[1] = gx[g1], gy[g1], gz[g1]
					xs[2], ys[2], zs[2] = gx[g2], gy[g2], gz[g2]
					xs[3], ys[3], zs[3] = gx[g3], gy[g3], gz[g3]
					addFacet(m, xs, ys, zs, 3)
					if c <= n - 2 - b then
						local g4 = (b + 1) * (n + 1) + c + 2
						xs[1], ys[1], zs[1] = gx[g2], gy[g2], gz[g2]
						xs[2], ys[2], zs[2] = gx[g4], gy[g4], gz[g4]
						xs[3], ys[3], zs[3] = gx[g3], gy[g3], gz[g3]
						addFacet(m, xs, ys, zs, 3)
					end
				end
			end
		end
		facetPlanes(m)
	end
	local inr = math.huge
	for l = 1, m.np do
		inr = math.min(inr, m.hd[l] - (m.hx[l] * m.sx + m.hy[l] * m.sy + m.hz[l] * m.sz))
	end
	m.inr = inr
	-- a curved model's planes in runs of BUCKET (neighbours on its surface): a run whose normals all point away from a facet
	-- by enough cannot cut it, so a hider asks a run before its planes
	if m.np > 2 * BUCKET then
		local nb = 0
		for l0 = 1, m.np, BUCKET do
			local l1 = math.min(m.np, l0 + BUCKET - 1)
			local cx, cy, cz = 0, 0, 0
			for l = l0, l1 do
				cx, cy, cz = cx + m.hx[l], cy + m.hy[l], cz + m.hz[l]
			end
			local lc = sqrt(cx * cx + cy * cy + cz * cz)
			nb += 1
			if lc > 0 then
				cx, cy, cz = cx / lc, cy / lc, cz / lc
			end
			local cosb, rmin = 1, math.huge
			for l = l0, l1 do
				cosb = math.min(cosb, m.hx[l] * cx + m.hy[l] * cy + m.hz[l] * cz)
				rmin = math.min(rmin, m.hd[l] - (m.hx[l] * m.sx + m.hy[l] * m.sy + m.hz[l] * m.sz))
			end
			if lc <= 0 then
				cosb = -1 -- normals that cancel: the run is always asked
			end
			m.bx[nb], m.by[nb], m.bz[nb] = cx, cy, cz
			m.bcos[nb], m.bsin[nb] = cosb, sqrt(math.max(0, 1 - cosb * cosb))
			m.binr[nb] = rmin
		end
		m.nb = nb
	end
	return m
end

-- ── a facet ───────────────────────────────────────────────────────────────────────────────────────────────────────

-- Clips the polygon x1/y1/e1 (n vertices) to a·x + b·y ≤ c into x2/y2/e2; a new edge on the line takes the id `line`.
-- Returns the new count, and whether anything was cut off. n = 0 out: nothing is left.
local function clip(ctx: Context, n: number, a: number, b: number, c: number, line: number): (number, boolean)
	local x1, y1, e1, s = ctx.x1, ctx.y1, ctx.e1, ctx.s
	local outside, inside = 0, 0
	for i = 1, n do
		local v = a * x1[i] + b * y1[i] - c
		s[i] = v
		if v > 0 then
			outside += 1
		else
			inside += 1
		end
	end
	if outside == 0 then
		return n, false
	end
	if inside == 0 then
		return 0, true
	end
	local x2, y2, e2 = ctx.x2, ctx.y2, ctx.e2
	local m = 0
	for i = 1, n do
		local j = if i == n then 1 else i + 1
		local si, sj = s[i], s[j]
		if si <= 0 then
			if sj > 0 then -- leaving: the rest of this edge is cut, the clip line runs on to the entry
				if si < 0 then
					m += 1
					x2[m], y2[m], e2[m] = x1[i], y1[i], e1[i]
					local t = si / (si - sj)
					m += 1
					x2[m], y2[m], e2[m] = x1[i] + t * (x1[j] - x1[i]), y1[i] + t * (y1[j] - y1[i]), line
				else
					m += 1
					x2[m], y2[m], e2[m] = x1[i], y1[i], line
				end
			else
				m += 1
				x2[m], y2[m], e2[m] = x1[i], y1[i], e1[i]
			end
		elseif sj < 0 then -- entering, mid-edge: the edge carries on from the entry point
			local t = si / (si - sj)
			m += 1
			x2[m], y2[m], e2[m] = x1[i] + t * (x1[j] - x1[i]), y1[i] + t * (y1[j] - y1[i]), e1[i]
		end
	end
	-- ping-pong: the result becomes x1
	ctx.x1, ctx.y1, ctx.e1, ctx.x2, ctx.y2, ctx.e2 = x2, y2, e2, x1, y1, e1
	return m, true
end

-- Marks every piece that lies inside another, within CONTAIN_TOL (the earlier of two equal ones): the union is the same.
-- Returns the pieces left, in order, in ctx.live.
local function prune(ctx: Context, K: number): (number, number)
	local qx, qy, qe, qf = ctx.qx, ctx.qy, ctx.qe, ctx.qf
	local bx0, bx1, by0, by1 = ctx.bx0, ctx.bx1, ctx.by0, ctx.by1
	local lx, ly, lc = ctx.lx, ctx.ly, ctx.lc
	local gone, live = ctx.gone, ctx.live
	for i = 1, K do
		gone[i] = false
	end
	local ops = 0
	for i = 1, K do
		local i0, i1 = qf[i], qf[i + 1] - 1
		local ax0, ax1, ay0, ay1 = bx0[i], bx1[i], by0[i], by1[i]
		for j = 1, K do
			if j ~= i and not gone[j] and bx0[j] <= ax0 + CONTAIN_TOL and bx1[j] >= ax1 - CONTAIN_TOL
				and by0[j] <= ay0 + CONTAIN_TOL and by1[j] >= ay1 - CONTAIN_TOL then
				local inside = true
				for l = qf[j], qf[j + 1] - 1 do
					local lj = qe[l]
					local nx, ny, nc = lx[lj], ly[lj], lc[lj]
					for v = i0, i1 do
						if nx * qx[v] + ny * qy[v] - nc > CONTAIN_TOL then
							inside = false
							break
						end
					end
					ops += i1 - i0 + 1
					if not inside then
						break
					end
				end
				if inside then
					gone[i] = true
					break
				end
			end
		end
	end
	local n = 0
	for i = 1, K do
		if not gone[i] then
			n += 1
			live[n] = i
		end
	end
	return n, ops
end

-- The union's area of the pieces left (Green's theorem, see the header).
local function unionArea(ctx: Context, K: number, spend: (number) -> ()): number
	local nLive, pruneOps = prune(ctx, K)
	spend(pruneOps / UNIT_OPS)
	local live = ctx.live
	local qx, qy, qe, qf = ctx.qx, ctx.qy, ctx.qe, ctx.qf
	local bx0, bx1, by0, by1 = ctx.bx0, ctx.bx1, ctx.by0, ctx.by1
	local lx, ly, lc = ctx.lx, ctx.ly, ctx.lc
	local gx, gy, gc = ctx.gx, ctx.gy, ctx.gc -- each piece edge's line, by the edge's first vertex
	for ii = 1, nLive do
		local i = live[ii]
		for k = qf[i], qf[i + 1] - 1 do
			local le = qe[k]
			gx[k], gy[k], gc[k] = lx[le], ly[le], lc[le]
		end
	end
	local T0, T1 = ctx.t0, ctx.t1
	local total = 0
	local hint = 0 -- the piece that last held a whole edge: asked first, it likely holds the next
	for ii = 1, nLive do
		local i = live[ii]
		local k0, k1 = qf[i], qf[i + 1] - 1
		local ops = 0
		for k = k0, k1 do
			local kn = if k == k1 then k0 else k + 1
			local ax, ay, bx, by = qx[k], qy[k], qx[kn], qy[kn]
			local cross = ax * by - ay * bx
			if cross ~= 0 then
				local le = qe[k]
				local mx, my, mc = gx[k], gy[k], gc[k]
				local ex0, ex1 = math.min(ax, bx) - LINE_TOL, math.max(ax, bx) + LINE_TOL
				local ey0, ey1 = math.min(ay, by) - LINE_TOL, math.max(ay, by) + LINE_TOL
				local count = 0
				local full = false
				ops += nLive
				local first = if hint ~= 0 and hint ~= i then 0 else 1
				for jj = first, nLive do
					local j = if jj == 0 then hint else live[jj]
					if j ~= i and (jj == 0 or j ~= hint) and bx0[j] <= ex1 and bx1[j] >= ex0 and by0[j] <= ey1 and by1[j] >= ey0 then
						local t0, t1 = 0, 1
						local ok = true
						local j0, j1 = qf[j], qf[j + 1] - 1
						ops += j1 - j0 + 1
						for l = j0, j1 do
							local lj = qe[l]
							if lj == le then -- the same line, the same side: the earlier piece keeps the edge
								if j > i then
									ok = false
									break
								end
								continue
							end
							local nx, ny, nc = gx[l], gy[l], gc[l]
							local sa = nx * ax + ny * ay - nc
							local sb = nx * bx + ny * by - nc
							if sa <= NEAR and sa >= -NEAR and sb <= NEAR and sb >= -NEAR then
								-- maybe one line (the rule's lines are this close): the rule decides
								local sine = mx * ny - my * nx
								if sine <= ANGLE_TOL and sine >= -ANGLE_TOL then
									if mx * nx + my * ny > 0 then
										if abs(mc - nc) <= LINE_TOL then -- one line, one side
											if j > i then
												ok = false
												break
											end
											continue
										end
									elseif abs(mc + nc) <= LINE_TOL then -- one line, opposite sides: both drop it
										continue
									end
								end
							end
							if sa > 0 then
								if sb > 0 then
									ok = false
									break
								end
								local t = sa / (sa - sb)
								if t > t0 then
									t0 = t
								end
							elseif sb > 0 then
								local t = sa / (sa - sb)
								if t < t1 then
									t1 = t
								end
							end
							if t0 >= t1 then
								ok = false
								break
							end
						end
						if ok then
							if t0 <= 0 and t1 >= 1 then -- inside one piece: nothing of it is boundary
								full = true
								hint = j
								break
							end
							-- insert by where it starts (they are few)
							local p = count
							while p >= 1 and T0[p] > t0 do
								T0[p + 1], T1[p + 1] = T0[p], T1[p]
								p -= 1
							end
							T0[p + 1], T1[p + 1] = t0, t1
							count += 1
						end
					end
				end
				if not full then
					local kept = 1
					if count > 0 then
						local covered, lo, hi = 0, T0[1], T1[1]
						for p = 2, count do
							if T0[p] > hi then
								covered += hi - lo
								lo, hi = T0[p], T1[p]
							elseif T1[p] > hi then
								hi = T1[p]
							end
						end
						kept = 1 - (covered + hi - lo)
					end
					total += kept * cross
				end
			end
		end
		spend(ops / UNIT_OPS)
	end
	return total / 2
end

-- What shows of facet f of model mp: its area less the union of its hiders' pieces.
local function facetShown(ctx: Context, mp: Model, f: number, hiders: { Prepared }, hm: { Model }, higher: { boolean },
	spend: (number) -> ()): number
	local area = mp.area[f]
	local box = mp.box
	local b = 6 * (f - 1)
	local fx0, fy0, fz0 = box[b + 1] - REACH, box[b + 2] - REACH, box[b + 3] - REACH
	local fx1, fy1, fz1 = box[b + 4] + REACH, box[b + 5] + REACH, box[b + 6] + REACH
	local ox, oy, oz = mp.ox[f], mp.oy[f], mp.oz[f]
	local ux, uy, uz = mp.ux[f], mp.uy[f], mp.uz[f]
	local vx, vy, vz = mp.vx[f], mp.vy[f], mp.vz[f]
	local nx, ny, nz = mp.nx[f], mp.ny[f], mp.nz[f]
	local rho = mp.rho[f]
	local reach = rho + REACH
	local k0, k1 = mp.first[f], mp.first[f + 1] - 1
	local m = k1 - k0 + 1
	local fpx, fpy = mp.px, mp.py
	local wxs, wys, wzs = mp.wx, mp.wy, mp.wz
	-- the facet's own edges are lines 1…m: outward unit normal (dy, −dx)/|·|, offset
	local lx, ly, lc = ctx.lx, ctx.ly, ctx.lc
	for i = 1, m do
		local j = if i == m then 1 else i + 1
		local dx, dy = fpx[k0 + j - 1] - fpx[k0 + i - 1], fpy[k0 + j - 1] - fpy[k0 + i - 1]
		local l = sqrt(dx * dx + dy * dy)
		local mx, my = dy / l, -dx / l
		lx[i], ly[i], lc[i] = mx, my, mx * fpx[k0 + i - 1] + my * fpy[k0 + i - 1]
	end
	local lines = m
	local qx, qy, qe, qf = ctx.qx, ctx.qy, ctx.qe, ctx.qf
	local bx0, bx1, by0, by1 = ctx.bx0, ctx.bx1, ctx.by0, ctx.by1
	local A, B, C0, DN = ctx.a, ctx.b, ctx.c0, ctx.dn
	local stC, stD, stA = ctx.stC, ctx.stD, ctx.stA
	local pieces = 0
	qf[1] = 1
	for h = 1, #hiders do
		local q = hiders[h]
		local qm = hm[h]
		local dx, dy, dz = qm.sx - ox, qm.sy - oy, qm.sz - oz
		local lim = qm.sr + reach
		if q.minx <= fx1 and q.maxx >= fx0 and q.miny <= fy1 and q.maxy >= fy0 and q.minz <= fz1 and q.maxz >= fz0
			and dx * dx + dy * dy + dz * dz <= lim * lim then
			local np = qm.np
			local hx, hy, hz, hd = qm.hx, qm.hy, qm.hz, qm.hd
			-- a plane's coefficients in f's frame, as far as they are needed: offset, the probe's term, the line
			local tok = ctx.tok + 1
			ctx.tok = tok
			local ops = 0
			for kind = 1, 2 do
				-- kind 1: buried (or on q's surface, q higher); kind 2: the probe in q
				local up = if higher[h] then EPS else -EPS
				-- every vertex (or its probe) within the sphere all of q's half-spaces hold, moved: all of f, at once
				local r = qm.inr + (if kind == 1 then up else EPS)
				if r > 0 then
					local off = if kind == 1 then 0 else DELTA
					local cx, cy, cz = qm.sx - off * nx, qm.sy - off * ny, qm.sz - off * nz
					local inside = true
					for i = k0, k1 do
						local ex, ey, ez = wxs[i] - cx, wys[i] - cy, wzs[i] - cz
						if ex * ex + ey * ey + ez * ez >= r * r then
							inside = false
							break
						end
					end
					ops += m
					if inside then
						spend(ops / UNIT_OPS)
						return 0
					end
				end
				local x1, y1, e1 = ctx.x1, ctx.y1, ctx.e1
				for i = 1, m do
					x1[i], y1[i], e1[i] = fpx[k0 + i - 1], fpy[k0 + i - 1], i
				end
				local n = m
				local cut = false
				-- the runs of a curved hider (one run of every plane otherwise): a run whose cone of normals keeps every plane
				-- at least rho beyond f's origin is passed over whole
				local wx, wy, wz = qm.sx - ox, qm.sy - oy, qm.sz - oz
				if kind == 2 then
					wx, wy, wz = wx - DELTA * nx, wy - DELTA * ny, wz - DELTA * nz
				end
				wx, wy, wz = -wx, -wy, -wz -- f's origin (or its probe) from the sphere's centre
				local w2 = wx * wx + wy * wy + wz * wz
				local wl = sqrt(w2)
				local slack = (if kind == 1 then up else EPS) - rho - CONE_MARGIN
				local nb = qm.nb
				for run = 1, if nb > 0 then nb else 1 do
					local l0, l1 = 1, np
					if nb > 0 then
						l0 = (run - 1) * BUCKET + 1
						l1 = math.min(np, l0 + BUCKET - 1)
						local t = qm.bx[run] * wx + qm.by[run] * wy + qm.bz[run] * wz
						local cosb = qm.bcos[run]
						local most = if t >= wl * cosb then wl else t * cosb + sqrt(math.max(0, w2 - t * t)) * qm.bsin[run]
						ops += 1
						if qm.binr[run] - most + slack >= 0 then
							continue
						end
					end
					for l = l0, l1 do
						-- f lies within rho of its frame's origin and |(a, b)| <= 1: a plane whose offset there is at least rho holds on all
						-- of f (no cut), one under -rho on none of it (nothing left), whatever its line
						if stC[l] ~= tok then
							C0[l] = hd[l] - (hx[l] * ox + hy[l] * oy + hz[l] * oz)
							stC[l] = tok
							ops += 1
						end
						local c
						if kind == 1 then
							c = C0[l] + up
						else
							local c0 = C0[l] + EPS
							if c0 - DELTA >= rho then
								continue
							end
							if stD[l] ~= tok then
								DN[l] = hx[l] * nx + hy[l] * ny + hz[l] * nz
								stD[l] = tok
								ops += 1
							end
							c = c0 - DELTA * DN[l]
						end
						if c >= rho then
							continue
						end
						if c < -rho then
							cut = true
							n = 0
							break
						end
						if stA[l] ~= tok then
							local px, py, pz = hx[l], hy[l], hz[l]
							A[l] = px * ux + py * uy + pz * uz
							B[l] = px * vx + py * vy + pz * vz
							stA[l] = tok
							ops += 2
						end
						ops += n
						local a, bb = A[l], B[l]
						local nn, did = clip(ctx, n, a, bb, c, lines + 1)
						if did then
							cut = true
							if nn == 0 then
								n = 0
								break
							end
							-- the line, unit normal: kept only if an edge of the result lies on it
							local len = sqrt(a * a + bb * bb)
							lines += 1
							lx[lines], ly[lines], lc[lines] = a / len, bb / len, c / len
						end
						n = nn
					end
					if n == 0 then
						break
					end
				end
				if n > 0 then
					if not cut then
						spend(ops / UNIT_OPS)
						return 0 -- a piece that is all of f
					end
					local x1b, y1b, e1b = ctx.x1, ctx.y1, ctx.e1
					local s = 0
					local xa, xb, ya, yb = x1b[1], x1b[1], y1b[1], y1b[1]
					for i = 1, n do
						local j = if i == n then 1 else i + 1
						s += x1b[i] * y1b[j] - y1b[i] * x1b[j]
						local x, y = x1b[i], y1b[i]
						if x < xa then
							xa = x
						elseif x > xb then
							xb = x
						end
						if y < ya then
							ya = y
						elseif y > yb then
							yb = y
						end
					end
					if s > 2 * SLIVER * area then
						pieces += 1
						local base = qf[pieces]
						for i = 1, n do
							qx[base + i - 1], qy[base + i - 1], qe[base + i - 1] = x1b[i], y1b[i], e1b[i]
						end
						qf[pieces + 1] = base + n
						bx0[pieces], bx1[pieces], by0[pieces], by1[pieces] = xa, xb, ya, yb
					end
				end
			end
			spend(ops / UNIT_OPS)
		end
	end
	if pieces == 0 then
		return area
	end
	local covered = unionArea(ctx, pieces, spend)
	local shown = area - covered
	return if shown > 0 then shown else 0
end

-- What shows of model mp (part p), facet by facet in the model's order, against hiders (in rank order, models hm,
-- higher[h]: hiders[h] ranks above p), stopping once it reaches need.
function Cover.shown(ctx: Context, mp: Model, hiders: { Prepared }, hm: { Model }, higher: { boolean }, need: number,
	spend: (number) -> ()): number
	local shown = 0
	for f = 1, mp.nf do
		shown += facetShown(ctx, mp, f, hiders, hm, higher, spend)
		if shown >= need then
			break
		end
	end
	return shown
end

-- Per facet, what shows (no early stop): for the measurements.
function Cover.facets(ctx: Context, mp: Model, hiders: { Prepared }, hm: { Model }, higher: { boolean },
	spend: (number) -> ()): { number }
	local out: { number } = table.create(mp.nf, 0)
	for f = 1, mp.nf do
		out[f] = facetShown(ctx, mp, f, hiders, hm, higher, spend)
	end
	return out
end

return table.freeze(Cover)
