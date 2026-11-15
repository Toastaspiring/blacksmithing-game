--!strict
-- T-BP-11 Blueprint/Mirror (SPEC §3.8, E-S2.6, E-S6.7, E-S8.5): a mirrored part occupies exactly the reflected solid,
-- as a proper rotation of the same shape. 10,000 points per shape and plane against two oracles (the §3.2 and §4.3
-- solids, written out here from the SPEC's tables, and Physics/Shapes), then exact checks on vertices, volumes,
-- centroids and extents with tests/lib/Gen's geometry; none of these knows Mirror. isSelfSymmetric, the test behind
-- §11.10's "parts on the plane are skipped", is checked by hand on the shapes' own symmetries and on F1–F5, and against
-- a brute-force comparison of each solid with its image. Trigonometry is fine here: tests are outside T-META-03's
-- folders.

local Test = require("../lib/Test")
local A = require("../lib/Assert")
local Dump = require("../lib/Dump")
local Gen = require("../lib/Gen")
local Prop = require("../lib/Prop")
local TestRng = require("../lib/TestRng")
local Tol = require("../lib/Tol")
local Blueprints = require("../fixtures/Blueprints")
local Drafts = require("./Drafts")
local Balance = require("../../src/shared/Definitions/Balance")
local EquipmentTypes = require("../../src/shared/Definitions/EquipmentTypes")
local Limits = require("../../src/shared/Definitions/Limits")
local Materials = require("../../src/shared/Definitions/Materials")
local Versions = require("../../src/shared/Definitions/Versions")
local Canonical = require("../../src/shared/Blueprint/Canonical")
local Mirror = require("../../src/shared/Blueprint/Mirror")
local Quat = require("../../src/shared/Blueprint/Quat")
local Shapes = require("../../src/shared/Physics/Shapes")

type TestRng = TestRng.TestRng
type Plane = Mirror.Plane
type Q = { number }

local H = 0.70710678118654757 -- §3.8's literal
local I: Q = { 0, 0, 0, 1 }
local Y90: Q = { 0, H, 0, H }
local Z90: Q = { 0, 0, H, H }
local EPS_GEOM = Balance.Geometry.EPS_GEOM
local CTX = Gen.context(Limits, EquipmentTypes.get("Sword") :: any, Materials.enabled, Versions.BLUEPRINT_SCHEMA,
	Balance.Geometry)

local PLANES: { Plane } = { "X", "Z" }
local POLYHEDRA = { "Block", "Wedge", "CornerWedge" }

local POINTS = 10000 -- per shape and plane (E-S8.5)
local PARTS = 20 -- random parts per shape and plane: 500 points each
-- stud; |Δsd| and the gap between the oracles, rounding only: a part up to MAX_DIM across has local coordinates of about 6,
-- whose last bits differ between a rotation and its image (worst of 120 seeds 2.66e-15; E-S2.6, smaller parts, 1.7e-16)
local SD_TOL = 4e-15
local BOUNDARY = 1e-12 -- stud; a point this close to the surface may round to either side

-- PartData's id unions are narrower than the plain strings of tests/lib: the spec talks to the module in `any`.
local function reflect(p: any, plane: Plane): any
	return Mirror.reflect(p, plane)
end

local function isSelfSymmetric(p: any, plane: Plane): boolean
	return Mirror.isSelfSymmetric(p, plane)
end

local function part(shape: string, pos: { number }, rot: Q, size: { number }): any
	return Drafts.part(1, "Guard", shape, "Iron", pos, rot, size)
end

-- ── the reflection and the solids, from the SPEC's tables ─────────────────────────────────────────────────────

local function reflected(plane: Plane, x: number, y: number, z: number): (number, number, number)
	if plane == "X" then
		return -x, y, z
	end
	return x, y, -z
end

type Solid = { shape: string, m: { number }, cx: number, cy: number, cz: number, hx: number, hy: number, hz: number }

local function solidOf(p: any): Solid
	return {
		shape = p.shape,
		m = Gen.matrix(p.rot),
		cx = p.pos[1],
		cy = p.pos[2],
		cz = p.pos[3],
		hx = p.size[1] / 2,
		hy = p.size[2] / 2,
		hz = p.size[3] / 2,
	}
end

-- Rᵀ·(x − c)
local function toLocal(s: Solid, x: number, y: number, z: number): (number, number, number)
	local m = s.m
	local dx, dy, dz = x - s.cx, y - s.cy, z - s.cz
	return m[1] * dx + m[4] * dy + m[7] * dz, m[2] * dx + m[5] * dy + m[8] * dz, m[3] * dx + m[6] * dy + m[9] * dz
end

-- §4.3's signed distance of a world point (≤ 0 = inside).
local function sdOf(s: Solid, wx: number, wy: number, wz: number): number
	local x, y, z = toLocal(s, wx, wy, wz)
	local hx, hy, hz = s.hx, s.hy, s.hz
	if s.shape == "Ball" then
		return math.sqrt(x * x + y * y + z * z) - math.min(hx, hy, hz)
	elseif s.shape == "Cylinder" then
		return math.max(math.abs(x) - hx, math.sqrt(y * y + z * z) - math.min(hy, hz))
	end
	local block = math.max(math.abs(x) - hx, math.abs(y) - hy, math.abs(z) - hz)
	if s.shape == "Wedge" then
		return math.max(block, (y * hz - z * hy) / math.sqrt(hy * hy + hz * hz))
	elseif s.shape == "CornerWedge" then
		return math.max(block, (y * hx - x * hy) / math.sqrt(hx * hx + hy * hy),
			(y * hz + z * hy) / math.sqrt(hy * hy + hz * hz))
	end
	return block
end

-- §3.2's solid, as its table writes it (a = x/hx, b = y/hy, c = z/hz).
local function insideOf(s: Solid, wx: number, wy: number, wz: number): boolean
	local x, y, z = toLocal(s, wx, wy, wz)
	local hx, hy, hz = s.hx, s.hy, s.hz
	if s.shape == "Ball" then
		local r = math.min(hx, hy, hz)
		return x * x + y * y + z * z <= r * r
	elseif s.shape == "Cylinder" then
		local r = math.min(hy, hz)
		return math.abs(x) <= hx and y * y + z * z <= r * r
	end
	if math.abs(x) > hx or math.abs(y) > hy or math.abs(z) > hz then
		return false
	end
	local a, b, c = x / hx, y / hy, z / hz
	if s.shape == "Wedge" then
		return c >= b
	elseif s.shape == "CornerWedge" then
		return b <= a and b <= -c
	end
	return true
end

-- A world point in the part's local box grown by a quarter.
local function pointAround(rng: TestRng, s: Solid): (number, number, number)
	local lx, ly, lz = rng:range(-1.25, 1.25) * s.hx, rng:range(-1.25, 1.25) * s.hy, rng:range(-1.25, 1.25) * s.hz
	local m = s.m
	return s.cx + m[1] * lx + m[2] * ly + m[3] * lz,
		s.cy + m[4] * lx + m[5] * ly + m[6] * lz,
		s.cz + m[7] * lx + m[8] * ly + m[9] * lz
end

type Stats = { inside: number, outside: number, mismatches: number, worst: number, gap: number }

local function newStats(): Stats
	return { inside = 0, outside = 0, mismatches = 0, worst = 0, gap = 0 }
end

-- inside(m, reflected(x)) against inside(p, x) at n points, half around p and half around m's image, by both oracles.
local function compare(p: any, m: any, plane: Plane, rng: TestRng, n: number, stats: Stats)
	local a, b = solidOf(p), solidOf(m)
	local pa, pb = Shapes.prepare(p, 1), Shapes.prepare(m, 1)
	for i = 1, n do
		local x: number, y: number, z: number
		if i % 2 == 1 then
			x, y, z = pointAround(rng, a)
		else
			x, y, z = reflected(plane, pointAround(rng, b))
		end
		local rx, ry, rz = reflected(plane, x, y, z)
		local d1, d2 = sdOf(a, x, y, z), sdOf(b, rx, ry, rz)
		local e1, e2 = Shapes.sd(pa, x, y, z), Shapes.sd(pb, rx, ry, rz)
		stats.worst = math.max(stats.worst, math.abs(d1 - d2), math.abs(e1 - e2))
		stats.gap = math.max(stats.gap, math.abs(d1 - e1), math.abs(d2 - e2))
		if math.abs(d1) > BOUNDARY then
			local isIn = d1 < 0
			if insideOf(a, x, y, z) ~= isIn or insideOf(b, rx, ry, rz) ~= isIn or (e1 < 0) ~= isIn or (e2 < 0) ~= isIn
			then
				stats.mismatches += 1
			end
			if isIn then
				stats.inside += 1
			else
				stats.outside += 1
			end
		end
	end
end

-- ── generators ────────────────────────────────────────────────────────────────────────────────────────────────

local function side(rng: TestRng): number
	local mode = rng:int(1, 8)
	if mode == 1 then
		return Limits.MIN_DIM
	elseif mode == 2 then
		return rng:range(Limits.MIN_DIM, Limits.MAX_DIM)
	end
	return rng:range(0.05, 0.7)
end

local function coordinate(rng: TestRng): number
	local mode = rng:int(1, 8)
	if mode == 1 then
		return 0
	elseif mode == 2 then
		return rng:range(-Limits.POS_ABS_MAX, Limits.POS_ABS_MAX)
	end
	return rng:range(-1, 1)
end

local function sizeFor(shape: string, a: number, b: number, c: number): { number }
	return if shape == "Ball" then { a, a, a } elseif shape == "Cylinder" then { a, b, b } else { a, b, c }
end

-- A canonical part of this shape, on Drafts.quat's mix of rotations (editor-like, threshold-hugging, axis-aligned,
-- qw = 0).
local function randomPart(rng: TestRng, shape: string): any
	return Drafts.part(rng:int(1, Limits.MAX_PART_ID), rng:pick(Drafts.SLOT_IDS), shape, rng:pick(Drafts.MATERIAL_IDS),
		{ coordinate(rng), coordinate(rng), coordinate(rng) }, Canonical.quat(Drafts.quat(rng)),
		sizeFor(shape, side(rng), side(rng), side(rng)))
