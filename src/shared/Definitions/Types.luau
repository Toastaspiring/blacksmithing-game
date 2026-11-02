--!strict
-- Definitions/Types (SPEC §2.2, §2.4; owner S1): the only module that declares id unions, plus the definition
-- record types every Definitions catalog uses. Types only; it returns an empty frozen table.
-- Ids are PascalCase, persisted verbatim and append-only: once an id can appear in Profile.Data it is never renamed
-- or deleted, only retired with `enabled = false` (§2.2). Untrusted strings become typed ids only through
-- Catalog.get / isEnabled.

-- ── ids (§2.2) ────────────────────────────────────────────────────────────────────────────────────────────────

export type EquipmentTypeId = "Sword" | "Axe" | "Spear" | "Hammer" | "Armor"
export type SlotId = "Blade" | "Guard" | "Grip" | "Pommel" -- Sword (MVP)
	| "Head" | "Haft" | "Tip" | "Shaft" | "Butt" | "Handle" -- reserved: Axe, Spear, Hammer
	| "Helmet" | "Pauldrons" | "Chestplate" | "Bracers" | "Belt" | "LegPlates" | "Boots" -- reserved: Armor
export type ShapeId = "Block" | "Wedge" | "CornerWedge" | "Cylinder" | "Ball"
export type MaterialId = "Iron" | "Steel" | "Bronze" | "Mithril" | "Obsidian" | "Wood" | "Leather"
export type StepId = "Smelting" | "Casting" | "Hammering" | "Quenching" | "Sharpening" | "Assembly" | "Riveting" | "Finishing"
export type FamilyId = "HoldZone" | "TimingStrike" | "RhythmSequence" | "PrecisionTrace" | "ReleaseTiming" | "FitPuzzle"
export type TierId = "Normal" | "Hard" | "Expert" | "Master" | "Hell"
export type RarityId = "Common" | "Uncommon" | "Rare" | "Epic" | "Legendary" | "Mythic" | "Divine"
export type StatId = "Damage" | "Sharpness" | "Durability" | "Purity" | "Balance" | "Reach" -- MVP (S4)
	| "SwingSpeed" | "Defense" | "Mobility" -- reserved
export type FactorId = "PartCount" | "Thinness" | "Asymmetry" | "SurfaceComplexity" | "EdgeLength" | "Joints"
	| "MaterialMix" | "Volume" -- this order is "FactorId order" for every factor array (S2, §5.2)
export type StationId = "DraftingTable" | "Furnace" | "Anvil" | "Grindstone" -- S7 (§13)

-- ── definition records (§2.4) ─────────────────────────────────────────────────────────────────────────────────

export type RGB = { number } -- {r, g, b}, integers 0–255 (Color3.fromRGB at the edge)
export type Vec3 = { number } -- {x, y, z}; Blueprint/Schema re-exports it

export type MaterialDef = {
	id: MaterialId,
	name: string,
	order: number, -- order breaks governing-material ties (§7.2)
	enabled: boolean,
	class: "Metal" | "Mineral" | "Organic",
	blurb: string,
	density: number, -- mass units per stud³, shown as kg
	hardness: number, -- integer 0–100; S4's formulas divide by MATERIAL_SCALE
	toughness: number, -- integer 0–100
	color: RGB, -- render values S7 consumes: color, robloxMaterial, reflectance
	robloxMaterial: string,
	reflectance: number,
	allowedSlots: { SlotId }?, -- nil = any slot
	difficultyTerm: number, -- S2: m in D_s, 0–1
	qualityTier: number, -- S4: T in Q
}

export type SlotDef = {
	id: SlotId,
	name: string,
	required: boolean, -- rule columns S2 (§3.7)
	min: number,
	max: number,
	rank: number, -- overlap ownership: lower rank owns first (§4.3)
}

export type FactorWeight = { factor: FactorId, w: number }
export type FactorRange = { factor: FactorId, lo: number, hi: number }

export type GeometryRules = { -- field list and values S2 (§3.1, §5)
	hitboxMin: Vec3,
	hitboxMax: Vec3,
	partsMin: number, -- the editor's part-count hint only (slot rules and MAX_PARTS validate)
	partsMax: number,
	strikingSlot: SlotId,
	gripSlot: SlotId,
	guardSlot: SlotId?,
	thicknessAxis: Vec3,
	refs: { FactorRange }, -- S2's factor order (all 8 factors)
}

export type EquipmentTypeDef = {
	id: EquipmentTypeId,
	name: string,
	order: number,
	enabled: boolean,
	kind: "Weapon" | "Armor",
	slots: { SlotDef },
	geometry: GeometryRules,
}

export type StepDef = {
	id: StepId,
	name: string,
	order: number, -- 10-spaced catalogue order; play order lives in CraftPlans (§7.1)
	enabled: boolean,
	family: FamilyId,
	factorWeights: { FactorWeight }, -- weights S2, FactorId order; plan data in CraftPlans (S4)
}

export type TierDef = {
	id: TierId,
	name: string,
	order: number,
	enabled: boolean,
	dMin: number, -- [dMin, dMax) on D_s; the last tier includes 1
	dMax: number,
	risk: string,
	color: RGB,
	rarityCap: RarityId, -- S4 (§8)
	qualityMultiplier: number,
	failScoreFactor: number,
	failOutcome: "LowerQuality" | "DestroyMaterial", -- S4; DestroyMaterial: Hell, Phase 2
}

export type RarityDef = {
	id: RarityId,
	name: string,
	order: number,
	enabled: boolean,
	color: RGB,
	minQuality: number, -- S4
}

export type StatDef = {
	id: StatId,
	name: string,
	order: number,
	enabled: boolean,
	unit: string,
	decimals: number,
}

return table.freeze({})
