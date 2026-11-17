--!strict
-- T-DIF-11, 12, 13 Physics/Analyze's difficulty on the fixtures (SPEC §5.5, §5.6, §14.6, §14.7, §14.9; E-S2.5, E-S2.7,
-- E-S8.4; §14.6 names them, the M3 plan defines them: .build-notes/m3-plan/plan-r2.md [8.2], [8.3], with the lead's
-- L15): S2's §5 table, blessed from Analyze.run for every fixture.
--   T-DIF-11  every fixture's tier and tierRaw as its record states (§5.5's table; for the X and P fixtures the plan's
--             [7.2]); F5's highest d ≤ Hard.dMin − STARTER_MARGIN (Q7, Q21)
--   T-DIF-12  the goldens tests/golden/difficulty_{calibration, regression, cost}.bv<N>.golden.txt (§14.9): per fixture
--             its verdict, cleaned list, physics, edge and steps with every factor, Dump.canonical's bits
--   T-DIF-13  the relations at E-S8.4's bounds: the Regression records' (D, Thinness, Edge, G, G+mass; X06's Asym
--             against its 120-probe oracle is Factors.spec's), the A variants' (Within; A23 finite, A24's caps), C10
--             and C11 against C01 (§5.6), and X03's fin, which splits F4's main chain (L15)
-- Every fixture is analysed once, with measureInvalid (the floating specks are invalid), and kept for the cases after.

local Test = require("../lib/Test")
local A = require("../lib/Assert")
local Dump = require("../lib/Dump")
local Golden = require("../lib/Golden")
local Tol = require("../lib/Tol")
local Adversarial = require("../fixtures/Adversarial")
local Blueprints = require("../fixtures/Blueprints")
local Build = require("../fixtures/Build")
local Calibration = require("../fixtures/Calibration")
local Cost = require("../fixtures/Cost")
local Regression = require("../fixtures/Regression")
local H = require("./PhysicsHelpers")
local Tiers = require("../../src/shared/Definitions/Tiers")
local Versions = require("../../src/shared/Definitions/Versions")
local Canonical = require("../../src/shared/Blueprint/Canonical")
local Analyze = require("../../src/shared/Physics/Analyze")

type StepAnalysis = Analyze.StepAnalysis

-- The A variants M3 measures: the hidden-grip variants, A24's needle and A23's MIN_DIM side.
local VARIANTS = { "A23", "A24", "A25", "A26base", "A26", "A27" }

local cores: { [string]: any } = {} -- by fixture id: Blueprints, Calibration, Regression, Cost, the A variants above
for _, id in Blueprints.order do
	cores[id] = Blueprints.get(id).core
end
for _, set in { Calibration.list, Regression.list, Cost.list } do
	for _, f in set do
		cores[f.id] = f.core
	end
end

local analyses: { [string]: any } = {} -- by fixture id, filled as the cases ask

local function analysisOf(id: string): any
	local report = analyses[id]
	if report == nil then
		local core = cores[id]
		if core == nil then
			local result = Canonical.draft(Adversarial.variant(id).draft()) :: any
			A.truthy(result.ok, id .. ": Canonical must accept it, got " .. Dump.short(result))
			core = result.value
			cores[id] = core
		end
		report = Analyze.run(core, { measureInvalid = true })
		analyses[id] = report
	end
	return report
end

local function stepOf(report: any, id: string): StepAnalysis
	for _, s in report.steps do
		if s.step == id then
			return s
		end
	end
	return A.fail("no step " .. id)
end

local function factorOf(s: StepAnalysis, id: string): any
	for _, f in s.factors do
		if f.factor == id then
			return f
		end
	end
	return A.fail("no factor " .. id)
end

-- The largest |Δ| of a step field over the steps (all, or one step's id).
local function worst(report: any, base: any, field: string, only: string?): number
	local w = 0
	for i, s in report.steps do
		if only == nil or only == "All" or s.step == only then
			w = math.max(w, math.abs((s :: any)[field] - base.steps[i][field]))
		end
	end
	return w
end

-- T-DIF-12's entry ([8.3]): what the §5 table and E-S2.9 state of a fixture, as Analyze.run measures it.
local function entry(id: string): any
	local report = analysisOf(id)
	local p, e = report.physics, report.edge
	local lengths: { number } = {}
	for _, c in e.chains do
		table.insert(lengths, c.length)
	end
	local steps: { any } = {}
	for _, s in report.steps do
		local factors: { any } = {}
		for _, f in s.factors do
			table.insert(factors, { factor = f.factor, raw = f.raw, x = f.x })
		end
		table.insert(steps, { step = s.step, g = s.g, m = s.m, d = s.d, tier = s.tier, tierRaw = s.tierRaw,
			material = s.material, factors = factors })
	end
	return {
		id = id,
		valid = report.validation.ok,
		cleaned = report.cleaned,
		physics = { mass = p.mass, volume = p.volume, balance = p.balance, reach = p.reach, bladeLength = p.bladeLength,
			edgeLength = p.edgeLength, cutIndex = p.cutIndex },
		edge = { chains = #e.chains, lengths = lengths, cell = e.cell, bladeArea = e.bladeArea,
			bladeMeanThickness = e.bladeMeanThickness },
		steps = steps,
	}
end

local function golden(group: string, ids: { string })
	local entries: { any } = {}
	for _, id in ids do
		table.insert(entries, entry(id))
	end
	Golden.check(string.format("difficulty_%s.bv%d", group, Versions.BALANCE_VERSION), entries)
end

local function idsOf(list: { Build.Measured }): { string }
	local ids: { string } = {}
	for _, f in list do
		table.insert(ids, f.id)
	end
	return ids
end

return Test.suite("Physics/DifficultyTable", function(t)
	t.it("T-DIF-11 every fixture plays its record's tiers, raw tiers too; F5's highest step 0.05 under Hard", function()
		local checked = 0
		local function check(id: string, tiers: { [string]: string }, tierRaw: { [string]: string })
			local report = analysisOf(id)
			A.eq(#report.steps, 3, id)
			for _, s in report.steps do
				A.eq(s.tier, tiers[s.step], id .. " " .. s.step .. " tier (d " .. s.d .. ")")
				A.eq(s.tierRaw, tierRaw[s.step], id .. " " .. s.step .. " tierRaw (d " .. s.d .. ")")
			end
			checked += 1
		end
		for _, f in Blueprints.list do
			check(f.id, f.expect.tiers, f.expect.tierRaw)
		end
		for _, set in { Calibration.list, Regression.list, Cost.list } do
			for _, f in set do
				check(f.id, f.expect.tiers, f.expect.tierRaw)
			end
		end
		A.eq(checked, #Blueprints.list + #Calibration.list + #Regression.list + #Cost.list, "fixtures")
		local hard = (Tiers.get("Hard") :: any).dMin
		for _, s in analysisOf("F5").steps do
			A.truthy(s.d <= hard - Tol.STARTER_MARGIN, "F5 " .. s.step .. " " .. s.d)
		end
		A.eq(math.max(analysisOf("F5").steps[1].d, analysisOf("F5").steps[2].d, analysisOf("F5").steps[3].d), 0.1037,
			"the starter's highest step (Q7: 0.104)")
	end)

	t.it("T-DIF-12 the §5 table golden: F1–F5 and S2's calibration swords", function()
		local ids = table.clone(Blueprints.order)
		for _, id in idsOf(Calibration.list) do
			table.insert(ids, id)
		end
		golden("calibration", ids)
	end)

	t.it("T-DIF-12 the §5 table golden: X01–X07 with their variants and bases, A24–A27", function()
		local ids = idsOf(Regression.list)
		for _, key in VARIANTS do
			if key ~= "A23" then
				table.insert(ids, key)
			end
		end
		golden("regression", ids)
	end)

	t.it("T-DIF-12 the §5 table golden: P1–P5 and P1–P3 with a speck, floating or attached", function()
		golden("cost", idsOf(Cost.list))
	end)

	t.it("T-DIF-13 the Regression records' relations at E-S2.5's bounds: D, Thinness, EdgeLength, G, G and mass",
		function()
			local seen: { [string]: number } = {}
			for _, f in Regression.list do
				local relation = f.expect.relation
				if relation and relation.kind ~= "Asym" then -- X06: Factors.spec, against the 120-probe oracle
					local report, base = analysisOf(f.id), analysisOf(relation.to)
					local what = string.format("%s against %s (%s ≤ %g)", f.id, relation.to, relation.kind,
						relation.bound)
					local kind = relation.kind
					if kind == "D" then
						A.truthy(worst(report, base, "d") <= relation.bound, what .. ": " .. worst(report, base, "d"))
					elseif kind == "Thinness" then
						for _, step in { "Hammering", "Sharpening" } do -- on All, on the Blade
							local dt = math.abs(factorOf(stepOf(report, step), "Thinness").raw
								- factorOf(stepOf(base, step), "Thinness").raw)
							A.truthy(dt <= relation.bound, what .. " " .. step .. ": " .. dt)
						end
					elseif kind == "Edge" then
						local de = math.abs(report.edge.length - base.edge.length)
						A.truthy(de <= relation.bound * base.edge.length, what .. ": " .. de)
						A.eq(#report.edge.chains, 1, what .. ": one chain")
					else
						A.truthy(worst(report, base, "g") <= relation.bound, what .. ": " .. worst(report, base, "g"))
						if kind == "G+mass" then
							local dm = math.abs(report.physics.mass - base.physics.mass) / base.physics.mass
							A.truthy(dm <= Tol.TOL_MASS_REL, what .. " mass: " .. dm)
						else
							A.eq(kind, "G", what)
						end
					end
					seen[kind] = (seen[kind] or 0) + 1
				end
			end
			A.deepEq(seen, { D = 3, Thinness = 1, Edge = 12, G = 7, ["G+mass"] = 3 }, "relations checked")
		end)

	-- L15: a visible fin 1.5 × the Dust floor on the blade's edge splits F4's main chain; Sharpening drops a tier. The
	-- main chain rule (§4.6), recorded in §5.6 and §17.2.
	t.it("T-DIF-13 X03's fin: Thinness within 0.02 of F4's, the main chain split, Sharpening 0.3420 Hard → 0.1980 "
		.. "Normal", function()
			local x03, f4 = analysisOf("X03"), analysisOf("F4")
			A.deepEq({ #f4.edge.chains, #x03.edge.chains }, { 1, 2 }, "chains")
			A.near(f4.edge.length, 5.7237, 5e-5, "F4's EdgeLength")
			A.near(x03.edge.length, 4.7564, 5e-5, "X03's: the longer of the two pieces")
			local before, after = stepOf(f4, "Sharpening"), stepOf(x03, "Sharpening")
			A.deepEq({ before.d, after.d }, { 0.3420, 0.1980 }, "Sharpening")
			A.deepEq({ before.tier, after.tier }, { "Hard", "Normal" }, "Sharpening's tier")
			A.deepEq({ stepOf(f4, "Hammering").d, stepOf(x03, "Hammering").d }, { 0.1572, 0.1575 }, "Hammering +0.0003")
		end)

	t.it("T-DIF-13 the A variants: A25, A26 and A27 within E-S2.7's bounds, A23 finite, A24's Thinness capped at 1",
		function()
			local within = 0
			for _, key in VARIANTS do
				local analysis = (Adversarial.variant(key) :: any).analysis
				local relation = analysis and analysis.relation
				local report = analysisOf(key)
				A.truthy(report.validation.ok, key)
				if relation and relation.d == "Within" then
					local w = worst(report, analysisOf(relation.to), "d", relation.steps)
					A.truthy(w <= relation.bound, string.format("%s against %s on %s: |ΔD| %.4f", key, relation.to,
						relation.steps, w))
					within += 1
				end
				if analysis and analysis.finite then
					H.finite(report, key)
				end
				if analysis and analysis.thinness then
					local all, blade = stepOf(report, "Hammering"), stepOf(report, "Sharpening")
					A.eq(factorOf(all, "Thinness").x, analysis.thinness.All, key .. " Thinness, All")
					A.eq(factorOf(blade, "Thinness").x, analysis.thinness.Blade, key .. " Thinness, Blade")
				end
				for step, want in (analysis and analysis.steps or {}) :: { [string]: any } do
					A.eq(stepOf(report, step).tier, want.tier, key .. " " .. step)
					A.near(stepOf(report, step).d, want.d, 5e-5, key .. " " .. step)
				end
			end
			A.eq(within, 3, "A25, A26, A27")
			-- A27's hilt 0.04 off x = 0 is a real change on All (Asymmetry), none on the Blade
			local a27, f1 = stepOf(analysisOf("A27"), "Hammering"), stepOf(analysisOf("F1"), "Hammering")
			A.deepEq({ a27.d, f1.d }, { 0.1537, 0.1037 }, "A27's Hammering")
		end)

	t.it("T-DIF-13 C10 and C11, C01 + 20 filler parts: D rises at most 0.008 on any step, all Normal (§5.6)", function()
		local c01 = analysisOf("C01")
		for _, id in { "C10", "C11" } do
			for i, s in analysisOf(id).steps do
				A.truthy(s.d - c01.steps[i].d <= 0.008, string.format("%s %s %+.4f", id, s.step, s.d - c01.steps[i].d))
				A.eq(s.tier, "Normal", id .. " " .. s.step)
			end
		end
		A.near(analysisOf("C10").steps[1].d - c01.steps[1].d, 0.0079, 5e-5, "C10's Smelting, the largest rise")
	end)
end)
