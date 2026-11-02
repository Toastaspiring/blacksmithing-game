--!strict
-- Definitions/Steps (SPEC §2.6, §5.3, §16.6; rows S1, family S3, factor weights S2).
-- `order` is the 10-spaced catalogue order; which steps a type plays, in which order, on which parts, with which
-- weight and feeding which stats lives only in Definitions/CraftPlans (§7.1). Factor weights are arrays in FactorId
-- order (Definitions/Types) and sum to 1 (Validate D6): g_s = q(Σ_f w_{s,f} · x_f) (§5.1).
-- MVP: Smelting (HoldZone), Hammering (TimingStrike), Sharpening (PrecisionTrace). Quenching, Assembly and Finishing
-- carry their Phase 2 weights (hooks, not computed); Casting and Riveting have none yet.

local Catalog = require("./Catalog")
local DT = require("./Types")

local ROWS: { DT.StepDef } = {
	{
		id = "Smelting",
		name = "Smelting",
		order = 10,
		enabled = true,
		family = "HoldZone",
		factorWeights = { -- material acts through S3 and S4
			{ factor = "Volume", w = 1.00 },
		},
	},
	{
		id = "Casting",
		name = "Casting",
		order = 20,
		enabled = false,
		family = "HoldZone", -- placeholder
		factorWeights = {},
	},
	{
		id = "Hammering",
		name = "Hammering",
		order = 30,
		enabled = true,
		family = "TimingStrike",
		factorWeights = { -- "thin parts warp under the hammer"
			{ factor = "Thinness", w = 0.40 },
			{ factor = "Asymmetry", w = 0.30 },
			{ factor = "SurfaceComplexity", w = 0.30 },
		},
	},
	{
		id = "Quenching",
		name = "Quenching",
		order = 40,
		enabled = false,
		family = "ReleaseTiming",
		factorWeights = { -- Phase 2 hook
			{ factor = "PartCount", w = 0.40 },
			{ factor = "Thinness", w = 0.60 },
		},
	},
	{
		id = "Sharpening",
		name = "Sharpening",
		order = 50,
		enabled = true,
		family = "PrecisionTrace",
		factorWeights = { -- the edge leads grinding (EdgeLength 0.50, listed last in FactorId order)
			{ factor = "Asymmetry", w = 0.30 },
			{ factor = "SurfaceComplexity", w = 0.20 },
			{ factor = "EdgeLength", w = 0.50 },
		},
	},
	{
		id = "Assembly",
		name = "Assembly",
		order = 60,
		enabled = false,
		family = "FitPuzzle",
		factorWeights = { -- Phase 2 hook
			{ factor = "PartCount", w = 0.35 },
			{ factor = "Joints", w = 0.45 },
			{ factor = "MaterialMix", w = 0.20 },
		},
	},
	{
		id = "Riveting",
		name = "Riveting",
		order = 65,
		enabled = false,
		family = "TimingStrike",
		factorWeights = {},
	},
	{
		id = "Finishing",
		name = "Finishing",
		order = 70,
		enabled = false,
		family = "RhythmSequence",
		factorWeights = { -- Phase 2 hook
			{ factor = "SurfaceComplexity", w = 1.00 },
		},
	},
}

return Catalog.build(ROWS)
