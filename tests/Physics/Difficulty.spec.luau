--!strict
-- T-DIF-02, 03, 05 Physics/Difficulty (SPEC §5.1, §5.3, §5.4, §4.7; §14.6, E-S8.5; the M3 plan's [8.2] with the lead's
-- L12 and L16), and §5.5's d per step on every fixture ([7.1]–[7.2], the measure's rank order) with T-DIF-01's ranges
-- on them. The factors' inputs are built as Analyze's phases hold them (DifficultyHelpers).
--   T-DIF-02  the soft OR: §5.1's formula and its properties on the 101 × 101 grid of m and g, and a planted material
--             term in a step (soft OR above the max)
--   T-DIF-03  the tier boundary is exact, production quantizes first, NaN raises, tierRaw is never clamped
--   T-DIF-05  Iron and Steel play the same d: C02 in both, F1 against F5, Gen designs with every material swapped
--   step      g over Definitions/Steps' weights in their order, m from the governing material (ties by Materials
--             order, nil on an empty set), the terms, the factors copied; planSteps follows CraftPlans; P-DET, P-NOMUT,
--             P-ORDER

local Test = require("../lib/Test")
local A = require("../lib/Assert")
local Dump = require("../lib/Dump")
local Gen = require("../lib/Gen")
local Prop = require("../lib/Prop")
local Tol = require("../lib/Tol")
local TestRng = require("../lib/TestRng")
local Drafts = require("../Blueprint/Drafts")
local Adversarial = require("../fixtures/Adversarial")
local Blueprints = require("../fixtures/Blueprints")
local Build = require("../fixtures/Build")
local Calibration = require("../fixtures/Calibration")
local Cost = require("../fixtures/Cost")
local Regression = require("../fixtures/Regression")
local D = require("./DifficultyHelpers")
local Balance = require("../../src/shared/Definitions/Balance")
local Catalog = require("../../src/shared/Definitions/Catalog")
local CraftPlans = require("../../src/shared/Definitions/CraftPlans")
local EquipmentTypes = require("../../src/shared/Definitions/EquipmentTypes")
local Limits = require("../../src/shared/Definitions/Limits")
local Materials = require("../../src/shared/Definitions/Materials")
local Steps = require("../../src/shared/Definitions/Steps")
local Tiers = require("../../src/shared/Definitions/Tiers")
local Types = require("../../src/shared/Definitions/Types")
local Versions = require("../../src/shared/Definitions/Versions")
local Quantize = require("../../src/shared/Util/Quantize")
local Canonical = require("../../src/shared/Blueprint/Canonical")
local Difficulty = require("../../src/shared/Physics/Difficulty")
local Edge = require("../../src/shared/Physics/Edge")
local Factors = require("../../src/shared/Physics/Factors")
local MassProps = require("../../src/shared/Physics/MassProps")
local Sampling = require("../../src/shared/Physics/Sampling")
local Shapes = require("../../src/shared/Physics/Shapes")

type Rng = TestRng.TestRng
type StepAnalysis = Difficulty.StepAnalysis
type FactorValue = Factors.FactorValue

local Geo = Balance.Geometry
local SWORD: any = EquipmentTypes.get("Sword")
local CTX = Gen.context(Limits, SWORD, Materials.enabled, Versions.BLUEPRINT_SCHEMA, Geo)

