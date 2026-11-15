--!strict
-- Physics/Shapes (SPEC §3.2, §4.1–§4.3, §4.5; owner S2): the five primitive solids exactly as Roblox renders them
-- (every row checked against the engine in Studio, E-S2.1). Pure; the determinism rules of §4.1 apply: + − × ÷ and
-- sqrt, floor, ceil, abs, min, max only, numeric loops, no module-level state. Local frame: half extents hx, hy, hz.
--
--   Block        |x| ≤ hx, |y| ≤ hy, |z| ≤ hz
--   Wedge        Block and z/hz ≥ y/hy             full −Y and +Z faces, the slope faces −Z/+Y
--   CornerWedge  Block and y/hy ≤ x/hx, y/hy ≤ −z/hz   a pyramid with its apex at (+hx, +hy, −hz)
--   Cylinder     |x| ≤ hx, y² + z² ≤ r²            axis = local X, r = min(hy, hz) (what Roblox draws)
--   Ball         x² + y² + z² ≤ r²                 r = min(hx, hy, hz)
--
-- PartData (Blueprint/Schema) is the part type that crosses module boundaries, and Shapes.aabb takes it directly (S6's
-- exact extents, §11.6, §11.12). A Prepared is prepare's working copy for one analysis: world basis (columns of R),
-- analytic volume, area and centroid, exact AABB. It stays inside Physics/, never enters a report and is never
-- written to after prepare, so a design's analysis cannot change its PartData.
--
--   prepare      PartData → Prepared
--   sd           signed distance of a world point (exact inside, a lower bound outside, 1-Lipschitz, ≤ 0 = inside)
--   chord        the interval of a world line inside the solid, optionally dilated (M3's raster and Thinness)
--   support      the farthest point along a direction (GJK; polyhedra = max-dot vertex in fixed order)
--   aabb         exact world extents of a PartData (§4.2 containment)
--   extentAlong  the solid's extent along a unit direction
--   maxDist      the exact largest distance from a point to the solid (§4.5 reach)
--   planes       a polyhedron's world half-spaces n·x ≤ d (MassProps' exact clipping)
--   faces        a polyhedron's world face polygons, counter-clockwise seen from outside
--   sameSolid    two prepared parts are exact copies of one solid (cleaning and ownership settle those at once)

local DT = require("../Definitions/Types")
local Quat = require("../Blueprint/Quat")
local Schema = require("../Blueprint/Schema")

local sqrt, abs, max, min = math.sqrt, math.abs, math.max, math.min
local HUGE = math.huge
local AXIAL2 = 1e-18 -- numeric guard, not a tunable: a line this close to the axis direction runs along it

local PI = 3.141592653589793 -- SPEC §4.1's literal: no math.pi in an authoritative path

local BLOCK, WEDGE, CORNER, CYLINDER, BALL = 1, 2, 3, 4, 5

local CODE: { [string]: number } = table.freeze({
	Block = BLOCK,
	Wedge = WEDGE,
	CornerWedge = CORNER,
	Cylinder = CYLINDER,
	Ball = BALL,
})

-- Vertices (±1 per axis, flat x, y, z) and faces (0-based vertex indices) of the polyhedra. The order is fixed: GJK's
-- max-dot support breaks ties by it (§4.2).
local BLOCK_VERTICES: { number } =
	table.freeze({ -1, -1, -1, 1, -1, -1, -1, 1, -1, 1, 1, -1, -1, -1, 1, 1, -1, 1, -1, 1, 1, 1, 1, 1 })
local BLOCK_FACES: { { number } } = table.freeze({
	table.freeze({ 0, 2, 6, 4 }),
	table.freeze({ 1, 3, 7, 5 }),
	table.freeze({ 0, 1, 5, 4 }),
	table.freeze({ 2, 3, 7, 6 }),
	table.freeze({ 0, 1, 3, 2 }),
	table.freeze({ 4, 5, 7, 6 }),
})
local WEDGE_VERTICES: { number } = table.freeze({ -1, -1, -1, 1, -1, -1, -1, -1, 1, 1, -1, 1, -1, 1, 1, 1, 1, 1 })
local WEDGE_FACES: { { number } } = table.freeze({
	table.freeze({ 0, 1, 3, 2 }),
	table.freeze({ 2, 3, 5, 4 }),
	table.freeze({ 0, 1, 5, 4 }),
	table.freeze({ 0, 2, 4 }),
	table.freeze({ 1, 3, 5 }),
})
local CORNER_VERTICES: { number } = table.freeze({ -1, -1, -1, 1, -1, -1, -1, -1, 1, 1, -1, 1, 1, 1, -1 })
local CORNER_FACES: { { number } } = table.freeze({
	table.freeze({ 0, 1, 3, 2 }),
	table.freeze({ 1, 3, 4 }),
	table.freeze({ 0, 1, 4 }),
	table.freeze({ 0, 2, 4 }),
	table.freeze({ 2, 3, 4 }),
})
local NO_NUMBERS: { number } = table.freeze({})
local NO_FACES: { { number } } = table.freeze({})

