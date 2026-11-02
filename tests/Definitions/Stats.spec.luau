--!strict
-- tests/Definitions/Stats.spec.luau — Definitions/Stats (SPEC §2.7, §8.2, §8.3, §16.9; T-DEF-02).

local A = require("../lib/Assert")
local Prop = require("../lib/Prop")
local Test = require("../lib/Test")
local Tol = require("../lib/Tol")
local H = require("./DefsHelpers")
local Stats = require("../../src/shared/Definitions/Stats")

-- id, name, order, enabled, unit, decimals
local EXPECTED: { { any } } = {
	{ "Damage", "Damage", 1, true, "", 0 },
	{ "Sharpness", "Sharpness", 2, true, "", 0 },
	{ "Durability", "Durability", 3, true, "", 0 },
	{ "Purity", "Purity", 4, true, "%", 0 },
	{ "Balance", "Balance", 5, true, "", 0 },
	{ "Reach", "Reach", 6, true, "studs", 1 },
	{ "SwingSpeed", "Swing speed", 7, false, "", 0 },
	{ "Defense", "Defense", 8, false, "", 0 },
	{ "Mobility", "Mobility", 9, false, "", 0 },
}

return Test.suite("Definitions/Stats", function(t)
	t.it("rows are SPEC §8.2 and §16.9, in order", function()
		A.eq(#Stats.ordered, #EXPECTED, "row count")
		for i, e in EXPECTED do
			local r = Stats.ordered[i]
			local where = "row " .. i .. " (" .. e[1] .. ")"
			A.eq(r.id, e[1], where)
			A.eq(r.name, e[2], where)
			A.eq(r.order, e[3], where)
			A.eq(r.enabled, e[4], where)
			A.eq(r.unit, e[5], where)
			A.eq(r.decimals, e[6], where)
		end
	end)

	t.it("T-DEF-02 the MVP shows Damage, Sharpness, Durability, Purity, Balance and Reach (Q13)", function()
		A.deepEq(H.ids(Stats.enabled), { "Damage", "Sharpness", "Durability", "Purity", "Balance", "Reach" })
		for _, id in { "SwingSpeed", "Defense", "Mobility" } do
			A.falsy(Stats.isEnabled(id), id .. " is reserved")
		end
	end)

	t.it("qualityPoints = floor(Q·100 + 0.5) (§8.3)", function()
		local cases = {
			{ 0, 0 }, { 0.8326, 83 }, { 0.8505, 85 }, { 1.0, 100 }, { 1.0125, 101 }, { 1.0506, 105 }, { 1.428, 143 },
			{ 0.6394, 64 }, { 0.5099, 51 }, { 0.004, 0 }, { 0.005, 1 },
		}
		for _, c in cases do
			A.eq(Stats.qualityPoints(c[1]), c[2], "Q " .. tostring(c[1]))
		end
	end)

	t.it("qualityPoints rejects non-finite or non-number Q", function()
		for _, bad in { 0 / 0, math.huge, -math.huge, "1" :: any, nil :: any } do
			A.throws(function()
				Stats.qualityPoints(bad)
			end, "Stats.qualityPoints")
		end
	end)

	t.it("P-FINITE qualityPoints is an integer within ±0.5 of Q·100", function()
		Prop.check(Tol.PROP_N, function(rng): number
			return rng:range(0, 1.5)
		end, function(q: number)
			local p = Stats.qualityPoints(q)
			A.eq(p % 1, 0, "an integer")
			A.truthy(math.abs(p - q * 100) <= 0.5 + 1e-9, "rounded")
		end)
	end)
end)