-- [7.1]–[7.2]: d per step (Smelting / Hammering / Sharpening) in the measure's rank order, every fixture with steps.
-- §5.5's table but C09's Hammering, 0.3170 in part order (§17.2: M3 walks the measure's rank); [7.2]'s rows the plan's
-- emulator measured. P1–P3 with a speck, floating or attached, play the same d. Fix round 1 (θ on every local axis, the
-- canonical walk and its lattice pick, the raster's samples off its centres; docs/build/M3-notes.md) moved C04
-- 0.3368 / 0.4703 → 0.3379 / 0.4769, C05 0.1363 → 0.1369, C09 0.3186 → 0.3201, C13 0.1133 → 0.1137, X01 and X01raw
-- 0.0756 → 0.0749, X05-0.050 0.1038 → 0.1037, P3 0.1804 → 0.2752 (Hard), P5 0.1902 → 0.2167 (Hard), P3 with a speck
-- 0.1759 → 0.2559 (Hard). Fix round 2's face ties (every part but a probe's own read grown by 1e-10: §5.2) moved
-- X04-5-0.006, X05+0.002, X05+0.006 and X05-0.020 0.1044 → 0.1037, F5's: their tip's probes on the blade's face.
local D_RANK: { [string]: { number } } = {
	F1 = { 0.0288, 0.1037, 0.0989 }, F2 = { 0.0797, 0.0176, 0.0282 }, F3 = { 0.0000, 0.4423, 0.6104 },
	F4 = { 0.4590, 0.1572, 0.3420 }, F5 = { 0.0288, 0.1037, 0.0989 },
	C01 = { 0.1486, 0.0000, 0.0407 }, C02 = { 0.0355, 0.1137, 0.1318 }, C02s = { 0.0355, 0.1137, 0.1318 },
	C04 = { 0.0000, 0.3379, 0.4769 }, C05 = { 0.5451, 0.1369, 0.3466 }, C06 = { 0.0097, 0.2991, 0.5948 },
	C07 = { 0, 0, 0 }, C08 = { 0.1563, 0.0992, 0.2487 }, C09 = { 0.0001, 0.3201, 0.1904 },
	C10 = { 0.1565, 0.0000, 0.0282 }, C11 = { 0.1562, 0.0012, 0.0368 }, C12 = { 0.0355, 0.1137, 0.1318 },
	C13 = { 0.0376, 0.1137, 0.1318 }, C14 = { 0.0355, 0.1137, 0.1318 }, C15 = { 0.0353, 0.2701, 0.4291 },
	A24 = { 0.0281, 0.4000, 0.3909 }, A25 = { 0.0288, 0.1037, 0.0989 },
	A26base = { 0.0468, 0.1037, 0.0989 }, A26 = { 0.0471, 0.1048, 0.0989 },
	A27 = { 0.0288, 0.1537, 0.0989 },
	X01base = { 0.0323, 0.0754, 0.0989 }, X01 = { 0.0323, 0.0749, 0.0989 }, X01raw = { 0.0323, 0.0749, 0.0989 },
	X02base = { 0.0358, 0.0520, 0.0989 }, X02 = { 0.0358, 0.0510, 0.0989 }, X03 = { 0.4594, 0.1575, 0.1980 },
	X04a = { 0.0289, 0.1035, 0.0989 }, X04b = { 0.0289, 0.1035, 0.0989 },
	["X04-5-0.004"] = { 0.0286, 0.1037, 0.0989 }, ["X04-5-0.006"] = { 0.0285, 0.1037, 0.0989 },
	["X04-5-0.009"] = { 0.0283, 0.1037, 0.0989 }, ["X04-10-0.004"] = { 0.0283, 0.1037, 0.0989 },
	["X04-10-0.006"] = { 0.0281, 0.1037, 0.0989 }, ["X04-10-0.009"] = { 0.0277, 0.1038, 0.0989 },
	["X04g0.005"] = { 0.0288, 0.1037, 0.0989 }, ["X04g0.010"] = { 0.0288, 0.1037, 0.0989 },
	["X04g0.015"] = { 0.0288, 0.1045, 0.0989 }, ["X04g0.020"] = { 0.0288, 0.1082, 0.0989 },
	["X05+0.002"] = { 0.0287, 0.1037, 0.0989 }, ["X05+0.004"] = { 0.0286, 0.1037, 0.0989 },
	["X05+0.006"] = { 0.0285, 0.1037, 0.0989 }, ["X05+0.009"] = { 0.0283, 0.1037, 0.0989 },
	["X05-0.005"] = { 0.0288, 0.1037, 0.0989 }, ["X05-0.020"] = { 0.0288, 0.1037, 0.0989 },
	["X05-0.050"] = { 0.0288, 0.1037, 0.0989 },
	["X06-0.00"] = { 0.0288, 0.1037, 0.0989 }, ["X06-0.01"] = { 0.0288, 0.1037, 0.0991 },
	["X06-0.02"] = { 0.0288, 0.1087, 0.1187 }, ["X06-0.03"] = { 0.0288, 0.1227, 0.1756 },
	["X06-0.04"] = { 0.0288, 0.1385, 0.2391 }, ["X06-0.05"] = { 0.0288, 0.1543, 0.3030 },
	X07a = { 0.0288, 0.1035, 0.0989 }, X07b = { 0.0288, 0.1035, 0.0989 }, X07c = { 0.0288, 0.1044, 0.0989 },
	P1 = { 1, 0, 0.0086 }, P2 = { 1, 0.0571, 0.0308 }, P3 = { 0.2777, 0.2752, 0.1821 }, P4 = { 1, 0.1389, 0.1556 },
	P5 = { 0.0328, 0.2167, 0.1202 },
	["P1-floating"] = { 1, 0, 0.0048 }, ["P2-floating"] = { 1, 0.0674, 0.0479 },
	["P3-floating"] = { 0.2622, 0.2559, 0.1612 },
	["P1-attached"] = { 1, 0, 0.0048 }, ["P2-attached"] = { 1, 0.0674, 0.0479 },
	["P3-attached"] = { 0.2622, 0.2559, 0.1612 },
}
-- The tiers of the fixtures whose records carry none (§5.5; the others' are in their records' expect): played, then
-- the raw tier where it differs.
local TIERS: { [string]: string } = {
	F1 = "N N N", F2 = "N N N", F3 = "N H/Ex H/Ma", F4 = "H/Ex N H", F5 = "N N N",
	A24 = "N H/Ex H", A25 = "N N N", A26base = "N N N", A26 = "N N N", A27 = "N N N",
}
local TIER_IDS: { [string]: string } = { N = "Normal", H = "Hard", Ex = "Expert", Ma = "Master", He = "Hell" }
local PLAN = { "Smelting", "Hammering", "Sharpening" }

local function canonicalOf(key: string): any
	local result = Canonical.draft(Adversarial.variant(key).draft()) :: any
	A.truthy(result.ok, key .. ": Canonical must accept it, got " .. Dump.short(result))
	return result.value
end

local function stepsOf(core: any, modules: any?): { StepAnalysis }
	local steps = D.steps(D.measured(core), modules)
	if steps == nil then
		return A.fail(core.name .. ": a work set is empty")
	end
	return steps
end

-- The 8 factors, every raw and x set to x.
local function factorsAt(x: number): { FactorValue }
	local out: { FactorValue } = {}
	for k = 1, #Factors.ORDER do
		local f: Types.FactorId = Factors.ORDER[k]
		out[k] = { factor = f, raw = x, x = x }
	end
	return out
end

local function withX(factors: { FactorValue }, id: string, x: number): { FactorValue }
	local out: { FactorValue } = {}
	for k, v in ipairs(factors) do
		out[k] = { factor = v.factor, raw = v.raw, x = if v.factor == id then x else v.x }
	end
	return out
end

-- A Definitions catalog module loaded anew, its rows handed to Catalog.build in the given order.
local function reordered(path: string, order: { number }): any
	return Drafts.planted(path, {
		["./Catalog"] = {
			build = function(rows: { any }): any
				return Catalog.build(Drafts.rows(rows, order))
			end,
			deepFreeze = Catalog.deepFreeze,
		},
		["./Types"] = Types,
	})
end

-- Factors and Difficulty on planted Definitions (Materials, Steps, Tiers, CraftPlans); the rest the real modules.
type Defs = { materials: any?, steps: any?, tiers: any?, craftPlans: any? }
local function planted(defs: Defs): { factors: any, difficulty: any }
	local materials = defs.materials or Materials
	local factors = Drafts.planted("src/shared/Physics/Factors.luau", {
		["../Definitions/Balance"] = Balance,
		["../Definitions/Types"] = Types,
		["../Definitions/Materials"] = materials,
		["./Edge"] = Edge,
		["./MassProps"] = MassProps,
		["./Sampling"] = Sampling,
		["./Shapes"] = Shapes,
	})
	local difficulty = Drafts.planted("src/shared/Physics/Difficulty.luau", {
		["../Definitions/CraftPlans"] = defs.craftPlans or CraftPlans,
		["../Definitions/Types"] = Types,
		["../Definitions/Materials"] = materials,
		["../Definitions/Steps"] = defs.steps or Steps,
		["../Definitions/Tiers"] = defs.tiers or Tiers,
		["../Util/Quantize"] = Quantize,
		["./Factors"] = factors,
		["./Shapes"] = Shapes,
	})
	return { factors = factors, difficulty = difficulty }
end

-- Materials with planted rows: the given fields of each id changed.
local function materialsWith(changes: { [string]: { [string]: any } }, order: { number }?): any
	local rows = Drafts.rows(Materials.ordered, order)
	for _, row in rows do
		local change = changes[row.id]
		if change then
			for k, v in change do
				row[k] = v
			end
		end
	end
	return Catalog.build(rows)
end

local function swapped(core: any): any
	local out = Build.copy(core)
	for _, p in out.parts do
		p.material = if p.material == "Iron" then "Steel" else "Iron"
	end
	return out
end

-- A step but for its material.
local function play(s: StepAnalysis): string
	return Dump.canonical({ step = s.step, g = s.g, m = s.m, d = s.d, tier = s.tier, tierRaw = s.tierRaw,
		terms = s.terms, factors = s.factors })
end

-- Steps alike but for the material: every number and tier bit for bit.
local function samePlay(a: { StepAnalysis }, b: { StepAnalysis }, what: string)
	A.eq(#a, #b, what)
	for i, s in ipairs(a) do
		A.eq(play(s), play(b[i]), what .. " " .. s.step)
	end
end

return Test.suite("Physics/Difficulty", function(t)
	t.it("T-DIF-02 softOr on the 101 × 101 grid: §5.1's q(1 − (1 − m)(1 − g)), identities, symmetric, ≥ the larger, "
		.. "non-decreasing, on the grid", function()
			-- the formula itself, not only its properties: max(m, g) has every one of them (M3's review, V1 and V2)
			A.eq(Difficulty.softOr(0.5, 0.5), 0.75, "softOr(0.5, 0.5)")
			A.eq(Difficulty.softOr(0.3, 0.4), 0.58, "softOr(0.3, 0.4)")
			A.eq(Difficulty.softOr(0.2, 0.3), 0.44, "softOr(0.2, 0.3)")
			local grid: { number } = {}
			for i = 0, 100 do
				grid[i + 1] = Difficulty.q(i / 100)
			end
			for i, m in grid do
				A.eq(Difficulty.softOr(m, 0), m, "softOr(m, 0) = m")
				A.eq(Difficulty.softOr(0, m), m, "softOr(0, g) = g")
				A.eq(Difficulty.softOr(1, m), 1, "softOr(1, g) = 1")
				for j, g in grid do
					local d = Difficulty.softOr(m, g)
					A.eq(d, Quantize.q(1 - (1 - m) * (1 - g), Quantize.SCALAR_SCALE), "q(1 − (1 − m)(1 − g))")
					A.eq(d, Difficulty.softOr(g, m), "symmetric")
					A.truthy(d >= math.max(m, g) and d <= 1, string.format("softOr(%g, %g) = %.17g", m, g, d))
					A.eq(Difficulty.q(d), d, "on the 1e-4 grid")
					if i > 1 then
						A.truthy(d >= Difficulty.softOr(grid[i - 1], g), "non-decreasing in m")
					end
					if j > 1 then
						A.truthy(d >= Difficulty.softOr(m, grid[j - 1]), "non-decreasing in g")
					end
				end
			end
		end)

	t.it("T-DIF-03 the tier boundary is exact, 0.1999999999 Normal and 0.2 Hard; production quantizes first", function()
		A.eq(Tiers.tierFor(0.1999999999), "Normal", "just under")
		A.eq(Tiers.tierFor(0.2), "Hard", "at dMin")
		A.eq(Difficulty.q(0.1999999999), 0.2, "q rounds it up")
		A.eq(Difficulty.q(0.19995), 0.2, "q(0.19995)")
		A.eq(Difficulty.q(0.199949), 0.1999, "q(0.199949)")
		-- through a step: Smelting weighs Volume alone (w 1)
		local hard = Difficulty.step("Smelting", withX(factorsAt(0), "Volume", 0.19995), "Iron")
		A.eq(hard.g, 0.2, "g")
		A.eq(hard.d, 0.2, "d")
		A.eq(hard.tier, "Hard", "0.19995 plays Hard")
		local normal = Difficulty.step("Smelting", withX(factorsAt(0), "Volume", 0.199949), "Iron")
		A.eq(normal.d, 0.1999, "d")
		A.eq(normal.tier, "Normal", "0.199949 plays Normal")
	end)

	t.it("T-DIF-03 NaN raises: Quantize.q, Tiers and a step whose factor is NaN", function()
		local nan = 0 / 0
		A.throws(function()
			Difficulty.q(nan)
		end, "non-finite")
		A.throws(function()
			Tiers.tierFor(nan)
		end, "D must be a finite number")
		A.throws(function()
			Tiers.tierRawFor(nan)
		end, "D must be a finite number")
		A.throws(function()
			Difficulty.step("Hammering", withX(factorsAt(0), "Thinness", nan), "Iron")
		end, "non-finite")
		A.throws(function()
			Difficulty.softOr(nan, 0)
		end, "non-finite")
	end)

	t.it("T-DIF-03 tierRaw is never clamped: F3 Hard at Expert and Master, P1's Smelting Hard at Hell", function()
		local function played(s: StepAnalysis): { d: number, tier: string, tierRaw: string }
			return { d = s.d, tier = s.tier, tierRaw = s.tierRaw }
		end
		local f3 = stepsOf(Blueprints.get("F3").core)
		A.deepEq(played(D.stepOf(f3, "Hammering")), { d = 0.4423, tier = "Hard", tierRaw = "Expert" }, "F3 Hammering")
		A.deepEq(played(D.stepOf(f3, "Sharpening")), { d = 0.6104, tier = "Hard", tierRaw = "Master" }, "F3 Sharpening")
		local p1 = D.stepOf(stepsOf(Cost.get("P1").core), "Smelting")
		A.deepEq(played(p1), { d = 1, tier = "Hard", tierRaw = "Hell" }, "P1 Smelting")
		A.deepEq(played(Difficulty.step("Smelting", factorsAt(1), "Steel")), { d = 1, tier = "Hard", tierRaw = "Hell" },
			"every x 1")
		A.deepEq(played(Difficulty.step("Sharpening", factorsAt(0), "Steel")),
			{ d = 0, tier = "Normal", tierRaw = "Normal" }, "every x 0")
	end)

	t.it("T-DIF-05 C02 in Iron and in Steel: g, m, d, tiers and every factor bit-identical, its material", function()
		local iron, steel = stepsOf(Calibration.get("C02").core), stepsOf(Calibration.get("C02s").core)
		samePlay(iron, steel, "C02")
		for i, s in ipairs(iron) do
			A.eq(s.material, "Iron", s.step)
			A.eq(steel[i].material, "Steel", s.step)
			A.eq(s.m, 0, s.step .. " m")
		end
	end)

	t.it("T-DIF-05 F1 (a Steel blade) and F5 (all Iron) play the same d; F1's MaterialMix 2 weighs nothing", function()
		local f1, f5 = stepsOf(Blueprints.get("F1").core), stepsOf(Blueprints.get("F5").core)
		for i, s in ipairs(f1) do
			A.eq(s.d, f5[i].d, s.step)
			A.eq(s.m, 0, s.step .. " m")
			for _, term in s.terms do
				A.truthy(term.factor ~= "MaterialMix", s.step .. " weighs no MaterialMix")
			end
		end
		A.eq(D.valueOf(D.stepOf(f1, "Hammering").factors, "MaterialMix").raw, 2, "F1 on All: Iron and Steel")
		A.eq(D.valueOf(D.stepOf(f5, "Hammering").factors, "MaterialMix").raw, 1, "F5")
		A.deepEq({ D.stepOf(f1, "Smelting").material, D.stepOf(f1, "Sharpening").material }, { "Steel", "Steel" },
			"Steel governs F1: harder, in the same term")
		A.eq(D.stepOf(f5, "Smelting").material, "Iron", "F5")
	end)

	local function swappedCorpus(n: number)
		Prop.check(n, function(rng: Rng): any
			return Gen.validSword(rng, CTX)
		end, function(core: any)
			local a, b = stepsOf(core), stepsOf(swapped(core))
			for i, s in ipairs(a) do
				A.eq(s.d, b[i].d, s.step .. " d")
				A.eq(Dump.canonical(s.factors), Dump.canonical(b[i].factors), s.step .. " factors")
				A.truthy(s.m == 0 and b[i].m == 0, s.step .. " m")
			end
		end)
	end

	-- Fast until M3's fix round 1 (§14.1's 27 s); its designs are the first of the FUZZ_N_VALID case's.
	t.slow("T-DIF-05 Gen designs with every Iron and Steel swapped: d and every factor bit-identical, m 0", function()
		swappedCorpus(20)
	end)

	t.slow("T-DIF-05 Gen designs with Iron and Steel swapped, FUZZ_N_VALID: d and the factors bit-identical", function()
		swappedCorpus(Tol.FUZZ_N_VALID)
	end)

	t.it("§5.1 governing: the highest (difficultyTerm, hardness), ties by Materials order, nil on no part", function()
		local f1 = D.measured(Blueprints.get("F1").core)
		local all, grip = D.set(f1, "All"), D.set(f1, { "Grip" })
		A.eq(Difficulty.governing(f1.parts, all), "Steel", "the harder of two in the same term")
		A.eq(Difficulty.governing(f1.parts, grip), "Iron", "Iron alone")
		A.eq(Difficulty.governing(f1.parts, {}), nil, "an empty set")
		-- planted terms: the term first, then hardness; equal on both, the first in Materials order
		local termFirst = planted({ materials = materialsWith({ Iron = { difficultyTerm = 0.3 } }) }).difficulty
		A.eq(termFirst.governing(f1.parts, all), "Iron", "Iron's term")
		local tie = materialsWith({ Steel = { hardness = 45 } })
		A.eq(planted({ materials = tie }).difficulty.governing(f1.parts, all), "Iron", "a tie: Iron comes first")
		local swappedOrder = materialsWith({ Steel = { hardness = 45, order = 1 }, Iron = { order = 2 } })
		A.eq(planted({ materials = swappedOrder }).difficulty.governing(f1.parts, all), "Steel", "Steel first, Steel")
	end)

	t.it("§5.1 step: g = q(Σ w·x) over Steps' weights in order, m from the material, the terms, factors copied",
		function()
			local m = D.measured(Calibration.get("C15").core)
			for _, row in Difficulty.planSteps("Sword") do
				local values = D.factors(m, row.worksOn)
				local s = Difficulty.step(row.step, values, "Iron")
				local weights = (Steps.get(row.step) :: any).factorWeights
				A.eq(#s.terms, #weights, row.step .. " terms")
				local g, sum = 0, 0
				for i, w in weights do
					local x = D.valueOf(values, w.factor).x
					A.deepEq(s.terms[i], { factor = w.factor, w = w.w, x = x }, row.step .. " term " .. i)
					g += w.w * x
					sum += w.w
				end
				A.near(sum, 1, 1e-12, row.step .. " Σw")
				A.eq(s.g, Quantize.q(g, Quantize.SCALAR_SCALE), row.step .. " g")
				A.eq(s.m, 0, row.step .. " m")
				A.eq(s.d, Difficulty.softOr(0, s.g), row.step .. " d")
				A.deepEq(s.factors, values, row.step .. " factors")
				for k, v in s.factors do
					A.truthy(v ~= values[k], row.step .. " copied")
				end
			end
			-- a planted material term reaches m and d, by §5.1's soft OR: above both, so not their max (C15's Hammering
			-- g 0.2701, m 0.25: d 0.4526)
			local termed = planted({ materials = materialsWith({ Steel = { difficultyTerm = 0.25 } }) }).difficulty
			local values = D.factors(m, "All")
			local plain = Difficulty.step("Hammering", values, "Steel")
			local s = termed.step("Hammering", values, "Steel")
			A.deepEq({ s.g, s.m, s.d }, { plain.g, 0.25, Quantize.q(1 - (1 - 0.25) * (1 - plain.g), Quantize.SCALAR_SCALE) },
				"m 0.25")
			A.truthy(s.d > math.max(s.m, s.g), string.format("d %.4f above m %.4f and g %.4f", s.d, s.m, s.g))
			A.eq(s.d, 0.4526, "C15's Hammering with m 0.25")
			A.throws(function()
				Difficulty.step("Hammering", values, "Adamant" :: any)
			end, "unknown material")
			A.throws(function()
				Difficulty.step("Forging" :: any, values, "Iron")
			end, "unknown step")
			A.throws(function()
				Difficulty.step("Hammering", { values[1] }, "Iron")
			end, "which the factors lack")
		end)

	t.it("§4.7 planSteps: the enabled CraftPlans steps in plan order; a planted plan is followed", function()
		local ids: { string } = {}
		for _, row in Difficulty.planSteps("Sword") do
			table.insert(ids, row.step)
		end
		A.deepEq(ids, PLAN, "the Sword")
		local rows = Build.copy(CraftPlans.Sword.steps) :: any
		rows[2].enabled = false
		table.insert(rows, { step = "Finishing", weight = 0.40, worksOn = "All", feeds = {}, enabled = true })
		local plan = { type = "Sword", steps = rows }
		local plans = { Sword = plan, ordered = { plan }, get = function(id: string): any
			return if id == "Sword" then plan else nil
		end }
		local modules = planted({ craftPlans = plans })
		local played: { string } = {}
		for _, s in stepsOf(Blueprints.get("F5").core, modules) do
			table.insert(played, s.step)
		end
		A.deepEq(played, { "Smelting", "Sharpening", "Finishing" }, "Hammering disabled, Finishing appended")
		A.throws(function()
			Difficulty.planSteps("Axe")
		end, "no CraftPlans entry")
	end)

	t.it("P-DET and P-NOMUT: Difficulty.step on frozen factors, twice, bit for bit", function()
		local m = D.measured(Calibration.get("C09").core)
		for _, row in Difficulty.planSteps("Sword") do
			local values = Build.freeze(D.factors(m, row.worksOn))
			local a = Difficulty.step(row.step, values, "Iron")
			local b = Difficulty.step(row.step, values, "Iron")
			A.eq(Dump.canonical(a), Dump.canonical(b), row.step)
		end
	end)

	t.it("P-ORDER: Steps, Tiers and Materials rebuilt in shuffled order leave every step bit-identical", function()
		local modules = planted({
			materials = reordered("src/shared/Definitions/Materials.luau", { 7, 3, 1, 5, 2, 6, 4 }),
			steps = reordered("src/shared/Definitions/Steps.luau", { 8, 6, 4, 2, 7, 5, 3, 1 }),
			tiers = reordered("src/shared/Definitions/Tiers.luau", { 5, 2, 4, 1, 3 }),
		})
		for _, core in { Blueprints.get("F1").core, Blueprints.get("F3").core, Blueprints.get("F4").core,
			Calibration.get("C09").core, Cost.get("P1").core } do
			A.eq(Dump.canonical(stepsOf(core, modules)), Dump.canonical(stepsOf(core)), core.name)
		end
	end)

	t.it("§5.5, T-DIF-01: every fixture's d per step ([7.1]–[7.2]), tiers and factors in range; F5's margin",
		function()
			local checked = 0
			local function check(id: string, core: any, expect: any?)
				local want = D_RANK[id]
				A.truthy(want ~= nil, id .. " has a row")
				local steps = stepsOf(core)
				D.inRange(steps, id)
				A.eq(#steps, 3, id .. " steps")
				for k, s in steps do
					A.eq(s.step, PLAN[k], id)
					A.near(s.d, want[k], 5e-5, id .. " " .. s.step)
					A.eq(s.g, s.d, id .. " " .. s.step .. " g: m is 0 on every MVP material")
					local tier, raw
					if expect then
						tier, raw = expect.tiers[s.step], expect.tierRaw[s.step]
					else
						local code = string.split(TIERS[id], " ")[k]
						local played, over = string.match(code, "^(%a+)/?(%a*)$")
						tier = TIER_IDS[played :: string]
						raw = if over == "" then tier else TIER_IDS[over :: string]
					end
					A.eq(s.tier, tier, id .. " " .. s.step .. " tier")
					A.eq(s.tierRaw, raw, id .. " " .. s.step .. " tierRaw")
				end
				checked += 1
			end
			for _, id in Blueprints.order do
				check(id, Blueprints.get(id).core)
			end
			for _, set in { Calibration.list, Regression.list, Cost.list } do
				for _, f in set do
					check(f.id, f.core, f.expect)
				end
			end
			for _, key in { "A24", "A25", "A26base", "A26", "A27" } do
				check(key, canonicalOf(key))
			end
			A.eq(checked, 5 + #Calibration.list + #Regression.list + #Cost.list + 5, "fixtures")
			local f5 = stepsOf(Blueprints.get("F5").core)
			local hard = (Tiers.get("Hard") :: any).dMin
			for _, s in f5 do
				A.truthy(s.d <= hard - Tol.STARTER_MARGIN, "F5 " .. s.step .. " " .. s.d)
			end
		end)
end)
