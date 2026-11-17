--!strict
-- tests/Physics/PhysicsHelpers.luau — what the Physics specs share (T-PHY, T-VAL). Not a spec (the runner loads
-- *.spec.luau only). Trigonometry is fine here: tests are outside the authoritative folders of T-META-03.
--   part, core, f, copy         designs: PartData records with plain string ids (tests/fixtures/Build's shape)
--   prepared, measure           a design's Prepared parts; its mass properties without Analyze, so a design rotated out
--                               of the hitbox can still be measured (T-PHY-05)
--   axisAngle, randomQuat,      rotations: T-PHY-05's rotated designs, random parts
--   rotated
--   insideLocal                 SPEC §3.2's solids, written from the table, independent of Physics/Shapes
--   closestPoint,               the exact closest point of a solid and distance to it, independent of Gjk and of Shapes.sd
--   distanceToSolid
--   bruteDistance               the smallest distance from either solid's surface samples and vertices to the other
--                               (T-VAL-03's brute force)
--   gapByProjections            the gap of two solids by alternating projections (T-VAL-03's answer at the legal extremes)
--   p1                          24 large overlapping tilted blocks (the shape of S2's adversarial cost fixture, E-S2.8)
--   ornate                      C09's 18 parts (E-S2.9): valid, nothing cleaned, and N_SUB_WORK runs out in the measure
--   anyDesign                   any canonical design inside the hitbox, within the slot rules: no sword about it
--   plantedSampling             Physics/Sampling (and its Cover) on planted Balance.Geometry fields
--   hidersOf, reads             the verdict's hiders of a part, as Sampling hands them to Cover; what it reads, whole
--   partsUnder, underLids       a plate whose top alone shows, under lids: what shows has a closed form
--   verdictReads                what the verdict reads on a part, bracketed by a planted ENCLOSED_EXPOSED_MAX
--   sameKeptMeasure             two designs' kept parts measure the same, to the bit
--   finite                      every number in a value is finite (P-FINITE)

local A = require("../lib/Assert")
local TestRng = require("../lib/TestRng")
local Drafts = require("../Blueprint/Drafts")
local Blueprints = require("../fixtures/Blueprints")
local Build = require("../fixtures/Build")
local Balance = require("../../src/shared/Definitions/Balance")
local EquipmentTypes = require("../../src/shared/Definitions/EquipmentTypes")
local Limits = require("../../src/shared/Definitions/Limits")
local Quat = require("../../src/shared/Blueprint/Quat")
local Cover = require("../../src/shared/Physics/Cover")
local MassProps = require("../../src/shared/Physics/MassProps")
local Sampling = require("../../src/shared/Physics/Sampling")
local Shapes = require("../../src/shared/Physics/Shapes")

type Rng = TestRng.TestRng
type Prepared = Shapes.Prepared

local H = {}

H.I = Build.I
H.Z45 = Build.Z45
H.Z90 = Build.Z90
H.Y90 = Build.Y90
H.Y45 = Build.Y45

H.part = Build.part

function H.core(name: string, parts: { Build.Part }): any
	return Build.core(name, parts)
end

-- A fresh mutable copy of a fixture's core.
function H.f(id: string): any
	return Blueprints.core(id)
end

-- A lone part of `shape` in `slot`, at pos, in Iron.
function H.solid(id: number, shape: string, pos: { number }, rot: { number }, size: { number }, slot: string?): any
	return Build.part(id, slot or "Blade", shape, "Iron", pos, rot, size)
end

function H.prepared(core: any): { Prepared }
	local out: { Prepared } = {}
	for i, p in ipairs(core.parts) do
		out[i] = Shapes.prepare(p, i)
	end
	return out
end

function H.prepare(part: any, index: number?): Prepared
	return Shapes.prepare(part, index or 1)
end

local function rankOf(typeDef: any): { [string]: number }
	local out: { [string]: number } = {}
	for _, slot in ipairs(typeDef.slots) do
		out[slot.id] = slot.rank
	end
	return out
end

-- The mass properties of any design, inside the hitbox or not: exposure, ownership and report, no validation.
function H.measure(core: any): (any, any, any)
	local typeDef: any = EquipmentTypes.get("Sword")
	local parts = H.prepared(core)
	local exposure = Sampling.exposure(parts)
	local owned = MassProps.ownership(parts, exposure.kept, rankOf(typeDef))
	local point, axis = MassProps.physicsFrame(parts, exposure.kept, typeDef.geometry.gripSlot)
	return MassProps.report(parts, exposure.kept, owned, typeDef.geometry, point, axis), exposure, owned
end

function H.ranks(): { [string]: number }
	return rankOf(EquipmentTypes.get("Sword"))
end

-- ── rotations ─────────────────────────────────────────────────────────────────────────────────────────────────────

function H.axisAngle(ax: number, ay: number, az: number, degrees: number): { number }
	local half = math.rad(degrees) / 2
	local s = math.sin(half)
	local n = math.sqrt(ax * ax + ay * ay + az * az)
	return Quat.hemisphere(Quat.normalize({ ax / n * s, ay / n * s, az / n * s, math.cos(half) }))
end

-- A uniform unit quaternion (Marsaglia), in the hemisphere of §3.5 C4.
function H.randomQuat(rng: Rng): { number }
	while true do
		local a, b = rng:range(-1, 1), rng:range(-1, 1)
		local c, d = rng:range(-1, 1), rng:range(-1, 1)
		local s1, s2 = a * a + b * b, c * c + d * d
		if s1 < 1 and s1 > 1e-4 and s2 < 1 and s2 > 1e-4 then
			local k = math.sqrt((1 - s1) / s2)
			return Quat.hemisphere(Quat.normalize({ a, b, c * k, d * k }))
		end
	end
end

-- The design turned by q about pivot, every part with a canonical quaternion.
function H.rotated(core: any, q: { number }, pivot: { number }): any
	local out = Build.copy(core)
	for _, p in ipairs(out.parts) do
		local r = Quat.rotate(q, { p.pos[1] - pivot[1], p.pos[2] - pivot[2], p.pos[3] - pivot[3] })
		p.pos = { pivot[1] + r[1], pivot[2] + r[2], pivot[3] + r[3] }
		p.rot = Quat.hemisphere(Quat.normalize(Quat.mul(q, p.rot)))
	end
	return out
end

-- ── SPEC §3.2, independently ──────────────────────────────────────────────────────────────────────────────────────

-- Is the local point in the solid? Normalized a = x/hx, b = y/hy, c = z/hz, as §3.2's table writes it.
function H.insideLocal(shape: string, size: { number }, x: number, y: number, z: number): boolean
	local hx, hy, hz = size[1] / 2, size[2] / 2, size[3] / 2
	if shape == "Ball" then
		local r = math.min(hx, hy, hz)
		return x * x + y * y + z * z <= r * r
	elseif shape == "Cylinder" then
		local r = math.min(hy, hz)
		return math.abs(x) <= hx and y * y + z * z <= r * r
	end
	local a, b, c = x / hx, y / hy, z / hz
	if math.abs(a) > 1 or math.abs(b) > 1 or math.abs(c) > 1 then
		return false
	end
	if shape == "Wedge" then
		return c >= b
	elseif shape == "CornerWedge" then
		return b <= a and b <= -c
	end
	return true
end

-- The closest point of triangle abc to p (Ericson, Real-Time Collision Detection), written for the test.
local function closestOnTriangle(px: number, py: number, pz: number, a: { number }, b: { number }, c: { number }): (number, number, number)
	local abx, aby, abz = b[1] - a[1], b[2] - a[2], b[3] - a[3]
	local acx, acy, acz = c[1] - a[1], c[2] - a[2], c[3] - a[3]
	local apx, apy, apz = px - a[1], py - a[2], pz - a[3]
	local d1 = abx * apx + aby * apy + abz * apz
	local d2 = acx * apx + acy * apy + acz * apz
	local qx, qy, qz
	if d1 <= 0 and d2 <= 0 then
		qx, qy, qz = a[1], a[2], a[3]
	else
		local bpx, bpy, bpz = px - b[1], py - b[2], pz - b[3]
		local d3 = abx * bpx + aby * bpy + abz * bpz
		local d4 = acx * bpx + acy * bpy + acz * bpz
		local cpx, cpy, cpz = px - c[1], py - c[2], pz - c[3]
		local d5 = abx * cpx + aby * cpy + abz * cpz
		local d6 = acx * cpx + acy * cpy + acz * cpz
		local vc = d1 * d4 - d3 * d2
		local vb = d5 * d2 - d1 * d6
		local va = d3 * d6 - d5 * d4
		if d3 >= 0 and d4 <= d3 then
			qx, qy, qz = b[1], b[2], b[3]
		elseif vc <= 0 and d1 >= 0 and d3 <= 0 then
			local t = d1 / (d1 - d3)
			qx, qy, qz = a[1] + t * abx, a[2] + t * aby, a[3] + t * abz
		elseif d6 >= 0 and d5 <= d6 then
			qx, qy, qz = c[1], c[2], c[3]
		elseif vb <= 0 and d2 >= 0 and d6 <= 0 then
			local t = d2 / (d2 - d6)
			qx, qy, qz = a[1] + t * acx, a[2] + t * acy, a[3] + t * acz
		elseif va <= 0 and d4 - d3 >= 0 and d5 - d6 >= 0 then
			local t = (d4 - d3) / ((d4 - d3) + (d5 - d6))
			qx, qy, qz = b[1] + t * (c[1] - b[1]), b[2] + t * (c[2] - b[2]), b[3] + t * (c[3] - b[3])
		else
			local sum = va + vb + vc
			local v, w = vb / sum, vc / sum
			qx, qy, qz = a[1] + abx * v + acx * w, a[2] + aby * v + acy * w, a[3] + abz * v + acz * w
		end
	end
	return qx, qy, qz
end

-- The point of a part's solid closest to a world point (the point itself inside): closed forms for Block, Cylinder and
-- Ball, the closest face triangle for Wedge and CornerWedge.
function H.closestPoint(P: Prepared, x: number, y: number, z: number): (number, number, number)
	local lx, ly, lz = Shapes.toLocal(P, x, y, z)
	if P.shape == "Ball" then
		local m = math.sqrt(lx * lx + ly * ly + lz * lz)
		if m <= P.r then
			return x, y, z
		end
		return Shapes.toWorld(P, lx * P.r / m, ly * P.r / m, lz * P.r / m)
	elseif P.shape == "Cylinder" then
		local m = math.sqrt(ly * ly + lz * lz)
		if m <= P.r and math.abs(lx) <= P.hx then
			return x, y, z
		elseif m > P.r then
			ly, lz = ly * P.r / m, lz * P.r / m
		end
		return Shapes.toWorld(P, math.clamp(lx, -P.hx, P.hx), ly, lz)
	elseif P.shape == "Block" then
		if math.abs(lx) <= P.hx and math.abs(ly) <= P.hy and math.abs(lz) <= P.hz then
			return x, y, z
		end
		return Shapes.toWorld(P, math.clamp(lx, -P.hx, P.hx), math.clamp(ly, -P.hy, P.hy), math.clamp(lz, -P.hz, P.hz))
	end
	if H.insideLocal(P.shape, { 2 * P.hx, 2 * P.hy, 2 * P.hz }, lx, ly, lz) then
		return x, y, z
	end
	local best, bx, by, bz = math.huge, x, y, z
	for _, poly in ipairs(Shapes.faces(P)) do
		local a = { poly[1], poly[2], poly[3] }
		for i = 1, #poly / 3 - 2 do
			local b = { poly[3 * i + 1], poly[3 * i + 2], poly[3 * i + 3] }
			local c = { poly[3 * i + 4], poly[3 * i + 5], poly[3 * i + 6] }
			local qx, qy, qz = closestOnTriangle(x, y, z, a, b, c)
			local dx, dy, dz = x - qx, y - qy, z - qz
			local d2 = dx * dx + dy * dy + dz * dz
			if d2 < best then
				best, bx, by, bz = d2, qx, qy, qz
			end
		end
	end
	return bx, by, bz
end

-- The exact distance from a world point to a part's solid: exactly 0 inside.
function H.distanceToSolid(P: Prepared, x: number, y: number, z: number): number
	local lx, ly, lz = Shapes.toLocal(P, x, y, z)
	if P.shape == "Ball" then
		return math.max(0, math.sqrt(lx * lx + ly * ly + lz * lz) - P.r)
	elseif P.shape == "Cylinder" then
		local dx = math.max(0, math.abs(lx) - P.hx)
		local dr = math.max(0, math.sqrt(ly * ly + lz * lz) - P.r)
		return math.sqrt(dx * dx + dr * dr)
	elseif P.shape == "Block" then
		local dx = math.max(0, math.abs(lx) - P.hx)
		local dy = math.max(0, math.abs(ly) - P.hy)
		local dz = math.max(0, math.abs(lz) - P.hz)
		return math.sqrt(dx * dx + dy * dy + dz * dz)
	end
	local qx, qy, qz = H.closestPoint(P, x, y, z)
	local dx, dy, dz = x - qx, y - qy, z - qz
	return math.sqrt(dx * dx + dy * dy + dz * dz)
end

-- An upper bound on the gap of two solids from alternating projections, x = P_a(P_b(x)): each step holds a point of each
-- solid and the steps converge to a closest pair, so the distance it returns falls toward the gap. It shares no support
-- function and no simplex with GJK. On thin solids and nearly parallel faces it crawls and stops short, by up to about
-- 0.01: so it can prove a longer answer wrong, and never a shorter one.
function H.gapByProjections(a: Prepared, b: Prepared): number
	local x, y, z = a.gx, a.gy, a.gz
	local gap = math.huge
	for k = 1, 5000 do
		local bx, by, bz = H.closestPoint(b, x, y, z)
		local ax, ay, az = H.closestPoint(a, bx, by, bz)
		local dx, dy, dz = ax - bx, ay - by, az - bz
		local d = math.sqrt(dx * dx + dy * dy + dz * dz)
		if d == 0 or (k > 8 and gap - d < 1e-13) then
			return d
		end
		gap = d
		x, y, z = ax, ay, az
	end
	return gap
end

-- min over a's surface samples and vertices of the exact distance to b.
local function samplesToSolid(a: Prepared, b: Prepared): number
	local S = Sampling.surfaceSamples(a, 0.005)
	local best = math.huge
	local function see(x: number, y: number, z: number)
		if Shapes.sd(b, x, y, z) < best then -- sd is a lower bound of the distance
			best = math.min(best, H.distanceToSolid(b, x, y, z))
		end
	end
	for k = 1, S.n do
		see(S.x[k], S.y[k], S.z[k])
	end
	local wv = a.wverts
	for i = 1, #wv, 3 do
		see(wv[i], wv[i + 1], wv[i + 2])
	end
	return best
end

-- The smallest distance from either solid's surface samples and vertices to the other solid, or 0 when the solids overlap.
-- It is at most the true distance + the samples' spacing error, so it decides only outside a band of about that error.
-- Both ways, and with the vertices: a CornerWedge's apex has no surface sample within a cell of it, and a cylinder's side
-- has 32 directions at most, so one solid's samples alone can miss by 0.012 where the other's do not (worst both ways
-- without the vertices 0.0071, with them 0.0026, 24 seeds × 300 pairs).
function H.bruteDistance(a: Prepared, b: Prepared): number
	if H.distanceToSolid(a, b.gx, b.gy, b.gz) == 0 or H.distanceToSolid(b, a.gx, a.gy, a.gz) == 0 then
		return 0
	end
	return math.min(samplesToSolid(a, b), samplesToSolid(b, a))
end

-- ── a budget stress case ──────────────────────────────────────────────────────────────────────────────────────────

-- 24 large overlapping tilted blocks: slots by height, every pair overlaps, inside the hitbox.
function H.p1(): any
	local slots = { "Pommel", "Pommel", "Grip", "Grip", "Guard", "Guard", "Guard", "Guard", "Guard", "Guard", "Guard",
		"Guard", "Blade", "Blade", "Blade", "Blade", "Blade", "Blade", "Blade", "Blade", "Blade", "Blade", "Blade", "Blade" }
	local parts: { Build.Part } = {}
	for i = 1, 24 do
		local q = Quat.mul(H.axisAngle(0, 0, 1, -8 + 16 * ((i * 7) % 24) / 23), H.axisAngle(0, 1, 0, -4 + 8 * ((i * 5) % 24) / 23))
		parts[i] = Build.part(i, slots[i], "Block", "Iron", { 0, 1.9 + 0.05 * i, 0 }, Quat.hemisphere(q),
			{ 1.0, 3.5 - 0.01 * i, 0.40 })
	end
	return Build.core("P1", parts)
end

-- C09 Ornate, as docs/spec/prototypes/S2/v2/fixtures builds it, until M3 brings the calibration fixtures: a sword whose
-- ribbed blade and capped grip spend the whole sub-grid budget before the measure ends (T-PHY-09).
function H.ornate(): any
	local I, Z90, Y90 = H.I, H.Z90, H.Y90
	local YNEG90 = { 0, -Y90[2], 0, Y90[4] }
	local S5, C5 = 0.08715574274765817, 0.9961946980917455 -- half of 10° about Z
	local RIB = { 2.4, 0.03, 0.05 }
	local CAP = { 0.04, 0.19, 0.19 }
	local QUILLON = { 0.4, 0.1, 0.14 }
	local TIP = { 0.06, 0.4, 0.11 }
	local function ball(id: number, slot: string, pos: { number }, d: number): Build.Part
		return Build.part(id, slot, "Ball", "Iron", pos, I, { d, d, d })
	end
	return Build.core("C09", {
		ball(1, "Pommel", { 0, 0.3, 0 }, 0.26),
		ball(2, "Pommel", { 0, 0.14, 0 }, 0.1),
		Build.part(3, "Grip", "Cylinder", "Iron", { 0, 0.88, 0 }, Z90, { 0.9, 0.15, 0.15 }),
		Build.part(4, "Grip", "Cylinder", "Iron", { 0, 0.6, 0 }, Z90, CAP),
		Build.part(5, "Grip", "Cylinder", "Iron", { 0, 0.88, 0 }, Z90, CAP),
		Build.part(6, "Grip", "Cylinder", "Iron", { 0, 1.16, 0 }, Z90, CAP),
		Build.part(7, "Guard", "Block", "Iron", { 0, 1.41, 0 }, I, { 0.3, 0.18, 0.26 }),
		Build.part(8, "Guard", "Block", "Iron", { 0.33, 1.43, 0 }, { 0, 0, S5, C5 }, QUILLON),
		Build.part(9, "Guard", "Block", "Iron", { -0.33, 1.43, 0 }, { 0, 0, -S5, C5 }, QUILLON),
		ball(10, "Guard", { 0.56, 1.47, 0 }, 0.14),
		ball(11, "Guard", { -0.56, 1.47, 0 }, 0.14),
		Build.part(12, "Blade", "Block", "Iron", { 0, 2.6, 0 }, I, { 0.12, 2.4, 0.06 }),
		Build.part(13, "Blade", "Wedge", "Iron", { 0.085, 2.6, 0.015 }, { 0.5, -0.5, -0.5, 0.5 }, RIB),
		Build.part(14, "Blade", "Wedge", "Iron", { 0.085, 2.6, -0.015 }, { -0.5, -0.5, 0.5, 0.5 }, RIB),
		Build.part(15, "Blade", "Wedge", "Iron", { -0.085, 2.6, 0.015 }, { 0.5, 0.5, 0.5, 0.5 }, RIB),
		Build.part(16, "Blade", "Wedge", "Iron", { -0.085, 2.6, -0.015 }, { -0.5, 0.5, -0.5, 0.5 }, RIB),
		Build.part(17, "Blade", "Wedge", "Iron", { 0.055, 4, 0 }, YNEG90, TIP),
		Build.part(18, "Blade", "Wedge", "Iron", { -0.055, 4, 0 }, Y90, TIP),
	})
end

-- 2..24 random parts of every shape and size, from MIN_DIM up, anywhere inside the hitbox: overlapping, enclosed, afloat.
function H.anyDesign(rng: Rng): any
	local slotMax = { Blade = 12, Guard = 8, Grip = 6, Pommel = 4 }
	local slotCount = { Blade = 1, Grip = 1, Guard = 0, Pommel = 0 }
	local shapes = { "Block", "Wedge", "CornerWedge", "Cylinder", "Ball" }
	local slots: { string } = { "Blade", "Blade", "Blade", "Grip", "Grip", "Guard", "Pommel" }
	local function side(): number
		local r = rng:float()
		if r < 0.2 then
			return 0.02
		elseif r < 0.4 then
			return rng:range(0.02, 0.1)
		elseif r < 0.95 then
			return rng:range(0.05, 1.2)
		end
		return rng:range(1, 6)
	end
	local parts: { Build.Part } = {}
	for i = 1, rng:int(2, 24) do
		local shape = rng:pick(shapes)
		local size = { side(), side(), side() }
		if shape == "Ball" then
			local d = math.min(size[1], size[2], size[3])
			size = { d, d, d }
		elseif shape == "Cylinder" then
			local d = math.min(size[2], size[3])
			size = { size[1], d, d }
		end
		local slot = if i == 1 then "Blade" elseif i == 2 then "Grip" else rng:pick(slots)
		if i > 2 then
			if slotCount[slot] >= slotMax[slot] then
				slot = if slotCount.Guard < slotMax.Guard then "Guard" else "Blade"
			end
			slotCount[slot] += 1
		end
		local rot = if rng:float() < 0.4 then Build.I else H.randomQuat(rng)
		local part = Build.part(i, slot, shape, rng:pick({ "Iron", "Steel" }), { 0, 2.5, 0 }, rot, size)
		-- shrink until the exact extents fit the hitbox (1.6 × 5 × 0.6), then place it anywhere they allow
		local lo, hi = Shapes.aabb(part :: any)
		while hi[1] - lo[1] > 1.6 or hi[2] - lo[2] > 5 or hi[3] - lo[3] > 0.6 do
			for k = 1, 3 do
				part.size[k] = math.max(0.02, part.size[k] * 0.7)
			end
			lo, hi = Shapes.aabb(part :: any)
		end
		part.pos = {
			rng:range(-0.8 - lo[1], 0.8 - hi[1]),
			2.5 + rng:range(0 - lo[2], 5 - hi[2]),
			rng:range(-0.3 - lo[3], 0.3 - hi[3]),
		}
		parts[i] = part
	end
	return Build.core("any", parts)
end

-- ── the verdict and the measure ───────────────────────────────────────────────────────────────────────────────────

-- Sampling on planted Definitions: the real module and its Cover, except the Balance.Geometry fields in `overrides`.
function H.plantedSampling(overrides: { [string]: any }): any
	local geometry: any = {}
	for k, v in Balance.Geometry :: any do
		geometry[k] = v
	end
	for k, v in overrides do
		geometry[k] = v
	end
	local cover = Drafts.planted("src/shared/Physics/Cover.luau", {
		["../Definitions/Balance"] = { Geometry = geometry },
		["./Shapes"] = Shapes,
	})
	return Drafts.planted("src/shared/Physics/Sampling.luau", {
		["../Definitions/Balance"] = { Geometry = geometry },
		["../Definitions/Limits"] = Limits,
		["./Cover"] = cover,
		["./Shapes"] = Shapes,
	})
end

-- The verdict's hiders of part i as Sampling hands them to Cover: every part but i, exact copies of a part above them and
-- Dust, whose box comes within the reach of i's model + the over of its own + 2·EPS_GEOM, in rank order, with whether each
-- ranks above i, and their models. Indices into parts; `models` (by index) are used where given, built where not.
function H.hidersOf(parts: { Prepared }, i: number,
	models: { [number]: Cover.Model }?): ({ number }, { boolean }, { Cover.Model })
	local rank, order = Sampling.ranked(parts)
	local built: { [number]: Cover.Model } = {}
	local function model(j: number): Cover.Model
		local m = (models and models[j]) or built[j]
		if m == nil then
			m = Cover.model(parts[j])
			built[j] = m
		end
		return m
	end
	local reach = model(i).reach + 2 * Balance.Geometry.EPS_GEOM
	local out: { number }, higher: { boolean }, hm: { Cover.Model } = {}, {}, {}
	for r = 1, #order do
		local q = order[r]
		local j = q.index
		local copy = false
		for t = 1, r - 1 do
			copy = copy or Shapes.sameSolid(q, order[t])
		end
		if j ~= i and not copy and q.volume >= Balance.Geometry.MIN_PART_VOLUME
			and Shapes.aabbOverlap(parts[i], q, reach + model(j).over)
		then
			table.insert(out, j)
			table.insert(higher, r < rank[i])
			table.insert(hm, model(j))
		end
	end
	return out, higher, hm
end

-- What the verdict reads on part i, whole (no stop at 2 %, no cap): the share of its model's area that shows, and the
-- area itself. Exactly the reading Sampling's verdict compares with ENCLOSED_EXPOSED_MAX.
function H.reads(parts: { Prepared }, i: number): (number, number)
	local m = Cover.model(parts[i])
	local _, higher, models = H.hidersOf(parts, i, { [i] = m })
	local shown = Cover.shown(m, models, higher, math.huge, math.huge)
	return shown / m.total, shown
end

-- A plate 0.5 × 0.5 × 0.02 on a slab, between 4 walls whose tops are flush with its top at y = 0, so only its top shows: each
-- of them is smaller than the plate, which keeps the top. Lids stand on the top, each { x0, x1, z0, z1 }, 0.1 tall, parts
-- 7, 8…; a lid hides its footprint grown by EPS_GEOM (the coincident face if it ranks higher, the probe's otherwise), so what
-- shows has a closed form in EPS_GEOM. Verdict.spec and Cover.spec read on it.
H.PLATE_AREA = 2 * 0.25 + 4 * 0.5 * 0.02

function H.partsUnder(lids: { { number } }): { any }
	local parts = {
		H.solid(1, "Block", { 0, -0.01, 0 }, H.I, { 0.5, 0.02, 0.5 }),
		H.solid(2, "Block", { 0, -0.0275, 0 }, H.I, { 0.5, 0.015, 0.5 }),
		H.solid(3, "Block", { 0.26, -0.02, 0 }, H.I, { 0.02, 0.04, 0.54 }),
		H.solid(4, "Block", { -0.26, -0.02, 0 }, H.I, { 0.02, 0.04, 0.54 }),
		H.solid(5, "Block", { 0, -0.02, 0.26 }, H.I, { 0.5, 0.04, 0.02 }),
		H.solid(6, "Block", { 0, -0.02, -0.26 }, H.I, { 0.5, 0.04, 0.02 }),
	}
	for k, lid in ipairs(lids) do
		table.insert(parts, H.solid(6 + k, "Block", { (lid[1] + lid[2]) / 2, 0.05, (lid[3] + lid[4]) / 2 }, H.I, { lid[2] - lid[1], 0.1, lid[4] - lid[3] }))
	end
	return parts
end

function H.underLids(lids: { { number } }): { Prepared }
	return H.prepared({ parts = H.partsUnder(lids) })
end

-- The verdict keeps no number, so what it reads is read off its threshold: part i is kept just under `share` of its area
-- and cleaned just over it.
function H.verdictReads(parts: { Prepared }, i: number, share: number, what: string)
	local under = H.plantedSampling({ ENCLOSED_EXPOSED_MAX = share * (1 - 1e-9) }).exposure(parts)
	local over = H.plantedSampling({ ENCLOSED_EXPOSED_MAX = share * (1 + 1e-9) + 1e-12 }).exposure(parts)
	A.truthy(under.kept[i], what .. ": reads at least " .. share)
	A.falsy(over.kept[i], what .. ": reads at most " .. share)
end

-- The first `count` parts of two exposures, the first `count` parts of a design with and without others: the same grid, the
-- same verdicts, and to the bit the same areas and contact rows.
function H.sameKeptMeasure(after: any, before: any, count: number)
	A.eq(after.hSurf, before.hSurf, "the grid kept parts are measured on")
	for i = 1, count do
		A.eq(after.kept[i], before.kept[i], "part " .. i .. "'s verdict")
		A.eq(after.exposedKept[i], before.exposedKept[i], "kept part " .. i .. " measures as without the others")
		for j = 1, count do
			A.eq(after.contact[i][j], before.contact[i][j], "contact " .. i .. ", " .. j)
		end
	end
end

-- ── values ────────────────────────────────────────────────────────────────────────────────────────────────────────

function H.finite(value: any, what: string)
	if type(value) == "number" then
		A.finite(value, what)
	elseif type(value) == "table" then
		for k, v in value do
			H.finite(v, what .. "." .. tostring(k))
		end
	end
end

return table.freeze(H)
