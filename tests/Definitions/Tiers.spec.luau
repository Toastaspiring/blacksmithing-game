--!strict
-- tests/Definitions/Tiers.spec.luau — Definitions/Tiers (SPEC §2.7, §5.4, §8.3, §16.7; T-DEF-02, T-DEF-05).

local A = require("../lib/Assert")
local Dump = require("../lib/Dump")
local Prop = require("../lib/Prop")
local Test = require("../lib/Test")
local Tol = require("../lib/Tol")
local H = require("./DefsHelpers")
local Rarities = require("../../src/shared/Definitions/Rarities")
local Tiers = require("../../src/shared/Definitions/Tiers")

-- id, order, enabled, dMin, dMax, risk, color, rarityCap, qualityMultiplier, failScoreFactor, failOutcome
local EXPECTED: { { any } } = {
	{ "Normal", 1, true, 0.0, 0.2, "Low", { 111, 191, 115 }, "Rare", 1.00, 0.75, "LowerQuality" },
	{ "Hard", 2, true, 0.2, 0.4, "Medium", { 242, 193, 78 }, "Epic", 1.25, 0.75, "LowerQuality" },
	{ "Expert", 3, false, 0.4, 0.6, "High", { 242, 140, 40 }, "Legendary", 1.55, 0.75, "LowerQuality" },
	{ "Master", 4, false, 0.6, 0.8, "Very high", { 217, 68, 43 }, "Mythic", 1.90, 0.75, "LowerQuality" },
	{ "Hell", 5, false, 0.8, 1.0, "Extreme", { 142, 27, 27 }, "Divine", 2.30, 0.75, "DestroyMaterial" },
}

