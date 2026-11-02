--!strict
-- tests/Definitions/Rarities.spec.luau — Definitions/Rarities (SPEC §2.7, §8.4, §16.8; T-DEF-02, T-DEF-05).

local A = require("../lib/Assert")
local Test = require("../lib/Test")
local H = require("./DefsHelpers")
local Rarities = require("../../src/shared/Definitions/Rarities")
local Tiers = require("../../src/shared/Definitions/Tiers")

-- id, order, enabled, color, minQuality
local EXPECTED: { { any } } = {
	{ "Common", 1, true, { 170, 170, 170 }, 0 },
	{ "Uncommon", 2, true, { 96, 196, 96 }, 0.55 },
	{ "Rare", 3, true, { 72, 140, 232 }, 0.84 },
	{ "Epic", 4, true, { 168, 92, 224 }, 1.04 },
	{ "Legendary", 5, false, { 240, 164, 48 }, 1.29 },
	{ "Mythic", 6, false, { 232, 64, 64 }, 1.58 },
	{ "Divine", 7, false, { 255, 236, 180 }, 1.91 },
}

return Test.suite("Definitions/Rarities", function(t)
	t.it("rows are SPEC §2.7 and §8.4, in order", function()
		A.eq(#Rarities.ordered, #EXPECTED, "row count")
		for i, e in EXPECTED do
			local r = Rarities.ordered[i]
			local where = "row " .. i .. " (" .. e[1] .. ")"
			A.eq(r.id, e[1], where)
			A.eq(r.name, e[1], where)
			A.eq(r.order, e[2], where)
			A.eq(r.enabled, e[3], where)
			A.deepEq(r.color, e[4], where)
			A.eq(r.minQuality, e[5], where)
		end
	end)

	t.it("T-DEF-02 all 7 rarities exist; the MVP enables Common..Epic because its tiers cap at Epic", function()
		A.deepEq(H.ids(Rarities.ordered), { "Common", "Uncommon", "Rare", "Epic", "Legendary", "Mythic", "Divine" })
		A.deepEq(H.ids(Rarities.enabled), { "Common", "Uncommon", "Rare", "Epic" })
		local top = 0
		for _, tier in Tiers.enabled do
			local cap = Rarities.get(tier.rarityCap)
			assert(cap)
			top = math.max(top, cap.order)
		end
		A.eq(top, #Rarities.enabled, "the highest enabled cap is the highest enabled rarity")
	end)

	t.it("T-DEF-05 thresholds increase from Common 0 (inclusive thresholds, §8.4)", function()
		A.eq(Rarities.ordered[1].minQuality, 0)
		for k = 2, #Rarities.ordered do
			A.truthy(Rarities.ordered[k].minQuality > Rarities.ordered[k - 1].minQuality, Rarities.ordered[k].id)
		end
	end)

	t.it("placeholders follow the ladder minQuality = d(tier) × 1.04 / 1.25 (E-S4.1)", function()
		local epic = Rarities.get("Epic")
		local hard = Tiers.get("Hard")
		assert(epic and hard)
		for _, pair in { { "Expert", "Legendary" }, { "Master", "Mythic" }, { "Hell", "Divine" } } do
			local tier, rarity = Tiers.get(pair[1]), Rarities.get(pair[2])
			assert(tier and rarity)
			A.eq(tier.rarityCap, rarity.id, pair[1] .. " caps at " .. pair[2])
			A.near(rarity.minQuality, tier.qualityMultiplier * epic.minQuality / hard.qualityMultiplier, 0.005, pair[2])
		end
	end)
end)
