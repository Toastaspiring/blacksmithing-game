--!strict
-- tests/Definitions/Materials.spec.luau — Definitions/Materials (SPEC §2.5, E-S1.7, §16.4; T-DEF-02, T-DEF-04).

local A = require("../lib/Assert")
local Test = require("../lib/Test")
local H = require("./DefsHelpers")
local Materials = require("../../src/shared/Definitions/Materials")
local Validate = require("../../src/shared/Definitions/Validate")

-- id, order, enabled, class, density, hardness, toughness, color, robloxMaterial, reflectance, qualityTier, blurb
local EXPECTED: { { any } } = {
	{ "Iron", 1, true, "Metal", 7.87, 45, 50, { 112, 114, 120 }, "Metal", 0.05, 1.00, "Reliable baseline, forgiving minigames" },
	{ "Steel", 2, true, "Metal", 7.85, 70, 55, { 196, 202, 210 }, "Metal", 0.18, 1.02, "Better edges, slightly tighter windows" },
	{ "Bronze", 3, false, "Metal", 8.80, 30, 70, { 176, 124, 64 }, "Metal", 0.10, 1.05, "Heavy and durable, poor edge" },
	{ "Mithril", 4, false, "Metal", 3.20, 75, 72, { 182, 222, 236 }, "Foil", 0.30, 1.35, "Light and strong, very tight windows" },
	{ "Obsidian", 5, false, "Mineral", 7.20, 92, 8, { 34, 26, 44 }, "Glass", 0.25, 1.30, "Brutal edge, shatters on failure" },
	{ "Wood", 6, false, "Organic", 0.65, 25, 45, { 120, 82, 50 }, "Wood", 0, 1.00, "Grips, hafts and light armor" },
	{ "Leather", 7, false, "Organic", 0.90, 20, 55, { 90, 58, 38 }, "Leather", 0, 1.00, "Grips, hafts and light armor" },
}

return Test.suite("Definitions/Materials", function(t)
	t.it("rows are SPEC §2.5 and E-S1.7, in order", function()
		A.eq(#Materials.ordered, #EXPECTED, "row count")
		for i, e in EXPECTED do
			local m = Materials.ordered[i]
			local where = "row " .. i .. " (" .. e[1] .. ")"
			A.eq(m.id, e[1], where)
			A.eq(m.name, e[1], where)
			A.eq(m.order, e[2], where)
			A.eq(m.enabled, e[3], where)
			A.eq(m.class, e[4], where)
			A.eq(m.density, e[5], where)
			A.eq(m.hardness, e[6], where)
			A.eq(m.toughness, e[7], where)
			A.deepEq(m.color, e[8], where)
			A.eq(m.robloxMaterial, e[9], where)
			A.eq(m.reflectance, e[10], where)
			A.eq(m.qualityTier, e[11], where)
			A.eq(m.blurb, e[12], where)
			A.eq(m.allowedSlots, nil, where .. ": any slot")
		end
	end)

	t.it("T-DEF-02 the MVP enables Iron and Steel only", function()
		A.deepEq(H.ids(Materials.enabled), { "Iron", "Steel" })
		A.truthy(Materials.isEnabled("Iron"))
		A.truthy(Materials.isEnabled("Steel"))
		for _, id in { "Bronze", "Mithril", "Obsidian", "Wood", "Leather" } do
			A.truthy(Materials.get(id) ~= nil, id .. " exists")
			A.falsy(Materials.isEnabled(id), id .. " is disabled")
		end
	end)

	t.it("T-DEF-04 hardness and toughness are integers 0–100; difficultyTerm is 0 (Q13)", function()
		for _, m in Materials.ordered do
			for _, v in { m.hardness, m.toughness } do
				A.truthy(v % 1 == 0 and v >= 0 and v <= 100, m.id .. ": " .. tostring(v))
			end
			A.eq(m.difficultyTerm, 0, m.id .. ".difficultyTerm")
		end
	end)

	t.it("Steel gives +2 % quality (T 1.02 ≤ 1.04) and Iron is the 1.00 baseline (Q13, E-S4.7)", function()
		local iron, steel = Materials.get("Iron"), Materials.get("Steel")
		assert(iron and steel)
		A.eq(iron.qualityTier, 1.00)
		A.eq(steel.qualityTier, 1.02)
		A.truthy(steel.qualityTier <= 1.04, "the Steel rarity targets need T ≤ 1.04")
		A.truthy(steel.hardness > iron.hardness and steel.toughness > iron.toughness, "Steel is never strictly worse")
		A.truthy(math.abs(steel.density - iron.density) < 0.05, "an Iron/Steel swap never changes mass noticeably")
	end)

	t.it("render values use Enum.Material names from KNOWN_PART_MATERIALS", function()
		for _, m in Materials.ordered do
			A.truthy(table.find(Validate.KNOWN_PART_MATERIALS, m.robloxMaterial) ~= nil, m.id)
			A.within(m.reflectance, 0, 1, m.id .. ".reflectance")
		end
		A.deepEq(Validate.KNOWN_PART_MATERIALS, { "Metal", "Foil", "Glass", "Wood", "Leather" })
	end)

	t.it("density puts the MVP metals in the draft's Medium band (6.0 ≤ ρ < 8.5)", function()
		for _, m in Materials.enabled do
			A.truthy(m.density >= 6.0 and m.density < 8.5, m.id)
		end
	end)
end)
