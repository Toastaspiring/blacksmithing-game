--!strict
-- Blueprint/Canonical (SPEC §3.5, §3.6, §3.11; owner S1; the per-shape hook canonicalSize is S2's rule, §3.2): the one
-- canonical form of blueprint data and the only entry point for client blueprint data. The editor runs it on every
-- commit and the server again (Save, Begin). No storage grid and no second sanitizer: positions, sizes and quaternions
-- stay the doubles the editor produced, so the stored, analysed and rendered design is exactly what the player built.
-- Pure, determinism rules of §4.1 (+ − × ÷, sqrt, comparisons, numeric for loops, a sort with a total order).
--
-- Canonical form (§3.5)                                                               on violation
--   C1  every number finite                                                           NonFinite
--   C2  |pos_k| ≤ POS_ABS_MAX · MIN_DIM ≤ size_k ≤ MAX_DIM · |‖q‖² − 1| ≤ QUAT_INPUT_TOL  OutOfRange · OutOfRange ·
--                                                                                     BadRotation; never clamped
--   C3  |‖q‖² − 1| > QUAT_NORM_TOL (1e-9): q ← q / ‖q‖. Only above the threshold: one renormalization lands within a
--       few ulps of unit, so a second pass keeps q, while renormalizing every pass would change the bits of a third of
--       all unit quaternions on every save (E-S1.1). Editor quaternions (≈ 1e-16 off) are never touched.
--   C4  hemisphere: −q if qw < 0, or qw = 0 and the first non-zero of (qx, qy, qz) is negative (q and −q are the
--       same rotation; negation is exact)
--   C5  −0 → +0 in pos and rot
--   C6  canonicalSize, S2's hook: Ball sides = min side; Cylinder Y = Z = min(Y, Z) (what Roblox draws; the editor
--       enforces both at edit time, so it is a no-op for editor data)
--   C7  parts sorted by ascending id                                                  DuplicatePartId
-- Idempotent: Canonical(Canonical(x)) = Canonical(x) bit for bit (0 failures over 10^6 parts, E-S1.1).
--
-- draft(raw): untrusted input. It reads only the known fields of the client's tables and never stores, mutates or
-- iterates them (one next() call tells an empty parts list from a map); it checks counts before looping and builds
-- every output table fresh, so unknown fields are dropped. The first failing check, in this order, is the result
-- {ok = false, code, path} (§3.6):
--   1  raw is a table                                                     Malformed                 ""
--   2  schema == BLUEPRINT_SCHEMA                                         UnsupportedSchema         "schema"
--   3  Names.sanitize(name)                                               BadName                   "name"
--   4  type known, enabled                                                UnknownId · DisabledId    "type"
--   5  parts an array (an empty one has no keys at all) · #parts ≤ MAX_PARTS
--                                                                         Malformed · TooManyParts  "parts"
--   6  each part a table · id an integer 1..MAX_PART_ID · slot a slot of the type · shape known · material known,
--      enabled, allowed for the slot
--                     Malformed "parts[i]" · Malformed ".id" · SlotNotInType ".slot" · UnknownId ".shape" ·
--                     UnknownId / DisabledId / MaterialNotAllowed ".material"
--   7  pos, size exactly 3 numbers, rot exactly 4                         Malformed   ".pos" ".size" ".rot"
--   8  C1, then C2, then C3–C6, then C7                                   NonFinite · OutOfRange · BadRotation ·
--                                                                         DuplicatePartId (".id" of the later copy)
-- Each check runs over every part, in the client's order, before the next check starts; i is the client's index
-- ("parts[7].rot"). Within a part the fields go pos, size, rot. S5 maps a CanonError to E_INVALID_BLUEPRINT with
-- details {code, path} (§10.3); an editor value the server rejects is a logged bug (the editor clamps first).
--
-- isCanonical(core, opts): the same checks on stored data, then a bit-for-bit fixed-point test (−0 ≠ +0). Other keys
-- of the core (a record's id, revision, times, analysis; a snapshot's sourceId, sourceRevision) and unknown part
-- fields are ignored. opts.bounds = false skips C2's bound tests (POS_ABS_MAX, MIN_DIM, MAX_DIM: a record that breaks
-- only a later, tighter bound stays, §9.6); the rotation tolerance is always checked. Never throws.

