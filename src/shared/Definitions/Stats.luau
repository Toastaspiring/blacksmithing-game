--!strict
-- Definitions/Stats (SPEC §2.7, §8.2, §16.9; rows S4, shapes S1): the item stats and how they display.
-- MVP: Damage, Sharpness, Durability, Purity, Balance, Reach [Decision to confirm] (Q13); items key stats by StatId
-- (stats.Damage …), stored on the 1e-4 grid. Purity is stored as 100·P. SwingSpeed, Defense and Mobility are
-- reserved (Phase 2+). Stats never feed Q or rarity (§8). `unit` and `decimals` are the display rule S6 and S7 share.
-- Stats.qualityPoints(Q) is the displayed Quality: floor(Q·100 + 0.5) on the open scale where 100 = a flawless
-- all-Normal Iron sword of the plainest design (D = 0) (§8.3).

local Catalog = require("./Catalog")
local DT = require("./Types")

local ROWS: { DT.StatDef } = {
	{ id = "Damage", name = "Damage", order = 1, enabled = true, unit = "", decimals = 0 },
	{ id = "Sharpness", name = "Sharpness", order = 2, enabled = true, unit = "", decimals = 0 },
	{ id = "Durability", name = "Durability", order = 3, enabled = true, unit = "", decimals = 0 },
	{ id = "Purity", name = "Purity", order = 4, enabled = true, unit = "%", decimals = 0 },
	{ id = "Balance", name = "Balance", order = 5, enabled = true, unit = "", decimals = 0 },
	{ id = "Reach", name = "Reach", order = 6, enabled = true, unit = "studs", decimals = 1 },
	{ id = "SwingSpeed", name = "Swing speed", order = 7, enabled = false, unit = "", decimals = 0 },
	{ id = "Defense", name = "Defense", order = 8, enabled = false, unit = "", decimals = 0 },
	{ id = "Mobility", name = "Mobility", order = 9, enabled = false, unit = "", decimals = 0 },
}

local catalog = Catalog.build(ROWS)

-- floor(Q·100 + 0.5): the Quality number the UI shows (Q 0.8326 → 83, F5 flawless 1.0125 → 101).
local function qualityPoints(q: number): number
	if type(q) ~= "number" or q ~= q or q == math.huge or q == -math.huge then
		error("Stats.qualityPoints: Q must be a finite number, got " .. tostring(q), 2)
	end
	return math.floor(q * 100 + 0.5)
end

-- Catalog.Catalog<StatDef> (the catalog views every catalog module returns) plus the Quality display rule
export type Stats = {
	ordered: { DT.StatDef },
	enabled: { DT.StatDef },
	byId: { [string]: DT.StatDef },
	get: (id: string) -> DT.StatDef?,
	isEnabled: (id: string) -> boolean,
	qualityPoints: (q: number) -> number,
}

local Stats: Stats = {
	ordered = catalog.ordered,
	enabled = catalog.enabled,
	byId = catalog.byId,
	get = catalog.get,
	isEnabled = catalog.isEnabled,
	qualityPoints = qualityPoints,
}

return table.freeze(Stats)
