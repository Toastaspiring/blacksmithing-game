--!strict
-- Definitions/Tiers (SPEC §2.7, §5.4, §8.3, §8.4, §16.7; rows S1, dMin S2, rarityCap / qualityMultiplier /
-- failScoreFactor / failOutcome S4).
-- [dMin, dMax) on D_s, the last tier includes 1. The MVP enables Normal and Hard, so every step with D ≥ 0.2 plays
-- Hard [Decision to confirm] (Q1): the clamp is data (the enabled prefix), not code. Expert, Master and Hell are
-- measured (tierRaw) and shown, never played; their S4 columns are placeholders.
-- qualityMultiplier is d(tier) in Q (§8.3); a failed step counts at failScoreFactor 0.75 and lifts no cap (Q9);
-- the hardest passed step's rarityCap caps the rarity (Q10). failOutcome DestroyMaterial (Hell) is Phase 2.
--
--   Tiers.tierFor(D)    = the enabled tier with the greatest order such that D ≥ dMin   (D on S2's 1e-4 grid)
--   Tiers.tierRawFor(D) = the same over all tiers (S2 reports both)
--   0.1999 → Normal, 0.2000 → Hard, 0.85 → Hard (raw Hell). D must be a finite number in [0, 1], else they error.

local Catalog = require("./Catalog")
local DT = require("./Types")

local ROWS: { DT.TierDef } = {
	{
		id = "Normal",
		name = "Normal",
		order = 1,
		enabled = true,
		dMin = 0.0,
		dMax = 0.2,
		risk = "Low",
		color = { 111, 191, 115 },
		rarityCap = "Rare",
		qualityMultiplier = 1.00,
		failScoreFactor = 0.75,
		failOutcome = "LowerQuality",
	},
	{
		id = "Hard",
		name = "Hard",
		order = 2,
		enabled = true,
		dMin = 0.2,
		dMax = 0.4,
		risk = "Medium",
		color = { 242, 193, 78 },
		rarityCap = "Epic",
		qualityMultiplier = 1.25,
		failScoreFactor = 0.75,
		failOutcome = "LowerQuality",
	},
	{
		id = "Expert",
		name = "Expert",
		order = 3,
		enabled = false,
		dMin = 0.4,
		dMax = 0.6,
		risk = "High",
		color = { 242, 140, 40 },
		rarityCap = "Legendary",
		qualityMultiplier = 1.55,
		failScoreFactor = 0.75,
		failOutcome = "LowerQuality",
	},
	{
		id = "Master",
		name = "Master",
		order = 4,
		enabled = false,
		dMin = 0.6,
		dMax = 0.8,
		risk = "Very high",
		color = { 217, 68, 43 },
		rarityCap = "Mythic",
		qualityMultiplier = 1.90,
		failScoreFactor = 0.75,
		failOutcome = "LowerQuality",
	},
	{
		id = "Hell",
		name = "Hell",
		order = 5,
		enabled = false,
		dMin = 0.8,
		dMax = 1.0,
		risk = "Extreme",
		color = { 142, 27, 27 },
		rarityCap = "Divine",
		qualityMultiplier = 2.30,
		failScoreFactor = 0.75,
		failOutcome = "DestroyMaterial",
	},
}

local catalog = Catalog.build(ROWS)

local function pick(rows: { DT.TierDef }, d: number, fn: string): DT.TierId
	if type(d) ~= "number" or d ~= d or d < 0 or d > 1 then
		error(string.format("Tiers.%s: D must be a finite number in [0, 1], got %s", fn, tostring(d)), 3)
	end
	local found: DT.TierDef? = nil
	for _, row in rows do
		if d >= row.dMin then
			found = row
		end
	end
	if found == nil then
		error(string.format("Tiers.%s: no tier starts at or below %s", fn, tostring(d)), 3)
	end
	return found.id
end

local function tierFor(d: number): DT.TierId
	return pick(catalog.enabled, d, "tierFor")
end

local function tierRawFor(d: number): DT.TierId
	return pick(catalog.ordered, d, "tierRawFor")
end

-- Catalog.Catalog<TierDef> (the catalog views every catalog module returns) plus the tier mapping
export type Tiers = {
	ordered: { DT.TierDef },
	enabled: { DT.TierDef },
	byId: { [string]: DT.TierDef },
	get: (id: string) -> DT.TierDef?,
	isEnabled: (id: string) -> boolean,
	tierFor: (d: number) -> DT.TierId,
	tierRawFor: (d: number) -> DT.TierId,
}

local Tiers: Tiers = {
	ordered = catalog.ordered,
	enabled = catalog.enabled,
	byId = catalog.byId,
	get = catalog.get,
	isEnabled = catalog.isEnabled,
	tierFor = tierFor,
	tierRawFor = tierRawFor,
}

return table.freeze(Tiers)
