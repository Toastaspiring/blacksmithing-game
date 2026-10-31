--!strict
-- S4 prototype v2: the Definitions values S4 owns or reads (SPEC §2, §7, §8), as ordered arrays.
-- Real tree: Definitions/{Materials, Tiers, Rarities, Stats, CraftPlans, Balance}. Mutable here ONLY so the tuning
-- scripts can try alternatives (Defs.set); production Definitions are deep-frozen.
local Defs = {}

-- Materials (S1 rows; S4 owns qualityTier). hardness/toughness are S1's integers 0-100.
Defs.Materials = {
	{ id = "Iron", order = 1, enabled = true, density = 7.87, hardness = 45, toughness = 50, difficultyTerm = 0.0, qualityTier = 1.00 },
	{ id = "Steel", order = 2, enabled = true, density = 7.85, hardness = 70, toughness = 55, difficultyTerm = 0.0, qualityTier = 1.02 },
}

-- Tiers (S1 rows; S4 owns rarityCap, qualityMultiplier, failScoreFactor, failOutcome).
Defs.Tiers = {
	{ id = "Normal", order = 1, enabled = true, dMin = 0.0, dMax = 0.2, rarityCap = "Rare", qualityMultiplier = 1.00, failScoreFactor = 0.75, failOutcome = "LowerQuality" },
	{ id = "Hard", order = 2, enabled = true, dMin = 0.2, dMax = 0.4, rarityCap = "Epic", qualityMultiplier = 1.25, failScoreFactor = 0.75, failOutcome = "LowerQuality" },
	{ id = "Expert", order = 3, enabled = false, dMin = 0.4, dMax = 0.6, rarityCap = "Legendary", qualityMultiplier = 1.55, failScoreFactor = 0.75, failOutcome = "LowerQuality" },
	{ id = "Master", order = 4, enabled = false, dMin = 0.6, dMax = 0.8, rarityCap = "Mythic", qualityMultiplier = 1.90, failScoreFactor = 0.75, failOutcome = "LowerQuality" },
	{ id = "Hell", order = 5, enabled = false, dMin = 0.8, dMax = 1.0, rarityCap = "Divine", qualityMultiplier = 2.30, failScoreFactor = 0.75, failOutcome = "DestroyMaterial" },
}

-- Rarities (S1 rows; S4 owns minQuality). Placeholders above Epic follow the ladder rule minQ = d_tier * Epic/d_Hard.
Defs.Rarities = {
	{ id = "Common", order = 1, enabled = true, minQuality = 0.00 },
	{ id = "Uncommon", order = 2, enabled = true, minQuality = 0.55 },
	{ id = "Rare", order = 3, enabled = true, minQuality = 0.84 },
	{ id = "Epic", order = 4, enabled = true, minQuality = 1.04 },
	{ id = "Legendary", order = 5, enabled = false, minQuality = 1.29 },
	{ id = "Mythic", order = 6, enabled = false, minQuality = 1.58 },
	{ id = "Divine", order = 7, enabled = false, minQuality = 1.91 },
}

-- Definitions/CraftPlans (S4): per equipment type, ordered, append-only; retire with enabled = false.
Defs.CraftPlans = {
	{ type = "Sword", steps = {
		{ step = "Smelting", weight = 0.25, worksOn = "All", feeds = { "Purity" }, enabled = true },
		{ step = "Hammering", weight = 0.40, worksOn = "All", feeds = { "Damage", "Durability" }, enabled = true },
		{ step = "Sharpening", weight = 0.35, worksOn = { "Blade" }, feeds = { "Sharpness", "Damage" }, enabled = true },
	} },
}

Defs.StepFamily = { Smelting = "HoldZone", Hammering = "TimingStrike", Sharpening = "PrecisionTrace",
	Quenching = "ReleaseTiming", Assembly = "FitPuzzle", Finishing = "RhythmSequence" }

-- Definitions/Balance.Stats (S4): rows per EquipmentTypeId.
Defs.Stats = {
	Sword = {
		MATERIAL_SCALE = 100,
		PURITY_FLOOR = 0.70, SHARP_FLOOR = 0.30, DURA_FLOOR = 0.50, FORGE_FLOOR = 0.60,
		EDGE_REF = 6.0, EDGE_GAIN = 1.0,
		MASS_REF = 0.80, MASS_BIAS = 0.4, MASS_FACTOR_MIN = 0.6, MASS_FACTOR_MAX = 1.3,
		DAMAGE_BASE = 28,
		BALANCE_IDEAL = 0.08, BALANCE_TOLERANCE = 0.04, BALANCE_FALLOFF = 0.30, BALANCE_REACH_MIN = 1.0,
		STAT_MAX = 100,
	},
}

-- Definitions/Balance.Quality (S4).
Defs.Quality = {
	FAILED_STEP_CAP_TIER = "Normal",
	DESIGN_GAMMA = 0.15,
	WEIGHT_SUM_TOL = 1e-9,
	CAP_RULE = "Max", -- prototype only: "Max" (default) | "Majority" | "Striking" (alternatives evaluated, E-S4)
}

local function index(rows: { any }): { [string]: any }
	local m = {}
	for _, r in rows do
		m[r.id or r.type] = r
	end
	return m
end
Defs.material = index(Defs.Materials)
Defs.tier = index(Defs.Tiers)
Defs.rarity = index(Defs.Rarities)
Defs.plan = index(Defs.CraftPlans)

-- prototype-only knob for the tuning scripts
function Defs.set(o: { [string]: any })
	if o.thresholds then
		for i, v in o.thresholds do
			Defs.Rarities[i + 1].minQuality = v -- {Uncommon, Rare, Epic}
		end
	end
	if o.steelT then
		Defs.material.Steel.qualityTier = o.steelT
	end
	if o.gamma then
		Defs.Quality.DESIGN_GAMMA = o.gamma
	end
	if o.phi then
		for _, t in Defs.Tiers do
			t.failScoreFactor = o.phi
		end
	end
	if o.dHard then
		Defs.tier.Hard.qualityMultiplier = o.dHard
	end
	if o.capRule then
		Defs.Quality.CAP_RULE = o.capRule
	end
	if o.weights then
		for i, w in o.weights do
			Defs.CraftPlans[1].steps[i].weight = w
		end
	end
end

return Defs