end

local function oneOfEach(rng: TestRng, shapes: { string }): { any }
	local parts = {}
	for _, shape in shapes do
		table.insert(parts, randomPart(rng, shape))
	end
	return parts
end

local function aboutAxis(ax: number, ay: number, az: number, degrees: number): Q
	local half = math.rad(degrees) / 2
	local s = math.sin(half) / math.sqrt(ax * ax + ay * ay + az * az)
	return Quat.hemisphere({ ax * s, ay * s, az * s, math.cos(half) })
end

-- ── comparisons ───────────────────────────────────────────────────────────────────────────────────────────────

local function same(a: any, b: any, what: string)
	local diff = Drafts.bitDiff(a, b)
	A.truthy(diff == nil, what .. ": " .. tostring(diff) .. " (" .. Dump.short(a) .. " vs " .. Dump.short(b) .. ")")
end

local function maxDiff(a: { number }, b: { number }): number
	local m = 0
	for k = 1, #a do
		m = math.max(m, math.abs(a[k] - b[k]))
	end
	return m
end

local function times(a: { number }, b: { number }): { number }
	local out: { number } = table.create(9)
	for i = 0, 2 do
		for j = 1, 3 do
			out[i * 3 + j] = a[i * 3 + 1] * b[j] + a[i * 3 + 2] * b[j + 3] + a[i * 3 + 3] * b[j + 6]
		end
	end
	return out
end

local function det(m: { number }): number
	return m[1] * (m[5] * m[9] - m[6] * m[8]) - m[2] * (m[4] * m[9] - m[6] * m[7]) + m[3] * (m[4] * m[8] - m[5] * m[7])
end

local function verticesOf(p: any): { Gen.Vec }
	return Gen.vertices(p) :: { Gen.Vec }
end

local function imageOfVertices(p: any, plane: Plane): { Gen.Vec }
	local out: { Gen.Vec } = {}
	for _, v in verticesOf(p) do
		local x, y, z = reflected(plane, v[1], v[2], v[3])
		table.insert(out, { x, y, z })
	end
	return out
end

