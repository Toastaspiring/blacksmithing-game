--!strict
-- tests/Definitions/EquipmentTypes.spec.luau — Definitions/EquipmentTypes (SPEC §2.6, §3.1, §3.7, §5.3, §16.5;
-- T-DEF-02, T-DEF-03).

local A = require("../lib/Assert")
local Test = require("../lib/Test")
local H = require("./DefsHelpers")
local Balance = require("../../src/shared/Definitions/Balance")
local EquipmentTypes = require("../../src/shared/Definitions/EquipmentTypes")
local Limits = require("../../src/shared/Definitions/Limits")
local Validate = require("../../src/shared/Definitions/Validate")

local function sword()
	local s = EquipmentTypes.get("Sword")
	assert(s, "Sword row")
	return s
end

return Test.suite("Definitions/EquipmentTypes", function(t)
	t.it("T-DEF-02 the MVP has one enabled type, the Sword (a Weapon, order 1)", function()
		A.deepEq(H.ids(EquipmentTypes.ordered), { "Sword" })
		A.deepEq(H.ids(EquipmentTypes.enabled), { "Sword" })
		local s = sword()
		A.eq(s.name, "Sword")
		A.eq(s.order, 1)
		A.eq(s.kind, "Weapon")
		for _, id in { "Axe", "Spear", "Hammer", "Armor" } do
			A.eq(EquipmentTypes.get(id), nil, id .. " is reserved, with no row yet")
		end
	end)

	t.it("Sword slots: Blade 1–12 r1, Guard 0–8 r2, Grip 1–6 r3, Pommel 0–4 r4; Blade and Grip required (Q4)", function()
		A.deepEq(sword().slots, {
			{ id = "Blade", name = "Blade", required = true, min = 1, max = 12, rank = 1 },
			{ id = "Guard", name = "Guard", required = false, min = 0, max = 8, rank = 2 },
			{ id = "Grip", name = "Grip", required = true, min = 1, max = 6, rank = 3 },
			{ id = "Pommel", name = "Pommel", required = false, min = 0, max = 4, rank = 4 },
		})
	end)

	t.it("Sword geometry: 1.6 × 5.0 × 0.6 hitbox from the bottom-face centre (Q3), parts 2–24, special slots", function()
		local g = sword().geometry
		A.deepEq(g.hitboxMin, { -0.80, 0.00, -0.30 })
		A.deepEq(g.hitboxMax, { 0.80, 5.00, 0.30 })
		A.eq(g.partsMin, 2, "the required slots' minima")
		A.eq(g.partsMax, 24)
		A.eq(g.partsMax, Limits.MAX_PARTS, "= MAX_PARTS")
		local minima = 0
		for _, s in sword().slots do
			if s.required then
				minima += s.min
			end
		end
		A.eq(g.partsMin, minima)
		A.eq(g.strikingSlot, "Blade")
		A.eq(g.gripSlot, "Grip")
		A.eq(g.guardSlot, "Guard")
		A.deepEq(g.thicknessAxis, { 0, 0, 1 })
		A.near(g.hitboxMax[1] - g.hitboxMin[1], 1.6, 1e-12, "width")
		A.near(g.hitboxMax[2] - g.hitboxMin[2], 5.0, 1e-12, "length")
		A.near(g.hitboxMax[3] - g.hitboxMin[3], 0.6, 1e-12, "thickness")
		A.eq(g.hitboxMin[1], -g.hitboxMax[1], "centred on x = 0")
		A.eq(g.hitboxMin[3], -g.hitboxMax[3], "centred on z = 0")
	end)

	t.it("T-DEF-03 reference ranges: the 8 factors in FactorId order with the §5.3 values", function()
		local refs = sword().geometry.refs
		A.deepEq(refs, {
			{ factor = "PartCount", lo = 3, hi = 16 },
			{ factor = "Thinness", lo = 45, hi = 130 },
			{ factor = "Asymmetry", lo = 0, hi = 0.6 },
			{ factor = "SurfaceComplexity", lo = 2.3, hi = 2.9 },
			{ factor = "EdgeLength", lo = 4.8, hi = 8.0 },
			{ factor = "Joints", lo = 3, hi = 24 },
			{ factor = "MaterialMix", lo = 1, hi = 4 },
			{ factor = "Volume", lo = 0.08, hi = 0.80 },
		})
		for i, r in refs do
			A.eq(r.factor, Validate.FACTOR_ORDER[i], "FactorId order")
		end
	end)

	t.it("the Thinness range is Balance.Difficulty SIGMA_LO..SIGMA_HI (one value, two views)", function()
		local thin = sword().geometry.refs[2]
		A.eq(thin.factor, "Thinness")
		A.eq(thin.lo, Balance.Difficulty.SIGMA_LO)
		A.eq(thin.hi, Balance.Difficulty.SIGMA_HI)
	end)
end)