export type Prepared = {
	index: number, -- 1-based position in the blueprint's parts
	id: number,
	code: number, -- Shapes.BLOCK, WEDGE, CORNER, CYLINDER, BALL
	shape: DT.ShapeId,
	slot: DT.SlotId,
	material: DT.MaterialId,
	cx: number, cy: number, cz: number, -- centre
	ux: number, uy: number, uz: number, -- world direction of local X (column 1 of R)
	vx: number, vy: number, vz: number, -- local Y
	wx: number, wy: number, wz: number, -- local Z
	hx: number, hy: number, hz: number, -- half extents
	r: number, -- radius (Cylinder, Ball), else 0
	k1: number, k2: number, -- 1 / length of the slope normals (Wedge k1; CornerWedge k1, k2), else 0
	volume: number, -- analytic (§3.2)
	area: number, -- analytic
	lcx: number, lcy: number, lcz: number, -- centroid, local (§3.2)
	gx: number, gy: number, gz: number, -- centroid, world
	minx: number, miny: number, minz: number, -- exact world AABB (§4.2)
	maxx: number, maxy: number, maxz: number,
	poly: boolean, -- Block, Wedge or CornerWedge
	lverts: { number }, -- polyhedra: local vertices, flat x, y, z (empty otherwise)
	wverts: { number }, -- polyhedra: world vertices, flat x, y, z (empty otherwise)
	faceIdx: { { number } }, -- polyhedra: faces as 0-based vertex indices (empty otherwise)
}

local Shapes = {}

Shapes.PI = PI
Shapes.BLOCK, Shapes.WEDGE, Shapes.CORNER, Shapes.CYLINDER, Shapes.BALL = BLOCK, WEDGE, CORNER, CYLINDER, BALL
Shapes.CODE = CODE

-- ── prepare ───────────────────────────────────────────────────────────────────────────────────────────────────────

