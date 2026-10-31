--!strict
-- S4 prototype data. Mirrors the tables of SPEC §7/§8 (draft S4-crafting-outcome.md).
-- In the real tree these values live in Definitions/{Materials,Tiers,Rarities,CraftPlans,Balance}.
-- Fields marked (S1) are S1-owned physical values ASSUMED here; everything else is S4-owned.

local Defs = {}

Defs.BALANCE_VERSION = 1

-- Materials: density/hardness/toughness/difficulty are S1/S2 values (assumed);
-- qualityTier (T) is S4's.
Defs.MaterialOrder = { "Iron", "Steel" }
Defs.Materials = {
	Iron = { density = 7.87, hardness = 0.50, toughness = 0.50, difficulty = 0.00, qualityTier = 1.00 },
	Steel = { density = 7.85, hardness = 0.70, toughness = 0.50, difficulty = 0.10, qualityTier = 1.10 },
}

-- Tiers: qualityMultiplier (d), rarityCap, failScoreFactor are S4's values.
Defs.TierOrder = { "Normal", "Hard", "Expert", "Master", "Hell" }
Defs.Tiers = {
	Normal = { order = 1, enabled = true, qualityMultiplier = 1.00, rarityCap = "Rare", failScoreFactor = 0.75 },
	Hard = { order = 2, enabled = true, qualityMultiplier = 1.25, rarityCap = "Epic", failScoreFactor = 0.75 },
	Expert = { order = 3, enabled = false, qualityMultiplier = 1.55, rarityCap = "Legendary", failScoreFactor = 0.75 },
	Master = { order = 4, enabled = false, qualityMultiplier = 1.90, rarityCap = "Mythic", failScoreFactor = 0.75 },
	Hell = { order = 5, enabled = false, qualityMultiplier = 2.30, rarityCap = "Divine", failScoreFactor = 0.75 },
}

-- Rarities: minQuality thresholds on Q are S4's values.
Defs.RarityOrder = { "Common", "Uncommon", "Rare", "Epic", "Legendary", "Mythic", "Divine" }
Defs.Rarities = {
	Common = { order = 1, minQuality = 0.00 },
	Uncommon = { order = 2, minQuality = 0.50 },
	Rare = { order = 3, minQuality = 0.72 },
	Epic = { order = 4, minQuality = 0.92 },
	Legendary = { order = 5, minQuality = 1.14 }, -- Phase 2 placeholder: d_Expert * 0.736
	Mythic = { order = 6, minQuality = 1.40 }, -- Phase 2 placeholder: d_Master * 0.736
	Divine = { order = 7, minQuality = 1.69 }, -- Phase 2 placeholder: d_Hell * 0.736
}

-- Craft plan for the Sword (play order). Weights sum to 1.
Defs.CraftPlans = {
	Sword = {
		{ step = "Smelting", family = "HoldZone", weight = 0.25, worksOn = { kind = "All" } },
		{ step = "Hammering", family = "TimingStrike", weight = 0.40, worksOn = { kind = "All" } },
		{ step = "Sharpening", family = "PrecisionTrace", weight = 0.35, worksOn = { kind = "Slots", slots = { "Blade" } } },
	},
}

Defs.Quality = {
	FailedStepCapTier = "Normal", -- a failed step contributes this tier's cap
	Scale = 10000, -- Q is quantized to 1/Scale (round half up) before thresholds/storage
}

Defs.Stats = {
	-- Damage
	DamageBase = 25, -- points for a reference-mass, blunt, perfectly hammered sword
	MassRef = 0.85, -- mass units; ~ S2 prototype reference arming sword in Iron (0.835)
	MassBias = 0.4, -- share of the mass factor that does not depend on mass
	MassFactorMin = 0.6,
	MassFactorMax = 1.3,
	EdgeRef = 6.0, -- studs of sharpenable edge giving a full cutting profile (c = 1)
	EdgeGain = 1.0, -- F_edge = 1 + EdgeGain * c * Sharpness/100
	ForgeFloor = 0.6, -- F_forge = ForgeFloor + (1 - ForgeFloor) * s_ham
	-- Purity
	PurityFloor = 0.70, -- P at smelting score 0
	-- Sharpness
	SharpFloor = 0.30, -- share of hardness kept at sharpening score 0
	-- Durability
	DuraFloor = 0.50, -- share of toughness kept at hammering score 0
	-- Balance
	BalanceIdeal = 0.08, -- ideal (balance offset from guard centroid) / reach
	BalanceTolerance = 0.04, -- plateau half-width around the ideal (full marks)
	BalanceFalloff = 0.30, -- beyond the plateau, linear drop to 0 over this distance
	BalanceReachMin = 1.0, -- studs; floor on reach in the ratio (division guard)
	StatMax = 100,
}

return Defs
