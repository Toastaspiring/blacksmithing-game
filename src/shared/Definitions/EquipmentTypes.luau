--!strict
-- Definitions/EquipmentTypes (SPEC §2.6, §3.1, §3.7, §5.3, §16.5; rows S1, slot rules and geometry S2).
-- MVP: one Sword. Axe, Spear, Hammer and Armor ids are reserved in Definitions/Types (Phase 3: one more row here
-- plus one CraftPlans entry per type).
--   hitbox     1.6 × 5.0 × 0.6 stud, origin at the centre of its bottom face, centred on the planes x = 0 and z = 0
--              [Decision to confirm] (Q3)
--   slots      Blade 1–12 (rank 1, striking), Guard 0–8 (rank 2), Grip 1–6 (rank 3), Pommel 0–4 (rank 4); Blade and
--              Grip required, 24 parts in total (= MAX_PARTS) [Decision to confirm] (Q4). Slot maxima are validation
--              rules (SlotTooMany, anti-filler); rank orders overlap ownership (an overlap takes the Blade first).
--   partsMin   2, partsMax 24: the required slots' minima and MAX_PARTS, read only by the editor's part-count hint
--   refs       factor reference ranges in FactorId order (§5.3, fitted so the iron arming sword C02 sits ≥ 0.05 below
--              Hard on every step, E-S2.9); PartCount, Joints and MaterialMix are Phase 2 factors (reported,
--              unweighted). Thinness's range is σ = L/τ and equals Balance.Difficulty SIGMA_LO / SIGMA_HI.

local Catalog = require("./Catalog")
local DT = require("./Types")

local ROWS: { DT.EquipmentTypeDef } = {
	{
		id = "Sword",
		name = "Sword",
		order = 1,
		enabled = true,
		kind = "Weapon",
		slots = {
			{ id = "Blade", name = "Blade", required = true, min = 1, max = 12, rank = 1 },
			{ id = "Guard", name = "Guard", required = false, min = 0, max = 8, rank = 2 },
			{ id = "Grip", name = "Grip", required = true, min = 1, max = 6, rank = 3 },
			{ id = "Pommel", name = "Pommel", required = false, min = 0, max = 4, rank = 4 },
		},
		geometry = {
			hitboxMin = { -0.80, 0.00, -0.30 },
			hitboxMax = { 0.80, 5.00, 0.30 },
			partsMin = 2,
			partsMax = 24,
			strikingSlot = "Blade", -- reach, edge, Sharpening work set
			gripSlot = "Grip", -- hand position (grip point) and physics axis
			guardSlot = "Guard", -- guard line for balance
			thicknessAxis = { 0, 0, 1 }, -- blueprint +Z (§3.1)
			refs = {
				{ factor = "PartCount", lo = 3, hi = 16 }, -- parts (volume-weighted count)
				{ factor = "Thinness", lo = 45, hi = 130 }, -- σ = L/τ
				{ factor = "Asymmetry", lo = 0, hi = 0.6 }, -- fraction
				{ factor = "SurfaceComplexity", lo = 2.3, hi = 2.9 }, -- ratio, a cube scores 1
				{ factor = "EdgeLength", lo = 4.8, hi = 8.0 }, -- studs, main chain
				{ factor = "Joints", lo = 3, hi = 24 }, -- joint units
				{ factor = "MaterialMix", lo = 1, hi = 4 }, -- distinct materials
				{ factor = "Volume", lo = 0.08, hi = 0.80 }, -- stud³, owned volume
			},
		},
	},
}

return Catalog.build(ROWS)