-- An unknown shape is a caller bug: Canonical refused it long before this.
function Shapes.prepare(part: Schema.PartData, index: number): Prepared
	local code = CODE[part.shape]
	if code == nil then
		error("Shapes.prepare: unknown shape " .. tostring(part.shape), 2)
	end
	local ux, vx, wx, uy, vy, wy, uz, vz, wz = Quat.toMatrix(part.rot)
	local cx, cy, cz = part.pos[1], part.pos[2], part.pos[3]
	local hx, hy, hz = part.size[1] / 2, part.size[2] / 2, part.size[3] / 2

	local r, k1, k2 = 0, 0, 0
	local lcx, lcy, lcz = 0, 0, 0
	local volume, area
	local vertices, faceIdx = NO_NUMBERS, NO_FACES
	if code == WEDGE then
		k1 = 1 / sqrt(hy * hy + hz * hz)
		vertices, faceIdx = WEDGE_VERTICES, WEDGE_FACES
		volume = 4 * hx * hy * hz
		area = 4 * hx * hz + 4 * hx * hy + 4 * hx * sqrt(hy * hy + hz * hz) + 4 * hy * hz
		lcx, lcy, lcz = 0, -hy / 3, hz / 3
	elseif code == CORNER then
		k1 = 1 / sqrt(hx * hx + hy * hy)
		k2 = 1 / sqrt(hy * hy + hz * hz)
		vertices, faceIdx = CORNER_VERTICES, CORNER_FACES
		volume = 8 * hx * hy * hz / 3
		area = 4 * hx * hz + 2 * hy * hz + 2 * hx * hy + 2 * hz * sqrt(hx * hx + hy * hy)
			+ 2 * hx * sqrt(hy * hy + hz * hz)
		lcx, lcy, lcz = hx / 4, -hy / 2, -hz / 4
	elseif code == BLOCK then
		vertices, faceIdx = BLOCK_VERTICES, BLOCK_FACES
		volume = 8 * hx * hy * hz
		area = 8 * (hx * hy + hy * hz + hx * hz)
	elseif code == CYLINDER then
		r = min(hy, hz)
		volume = 2 * PI * r * r * hx
		area = 2 * PI * r * r + 4 * PI * r * hx
	else
		r = min(hx, hy, hz)
		volume = 4 * PI * r * r * r / 3
		area = 4 * PI * r * r
	end

	-- exact world extents (§4.2): polyhedra by their vertices, a cylinder from its axis, a ball c ± r
	local minx, miny, minz, maxx, maxy, maxz
	local lverts, wverts = NO_NUMBERS, NO_NUMBERS
	local poly = #vertices > 0
	if poly then
		minx, miny, minz, maxx, maxy, maxz = HUGE, HUGE, HUGE, -HUGE, -HUGE, -HUGE
		lverts, wverts = table.create(#vertices, 0), table.create(#vertices, 0)
		for i = 1, #vertices, 3 do
			local a, b, c = vertices[i] * hx, vertices[i + 1] * hy, vertices[i + 2] * hz
			local x = cx + a * ux + b * vx + c * wx
			local y = cy + a * uy + b * vy + c * wy
			local z = cz + a * uz + b * vz + c * wz
			lverts[i], lverts[i + 1], lverts[i + 2] = a, b, c
			wverts[i], wverts[i + 1], wverts[i + 2] = x, y, z
			minx, miny, minz = min(minx, x), min(miny, y), min(minz, z)
			maxx, maxy, maxz = max(maxx, x), max(maxy, y), max(maxz, z)
		end
	elseif code == CYLINDER then
		local ex = hx * abs(ux) + r * sqrt(max(0, 1 - ux * ux))
		local ey = hx * abs(uy) + r * sqrt(max(0, 1 - uy * uy))
		local ez = hx * abs(uz) + r * sqrt(max(0, 1 - uz * uz))
		minx, maxx = cx - ex, cx + ex
		miny, maxy = cy - ey, cy + ey
		minz, maxz = cz - ez, cz + ez
	else
		minx, maxx = cx - r, cx + r
		miny, maxy = cy - r, cy + r
		minz, maxz = cz - r, cz + r
	end

	return {
		index = index,
		id = part.id,
		code = code,
		shape = part.shape,
		slot = part.slot,
		material = part.material,
		cx = cx, cy = cy, cz = cz,
		ux = ux, uy = uy, uz = uz,
		vx = vx, vy = vy, vz = vz,
		wx = wx, wy = wy, wz = wz,
		hx = hx, hy = hy, hz = hz,
		r = r,
		k1 = k1, k2 = k2,
		volume = volume,
		area = area,
		lcx = lcx, lcy = lcy, lcz = lcz,
		gx = cx + lcx * ux + lcy * vx + lcz * wx,
		gy = cy + lcx * uy + lcy * vy + lcz * wy,
		gz = cz + lcx * uz + lcy * vz + lcz * wz,
		minx = minx, miny = miny, minz = minz,
		maxx = maxx, maxy = maxy, maxz = maxz,
		poly = poly,
		lverts = lverts,
		wverts = wverts,
		faceIdx = faceIdx,
	}
end

-- Exact world extents of a part (min, max), S6's selection pivot and drag containment (§11.6, §11.12).
function Shapes.aabb(part: Schema.PartData): (Schema.Vec3, Schema.Vec3)
	local P = Shapes.prepare(part, 0)
	return { P.minx, P.miny, P.minz }, { P.maxx, P.maxy, P.maxz }
end

-- ── frames ────────────────────────────────────────────────────────────────────────────────────────────────────────

function Shapes.toWorld(P: Prepared, lx: number, ly: number, lz: number): (number, number, number)
	return P.cx + lx * P.ux + ly * P.vx + lz * P.wx,
		P.cy + lx * P.uy + ly * P.vy + lz * P.wy,
		P.cz + lx * P.uz + ly * P.vz + lz * P.wz
end

function Shapes.toLocal(P: Prepared, x: number, y: number, z: number): (number, number, number)
	local dx, dy, dz = x - P.cx, y - P.cy, z - P.cz
	return dx * P.ux + dy * P.uy + dz * P.uz, dx * P.vx + dy * P.vy + dz * P.vz, dx * P.wx + dy * P.wy + dz * P.wz
end

-- ── signed distance (§4.3) ────────────────────────────────────────────────────────────────────────────────────────

function Shapes.sdLocal(P: Prepared, lx: number, ly: number, lz: number): number
	local code = P.code
	if code == BALL then
		return sqrt(lx * lx + ly * ly + lz * lz) - P.r
	elseif code == CYLINDER then
		return max(abs(lx) - P.hx, sqrt(ly * ly + lz * lz) - P.r)
	end
	local hx, hy, hz = P.hx, P.hy, P.hz
	local d = max(abs(lx) - hx, abs(ly) - hy, abs(lz) - hz)
	if code == WEDGE then
		return max(d, (ly * hz - lz * hy) * P.k1)
	elseif code == CORNER then
		return max(d, (ly * hx - lx * hy) * P.k1, (ly * hz + lz * hy) * P.k2)
	end
	return d
end

function Shapes.sd(P: Prepared, x: number, y: number, z: number): number
	local dx, dy, dz = x - P.cx, y - P.cy, z - P.cz
	return Shapes.sdLocal(
		P,
		dx * P.ux + dy * P.uy + dz * P.uz,
		dx * P.vx + dy * P.vy + dz * P.vz,
		dx * P.wx + dy * P.wy + dz * P.wz
	)
end

-- The same solid, bit for bit: shape, centre, half extents and frame. R(q) = R(−q), so the sign of q cannot hide a copy.
function Shapes.sameSolid(a: Prepared, b: Prepared): boolean
	return a.code == b.code and a.cx == b.cx and a.cy == b.cy and a.cz == b.cz and a.hx == b.hx and a.hy == b.hy
		and a.hz == b.hz and a.ux == b.ux and a.uy == b.uy and a.uz == b.uz and a.vx == b.vx and a.vy == b.vy
		and a.vz == b.vz and a.wx == b.wx and a.wy == b.wy and a.wz == b.wz
end

-- ── AABB tests ────────────────────────────────────────────────────────────────────────────────────────────────────

function Shapes.aabbContains(P: Prepared, x: number, y: number, z: number, margin: number): boolean
	return x >= P.minx - margin and x <= P.maxx + margin and y >= P.miny - margin and y <= P.maxy + margin
		and z >= P.minz - margin and z <= P.maxz + margin
end

function Shapes.aabbOverlap(A: Prepared, B: Prepared, margin: number): boolean
	return A.minx <= B.maxx + margin and B.minx <= A.maxx + margin and A.miny <= B.maxy + margin
		and B.miny <= A.maxy + margin and A.minz <= B.maxz + margin and B.minz <= A.maxz + margin
end

-- ── line chord (world line o + t·u) ───────────────────────────────────────────────────────────────────────────────

local function clipSlab(t0: number, t1: number, o: number, u: number, h: number): (boolean, number, number)
	if u == 0 then
		return (o >= -h and o <= h), t0, t1
	end
	local a = (-h - o) / u
	local b = (h - o) / u
	if a > b then
		a, b = b, a
	end
	if a > t0 then
		t0 = a
	end
	if b < t1 then
		t1 = b
	end
	return t0 <= t1, t0, t1
end

-- Keeps no + t·nu ≤ 0.
local function clipHalf(t0: number, t1: number, no: number, nu: number): (boolean, number, number)
	if nu == 0 then
		return no <= 0, t0, t1
	end
	local t = -no / nu
	if nu > 0 then
		if t < t1 then
			t1 = t
		end
	elseif t > t0 then
		t0 = t
	end
	return t0 <= t1, t0, t1
end

-- (hit, t0, t1). dilate ≥ 0 moves every supporting plane (and the quadric radius, the cylinder's half length) out by
-- that distance, so seams and connected gaps never open in the raster (§4.6). u is a unit vector.
function Shapes.chord(P: Prepared, ox: number, oy: number, oz: number, ux: number, uy: number, uz: number,
	dilate: number?): (boolean, number, number)
	local d = dilate or 0
	local lox, loy, loz = Shapes.toLocal(P, ox, oy, oz)
	local lux = ux * P.ux + uy * P.uy + uz * P.uz
	local luy = ux * P.vx + uy * P.vy + uz * P.vz
	local luz = ux * P.wx + uy * P.wy + uz * P.wz
	local code = P.code
	local t0, t1 = -HUGE, HUGE
	local ok: boolean
	if code == BALL then
		local r = P.r + d
		local a = lux * lux + luy * luy + luz * luz
		local b = 2 * (lox * lux + loy * luy + loz * luz)
		local c = lox * lox + loy * loy + loz * loz - r * r
		local disc = b * b - 4 * a * c
		if disc < 0 then
			return false, 0, 0
		end
		local s = sqrt(disc)
		return true, (-b - s) / (2 * a), (-b + s) / (2 * a)
	elseif code == CYLINDER then
		ok, t0, t1 = clipSlab(t0, t1, lox, lux, P.hx + d)
		if not ok then
			return false, 0, 0
		end
		local r = P.r + d
		local a = luy * luy + luz * luz
		local c = loy * loy + loz * loz - r * r
		if a <= AXIAL2 then
			return c <= 0, t0, t1
		end
		local b = 2 * (loy * luy + loz * luz)
		local disc = b * b - 4 * a * c
		if disc < 0 then
			return false, 0, 0
		end
		local s = sqrt(disc)
		local q0, q1 = (-b - s) / (2 * a), (-b + s) / (2 * a)
		if q0 > t0 then
			t0 = q0
		end
		if q1 < t1 then
			t1 = q1
		end
		return t0 <= t1, t0, t1
	end
	local hx, hy, hz = P.hx, P.hy, P.hz
	ok, t0, t1 = clipSlab(t0, t1, lox, lux, hx + d)
	if not ok then
		return false, 0, 0
	end
	ok, t0, t1 = clipSlab(t0, t1, loy, luy, hy + d)
	if not ok then
		return false, 0, 0
	end
	ok, t0, t1 = clipSlab(t0, t1, loz, luz, hz + d)
	if not ok then
		return false, 0, 0
	end
	if code == WEDGE then
		ok, t0, t1 = clipHalf(t0, t1, loy * hz - loz * hy - d / P.k1, luy * hz - luz * hy)
	elseif code == CORNER then
		ok, t0, t1 = clipHalf(t0, t1, loy * hx - lox * hy - d / P.k1, luy * hx - lux * hy)
		if ok then
			ok, t0, t1 = clipHalf(t0, t1, loy * hz + loz * hy - d / P.k2, luy * hz + luz * hy)
		end
	end
	if not ok then
		return false, 0, 0
	end
	return true, t0, t1
end

-- ── support, extents, distance ────────────────────────────────────────────────────────────────────────────────────

-- The farthest point of the solid along (dx, dy, dz), any non-zero length (§4.2): Block (sgn·h), Cylinder
-- (sgn dx·hx, r·(dy, dz)/|·|), Ball r·d/|d|, polyhedra the max-dot vertex in fixed order.
function Shapes.support(P: Prepared, dx: number, dy: number, dz: number): (number, number, number)
	local lx = dx * P.ux + dy * P.uy + dz * P.uz
	local ly = dx * P.vx + dy * P.vy + dz * P.vz
	local lz = dx * P.wx + dy * P.wy + dz * P.wz
	local code = P.code
	local sx, sy, sz
	if code == BLOCK then
		sx = if lx >= 0 then P.hx else -P.hx
		sy = if ly >= 0 then P.hy else -P.hy
		sz = if lz >= 0 then P.hz else -P.hz
	elseif code == CYLINDER then
		sx = if lx >= 0 then P.hx else -P.hx
		local m = sqrt(ly * ly + lz * lz)
		if m > 0 then
			sy, sz = ly * P.r / m, lz * P.r / m
		else
			sy, sz = 0, 0
		end
	elseif code == BALL then
		local m = sqrt(lx * lx + ly * ly + lz * lz)
		if m > 0 then
			sx, sy, sz = lx * P.r / m, ly * P.r / m, lz * P.r / m
		else
			sx, sy, sz = P.r, 0, 0
		end
	else
		local lv = P.lverts
		local best = -HUGE
		sx, sy, sz = 0, 0, 0
		for i = 1, #lv, 3 do
			local d = lx * lv[i] + ly * lv[i + 1] + lz * lv[i + 2]
			if d > best then
				best = d
				sx, sy, sz = lv[i], lv[i + 1], lv[i + 2]
			end
		end
	end
	return Shapes.toWorld(P, sx, sy, sz)
end

-- (lo, hi): the solid's extent along the unit direction a.
function Shapes.extentAlong(P: Prepared, ax: number, ay: number, az: number): (number, number)
	local hx, hy, hz = Shapes.support(P, ax, ay, az)
	local lx, ly, lz = Shapes.support(P, -ax, -ay, -az)
	return lx * ax + ly * ay + lz * az, hx * ax + hy * ay + hz * az
end

-- The exact largest distance from (gx, gy, gz) to the solid (§4.5): vertices; cylinder caps
-- sqrt(|c± − g|² + r² + 2r·|(c± − g)⊥|); ball |c − g| + r.
function Shapes.maxDist(P: Prepared, gx: number, gy: number, gz: number): number
	if P.poly then
		local wv = P.wverts
		local best = 0
		for i = 1, #wv, 3 do
			local dx, dy, dz = wv[i] - gx, wv[i + 1] - gy, wv[i + 2] - gz
			local d2 = dx * dx + dy * dy + dz * dz
			if d2 > best then
				best = d2
			end
		end
		return sqrt(best)
	elseif P.code == CYLINDER then
		local best = 0
		for s = -1, 1, 2 do
			local ccx, ccy, ccz = P.cx + s * P.hx * P.ux, P.cy + s * P.hx * P.uy, P.cz + s * P.hx * P.uz
			local dx, dy, dz = ccx - gx, ccy - gy, ccz - gz
			local dd = dx * dx + dy * dy + dz * dz
			local a = dx * P.ux + dy * P.uy + dz * P.uz
			local perp = sqrt(max(0, dd - a * a))
			local d2 = dd + P.r * P.r + 2 * P.r * perp
			if d2 > best then
				best = d2
			end
		end
		return sqrt(best)
	end
	local dx, dy, dz = P.cx - gx, P.cy - gy, P.cz - gz
	return sqrt(dx * dx + dy * dy + dz * dz) + P.r
end

-- ── polyhedra: world half-spaces and faces (§4.3 exact clipping) ──────────────────────────────────────────────────

-- World half-spaces {nx, ny, nz, d}, n·x ≤ d, unit n; empty for Cylinder and Ball.
function Shapes.planes(P: Prepared): { { number } }
	local out: { { number } } = {}
	if not P.poly then
		return out
	end
	local function add(a: number, b: number, c: number, e: number)
		local nx = a * P.ux + b * P.vx + c * P.wx
		local ny = a * P.uy + b * P.vy + c * P.wy
		local nz = a * P.uz + b * P.vz + c * P.wz
		local l = sqrt(nx * nx + ny * ny + nz * nz)
		nx, ny, nz, e = nx / l, ny / l, nz / l, e / l
		table.insert(out, { nx, ny, nz, e + nx * P.cx + ny * P.cy + nz * P.cz })
	end
	local hx, hy, hz = P.hx, P.hy, P.hz
	add(1, 0, 0, hx)
	add(-1, 0, 0, hx)
	add(0, 1, 0, hy)
	add(0, -1, 0, hy)
	add(0, 0, 1, hz)
	add(0, 0, -1, hz)
	if P.code == WEDGE then
		add(0, hz, -hy, 0)
	elseif P.code == CORNER then
		add(-hy, hx, 0, 0)
		add(0, hz, hy, 0)
	end
	return out
end

-- World face polygons, each a flat {x1, y1, z1, x2, …}, counter-clockwise seen from outside; empty for Cylinder and
-- Ball.
function Shapes.faces(P: Prepared): { { number } }
	local out: { { number } } = {}
	local wv = P.wverts
	local list = P.faceIdx
	for f = 1, #list do
		local face = list[f]
		local n = #face
		local poly: { number } = table.create(3 * n, 0)
		local fx, fy, fz = 0, 0, 0
		for i = 1, n do
			local k = face[i]
			local x, y, z = wv[3 * k + 1], wv[3 * k + 2], wv[3 * k + 3]
			poly[3 * i - 2], poly[3 * i - 1], poly[3 * i] = x, y, z
			fx, fy, fz = fx + x, fy + y, fz + z
		end
		fx, fy, fz = fx / n, fy / n, fz / n
		-- Newell normal
		local nx, ny, nz = 0, 0, 0
		for i = 0, n - 1 do
			local j = if i == n - 1 then 0 else i + 1
			local ax, ay, az = poly[3 * i + 1], poly[3 * i + 2], poly[3 * i + 3]
			local bx, by, bz = poly[3 * j + 1], poly[3 * j + 2], poly[3 * j + 3]
			nx += (ay - by) * (az + bz)
			ny += (az - bz) * (ax + bx)
			nz += (ax - bx) * (ay + by)
		end
		if nx * (fx - P.gx) + ny * (fy - P.gy) + nz * (fz - P.gz) < 0 then
			local rev: { number } = table.create(3 * n, 0)
			for i = 1, n do
				local s = n - i
				rev[3 * i - 2], rev[3 * i - 1], rev[3 * i] = poly[3 * s + 1], poly[3 * s + 2], poly[3 * s + 3]
			end
			poly = rev
		end
		table.insert(out, poly)
	end
	return out
end

return table.freeze(Shapes)
