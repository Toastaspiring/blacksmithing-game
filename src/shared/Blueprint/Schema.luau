--!strict
-- Blueprint/Schema (SPEC §3.3; owner S1): the blueprint types every section uses; nobody redefines them. Types only;
-- it returns an empty frozen table. Blueprint space, the canonical form and the wire rules: §3.1, §3.5, §3.6.
--   schema    BLUEPRINT_SCHEMA (Definitions/Versions): a blueprint is self-describing outside the profile (fixtures,
--             Phase 3 sharing); after load every record and snapshot has the current value (§9.6), and the wire
--             accepts only it
--   analysis  a cache: stale when absent (the Starter Sword that Prepare grants has none) or when
--             balanceVersion ≠ BALANCE_VERSION; rewritten on every save, recomputed by the client for display when
--             stale; the server never accepts it (nor revision, timestamps or item data) from a client (§3.10)
--   summary   materials = the distinct part materials in Materials order (Blueprint/Views)
-- Work in progress: saving needs only §3.6 (Canonical.draft); S2's validation gates forging (Q6). There is no
-- mirrored flag: every shape mirrors to a rotated copy of itself (§3.8).

local DT = require("../Definitions/Types")

export type Vec3 = DT.Vec3 -- {x, y, z}: raw finite doubles, studs
export type Quat = { number } -- {qx, qy, qz, qw} (CFrame.new order), canonical form §3.5
export type BlueprintId = string -- upper-case GUID

export type PartData = {
	id: number, -- integer 1..MAX_PART_ID, unique in the blueprint
	slot: DT.SlotId, -- a slot of the blueprint's type
	shape: DT.ShapeId,
	material: DT.MaterialId, -- per part (Q14); enabled and allowed for the slot
	pos: Vec3, -- part centre, blueprint space (§3.1)
	rot: Quat, -- orientation, blueprint space (§3.1)
	size: Vec3, -- Part.Size along local X, Y, Z (Cylinder axis = local X)
}

export type BlueprintCore = { schema: number, name: string, type: DT.EquipmentTypeId, parts: { PartData } }
export type BlueprintDraft = BlueprintCore -- client → server; the id travels as Save.blueprintId

export type PhysicsView = { mass: number, balance: number, reach: number } -- S2 names and semantics (§4)
export type StepPreview = { step: DT.StepId, difficulty: number, tier: DT.TierId }

export type BlueprintAnalysis = { -- Pipeline.summary(report); written by the server only
	balanceVersion: number,
	valid: boolean,
	issues: { string }, -- distinct S2 ValidationCode values, ≤ MAX_ISSUES_STORED
	physics: PhysicsView?, -- absent when structural validation failed
	steps: { StepPreview }, -- plan order; empty when not analysed
}

export type BlueprintRecord = BlueprintCore & { -- Profile.Data.blueprints[id]
	id: BlueprintId,
	revision: number, -- revision 1 on creation, +1 per accepted save
	createdAt: number, -- os.time(), server clock
	updatedAt: number,
	analysis: BlueprintAnalysis?,
}

export type BlueprintSnapshot = BlueprintCore & { sourceId: BlueprintId, sourceRevision: number } -- in an item

export type BlueprintSummary = {
	id: BlueprintId,
	name: string,
	type: DT.EquipmentTypeId,
	revision: number,
	updatedAt: number,
	partCount: number,
	materials: { DT.MaterialId },
	analysis: BlueprintAnalysis?,
}

return table.freeze({})
