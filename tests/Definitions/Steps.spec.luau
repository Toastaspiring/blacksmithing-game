--!strict
-- tests/Definitions/Steps.spec.luau — Definitions/Steps (SPEC §2.6, §5.3, §16.6; T-DEF-02, T-DEF-03).

local A = require("../lib/Assert")
local Test = require("../lib/Test")
local H = require("./DefsHelpers")
local Balance = require("../../src/shared/Definitions/Balance")
local MinigameFamilies = require("../../src/shared/Definitions/MinigameFamilies")
local Steps = require("../../src/shared/Definitions/Steps")
local Validate = require("../../src/shared/Definitions/Validate")

local function w(factor: string, weight: number): { factor: string, w: number }
	return { factor = factor, w = weight }
end

local function row(id: string, order: number, enabled: boolean, family: string, weights: { { factor: string, w: number } })
	return { id = id, name = id, order = order, enabled = enabled, family = family, factorWeights = weights }
end

-- weights in FactorId order (§5.3; Sharpening's EdgeLength 0.50 is listed last)
local EXPECTED = {
	row("Smelting", 10, true, "HoldZone", { w("Volume", 1.00) }),
	row("Casting", 20, false, "HoldZone", {}),
	row("Hammering", 30, true, "TimingStrike", { w("Thinness", 0.40), w("Asymmetry", 0.30), w("SurfaceComplexity", 0.30) }),
	row("Quenching", 40, false, "ReleaseTiming", { w("PartCount", 0.40), w("Thinness", 0.60) }),
	row("Sharpening", 50, true, "PrecisionTrace", { w("Asymmetry", 0.30), w("SurfaceComplexity", 0.20), w("EdgeLength", 0.50) }),
	row("Assembly", 60, false, "FitPuzzle", { w("PartCount", 0.35), w("Joints", 0.45), w("MaterialMix", 0.20) }),
	row("Riveting", 65, false, "TimingStrike", {}),
	row("Finishing", 70, false, "RhythmSequence", { w("SurfaceComplexity", 1.00) }),
}

return Test.suite("Definitions/Steps", function(t)
	t.it("rows are SPEC §2.6 and §5.3 (orders, families, factor weights)", function()
		A.eq(#Steps.ordered, #EXPECTED, "row count")
		for i, e in EXPECTED do
			A.deepEq(Steps.ordered[i], e, "row " .. i .. " (" .. e.id .. ")")
		end
	end)

	t.it("T-DEF-02 the MVP plays Smelting, Hammering and Sharpening", function()
		A.deepEq(H.ids(Steps.enabled), { "Smelting", "Hammering", "Sharpening" })
	end)

	t.it("T-DEF-03 weights follow FactorId order and sum to 1 ± 1e-9; families resolve", function()
		local tol = Balance.Quality.WEIGHT_SUM_TOL
		A.eq(tol, 1e-9)
		for _, s in Steps.ordered do
			local family = MinigameFamilies.get(s.family)
			A.truthy(family ~= nil, s.id .. "'s family exists")
			if s.enabled then
				A.truthy(family ~= nil and family.enabled, s.id .. "'s family is enabled")
				A.truthy(#s.factorWeights > 0, s.id .. " has weights")
			end
			if #s.factorWeights > 0 then
				local sum, last = 0, 0
				for _, fw in s.factorWeights do
					local idx = table.find(Validate.FACTOR_ORDER, fw.factor)
					A.truthy(idx ~= nil and idx > last, s.id .. ": " .. fw.factor .. " in FactorId order")
					last = idx or last
					A.truthy(fw.w > 0, s.id .. ": positive weight")
					sum += fw.w
				end
				A.near(sum, 1, tol, s.id .. " weights sum")
			end
		end
	end)

	t.it("each MVP step's design factors are its own weight list (§5.2): Smelting Volume; Hammering Thinness, "
		.. "Asymmetry, SurfaceComplexity; Sharpening EdgeLength, Asymmetry, SurfaceComplexity", function()
		local function factors(id: string): { string }
			local s = Steps.get(id)
			assert(s)
			local out: { string } = {}
			for _, fw in s.factorWeights do
				table.insert(out, fw.factor)
			end
			return out
		end
		A.deepEq(factors("Smelting"), { "Volume" })
		A.deepEq(factors("Hammering"), { "Thinness", "Asymmetry", "SurfaceComplexity" })
		A.deepEq(factors("Sharpening"), { "Asymmetry", "SurfaceComplexity", "EdgeLength" })
	end)

	t.it("worked example (§5.4): F5 Hammering g = 0.40 · 0.2593 = 0.1037", function()
		local s = Steps.get("Hammering")
		assert(s)
		local x = { Thinness = 0.2593, Asymmetry = 0, SurfaceComplexity = 0 }
		local g = 0
		for _, fw in s.factorWeights do
			g += fw.w * (x :: any)[fw.factor]
		end
		A.eq(math.round(g * 1e4) / 1e4, 0.1037)
	end)
end)