-- The largest distance of a one-to-one match of two vertex lists, each vertex taking its nearest free partner.
local function vertexError(a: { Gen.Vec }, b: { Gen.Vec }): number
	if #a ~= #b then
		return math.huge
	end
	local used: { [number]: boolean } = {}
	local worst = 0
	for _, v in a do
		local best, at = math.huge, 0
		for j, w in b do
			if not used[j] then
				local dx, dy, dz = v[1] - w[1], v[2] - w[2], v[3] - w[3]
				local d = math.sqrt(dx * dx + dy * dy + dz * dz)
				if d < best then
					best, at = d, j
				end
			end
		end
		used[at] = true
		worst = math.max(worst, best)
	end
	return worst
end

local function noNegativeZero(t: { number }): boolean
	for k = 1, #t do
		if t[k] == 0 and 1 / t[k] < 0 then
			return false
		end
	end
	return true
end

local function mirroredCore(core: any, plane: Plane): any
	local parts = {}
	for i, p in core.parts do
		parts[i] = reflect(p, plane)
	end
	return { schema = core.schema, name = core.name, type = core.type, parts = parts }
end

local function expectCanonical(core: any, what: string)
	A.truthy(Canonical.isCanonical(core), what .. ": isCanonical")
	local r: any = Canonical.draft(core)
	A.truthy(r.ok, what .. ": Canonical.draft")
	local diff = Drafts.draftDiff(r.value, core)
	A.truthy(diff == nil, what .. ": canonicalizing changed " .. tostring(diff))
end

-- ── closed forms worked by hand ───────────────────────────────────────────────────────────────────────────────

type FormRow = {
	shape: string,
	pos: { number },
	rot: Q,
	size: { number },
	plane: Plane,
	wantPos: { number },
	wantRot: Q,
	wantSize: { number },
}

local function form(shape: string, pos: { number }, rot: Q, size: { number }, plane: Plane, wantPos: { number },
	wantRot: Q, wantSize: { number }): FormRow
	return { shape = shape, pos = pos, rot = rot, size = size, plane = plane, wantPos = wantPos, wantRot = wantRot,
		wantSize = wantSize }
end

local SLAB = { 0.2, 1, 0.1 }
local TIP = { 0.16, 0.4, 0.85 }
local GRIP = { 0.9, 0.13, 0.13 }
local KNOB = { 0.12, 0.12, 0.12 }
local WIDE = { 0.4, 0.5, 0.2 }
local WIDE_SWAPPED = { 0.2, 0.5, 0.4 }
local Y180: Q = { 0, 1, 0, 0 }
local ZP30: Q = { 0, 0, math.sin(math.rad(15)), math.cos(math.rad(15)) } -- E-S6.7: rotZ(+30°) → rotZ(−30°)
local ZM30: Q = { 0, 0, -math.sin(math.rad(15)), math.cos(math.rad(15)) }
local AT_Y = { 0, 1, 0 }

local FORMS: { FormRow } = {
	form("Block", { 0.4, 1, 0.1 }, I, SLAB, "X", { -0.4, 1, 0.1 }, I, SLAB),
	form("Block", { 0.4, 1, 0 }, ZP30, SLAB, "X", { -0.4, 1, 0 }, ZM30, SLAB),
	form("Block", AT_Y, Y90, SLAB, "X", AT_Y, { 0, -H, 0, H }, SLAB),
	form("Block", AT_Y, { H, 0, 0, H }, SLAB, "X", AT_Y, { H, 0, 0, H }, SLAB),
	form("Block", AT_Y, { 0, 0, 1, 0 }, SLAB, "X", AT_Y, { 0, 0, 1, 0 }, SLAB),
	form("Wedge", { 0.175, 3.75, 0 }, Y90, TIP, "X", { -0.175, 3.75, 0 }, { 0, -H, 0, H }, TIP),
	form("Cylinder", { 0.1, 1, 0 }, Z90, GRIP, "X", { -0.1, 1, 0 }, { 0, 0, -H, H }, GRIP),
	form("Ball", { -0.45, 1.24, 0 }, I, KNOB, "X", { 0.45, 1.24, 0 }, I, KNOB),
	form("CornerWedge", { 0.3, 1, 0 }, I, WIDE, "X", { -0.3, 1, 0 }, { 0, H, 0, H }, WIDE_SWAPPED),
	form("Block", { 0.4, 1, 0.1 }, I, SLAB, "Z", { 0.4, 1, -0.1 }, Y180, SLAB),
	form("Block", AT_Y, Z90, SLAB, "Z", AT_Y, { H, -H, 0, 0 }, SLAB),
	form("Block", AT_Y, { H, 0, 0, H }, SLAB, "Z", AT_Y, { 0, H, -H, 0 }, SLAB),
	form("Wedge", { 0, 1, 0.05 }, I, TIP, "Z", { 0, 1, -0.05 }, Y180, TIP),
	form("Cylinder", { 0, 1, -0.05 }, I, GRIP, "Z", { 0, 1, 0.05 }, Y180, GRIP),
	form("Ball", { 0, 1, 0.05 }, I, KNOB, "Z", { 0, 1, -0.05 }, Y180, KNOB),
	form("CornerWedge", { 0.3, 1, 0.1 }, I, WIDE, "Z", { 0.3, 1, -0.1 }, { 0, -H, 0, H }, WIDE_SWAPPED),
}

-- ── isSelfSymmetric: cases worked by hand ─────────────────────────────────────────────────────────────────────

type SymCase = { shape: string, pos: { number }, rot: Q, size: { number }, x: boolean, z: boolean, what: string }

local function sym(shape: string, pos: { number }, rot: Q, size: { number }, x: boolean, z: boolean, what: string)
	: SymCase
	return { shape = shape, pos = pos, rot = rot, size = size, x = x, z = z, what = what }
end

local BALL = { 0.3, 0.3, 0.3 }
local LONG = { 0.8, 0.2, 0.2 }
local BOX = { 0.2, 0.6, 0.1 }
local PLANK = { 0.3, 0.4, 0.2 }
local SQUARE = { 0.3, 0.4, 0.3 }
local Y45, YM45 = aboutAxis(0, 1, 0, 45), aboutAxis(0, 1, 0, -45)
local X45, Z45 = aboutAxis(1, 0, 0, 45), aboutAxis(0, 0, 1, 45)