return Test.suite("Definitions/Tiers", function(t)
	t.it("rows are SPEC §2.7 and §8.3, in order", function()
		A.eq(#Tiers.ordered, #EXPECTED, "row count")
		for i, e in EXPECTED do
			local r = Tiers.ordered[i]
			local where = "row " .. i .. " (" .. e[1] .. ")"
			A.eq(r.id, e[1], where)
			A.eq(r.name, e[1], where)
			A.eq(r.order, e[2], where)
			A.eq(r.enabled, e[3], where)
			A.eq(r.dMin, e[4], where)
			A.eq(r.dMax, e[5], where)
			A.eq(r.risk, e[6], where)
			A.deepEq(r.color, e[7], where)
			A.eq(r.rarityCap, e[8], where)
			A.eq(r.qualityMultiplier, e[9], where)
			A.eq(r.failScoreFactor, e[10], where)
			A.eq(r.failOutcome, e[11], where)
		end
	end)

	t.it("T-DEF-02 all 5 tiers exist; the MVP enables Normal and Hard (Q1)", function()
		A.deepEq(H.ids(Tiers.ordered), { "Normal", "Hard", "Expert", "Master", "Hell" })
		A.deepEq(H.ids(Tiers.enabled), { "Normal", "Hard" })
	end)

	t.it("T-DEF-05 thresholds increase, caps and multipliers never fall", function()
		for k = 2, #Tiers.ordered do
			local a, b = Tiers.ordered[k - 1], Tiers.ordered[k]
			A.truthy(b.dMin > a.dMin, b.id .. ".dMin increases")
			A.eq(b.dMin, a.dMax, b.id .. " starts where " .. a.id .. " ends")
			A.truthy(b.qualityMultiplier > a.qualityMultiplier, b.id .. " pays more")
			local capA, capB = Rarities.get(a.rarityCap), Rarities.get(b.rarityCap)
			assert(capA and capB)
			A.truthy(capB.order >= capA.order, b.id .. "'s cap is not lower")
		end
		A.eq(Tiers.ordered[1].dMin, 0, "Normal starts at 0")
		A.eq(Tiers.ordered[#Tiers.ordered].dMax, 1, "the last tier includes 1")
	end)

	t.it("Q9: a failed step counts at 75 % and nothing is destroyed on a played tier", function()
		for _, r in Tiers.ordered do
			A.eq(r.failScoreFactor, 0.75, r.id)
		end
		for _, r in Tiers.enabled do
			A.eq(r.failOutcome, "LowerQuality", r.id)
		end
	end)

	t.it("Q11: Hard at its threshold (1.25) beats Normal's top multiplier with γ 0.15 (1.03)", function()
		local normal, hard = Tiers.get("Normal"), Tiers.get("Hard")
		assert(normal and hard)
		A.truthy(hard.qualityMultiplier > normal.qualityMultiplier * (1 + 0.15 * (normal.dMax - normal.dMin)))
	end)

	t.it("tierFor: the boundary is exact and every D ≥ 0.2 plays Hard (§2.7)", function()
		local cases: { { d: number, tier: string } } = {
			{ d = 0, tier = "Normal" }, { d = 0.0001, tier = "Normal" }, { d = 0.1999, tier = "Normal" },
			{ d = 0.1999999999, tier = "Normal" }, { d = 0.2, tier = "Hard" }, { d = 0.2000, tier = "Hard" },
			{ d = 0.4, tier = "Hard" }, { d = 0.85, tier = "Hard" }, { d = 1, tier = "Hard" },
		}
		for _, c in cases do
			A.eq(Tiers.tierFor(c.d), c.tier, "tierFor(" .. tostring(c.d) .. ")")
		end
	end)

	t.it("tierRawFor: the same over all tiers, unclamped", function()
		local cases: { { d: number, tier: string } } = {
			{ d = 0, tier = "Normal" }, { d = 0.1999, tier = "Normal" }, { d = 0.2, tier = "Hard" },
			{ d = 0.3999, tier = "Hard" }, { d = 0.4, tier = "Expert" }, { d = 0.4423, tier = "Expert" },
			{ d = 0.6, tier = "Master" }, { d = 0.6104, tier = "Master" }, { d = 0.8, tier = "Hell" },
			{ d = 0.85, tier = "Hell" }, { d = 1, tier = "Hell" },
		}
		for _, c in cases do
			A.eq(Tiers.tierRawFor(c.d), c.tier, "tierRawFor(" .. tostring(c.d) .. ")")
		end
	end)

	t.it("tierFor and tierRawFor reject NaN, ±inf, D outside [0, 1] and non-numbers", function()
		for _, bad in { 0 / 0, math.huge, -math.huge, -0.0001, 1.0001, -1, 2 } do
			A.throws(function()
				Tiers.tierFor(bad)
			end, "Tiers.tierFor", tostring(bad))
			A.throws(function()
				Tiers.tierRawFor(bad)
			end, "Tiers.tierRawFor", tostring(bad))
		end
		local wrongTypes: { any } = { "0.5", true, {} }
		for _, bad in wrongTypes do
			A.throws(function()
				Tiers.tierFor(bad)
			end, "Tiers.tierFor")
		end
	end)

	t.it("P-RANGE every D in [0, 1] maps to an enabled tier whose dMin ≤ D; tierRaw is never below tier", function()
		Prop.check(Tol.PROP_N * 5, function(rng): number
			return math.round(rng:float() * 10001) / 10000 -- the 1e-4 grid, 0 … 1 inclusive
		end, function(d: number)
			if d > 1 then
				d = 1
			end
			local tier = Tiers.get(Tiers.tierFor(d))
			local raw = Tiers.get(Tiers.tierRawFor(d))
			assert(tier and raw)
			A.truthy(tier.enabled, "played tiers are enabled")
			A.truthy(tier.dMin <= d and raw.dMin <= d, "dMin ≤ D")
			A.truthy(raw.order >= tier.order, "the raw tier is the same or higher")
			if d < raw.dMax or raw.order == #Tiers.ordered then
				return
			end
			A.fail("D " .. Dump.short(d) .. " lies past its raw tier")
		end)
	end)
end)
