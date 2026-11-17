--!strict
-- tests/fixtures/Build.luau — what the fixture modules share (SPEC §14.7): the record shape they are written in, the
-- rotations of E-S8.3, the Hamilton product for compound rotations, deep copies and deep freezing.
-- tests/fixtures is a Rojo root (ReplicatedStorage.BlacksmithTests.fixtures), so these modules require nothing outside
-- it (SPEC §1.3 L1) and run unchanged in Lune and in Studio. Exact arithmetic only (no trigonometry: the 45° and 90°
-- constants are pasted with 17 significant digits), so every fixture has the same bits on every machine.
--
-- The record shape is Blueprint/Schema's BlueprintCore and PartData (SPEC §3.3), restated structurally because a
-- fixture cannot require src/. Ids are plain strings here: the adversarial drafts carry unknown ones on purpose.

export type Vec = { number }
export type Part = {
	id: number,
	slot: string,
	shape: string,
	material: string,
	pos: Vec, -- part centre, blueprint space (origin = centre of the hitbox's bottom face, SPEC §3.1)
	rot: Vec, -- {qx, qy, qz, qw}
	size: Vec, -- Part.Size along local X, Y, Z (Cylinder axis = local X)
}
export type Core = { schema: number, name: string, type: string, parts: { Part } }

-- The record of a measured fixture (Calibration, Regression, Cost): what §14 expects of it, as Blueprints' record without
-- its oracle and starter, with the parts Physics cleans and, for a regression, its bound against a base (E-S2.5).
export type Cleaned = { partId: number, reason: string } -- "Dust" | "Enclosed"
export type Expected = {
	canon: { ok: boolean, equals: string }, -- Canonical.draft(core) is ok and returns core bit for bit (M1)
	validation: { valid: boolean, errors: { { code: string, partId: number? } } }, -- Physics/Analyze (M2)
	tiers: { [string]: string }, -- played tier per step (T-DIF-11, M3)
	tierRaw: { [string]: string },
	cleaned: { Cleaned }, -- Analyze.run's cleaned list, in part order (M2)
	relation: { to: string, kind: string, bound: number }?, -- a fixture id; kind and bound as E-S2.5's table (T-DIF-13)
	save: string, -- what Blueprint.Save does: "Valid" / "Invalid" (M7)
}
export type Measured = { id: string, label: string, what: string, core: Core, expect: Expected }

local Build = {}

-- The blueprint format the fixtures are written in: a blueprint is self-describing (SPEC §3.3), so this is data,
-- checked against Definitions/Versions.BLUEPRINT_SCHEMA by tests/FixtureSet.
Build.SCHEMA = 1
Build.TYPE = "Sword"

Build.R = 0.70710678118654757 -- √½
Build.S225 = 0.38268343236508978 -- sin 22.5°
Build.C225 = 0.92387953251128674 -- cos 22.5°

local R, S, C = Build.R, Build.S225, Build.C225
Build.I = table.freeze({ 0, 0, 0, 1 }) :: Vec -- identity
Build.Z45 = table.freeze({ 0, 0, S, C }) :: Vec -- 45° about Z (E-S8.3)
Build.Z90 = table.freeze({ 0, 0, R, R }) :: Vec -- 90° about Z: a cylinder's axis (local X) along +Y
Build.Y90 = table.freeze({ 0, R, 0, R }) :: Vec -- 90° about Y: local X → −Z, local Z → +X (the wedge tips)
Build.Y45 = table.freeze({ 0, S, 0, C }) :: Vec -- 45° about Y, the sword axis
Build.Z180 = table.freeze({ 0, 0, 1, 0 }) :: Vec -- 180° about Z (qw = 0: the second hemisphere rule, C4)
Build.YM90 = table.freeze({ 0, -R, 0, R }) :: Vec -- −90° about Y: the prototype's RY_M90, the +X tips (local X → +Z)

-- a ⊗ b: rotate by b, then by a (Blueprint/Quat.mul's convention, SPEC §3.11).
function Build.mul(a: Vec, b: Vec): Vec
	local ax, ay, az, aw = a[1], a[2], a[3], a[4]
	local bx, by, bz, bw = b[1], b[2], b[3], b[4]
	return {
		aw * bx + ax * bw + ay * bz - az * by,
		aw * by - ax * bz + ay * bw + az * bx,
		aw * bz + ax * by - ay * bx + az * bw,
		aw * bw - ax * bx - ay * by - az * bz,
	}
end

-- −q, component by component: −0 stays −0 (A13 relies on it).
function Build.neg(q: Vec): Vec
	return { -q[1], -q[2], -q[3], -q[4] }
end

-- SPEC §3.5 C4 + C5 on a quaternion already within QUAT_NORM_TOL of unit: the canonical sign, then −0 → +0.
function Build.hemisphere(q: Vec): Vec
	local x, y, z, w = q[1], q[2], q[3], q[4]
	local flip: boolean
	if w ~= 0 then
		flip = w < 0
	elseif x ~= 0 then
		flip = x < 0
	elseif y ~= 0 then
		flip = y < 0
	else
		flip = z < 0
	end
	if flip then
		x, y, z, w = -x, -y, -z, -w
	end
	return { x + 0, y + 0, z + 0, w + 0 } -- −0 + 0 = +0
end

-- Deep copy of plain data (tables, numbers, strings, booleans); a copy is never frozen.
function Build.copy<T>(v: T): T
	if type(v) ~= "table" then
		return v
	end
	local out = {}
	for k, x in v :: any do
		out[k] = Build.copy(x)
	end
	return (out :: any) :: T
end

-- Recursive table.freeze; returns its argument.
function Build.freeze<T>(v: T): T
	if type(v) == "table" and not table.isfrozen(v :: any) then
		for _, x in v :: any do
			Build.freeze(x)
		end
		table.freeze(v :: any)
	end
	return v
end

-- A fresh part: every vector is copied, so parts never share tables.
function Build.part(id: number, slot: string, shape: string, material: string, pos: Vec, rot: Vec, size: Vec): Part
	return {
		id = id,
		slot = slot,
		shape = shape,
		material = material,
		pos = { pos[1], pos[2], pos[3] },
		rot = { rot[1], rot[2], rot[3], rot[4] },
		size = { size[1], size[2], size[3] },
	}
end

function Build.core(name: string, parts: { Part }): Core
	return { schema = Build.SCHEMA, name = name, type = Build.TYPE, parts = parts }
end

-- The part with this id in a part list, or nil.
function Build.find(parts: { Part }, id: number): Part?
	for _, p in parts do
		if p.id == id then
			return p
		end
	end
	return nil
end

-- parts without the part of this id (a fresh list; the remaining parts are the same tables).
function Build.without(parts: { Part }, id: number): { Part }
	local out: { Part } = {}
	for _, p in parts do
		if p.id ~= id then
			table.insert(out, p)
		end
	end
	return out
end

return table.freeze(Build)
