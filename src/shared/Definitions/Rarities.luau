--!strict
-- Definitions/Rarities (SPEC §2.7, §8.4, §16.8; rows and colours S1 / S7, minQuality S4).
-- byScore = the highest enabled rarity with Q ≥ minQuality (inclusive; Common 0), then capped by the hardest passed
-- step's tier (Crafting/Rarity, S4). The MVP enables Common..Epic because its tiers cap at Epic; Legendary, Mythic and
-- Divine are placeholders (minQuality = d(tier) × 1.04 / 1.25 up the ladder). Thresholds 0.55 / 0.84 / 1.04 come from
-- a grid search on S3's score distributions, minimum margin 6.15 points [Decision to confirm] (Q12, E-S4.7). The UI
-- prints a rarity's name next to its colour.

local Catalog = require("./Catalog")
local DT = require("./Types")

local ROWS: { DT.RarityDef } = {
	{ id = "Common", name = "Common", order = 1, enabled = true, color = { 170, 170, 170 }, minQuality = 0 },
	{ id = "Uncommon", name = "Uncommon", order = 2, enabled = true, color = { 96, 196, 96 }, minQuality = 0.55 },
	{ id = "Rare", name = "Rare", order = 3, enabled = true, color = { 72, 140, 232 }, minQuality = 0.84 },
	{ id = "Epic", name = "Epic", order = 4, enabled = true, color = { 168, 92, 224 }, minQuality = 1.04 },
	{ id = "Legendary", name = "Legendary", order = 5, enabled = false, color = { 240, 164, 48 }, minQuality = 1.29 },
	{ id = "Mythic", name = "Mythic", order = 6, enabled = false, color = { 232, 64, 64 }, minQuality = 1.58 },
	{ id = "Divine", name = "Divine", order = 7, enabled = false, color = { 255, 236, 180 }, minQuality = 1.91 },
}

return Catalog.build(ROWS)
