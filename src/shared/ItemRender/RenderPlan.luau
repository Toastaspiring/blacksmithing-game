--!strict
-- ItemRender/RenderPlan (SPEC §13.7, §3.4, E-S7.4; owner S7): the one pure description of how an item draws. It turns
-- a blueprint's PartData list into render primitives, which ItemRender/ItemModelBuilder (Roblox-bound) turns into
-- Instances, so everyone sees exactly the part list that was measured. M2 builds what S-PAR-01 needs; M6 adds the
-- callers (stands, workpieces, viewports) and the goldens of T-RND-01.
--
--   fromBlueprint  a whole item: the primitives in part order, its bounds, per-slot bounds, anchor and scale
--   primitive      one part against a given anchor point, for the editor's per-part updates (§11)
--
-- Two frames, on purpose:
--   plan space       primitive.size and primitive.cf: scale·size, and position scale·(p − anchor) from the plan pivot;
--                    the rotation is Blueprint/Quat.toMatrix(rot), R00..R22 row-major, never scaled
--   blueprint space  plan.bounds and plan.slotBounds: min/max of the solids in the record's own coordinates, neither
--                    anchored nor scaled (§13.7's formula and E-S7.4's figures), so they do not depend on opts. A
--                    consumer on the plan pivot takes extents e = scale·(max − min)/2 and, for Center, centres on 0;
--                    for BaseCenter, on (0, e_y, 0). `anchor` and `scale` stay on the plan for that purpose
-- Anchors: Center = the bounds centre; BaseCenter = (cx, minY, cz), so the item's lowest point sits at plan y = 0;
-- Origin = blueprint (0, 0, 0). Defaults Center, scale 1 (§13.7). The bounds are Physics/Shapes.aabb's exact extents
-- (§4.2 and §13.7 state one formula): S2 owns the solids, so a corrected shape convention has one place to change.
--
-- Checks, in this order, each over every part before the next starts (the order of Blueprint/Canonical):
--   1 count     no parts (or no table at all) Empty; more than Limits.MAX_PARTS TooManyParts
--   2 shape     a known ShapeId, else BadShape; §13.7 has no code of its own for a part that is not a table or a slot
--               that is not a string (the slot only keys slotBounds and names the Part), so they answer BadShape too
--   3 material  a row of Definitions/Materials, retired ones included (a stored item stays readable), else BadMaterial
--   4 finite    id and scale finite, pos and size exactly 3 finite numbers, rot exactly 4, else NonFinite; so are the
--               computed bounds and primitives (a zero or overflowing quaternion has no rotation: R(rot) holds NaN)
--   5 size      each stored side in [MIN_DIM, MAX_DIM], and scale > 0, else BadSize
-- Canonical data never fails. Sizes are as stored, and C6 already made Ball and Cylinder sizes what Roblox draws. On an
-- error the caller builds ItemModelBuilder.placeholder and logs RenderFailed. Untrusted data returns an error and never
-- throws; an unknown anchor name is a caller's bug and errors. Every table of a result is new: nothing is shared with
-- the input or with Definitions. Pure and deterministic; not an authoritative path, but it follows §4.1's arithmetic.

local DT = require("../Definitions/Types")
local Limits = require("../Definitions/Limits")
local Materials = require("../Definitions/Materials")
local Presentation = require("../Definitions/Presentation")
local Quat = require("../Blueprint/Quat")
local Schema = require("../Blueprint/Schema")
local Shapes = require("../Physics/Shapes")

type Vec3 = Schema.Vec3
type PartData = Schema.PartData

export type Anchor = Presentation.Anchor -- "BaseCenter" | "Center" | "Origin"
export type RenderPrimitive = {
	partId: number,
	slot: DT.SlotId,
	shape: DT.ShapeId,
	material: DT.MaterialId,
	size: Vec3, -- scaled
	cf: { number }, -- x, y, z, R00..R22 from the plan pivot; the position is scaled
	color: DT.RGB,
	robloxMaterial: string,
	reflectance: number,
}
export type Bounds = { min: Vec3, max: Vec3 }
export type RenderPlan = {
	primitives: { RenderPrimitive },
	bounds: Bounds,
	slotBounds: { [DT.SlotId]: Bounds },
	anchor: Anchor,
	scale: number,
}
export type PlanError = "Empty" | "TooManyParts" | "BadShape" | "BadMaterial" | "NonFinite" | "BadSize"

local DEFAULT_ANCHOR: Anchor = "Center"
local DEFAULT_SCALE = 1

local RenderPlan = {}

-- ── checks ────────────────────────────────────────────────────────────────────────────────────────────────────────

local function isFinite(x: any): boolean
	return type(x) == "number" and x == x and x > -math.huge and x < math.huge
end

-- A table of exactly n finite numbers.
local function finiteTuple(v: any, n: number): boolean
	if type(v) ~= "table" or #v ~= n then
		return false
	end
	for k = 1, n do
		if not isFinite(v[k]) then
			return false
		end
	end
	return true
end

local function checkShape(part: any): PlanError?
	if type(part) ~= "table" or type(part.slot) ~= "string" or type(part.shape) ~= "string"
		or Shapes.CODE[part.shape] == nil
	then
		return "BadShape"
	end
	return nil
end

local function checkMaterial(part: any): PlanError?
	return if Materials.get(part.material) == nil then "BadMaterial" else nil
end

local function checkFinite(part: any): PlanError?
	local ok = isFinite(part.id) and finiteTuple(part.pos, 3) and finiteTuple(part.rot, 4) and finiteTuple(part.size, 3)
	return if ok then nil else "NonFinite"