local DT = require("../Definitions/Types")
local EquipmentTypes = require("../Definitions/EquipmentTypes")
local Limits = require("../Definitions/Limits")
local Materials = require("../Definitions/Materials")
local Versions = require("../Definitions/Versions")
local Names = require("./Names")
local Quat = require("./Quat")
local Schema = require("./Schema")

type Vec3 = Schema.Vec3
type PartData = Schema.PartData
type BlueprintDraft = Schema.BlueprintDraft

export type CanonError =
	"Malformed"
	| "UnsupportedSchema"
	| "UnknownId"
	| "DisabledId"
	| "SlotNotInType"
	| "MaterialNotAllowed"
	| "TooManyParts"
	| "DuplicatePartId"
	| "NonFinite"
	| "OutOfRange"
	| "BadRotation"
	| "BadName"
export type CanonResult<T> = { ok: true, value: T } | { ok: false, code: CanonError, path: string }

type DraftResult = CanonResult<BlueprintDraft>

-- The ShapeId values (Definitions/Types), in its order. Shapes have no catalog: this list is the "known" set.
local SHAPES: { DT.ShapeId } = { "Block", "Wedge", "CornerWedge", "Cylinder", "Ball" }

local GUID_HEX = "[0-9A-Fa-f]"
local GUID_PATTERN = "^"
	.. string.rep(GUID_HEX, 8) .. "%-"
	.. string.rep(GUID_HEX, 4) .. "%-"
	.. string.rep(GUID_HEX, 4) .. "%-"
	.. string.rep(GUID_HEX, 4) .. "%-"
	.. string.rep(GUID_HEX, 12) .. "$"
local UPPER_HEX: { [string]: string } = { a = "A", b = "B", c = "C", d = "D", e = "E", f = "F" }

local Canonical = {}

-- ── helpers ───────────────────────────────────────────────────────────────────────────────────────────────────

local function fail(code: CanonError, path: string): DraftResult
	return { ok = false, code = code, path = path }
end

local function partPath(i: number, field: string?): string
	local base = "parts[" .. tostring(i) .. "]"
	return if field then base .. "." .. field else base
end

local function isFinite(x: number): boolean
	return x == x and x > -math.huge and x < math.huge
end

local function zero(v: number): number
	return if v == 0 then 0 else v -- −0 → +0 (C5)
end

-- A fresh copy of exactly n numbers, or nil when v is not a table of exactly n numbers.
local function tuple(v: any, n: number): { number }?
	if type(v) ~= "table" or #v ~= n then
		return nil
	end
	local out = table.create(n)
	for k = 1, n do
		local x = v[k]
		if type(x) ~= "number" then
			return nil
		end
		out[k] = x
	end
	return out
end

local function allFinite(t: { number }): boolean
	for k = 1, #t do
		if not isFinite(t[k]) then
			return false
		end
	end
	return true
end

local function squaredNorm(q: { number }): number
	return q[1] * q[1] + q[2] * q[2] + q[3] * q[3] + q[4] * q[4]
end

-- The SlotDef id of the type that equals slot, or nil.
local function slotOf(def: DT.EquipmentTypeDef, slot: any): DT.SlotId?
	if type(slot) ~= "string" then
		return nil
	end
	local slots = def.slots
	for k = 1, #slots do
		if slots[k].id == slot then
			return slots[k].id
		end
	end
	return nil
end

local function shapeOf(shape: any): DT.ShapeId?
	if type(shape) ~= "string" then
		return nil
	end
	for k = 1, #SHAPES do
		if SHAPES[k] == shape then
			return SHAPES[k]
		end
	end
	return nil
end

local function allowedIn(def: DT.MaterialDef, slot: DT.SlotId): boolean
	local allowed = def.allowedSlots
	if allowed == nil then
		return true -- nil = any slot
	end
	for k = 1, #allowed do
		if allowed[k] == slot then
			return true
		end
	end
	return false
end

-- bit for bit, −0 distinguished from +0
local function sameBits(a: any, b: { number }, n: number): boolean
	if type(a) ~= "table" then
		return false
	end
	for k = 1, n do
		local x, y = a[k], b[k]
		if x ~= y or (x == 0 and 1 / x ~= 1 / y) then
			return false
		end
	end
	return true
end

-- ── the hook and the quaternion rule ──────────────────────────────────────────────────────────────────────────

