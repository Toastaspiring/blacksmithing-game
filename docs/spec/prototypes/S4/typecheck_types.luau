--!strict
export type StepId = string        -- "Smelting" | "Hammering" | "Sharpening" (later "Quenching", ...)
export type TierId = string        -- "Normal" | "Hard" | "Expert" | "Master" | "Hell"
export type MaterialId = string    -- "Iron" | "Steel" (later more)
export type RarityId = string      -- "Common" .. "Divine"
export type SlotId = string        -- "Blade" | "Guard" | "Grip" | "Pommel"
export type FamilyId = string      -- "HoldZone" | "TimingStrike" | "PrecisionTrace"
export type StatId = "Damage" | "Reach" | "Durability" | "Sharpness" | "Purity" | "Balance"

-- What Crafting reads from other owners' records (their types must be supersets).
export type BlueprintInputs = {    -- Assumes (S1)
	equipmentType: string,
	parts: { { slot: SlotId, material: MaterialId } },
}
export type PhysicsInputs = {      -- Assumes (S2); S2 prototype names in brackets
	mass: number,                  -- mass units                                   [mass.mass]
	reach: number,                 -- studs, grip centroid -> furthest Blade point [mass.reach]
	balanceOffset: number,         -- studs, COM.y - guard line, + toward the tip  [mass.balance]
	edgeLength: number,            -- studs of sharpenable Blade edge              [edge.length]
	kept: { boolean },             -- per blueprint part                           [kept]
	partVolumes: { number },       -- per blueprint part, owned stud³              [ownV]; only kept parts are summed
}
export type DifficultyInputs = {   -- Assumes (S2); S2's prototype emits a list { id, G, m, D, tier, played }
	steps: { [StepId]: { difficulty: number, tier: TierId } },   -- tier = played tier (clamped)
}
export type StepScore = { score: number, passed: boolean }   -- Assumes (S3): replay result
export type StepRun = {            -- Assumes (S5): what the session holds per scored step (superset of StepScore)
	seed: number, score: number, passed: boolean, timedOut: boolean, durationMs: number,
}

-- Plan data (Definitions/CraftPlans) and the frozen plan.
export type WorkSelector = "All" | { SlotId }   -- "All" kept parts, or the kept parts of these slots
export type PlanStepDef = { step: StepId, weight: number, worksOn: WorkSelector, feeds: { StatId } }
export type CraftPlanDef = { equipmentType: string, steps: { PlanStepDef } }

export type PlannedStep = {
	index: number,                 -- 1..n, play order
	step: StepId,
	family: FamilyId,
	weight: number,                -- w_i
	tier: TierId,                  -- played tier (enabled tiers only)
	difficulty: number,            -- D_s
	material: MaterialId,          -- mat_s: drives m_s (S2) and m_material (S3)
	workParts: { number },         -- kept part indices, ascending
}
export type CraftPlan = { equipmentType: string, balanceVersion: number, steps: { PlannedStep } }

-- Outcome.
export type StatInputs = {
	mass: number, reach: number, balanceOffset: number, edgeLength: number,
	bladeHardness: number,         -- H
	bodyToughness: number,         -- K
	smelting: number,              -- effective scores (F1)
	hammering: number,
	sharpening: number,
}
export type ItemStats = {
	damage: number, reach: number, durability: number, sharpness: number, purity: number, balance: number,
}
export type StatBreakdown = {      -- unquantized intermediates (tests, results-card tooltips)
	purity: number, hEff: number, kEff: number, sharpness: number, durability: number, c: number,
	fMass: number, fEdge: number, fForge: number, damage: number, beta: number, balance: number, reach: number,
}
export type QualityTerm = { step: StepId, weight: number, effectiveScore: number, multiplier: number, contribution: number }
export type QualityResult = { q: number, materialTier: number, terms: { QualityTerm } }
export type RarityResult = { rarity: RarityId, byScore: RarityId, cap: RarityId, capStep: StepId? }
export type Outcome = { stats: ItemStats, quality: QualityResult, rarity: RarityResult }

export type CraftStepRecord = {
	step: StepId,          -- "Smelting"
	tier: TierId,          -- tier actually played (kept on recompute: it is a fact)
	difficulty: number,    -- D_s at open, quantized to 1e-3
	material: MaterialId,  -- material whose modifiers the minigame used (mat_s)
	seed: number,          -- u32 issued by the server for this step
	score: number,         -- raw replay score 0..1, as returned by S3 (Assumes (S3): quantized to 1e-4)
	passed: boolean,
	timedOut: boolean,     -- R8: started but never submitted (score 0, failed)
	durationMs: number,    -- length of the accepted input timeline, 0 if timed out (Assumes (S3/S5))
}

export type StoredOutcome = {
	stats: ItemStats,      -- §8.2, quantized
	quality: number,       -- Q, quantized to 1e-4
	materialTier: number,  -- T, quantized to 1e-4
	rarity: RarityId,      -- final
	rarityByScore: RarityId,
	rarityCap: RarityId,
	capStep: StepId?,      -- step that set the cap; key absent = base cap (Profile.Data allows absent keys)
}

export type CraftRecord = {
	balanceVersion: number,          -- BALANCE_VERSION the item was forged under
	steps: { CraftStepRecord },      -- plan order, no gaps
	outcome: StoredOutcome,
}


return {}
