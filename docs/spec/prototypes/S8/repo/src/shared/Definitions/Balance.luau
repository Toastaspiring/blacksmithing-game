--!strict
-- PROTOTYPE stand-in for S1's Definitions/Balance (values are placeholders).
local Balance = {
	BALANCE_VERSION = 1,
	tierThresholds = { Normal = 0.0, Hard = 0.2 },
	stepWeights = {
		Smelting = { MaterialTerm = 0.0, Volume = 1.0 },
		Hammering = { Thinness = 0.4, Asymmetry = 0.3, SurfaceComplexity = 0.3 },
		Sharpening = { EdgeLength = 0.5, SurfaceComplexity = 0.3, Asymmetry = 0.2 },
	},
}
return table.freeze(Balance)