end

local function checkSize(part: any): PlanError?
	local size = part.size
	for k = 1, 3 do
		if size[k] < Limits.MIN_DIM or size[k] > Limits.MAX_DIM then
			return "BadSize"
		end
	end
	return nil
end

-- ── building ──────────────────────────────────────────────────────────────────────────────────────────────────────

-- The primitive of a part that passed the checks; NonFinite when huge values overflowed on the way.
local function build(part: PartData, anchor: Vec3, scale: number): (RenderPrimitive?, PlanError?)
	local def = Materials.get(part.material) :: DT.MaterialDef
	local p, s, c = part.pos, part.size, def.color
	local r00, r01, r02, r10, r11, r12, r20, r21, r22 = Quat.toMatrix(part.rot)
	local size = { scale * s[1], scale * s[2], scale * s[3] }
	local cf = {
		scale * (p[1] - anchor[1]),
		scale * (p[2] - anchor[2]),
		scale * (p[3] - anchor[3]),
		r00, r01, r02,
		r10, r11, r12,
		r20, r21, r22,
	}
	if not (finiteTuple(size, 3) and finiteTuple(cf, 12)) then
		return nil, "NonFinite"
	end
	return {
		partId = part.id,
		slot = part.slot,
		shape = part.shape,
		material = part.material,
		size = size,
		cf = cf,
		color = { c[1], c[2], c[3] },
		robloxMaterial = def.robloxMaterial,
		reflectance = def.reflectance,
	}, nil
end

local function merge(into: Bounds, lo: Vec3, hi: Vec3)
	local a, b = into.min, into.max
	for k = 1, 3 do
		a[k] = math.min(a[k], lo[k])
		b[k] = math.max(b[k], hi[k])
	end
end

-- The anchor point in blueprint space.
local function anchorPoint(anchor: Anchor, bounds: Bounds): Vec3
	if anchor == "Origin" then
		return { 0, 0, 0 }
	end
	local lo, hi = bounds.min, bounds.max
	local cx, cz = (lo[1] + hi[1]) / 2, (lo[3] + hi[3]) / 2
	return { cx, if anchor == "BaseCenter" then lo[2] else (lo[2] + hi[2]) / 2, cz }
end

-- ── API ───────────────────────────────────────────────────────────────────────────────────────────────────────────

function RenderPlan.fromBlueprint(parts: { PartData }, opts: { anchor: Anchor?, scale: number? }?)
	: (RenderPlan?, PlanError?)
	local anchor: Anchor = DEFAULT_ANCHOR
	local scale: any = DEFAULT_SCALE
	if opts then
		anchor = opts.anchor or DEFAULT_ANCHOR
		if opts.scale ~= nil then
			scale = opts.scale
		end
	end
	if anchor ~= "BaseCenter" and anchor ~= "Center" and anchor ~= "Origin" then
		error("RenderPlan.fromBlueprint: unknown anchor " .. tostring(anchor), 2)
	end

	if type(parts) ~= "table" or #parts == 0 then
		return nil, "Empty"
	end
	local n = #parts
	if n > Limits.MAX_PARTS then
		return nil, "TooManyParts"
	end
	for i = 1, n do
		local e: PlanError? = checkShape(parts[i])
		if e then
			return nil, e
		end
	end
	for i = 1, n do
		local e: PlanError? = checkMaterial(parts[i])
		if e then
			return nil, e
		end
	end
	if not isFinite(scale) then
		return nil, "NonFinite"
	end
	for i = 1, n do
		local e: PlanError? = checkFinite(parts[i])
		if e then
			return nil, e
		end
	end
	if scale <= 0 then
		return nil, "BadSize"
	end
	for i = 1, n do
		local e: PlanError? = checkSize(parts[i])
		if e then
			return nil, e
		end
	end

	local bounds: Bounds = {
		min = { math.huge, math.huge, math.huge },
		max = { -math.huge, -math.huge, -math.huge },
	}
	local slotBounds: { [DT.SlotId]: Bounds } = {}
	for i = 1, n do
		local part = parts[i]
		local lo, hi = Shapes.aabb(part)
		if not (finiteTuple(lo, 3) and finiteTuple(hi, 3)) then
			return nil, "NonFinite"
		end
		merge(bounds, lo, hi)
		local slot = slotBounds[part.slot]
		if slot then
			merge(slot, lo, hi)
		else
			slotBounds[part.slot] = { min = lo, max = hi }
		end
	end

	local point = anchorPoint(anchor, bounds)
	local primitives: { RenderPrimitive } = table.create(n)
	for i = 1, n do
		local prim: RenderPrimitive?, e: PlanError? = build(parts[i], point, scale)
		if prim == nil then
			return nil, e
		end
		primitives[i] = prim
	end
	return { primitives = primitives, bounds = bounds, slotBounds = slotBounds, anchor = anchor, scale = scale }, nil
end

function RenderPlan.primitive(part: PartData, anchor: Vec3, scale: number): (RenderPrimitive?, PlanError?)
	local e: PlanError? = checkShape(part) or checkMaterial(part) or checkFinite(part)
	if e then
		return nil, e
	end
	if not (finiteTuple(anchor, 3) and isFinite(scale)) then
		return nil, "NonFinite"
	end
	if scale <= 0 then
		return nil, "BadSize"
	end
	e = checkSize(part)
	if e then
		return nil, e
	end
	return build(part, anchor, scale)
end

return table.freeze(RenderPlan)
