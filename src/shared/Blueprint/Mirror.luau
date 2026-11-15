--!strict
-- Blueprint/Mirror (SPEC §3.8; owner S2, S6's tool wraps it): the only mirror implementation. It reflects parts across
-- the fixed planes x = 0 ("X", left/right) and z = 0 ("Z", front/back), the hitbox's centre planes (§3.1); Asymmetry
-- is measured about x = 0 (§5.2). Pure, determinism rules of §4.1: + − × ÷, sqrt, abs, min, comparisons, numeric for
-- loops.
--
-- No negative scale: if a shape has a local reflection symmetry F, the image of R·S + c is (M·R·F)·S + M·c, and M·R·F
-- is a proper rotation, so every shape mirrors to a rotated copy of itself and a record has no mirrored flag (§3.3).
--
--   Shape                           Local symmetry F                                  Size after mirroring
--   Block, Wedge, Cylinder, Ball    reflect local X                                   unchanged
--   CornerWedge                     diagonal (x, y, z) → (−z, y, −x), which maps      (sz, sy, sx)
--                                   CornerWedge(hx, hy, hz) onto CornerWedge(hz, hy, hx)
--
-- Closed forms on q = {qx, qy, qz, qw} (⊗ = Quat.mul, H = √½), then the hemisphere rule (C4) and −0 → +0 (C5):
--
--   Plane  Position       Block, Wedge, Cylinder, Ball         CornerWedge
--   "X"    (−px, py, pz)  {qx, −qy, −qz, qw}                   {qx, −qy, −qz, qw} ⊗ {0, H, 0, H}
--   "Z"    (px, py, −pz)  {−qx, −qy, qz, qw} ⊗ {0, 1, 0, 0}    {−qx, −qy, qz, qw} ⊗ {0, −H, 0, H}
--
--   reflect          a new PartData with the same id (the caller assigns new ids to copies); it shares no table with
--                    the input. S6 canonicalizes after it (§11.10): C3 can fire on a quaternion that hugged
--                    QUAT_NORM_TOL, since the factors with H scale the norm by about 1 + 1e-16. Twice restores a part
--                    bit for bit, except a CornerWedge's rotation, within a few ulps (2·H² is not exactly 1).
--   isSelfSymmetric  does the solid coincide with its own image, within EPS_GEOM? Then a mirror copy would only be a
--                    coincident duplicate, and the editor's mirror copy skips the part ("parts on the plane", §11.10).
--                    It compares solids, not records: a Block at z = 0 mirrors to {0, 1, 0, 0}, the same solid. A part
--                    centred on the plane can still have a distinct image: a tilted Block, a Wedge whose slope faces
--                    the plane's normal, a CornerWedge in general.

local Balance = require("../Definitions/Balance")
local Quat = require("./Quat")
local Schema = require("./Schema")

type PartData = Schema.PartData

export type Plane = "X" | "Z"

local Mirror = {}

local H = 0.70710678118654757 -- √½ to 17 digits, the SPEC's literal: one bit pattern on every platform

-- M·F of the closed forms, as right factors: each is a proper rotation about local Y.
local Y_POS_90: Schema.Quat = table.freeze({ 0, H, 0, H }) -- CornerWedge, "X"
local Y_NEG_90: Schema.Quat = table.freeze({ 0, -H, 0, H }) -- CornerWedge, "Z"
local Y_180: Schema.Quat = table.freeze({ 0, 1, 0, 0 }) -- the other shapes, "Z"

-- The polyhedra's local vertices (§3.2) as ±1 multiples of (hx, hy, hz), flat x, y, z triples. Looked up by shape only.
local VERTEX_SIGNS: { [string]: { number } } = table.freeze({
	Block = table.freeze({ -1, -1, -1, 1, -1, -1, -1, 1, -1, 1, 1, -1, -1, -1, 1, 1, -1, 1, -1, 1, 1, 1, 1, 1 }),
	Wedge = table.freeze({ -1, -1, -1, 1, -1, -1, -1, -1, 1, 1, -1, 1, -1, 1, 1, 1, 1, 1 }),
	CornerWedge = table.freeze({ -1, -1, -1, 1, -1, -1, -1, -1, 1, 1, -1, 1, 1, 1, -1 }),
})

-- The plane's normal axis: 1 for "X", 3 for "Z". Anything else is a caller's bug.
local function normalAxis(plane: Plane): number
	if plane == "X" then
		return 1
	elseif plane == "Z" then
		return 3
	end
	error('Mirror: plane must be "X" or "Z", got ' .. tostring(plane), 3)
end

local function zero(v: number): number
	return if v == 0 then 0 else v -- −0 → +0 (C5)
end

function Mirror.reflect(part: PartData, plane: Plane): PartData
	local axis = normalAxis(plane)
	local pos, q, size = part.pos, part.rot, part.size
	local corner = part.shape == "CornerWedge"
	local rot: Schema.Quat
	if axis == 1 then
		rot = { q[1], -q[2], -q[3], q[4] }
		if corner then
			rot = Quat.mul(rot, Y_POS_90)
		end
	else
		rot = Quat.mul({ -q[1], -q[2], q[3], q[4] }, if corner then Y_NEG_90 else Y_180)
	end
	local out: Schema.Vec3 = { zero(pos[1]), zero(pos[2]), zero(pos[3]) }
	out[axis] = zero(-pos[axis])
	return {
		id = part.id,
		slot = part.slot,
		shape = part.shape,
		material = part.material,
		pos = out,
		rot = Quat.hemisphere(rot),
		size = if corner then { size[3], size[2], size[1] } else { size[1], size[2], size[3] },
	}
end

-- A polyhedron is its own image iff the reflection permutes its vertices. The reflection is injective and vertices are
-- at least MIN_DIM apart, far more than eps, so landing on some vertex each is a permutation.
local function polyhedronIsOwnImage(part: PartData, signs: { number }, axis: number, eps: number): boolean
	local pos, size = part.pos, part.size
	local hx, hy, hz = size[1] / 2, size[2] / 2, size[3] / 2
	local r00, r01, r02, r10, r11, r12, r20, r21, r22 = Quat.toMatrix(part.rot)
	local n = #signs / 3
	local xs: { number } = table.create(n)
	local ys: { number } = table.create(n)
	local zs: { number } = table.create(n)
	for v = 1, n do
		local a, b, c = signs[3 * v - 2] * hx, signs[3 * v - 1] * hy, signs[3 * v] * hz
		xs[v] = pos[1] + r00 * a + r01 * b + r02 * c
		ys[v] = pos[2] + r10 * a + r11 * b + r12 * c
		zs[v] = pos[3] + r20 * a + r21 * b + r22 * c
	end
	local flipX = if axis == 1 then -1 else 1
	local flipZ = if axis == 3 then -1 else 1
	local eps2 = eps * eps
	for v = 1, n do
		local x, y, z = flipX * xs[v], ys[v], flipZ * zs[v]
		local landed = false
		for w = 1, n do
			local dx, dy, dz = x - xs[w], y - ys[w], z - zs[w]
			if dx * dx + dy * dy + dz * dz <= eps2 then
				landed = true
				break
			end
		end
		if not landed then
			return false
		end
	end
	return true
end

-- A cylinder is its own image iff its centre is on the plane and its axis u lies in the plane or along the normal. No
-- point of it moves further than |c − M·c| + √(hx² + r²)·|u ∓ M·u|, with the sign that fits. The second axis term comes
-- from the other two components of u: 1 − u_k² would round to noise when u is almost the normal.
local function cylinderIsOwnImage(part: PartData, axis: number, eps: number): boolean
	local size = part.size
	local hx, r = size[1] / 2, math.min(size[2], size[3]) / 2
	local ux, _, _, uy, _, _, uz = Quat.toMatrix(part.rot) -- the first column of R: local X, the axis
	local alongNormal = if axis == 1 then ux else uz
	local acrossNormal = if axis == 1 then uz else ux -- and uy, on every plane
	local axisMoves = 2 * math.min(math.abs(alongNormal), math.sqrt(acrossNormal * acrossNormal + uy * uy))
	return 2 * math.abs(part.pos[axis]) + math.sqrt(hx * hx + r * r) * axisMoves <= eps
end

function Mirror.isSelfSymmetric(part: PartData, plane: Plane): boolean
	local axis = normalAxis(plane)
	local eps = Balance.Geometry.EPS_GEOM
	if part.shape == "Ball" then
		return 2 * math.abs(part.pos[axis]) <= eps
	elseif part.shape == "Cylinder" then
		return cylinderIsOwnImage(part, axis, eps)
	end
	return polyhedronIsOwnImage(part, VERTEX_SIGNS[part.shape], axis, eps)
end

return table.freeze(Mirror)