local SYM_CASES: { SymCase } = {
	sym("Ball", AT_Y, I, BALL, true, true, "a centred ball"),
	sym("Ball", { 0.1, 1, 0 }, I, BALL, false, true, "off x = 0"),
	sym("Ball", { 0, 1, 0.1 }, I, BALL, true, false, "off z = 0"),
	sym("Ball", AT_Y, aboutAxis(1, 2, 3, 77), BALL, true, true, "rotation does nothing to a ball"),
	sym("Block", AT_Y, I, BOX, true, true, "a centred block"),
	sym("Block", { 0.3, 1, 0 }, I, BOX, false, true, "off x = 0"),
	sym("Block", { 0, 1, 0.05 }, I, BOX, true, false, "off z = 0"),
	sym("Block", AT_Y, Y90, BOX, true, true, "a quarter turn keeps both planes"),
	sym("Block", AT_Y, Y180, BOX, true, true, "a half turn too"),
	sym("Block", AT_Y, aboutAxis(0, 0, 1, 30), BOX, false, true, "tilted in the blade plane: the copy crosses it"),
	sym("Block", AT_Y, aboutAxis(1, 0, 0, 30), BOX, true, false, "tilted about X"),
	sym("Block", AT_Y, aboutAxis(0, 1, 0, 30), BOX, false, false, "turned about Y"),
	sym("Block", AT_Y, Z45, { 0.3, 0.3, 0.1 }, true, true, "a square turned 45° is a diamond"),
	sym("Block", AT_Y, Z45, { 0.3, 0.4, 0.1 }, false, true, "an oblong turned 45° is not"),
	sym("Block", AT_Y, Y45, { 0.3, 0.6, 0.3 }, true, true, "a square turned about Y"),
	sym("Wedge", AT_Y, I, PLANK, true, false, "the slope faces −Z: a Z copy makes a ridge"),
	sym("Wedge", AT_Y, Y90, PLANK, false, true, "the slope faces −X: an X copy makes a double edge"),
	sym("Wedge", { 0.2, 1, 0 }, I, PLANK, false, false, "off x = 0, slope to −Z"),
	sym("Wedge", AT_Y, X45, { 0.3, 0.4, 0.4 }, true, true, "an isosceles profile on its axis"),
	sym("Wedge", AT_Y, X45, PLANK, true, false, "a scalene profile has no such axis"),
	sym("CornerWedge", AT_Y, I, PLANK, false, false, "no reflection maps it onto itself here"),
	sym("CornerWedge", AT_Y, Y45, SQUARE, true, false, "square base, apex over x = 0"),
	sym("CornerWedge", AT_Y, YM45, SQUARE, false, true, "square base, apex over z = 0"),
	sym("CornerWedge", { 0.2, 1, 0 }, Y45, SQUARE, false, false, "square base, off x = 0"),
	sym("CornerWedge", AT_Y, Y45, PLANK, false, false, "an oblong base has no diagonal"),
	sym("Cylinder", AT_Y, I, LONG, true, true, "axis along X: normal to x = 0, in z = 0"),
	sym("Cylinder", AT_Y, Z90, LONG, true, true, "axis along Y: in both"),
	sym("Cylinder", AT_Y, Y90, LONG, true, true, "axis along Z: normal to z = 0, in x = 0"),
	sym("Cylinder", AT_Y, aboutAxis(1, 0, 0, 33), LONG, true, true, "turned about its own axis"),
	sym("Cylinder", { 0.1, 1, 0 }, Z90, LONG, false, true, "off x = 0"),
	sym("Cylinder", AT_Y, aboutAxis(0, 0, 1, 30), LONG, false, true, "axis tilted in the XY plane"),
	sym("Cylinder", AT_Y, aboutAxis(0, 1, 0, 30), LONG, false, false, "axis tilted in the XZ plane"),
}

-- Per part of each fixture, the planes it is its own image across (§14.7, E-S8.3).
local FIXTURE_SYMMETRY: { [string]: string } = {
	F1 = "XZ XZ XZ XZ XZ", -- every part centred; the 45° tip is a square
	F2 = "XZ XZ XZ XZ",
	F3 = "XZ XZ XZ Z Z XZ Z", -- ball quillons at x = ±0.45, the wedge tip's slope faces −X
	F4 = "XZ XZ XZ Z Z", -- the cleaver's blade and tip sit at x = 0.175
	F5 = "XZ XZ XZ XZ XZ",
}

local function symmetryWord(p: any): string
	return (if isSelfSymmetric(p, "X") then "X" else "") .. (if isSelfSymmetric(p, "Z") then "Z" else "")
end

-- ── brute force for isSelfSymmetric ───────────────────────────────────────────────────────────────────────────

local SIDES = { 0.2, 0.3, 0.45, 0.6, 0.8 }
local ANGLES = { 0, 45, 90, 135, 180, -45, -90, -135 }
local AXES = { { 1, 0, 0 }, { 0, 1, 0 }, { 0, 0, 1 } }
local OFFSETS = { 0.01, -0.1, 0.4 }
local DIAGONALS = { 45, 135, -45, -135 }

-- Symmetric often, not by accident: square sides, quarter turns and 45° turns, mostly centred on the planes.
local function structuredPart(rng: TestRng, shape: string): any
	local a, b, c = rng:pick(SIDES), rng:pick(SIDES), rng:pick(SIDES)
	if rng:float() < 0.6 then
		c = a
	end
	local first, second = rng:pick(AXES), rng:pick(AXES)
	local q = aboutAxis(first[1], first[2], first[3], rng:pick(ANGLES))
	if rng:float() < 0.5 then
		q = Quat.hemisphere(Quat.mul(aboutAxis(second[1], second[2], second[3], rng:pick(ANGLES)), q))
	end
	-- A CornerWedge's one mirror plane holds its apex and a diagonal of its base: it needs a square base, and that diagonal
	-- on x = 0 or z = 0. Half of them are drawn so; left to the draws above, a seed can see as few as 9 symmetric cases.
	if shape == "CornerWedge" and rng:float() < 0.5 then
		c = a
		q = aboutAxis(0, 1, 0, rng:pick(DIAGONALS))
		if rng:float() < 0.5 then
			q = Quat.hemisphere(Quat.mul(aboutAxis(second[1], second[2], second[3], rng:pick(ANGLES)), q))
		end
	end
	local function offset(): number
		return if rng:float() < 0.8 then 0 else rng:pick(OFFSETS)
	end
	return part(shape, { offset(), rng:range(0.5, 4), offset() }, q, sizeFor(shape, a, b, c))