-- S2's per-shape size rule (§3.2, C6), called per part after the bound checks. Idempotent; a new table.
function Canonical.canonicalSize(shape: DT.ShapeId, size: Vec3): Vec3
	local sx, sy, sz = size[1], size[2], size[3]
	if shape == "Ball" then
		local d = math.min(sx, sy, sz)
		return { d, d, d }
	elseif shape == "Cylinder" then
		local d = math.min(sy, sz) -- the axis is local X: sx is the length
		return { sx, d, d }
	end
	return { sx, sy, sz }
end

-- C3–C5 on a quaternion that passed C1–C2 (finite, |‖q‖² − 1| ≤ QUAT_INPUT_TOL); anything else is a caller's bug and
-- errors. A new table.
function Canonical.quat(q: Schema.Quat): Schema.Quat
	local d = math.abs(squaredNorm(q) - 1)
	if not (d <= Limits.QUAT_INPUT_TOL) then
		error("Canonical.quat: needs a finite quaternion with |‖q‖² − 1| ≤ QUAT_INPUT_TOL (C1–C2), got |‖q‖² − 1| = "
			.. tostring(d), 2)
	end
	if d > Limits.QUAT_NORM_TOL then
		return Quat.hemisphere(Quat.normalize(q))
	end
	return Quat.hemisphere(q)
end

-- ── the checks (§3.6) ─────────────────────────────────────────────────────────────────────────────────────────

local function canonicalize(raw: unknown, bounds: boolean): DraftResult
	-- 1
	if type(raw) ~= "table" then
		return fail("Malformed", "")
	end
	local r: any = raw
	-- 2
	if r.schema ~= Versions.BLUEPRINT_SCHEMA then
		return fail("UnsupportedSchema", "schema")
	end
	-- 3
	local name = Names.sanitize(r.name)
	if name == nil then
		return fail("BadName", "name")
	end
	-- 4
	local typeDef = EquipmentTypes.get(r.type)
	if typeDef == nil then
		return fail("UnknownId", "type")
	elseif bounds and not typeDef.enabled then
		return fail("DisabledId", "type")
	end
	-- 5
	local rawParts = r.parts
	if type(rawParts) ~= "table" then
		return fail("Malformed", "parts")
	end
	local n = #rawParts
	if n == 0 and next(rawParts) ~= nil then
		return fail("Malformed", "parts") -- keys but no element 1: a map or a holey list, not an array
	end
	if n > Limits.MAX_PARTS then
		return fail("TooManyParts", "parts")
	end
	-- 6: identity fields, kept as typed values (ids come from the catalogs and the shape list, never cast)
	local ids: { number } = table.create(n)
	local slots: { DT.SlotId } = table.create(n)
	local shapes: { DT.ShapeId } = table.create(n)
	local materials: { DT.MaterialId } = table.create(n)
	for i = 1, n do
		local p = rawParts[i]
		if type(p) ~= "table" then
			return fail("Malformed", partPath(i))
		end
		local id = p.id
		if type(id) ~= "number" or id ~= math.floor(id) or id < 1 or id > Limits.MAX_PART_ID then
			return fail("Malformed", partPath(i, "id"))
		end
		local slot: DT.SlotId? = slotOf(typeDef, p.slot) -- annotated: an unannotated local widens singletons to string
		if slot == nil then
			return fail("SlotNotInType", partPath(i, "slot"))
		end
		local shape: DT.ShapeId? = shapeOf(p.shape)
		if shape == nil then
			return fail("UnknownId", partPath(i, "shape"))
		end
		local material = Materials.get(p.material)
		if material == nil then
			return fail("UnknownId", partPath(i, "material"))
		elseif bounds and not material.enabled then
			return fail("DisabledId", partPath(i, "material"))
		elseif bounds and not allowedIn(material, slot) then
			return fail("MaterialNotAllowed", partPath(i, "material"))
		end
		ids[i], slots[i], shapes[i], materials[i] = id, slot, shape, material.id
	end
	-- 7: the transform tuples, copied into fresh tables
	local poss: { { number } } = table.create(n)
	local sizes: { { number } } = table.create(n)
	local rots: { { number } } = table.create(n)
	for i = 1, n do
		local p = rawParts[i]
		local pos = tuple(p.pos, 3)
		if pos == nil then
			return fail("Malformed", partPath(i, "pos"))
		end
		local size = tuple(p.size, 3)
		if size == nil then
			return fail("Malformed", partPath(i, "size"))
		end
		local rot = tuple(p.rot, 4)
		if rot == nil then
			return fail("Malformed", partPath(i, "rot"))
		end
		poss[i], sizes[i], rots[i] = pos, size, rot
	end
	-- 8: C1
	for i = 1, n do
		if not allFinite(poss[i]) then
			return fail("NonFinite", partPath(i, "pos"))
		elseif not allFinite(sizes[i]) then
			return fail("NonFinite", partPath(i, "size"))
		elseif not allFinite(rots[i]) then
			return fail("NonFinite", partPath(i, "rot"))
		end
	end
	-- 8: C2
	for i = 1, n do
		if bounds then
			local pos, size = poss[i], sizes[i]
			for k = 1, 3 do
				if math.abs(pos[k]) > Limits.POS_ABS_MAX then
					return fail("OutOfRange", partPath(i, "pos"))
				end
			end
			for k = 1, 3 do
				if size[k] < Limits.MIN_DIM or size[k] > Limits.MAX_DIM then
					return fail("OutOfRange", partPath(i, "size"))
				end
			end
		end
		if not (math.abs(squaredNorm(rots[i]) - 1) <= Limits.QUAT_INPUT_TOL) then
			return fail("BadRotation", partPath(i, "rot"))
		end
	end
	-- 8: C3–C6
	local parts: { PartData } = table.create(n)
	for i = 1, n do
		local pos = poss[i]
		parts[i] = {
			id = ids[i],
			slot = slots[i],
			shape = shapes[i],
			material = materials[i],
			pos = { zero(pos[1]), zero(pos[2]), zero(pos[3]) },
			rot = Canonical.quat(rots[i]),
			size = Canonical.canonicalSize(shapes[i], sizes[i]),
		}
	end
	-- 8: C7
	local seen: { [number]: boolean } = {}
	for i = 1, n do
		local id = parts[i].id
		if seen[id] then
			return fail("DuplicatePartId", partPath(i, "id"))
		end
		seen[id] = true
	end
	table.sort(parts, function(a: PartData, b: PartData): boolean
		return a.id < b.id -- ids are unique here: a total order, so every platform sorts the same way
	end)
	local draft: BlueprintDraft = { schema = Versions.BLUEPRINT_SCHEMA, name = name, type = typeDef.id, parts = parts }
	return { ok = true, value = draft }
end

-- ── public API (§3.11) ────────────────────────────────────────────────────────────────────────────────────────

-- The only entry point for client blueprint data. Never throws.
function Canonical.draft(raw: unknown): CanonResult<BlueprintDraft>
	return canonicalize(raw, true)
end

-- Is core (structurally valid and) a fixed point of the canonical form? Never throws.
function Canonical.isCanonical(core: Schema.BlueprintCore, opts: { bounds: boolean? }?): boolean
	local o: any = opts
	local bounds = not (type(o) == "table" and o.bounds == false)
	local result: any = canonicalize(core, bounds)
	if not result.ok then
		return false
	end
	local c: BlueprintDraft = result.value
	local r: any = core
	if r.name ~= c.name then
		return false -- schema and type are equal by checks 2 and 4
	end
	local parts = r.parts -- #parts == #c.parts by check 5
	for i = 1, #c.parts do
		local a, b = parts[i], c.parts[i]
		if a.id ~= b.id or a.slot ~= b.slot or a.shape ~= b.shape or a.material ~= b.material then
			return false
		end
		if not (sameBits(a.pos, b.pos, 3) and sameBits(a.size, b.size, 3) and sameBits(a.rot, b.rot, 4)) then
			return false
		end
	end
	return true
end

-- A blueprint id from the client: an 8-4-4-4-12 hex GUID (HttpService:GenerateGUID(false), 36 characters, no braces),
-- returned upper-cased, else nil. Never throws.
function Canonical.guid(raw: unknown): string?
	if type(raw) ~= "string" or #raw ~= 36 or string.find(raw, GUID_PATTERN) == nil then
		return nil
	end
	return (string.gsub(raw, "[a-f]", UPPER_HEX))
end

return table.freeze(Canonical)