end

-- The solid's §4.3 distance field is unchanged by any symmetry of the solid, and differs almost everywhere otherwise.
local function fieldIsSymmetric(p: any, plane: Plane, rng: TestRng): boolean
	local s = solidOf(p)
	for _ = 1, 64 do
		local x, y, z = pointAround(rng, s)
		local rx, ry, rz = reflected(plane, x, y, z)
		if math.abs(sdOf(s, x, y, z) - sdOf(s, rx, ry, rz)) > 1e-9 then
			return false
		end
	end
	return true
end

return Test.suite("Blueprint/Mirror", function(t)
	t.it("T-BP-11 the module is frozen", function()
		A.truthy(table.isfrozen(Mirror), "module frozen")
	end)

	-- ── the solid ─────────────────────────────────────────────────────────────────────────────────────────────

	for _, shape in Gen.SHAPES do
		for _, plane: Plane in PLANES do
			local name = string.format("T-BP-11 %s across %s: inside(reflect(p), Mx) == inside(p, x), %d points", shape,
				plane, POINTS)
			t.it(name, function()
				local stats = newStats()
				Prop.check(PARTS, function(rng: TestRng): any
					return { part = randomPart(rng, shape), rng = rng }
				end, function(input: any)
					compare(input.part, reflect(input.part, plane), plane, input.rng, POINTS / PARTS, stats)
					A.eq(stats.mismatches, 0, "membership mismatches")
					A.truthy(stats.worst <= SD_TOL, string.format("|Δsd| %.3g", stats.worst))
					A.truthy(stats.gap <= SD_TOL, string.format("the oracles differ by %.3g", stats.gap))
				end)
				if Prop.only == nil then -- a --seed replay runs one part only
					A.truthy(stats.inside >= POINTS / 20, "too few points inside: " .. stats.inside)
					A.truthy(stats.outside >= POINTS / 20, "too few points outside: " .. stats.outside)
				end
			end)
		end
	end

	t.it("T-BP-11 the oracles catch planted wrong mirrors", function()
		local rng = TestRng.new(Tol.PROP_BASE_SEED)
		local function mismatches(p: any, m: any, plane: Plane): number
			local stats = newStats()
			compare(p, m, plane, rng, 2000, stats)
			return stats.mismatches
		end
		local corner = part("CornerWedge", { 0.3, 1, 0.1 }, aboutAxis(1, 2, 3, 40), WIDE)
		A.eq(mismatches(corner, reflect(corner, "X"), "X"), 0, "the real mirror")

		local noSwap = reflect(corner, "X")
		noSwap.size = table.clone(corner.size)
		A.truthy(mismatches(corner, noSwap, "X") > 100, "CornerWedge without the size swap")

		local q = corner.rot
		local wrongFactor = reflect(corner, "X")
		wrongFactor.rot = Quat.hemisphere(Quat.mul({ q[1], -q[2], -q[3], q[4] }, { 0, -H, 0, H }))
		A.truthy(mismatches(corner, wrongFactor, "X") > 100, "CornerWedge with the other plane's factor")

		local wedge = part("Wedge", { 0.1, 2, 0.05 }, aboutAxis(1, 0, 1, 25), PLANK)
		A.eq(mismatches(wedge, reflect(wedge, "Z"), "Z"), 0, "the real mirror")
		local unturned = reflect(wedge, "Z")
		unturned.rot = Quat.hemisphere({ -wedge.rot[1], -wedge.rot[2], wedge.rot[3], wedge.rot[4] })
		A.truthy(mismatches(wedge, unturned, "Z") > 100, "Wedge across Z without the half turn (right for a Block)")

		local block = part("Block", { 0.2, 1, 0 }, I, BALL)
		local unmoved = reflect(block, "X")
		unmoved.pos = table.clone(block.pos)
		A.truthy(mismatches(block, unmoved, "X") > 100, "position not negated")
	end)

	t.it("T-BP-11 reflect is M·R·F, det +1, sizes positive, per shape and plane (PROP_N)", function()
		local M: { [string]: { number } } = { X = { -1, 0, 0, 0, 1, 0, 0, 0, 1 }, Z = { 1, 0, 0, 0, 1, 0, 0, 0, -1 } }
		local F_PLAIN = { -1, 0, 0, 0, 1, 0, 0, 0, 1 } -- reflect local X
		local F_CORNER = { 0, 0, -1, 0, 1, 0, -1, 0, 0 } -- (x, y, z) → (−z, y, −x)
		A.eq(det(F_PLAIN), -1, "F is a reflection")
		A.eq(det(F_CORNER), -1, "F is a reflection")
		Prop.check(Tol.PROP_N, function(rng: TestRng): Q
			return Canonical.quat(Drafts.quat(rng))
		end, function(q: Q)
			for _, shape in Gen.SHAPES do
				for _, plane: Plane in PLANES do
					local m = reflect(part(shape, { 0.1, 2, -0.2 }, q, sizeFor(shape, 0.3, 0.4, 0.2)), plane)
					local F = if shape == "CornerWedge" then F_CORNER else F_PLAIN
					local want = times(times(M[plane], Gen.matrix(q)), F)
					local got = Gen.matrix(m.rot)
					local e = maxDiff(got, want)
					A.truthy(e <= 3e-15, string.format("%s %s: |R − M·R·F| = %.3g", shape, plane, e))
					A.truthy(math.abs(det(got) - 1) <= 1e-12, "a proper rotation")
					for k = 1, 3 do
						A.truthy(m.size[k] > 0, "no negative scale")
					end
				end
			end
		end)
	end)

	t.it("T-BP-11 closed forms worked by hand (§3.8's table, E-S6.7's rotZ(30°) example)", function()
		for n, row in FORMS do
			local m = reflect(part(row.shape, row.pos, row.rot, row.size), row.plane)
			local what = string.format("row %d (%s, %s)", n, row.shape, row.plane)
			same(m.pos, row.wantPos, what .. " pos")
			same(m.size, row.wantSize, what .. " size")
			same(m.rot, row.wantRot, what .. " rot")
		end
	end)

	t.it("T-BP-11 CornerWedge swaps X and Z sizes, its apex lands on its image; other shapes keep theirs", function()
		local p = part("CornerWedge", { 0.3, 1, 0 }, I, WIDE)
		-- local apex (+hx, +hy, −hz): world (0.5, 1.25, −0.1), the last of Gen's vertices
		local function apex(c: any): Gen.Vec
			local v = verticesOf(c)
			return v[#v]
		end
		A.truthy(maxDiff(apex(p), { 0.5, 1.25, -0.1 }) <= 1e-15, "the original's apex")
		A.truthy(maxDiff(apex(reflect(p, "X")), { -0.5, 1.25, -0.1 }) <= 1e-15, "across x = 0")
		A.truthy(maxDiff(apex(reflect(p, "Z")), { 0.5, 1.25, 0.1 }) <= 1e-15, "across z = 0")
		local others = { "Block", "Wedge", "Cylinder", "Ball" }
		Prop.check(Tol.PROP_N, function(rng: TestRng): { any }
			return { randomPart(rng, "CornerWedge"), randomPart(rng, rng:pick(others)) }
		end, function(parts: { any })
			local corner, other = parts[1], parts[2]
			for _, plane: Plane in PLANES do
				same(reflect(corner, plane).size, { corner.size[3], corner.size[2], corner.size[1] }, "(sz, sy, sx)")
				same(reflect(other, plane).size, other.size, "unchanged")
			end
		end)
	end)

	t.it("T-BP-11 polyhedra: the world vertices are the reflected vertices, one to one (PROP_N, E-S6.7)", function()
		Prop.check(Tol.PROP_N, function(rng: TestRng): { any }
			return oneOfEach(rng, POLYHEDRA)
		end, function(parts: { any })
			for _, p in parts do
				for _, plane: Plane in PLANES do
					local e = vertexError(verticesOf(reflect(p, plane)), imageOfVertices(p, plane))
					A.truthy(e <= 1e-14, string.format("%s %s: vertex error %.3g", p.shape, plane, e))
				end
			end
		end)
	end)

	t.it("T-BP-11 volume, centroid and extents are the image's, every shape (PROP_N, Gen's exact geometry)", function()
		Prop.check(Tol.PROP_N, function(rng: TestRng): { any }
			return oneOfEach(rng, Gen.SHAPES)
		end, function(parts: { any })
			for _, p in parts do
				for _, plane: Plane in PLANES do
					local m = reflect(p, plane)
					local what = p.shape .. " " .. plane
					A.rel(Gen.volume(m), Gen.volume(p), 1e-15, what .. " volume")
					local c = Gen.centroid(p)
					local x, y, z = reflected(plane, c[1], c[2], c[3])
					A.truthy(maxDiff(Gen.centroid(m), { x, y, z }) <= 1e-14, what .. " centroid")
					local lo, hi = Gen.aabb(p)
					local mlo, mhi = Gen.aabb(m)
					local k = if plane == "X" then 1 else 3
					-- a cylinder's extent takes sqrt(1 − u²), which magnifies the rounding of an axis near ±1 (1.24e-13 seen)
					local tolerance = if p.shape == "Cylinder" then 1e-12 else 1e-14
					for axis = 1, 3 do
						A.near(mlo[axis], if axis == k then -hi[axis] else lo[axis], tolerance, what .. " extent low")
						A.near(mhi[axis], if axis == k then -lo[axis] else hi[axis], tolerance, what .. " extent high")
					end
				end
			end
		end)
	end)

	t.it("T-BP-11 reflecting twice restores a part bit for bit, a CornerWedge's rotation to 1e-15 (PROP_N)", function()
		A.eq(H * H + H * H, 1.0000000000000002, "2·H² is one ulp over 1: why a CornerWedge's rotation only comes near")
		Prop.check(Tol.PROP_N, function(rng: TestRng): { any }
			return oneOfEach(rng, Gen.SHAPES)
		end, function(parts: { any })
			for _, p in parts do
				for _, plane: Plane in PLANES do
					local back = reflect(reflect(p, plane), plane)
					same(back.pos, p.pos, p.shape .. " pos")
					same(back.size, p.size, p.shape .. " size")
					if p.shape == "CornerWedge" then
						local e = maxDiff(back.rot, p.rot)
						A.truthy(e <= 1e-15, string.format("%s %s: rotation off by %.3g", p.shape, plane, e))
					else
						same(back.rot, p.rot, p.shape .. " " .. plane .. " rot")
					end
				end
			end
		end)
	end)

	t.it("T-BP-11 across X then Z is the half turn about Y through the origin, in either order (PROP_N)", function()
		Prop.check(Tol.PROP_N, function(rng: TestRng): { any }
			return { oneOfEach(rng, Gen.SHAPES), rng }
		end, function(input: { any })
			local rng: TestRng = input[2]
			for _, p in input[1] :: { any } do
				for _, m in { reflect(reflect(p, "X"), "Z"), reflect(reflect(p, "Z"), "X") } do
					local a, b = solidOf(p), solidOf(m)
					for _ = 1, 25 do
						local x, y, z = pointAround(rng, a)
						A.near(sdOf(b, -x, y, -z), sdOf(a, x, y, z), SD_TOL, p.shape)
					end
				end
			end
		end)
	end)

	-- ── the record ────────────────────────────────────────────────────────────────────────────────────────────

	t.it("T-BP-11 a new record: same id, slot, shape, material, known fields only, no shared table (PROP_N)", function()
		Prop.check(Tol.PROP_N, function(rng: TestRng): any
			local p = randomPart(rng, rng:pick(Gen.SHAPES))
			p.extra = "dropped"
			return p
		end, function(p: any)
			local before = Drafts.deepCopy(p)
			for _, plane: Plane in PLANES do
				local m = reflect(p, plane)
				A.eq(m.id, p.id, "the caller assigns new ids")
				A.eq(m.slot, p.slot)
				A.eq(m.shape, p.shape)
				A.eq(m.material, p.material)
				A.eq(table.concat(Dump.sortedKeys(m), ","), "id,material,pos,rot,shape,size,slot", "known fields only")
				A.falsy(Drafts.sharesTable(m, p), "no table shared with the input")
				A.falsy(Drafts.repeatsTable(m), "no table repeated inside the record")
				same(reflect(p, plane), m, "P-DET")
				for k = 1, 3 do
					A.finite(m.pos[k], "P-FINITE")
					A.finite(m.size[k], "P-FINITE")
				end
				same(p, before, "P-NOMUT")
			end
		end)
	end)

	t.it("T-BP-11 frozen input is enough: F1–F5 are deep-frozen, reflect and isSelfSymmetric only read them", function()
		for _, id in Blueprints.order do
			for _, p in Blueprints.get(id).core.parts do
				for _, plane: Plane in PLANES do
					reflect(p, plane)
					isSelfSymmetric(p, plane)
				end
			end
		end
	end)

	t.it("T-BP-11 output in the hemisphere, no −0: qw = 0 rotations, −0 positions and parts on the plane", function()
		local turns: { Q } =
			{ I, { 1, 0, 0, 0 }, Y180, { 0, 0, 1, 0 }, { 0, H, H, 0 }, { H, 0, -H, 0 }, { 0, H, -H, 0 } }
		for _, shape in Gen.SHAPES do
			for _, plane: Plane in PLANES do
				for _, q in turns do
					local m = reflect(part(shape, AT_Y, q, BALL), plane)
					A.truthy(noNegativeZero(m.pos), "pos: " .. shape .. " " .. plane)
					A.truthy(noNegativeZero(m.rot), "rot: " .. shape .. " " .. plane)
					same(Quat.hemisphere(m.rot), m.rot, "a fixed point of the hemisphere rule")
				end
			end
		end
		-- −0 in the input (not canonical, but cheap to keep out of the output)
		local p = part("Block", { -0.0, -0.0, -0.0 }, I, BALL)
		for _, plane: Plane in PLANES do
			A.truthy(noNegativeZero(reflect(p, plane).pos), "−0 " .. plane)
		end
		-- the sign rule applies to the result: {0, 0, 1, 0} across X is first {0, 0, −1, 0}
		same(reflect(part("Block", AT_Y, { 0, 0, 1, 0 }, BALL), "X").rot, { 0, 0, 1, 0 }, "C4 on qw = 0")
	end)

	t.it("T-BP-11 F1–F5 mirrored stay canonical, ids in order, with the same margin to the hitbox", function()
		for _, id in Blueprints.order do
			local core = Blueprints.core(id)
			for _, plane: Plane in PLANES do
				local m = mirroredCore(core, plane)
				expectCanonical(m, id .. " across " .. plane)
				A.near(Gen.margin(CTX, m.parts), Gen.margin(CTX, core.parts), 1e-15, "the hitbox is centred on it")
			end
		end
	end)

	t.it("T-BP-11 mirrored Gen.validSword designs stay canonical and inside (PROP_N)", function()
		Prop.check(Tol.PROP_N, function(rng: TestRng): any
			return Gen.validSword(rng, CTX)
		end, function(core: any)
			for _, plane: Plane in PLANES do
				local m = mirroredCore(core, plane)
				expectCanonical(m, "across " .. plane)
				A.near(Gen.margin(CTX, m.parts), Gen.margin(CTX, core.parts), 1e-14, "margin to the hitbox")
			end
		end)
	end)

	t.it("T-BP-11 mirrored editor documents stay canonical, as the tool needs (PROP_N, §11.10)", function()
		Prop.check(Tol.PROP_N, function(rng: TestRng): any
			return Drafts.editorDraft(rng, Quat, Canonical)
		end, function(core: any)
			for _, plane: Plane in PLANES do
				expectCanonical(mirroredCore(core, plane), "across " .. plane)
			end
		end)
	end)

	t.it("T-BP-11 any canonical part mirrors within the bounds; Canonical moves q by at most C3 (PROP_N)", function()
		Prop.check(Tol.PROP_N, function(rng: TestRng): any
			local r: any = Canonical.draft(Drafts.validDraft(rng))
			assert(r.ok, "validDraft passes §3.6")
			return r.value
		end, function(core: any)
			for _, plane: Plane in PLANES do
				local m = mirroredCore(core, plane)
				local r: any = Canonical.draft(m)
				A.truthy(r.ok, "accepted")
				for i, p in r.value.parts do
					same(p.pos, m.parts[i].pos, "pos")
					same(p.size, m.parts[i].size, "size")
					A.truthy(maxDiff(p.rot, m.parts[i].rot) <= 1e-8, "only a renormalization at QUAT_NORM_TOL")
				end
			end
		end)
	end)

	t.it("T-BP-11 a plane other than X or Z is a caller's bug", function()
		local p = part("Block", AT_Y, I, BALL)
		local bad: { any } = { "Y", "x", "", 1, false }
		for k = 1, #bad + 1 do -- the last one is nil
			A.throws(function()
				reflect(p, bad[k])
			end, "plane")
			A.throws(function()
				isSelfSymmetric(p, bad[k])
			end, "plane")
		end
	end)

	-- ── isSelfSymmetric ───────────────────────────────────────────────────────────────────────────────────────

	t.it("T-BP-11 isSelfSymmetric: the shapes' own symmetries, worked by hand", function()
		for _, c in SYM_CASES do
			local p = part(c.shape, c.pos, c.rot, c.size)
			A.eq(isSelfSymmetric(p, "X"), c.x, c.shape .. " across X: " .. c.what)
			A.eq(isSelfSymmetric(p, "Z"), c.z, c.shape .. " across Z: " .. c.what)
		end
	end)

	t.it("T-BP-11 isSelfSymmetric: per part of F1–F5", function()
		for _, id in Blueprints.order do
			local words: { string } = {}
			for _, p in Blueprints.get(id).core.parts do
				table.insert(words, symmetryWord(p))
			end
			A.eq(table.concat(words, " "), FIXTURE_SYMMETRY[id], id)
		end
	end)

	t.it("T-BP-11 isSelfSymmetric compares solids, not records: a Block at z = 0 mirrors to another q", function()
		local p = part("Block", AT_Y, I, BOX)
		local m = reflect(p, "Z")
		same(m.rot, Y180, "the half turn of the closed form")
		A.truthy(Drafts.bitDiff(m, p) ~= nil, "a different record")
		A.truthy(isSelfSymmetric(p, "Z"), "the same solid")
		A.truthy(vertexError(verticesOf(m), verticesOf(p)) <= 1e-15, "the same vertices")
	end)

	t.it("T-BP-11 isSelfSymmetric: off the plane by more than EPS_GEOM / 2 is not its own image, any shape", function()
		for _, shape in Gen.SHAPES do
			for _, plane: Plane in PLANES do
				-- an orientation in which this shape is symmetric across this plane
				local rot = I
				if shape == "Wedge" and plane == "Z" then
					rot = Y90
				elseif shape == "CornerWedge" then
					rot = if plane == "X" then Y45 else YM45
				end
				local size = if shape == "CornerWedge" then SQUARE else BALL
				local k = if plane == "X" then 1 else 3
				for _, offset in { 0.45 * EPS_GEOM, -0.45 * EPS_GEOM, 0.55 * EPS_GEOM, -0.55 * EPS_GEOM } do
					local pos = { 0, 1, 0 }
					pos[k] = offset
					A.eq(isSelfSymmetric(part(shape, pos, rot, size), plane), math.abs(offset) < 0.5 * EPS_GEOM,
						string.format("%s across %s at %+.3g", shape, plane, offset))
				end
			end
		end
	end)

	t.it("T-BP-11 isSelfSymmetric: a block's tilt counts by what moves at its corners", function()
		-- hx = 0.4, hy = 0.3: tilted α about Z, a corner lands 2·0.5·sin α from the one it should, so the limit is α = EPS_GEOM
		for _, c in { { radians = 0.9 * EPS_GEOM, own = true }, { radians = 1.1 * EPS_GEOM, own = false } } do
			A.eq(isSelfSymmetric(part("Block", AT_Y, aboutAxis(0, 0, 1, math.deg(c.radians)), { 0.8, 0.6, 0.1 }), "X"), c.own)
		end
	end)

	t.it("T-BP-11 isSelfSymmetric: a cylinder's tilt counts by what moves at its rim, also near the normal", function()
		-- hx = 0.4, r = 0.3: a point of the solid lies up to 0.5 from the centre. An axis α off the plane or the normal
		-- is 2α off its image, which moves that point by 2·0.5·sin α, so the limit is α = EPS_GEOM.
		local size = { 0.8, 0.6, 0.6 }
		for _, c in { { radians = 0.9 * EPS_GEOM, own = true }, { radians = 1.1 * EPS_GEOM, own = false } } do
			local tilt = aboutAxis(0, 0, 1, math.deg(c.radians))
			local inPlane = Quat.hemisphere(Quat.mul(tilt, Z90)) -- axis in the plane x = 0, tilted out of it
			local atNormal = tilt -- axis along the normal of x = 0, tilted off it
			A.eq(isSelfSymmetric(part("Cylinder", AT_Y, inPlane, size), "X"), c.own, "axis in the plane, tilted")
			A.eq(isSelfSymmetric(part("Cylinder", AT_Y, atNormal, size), "X"), c.own, "axis along the normal, tilted")
		end
		-- the largest cylinder on exact turns: rounding noise (≈ 1e-16 in the axis) stays far below EPS_GEOM
		local big = { Limits.MAX_DIM, Limits.MAX_DIM, Limits.MAX_DIM }
		local top = { 0, Limits.POS_ABS_MAX, 0 }
		local turns: { Q } = { I, Y90, Z90, { 0, -H, 0, H }, { 0, 0, -H, H }, { 0, 0, 1, 0 }, Y180, { 1, 0, 0, 0 } }
		for _, q in turns do
			for _, plane: Plane in PLANES do
				A.truthy(isSelfSymmetric(part("Cylinder", top, q, big), plane),
					"MAX_DIM at POS_ABS_MAX, " .. Dump.short(q) .. " across " .. plane)
			end
		end
	end)

	for _, shape in Gen.SHAPES do
		t.it(string.format("T-BP-11 isSelfSymmetric = the %s equals its image, brute force (PROP_N)", shape), function()
			local trues, falses = 0, 0
			Prop.check(Tol.PROP_N, function(rng: TestRng): any
				return { part = structuredPart(rng, shape), rng = rng }
			end, function(input: any)
				local p, rng = input.part, input.rng
				for _, plane: Plane in PLANES do
					local said = isSelfSymmetric(p, plane)
					A.eq(said, fieldIsSymmetric(p, plane, rng), "against the distance field across " .. plane)
					if said then
						trues += 1
					else
						falses += 1
					end
					local m = reflect(p, plane)
					A.eq(isSelfSymmetric(m, plane), said, "the image of a symmetric part is symmetric, and only then")
					local negated = part(shape, p.pos, { -p.rot[1], -p.rot[2], -p.rot[3], -p.rot[4] }, p.size)
					A.eq(isSelfSymmetric(negated, plane), said, "q ≡ −q")
					if said and shape ~= "Ball" and shape ~= "Cylinder" then
						A.truthy(vertexError(verticesOf(m), verticesOf(p)) <= 2 * EPS_GEOM, "the copy would coincide")
					end
				end
			end)
			if Prop.only == nil then
				A.truthy(trues >= 20, "too few symmetric cases: " .. trues)
				A.truthy(falses >= 20, "too few asymmetric cases: " .. falses)
			end
		end)
	end

	t.it("T-BP-11 isSelfSymmetric is false on generic parts, and P-NOMUT, P-DET (PROP_N)", function()
		Prop.check(Tol.PROP_N, function(rng: TestRng): any
			local q = aboutAxis(rng:range(0.2, 1), rng:range(0.2, 1), rng:range(0.2, 1), rng:range(5, 40))
			return part(rng:pick(Gen.SHAPES), { rng:range(0.01, 0.5), 1, rng:range(0.01, 0.2) }, q,
				{ rng:range(0.1, 0.3), rng:range(0.4, 0.6), rng:range(0.7, 0.9) })
		end, function(p: any)
			local before = Drafts.deepCopy(p)
			for _, plane: Plane in PLANES do
				A.falsy(isSelfSymmetric(p, plane), "off the plane and tilted")
				A.falsy(isSelfSymmetric(p, plane), "P-DET")
			end
			same(p, before, "P-NOMUT")
		end)
	end)
end)
