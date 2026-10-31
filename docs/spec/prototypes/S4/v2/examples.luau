--!strict
-- S4 prototype v2: worked examples from S2's LIVE analysis (proto/S2/v2: Analyze.run on its fixtures), no copied
-- constants (R4a-13). Prints: per-fixture stat inputs and preview; the step-by-step for F5 and F1; stats per profile;
-- the golden outcome cases (T-CR-02). Profile scores = S3's final means (final/S3-score-distributions.luau).
-- usage: lune run examples.luau
local Analyze = require("../../S2/v2/analyze")
local Fx = require("../../S2/v2/fixtures")
local Dist = require("../../../final/S3-score-distributions")
local Defs = require("./Crafting/Defs")
local C = require("./Crafting/Core")

local fmt = string.format

local function analyse(core: any): (any, any, any)
	core.type = core.type or "Sword"
	local R = Analyze.run(core)
	assert(R.valid, core.name .. " invalid")
	local physics = table.clone(R.physics)
	physics.cutIndex = R.edge.cutIndex -- S2 spec: PhysicsReport.cutIndex (prototype keeps it on edge)
	local analysis = { physics = physics, steps = R.steps }
	return C.build(core, analysis), physics, R
end

local function tiersOf(plan: any): string
	local t = {}
	for _, ps in plan.steps do
		table.insert(t, string.sub(ps.tier, 1, 1))
	end
	return table.concat(t, "/")
end

local function meanScore(fam: string, tier: string, mat: string, prof: string): number
	for _, c in Dist.cells do
		if c.family == fam and c.tier == tier and c.material == mat and c.profile == prof then
			return c.mean
		end
	end
	error("no cell")
end

local fixtures = {}
for _, b in Fx.golden() do
	table.insert(fixtures, b)
end
for _, b in Fx.calibration() do
	table.insert(fixtures, b)
end

print(fmt("# gamma %.2f, T Steel %.2f, thresholds U %.2f R %.2f E %.2f", Defs.Quality.DESIGN_GAMMA, Defs.material.Steel.qualityTier,
	Defs.rarity.Uncommon.minQuality, Defs.rarity.Rare.minQuality, Defs.rarity.Epic.minQuality))
print("## E1 fixture inputs (S2 live) and preview")
print("| Fixture | mass | reach | balance | beta | edge | cutIndex | c | F_mass | Balance | H | K | T | D S/H/Sh | tiers | d S/H/Sh | ceiling | cap |")
print("|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|")
local planBy: { [string]: any } = {}
for _, core in fixtures do
	local plan, physics = analyse(core)
	planBy[core.name] = { plan = plan, physics = physics, core = core }
	local runs = { { score = 1, passed = true }, { score = 1, passed = true }, { score = 1, passed = true } }
	local inp = C.statInputs(core, physics, plan, runs)
	local b = C.breakdown("Sword", inp)
	local pv = C.preview(core, physics, plan)
	local ds, ms = {}, {}
	for i, ps in plan.steps do
		ds[i] = fmt("%.4f", ps.difficulty)
		ms[i] = fmt("%.3f", pv.multipliers[i])
	end
	print(fmt("| %s | %.4f | %.3f | %.3f | %.3f | %.3f | %.2f | %.3f | %.3f | %.0f | %.4f | %.4f | %.4f | %s | %s | %s | %.4f | %s%s |",
		core.name, physics.mass, physics.reach, physics.balance, b.beta, physics.edgeLength, physics.cutIndex, b.c, b.fMass, b.balance,
		inp.hardness, inp.toughness, pv.materialTier, table.concat(ds, " / "), tiersOf(plan), table.concat(ms, " / "), pv.qualityCeiling,
		pv.rarityCap, if pv.capStep then " (" .. pv.capStep .. ")" else ""))
end

-- step-by-step: F5 (Iron) and F1 (Steel blade), Good profile mean scores at the fixture's own tiers
print("## E2 step-by-step, Good player (S3 mean score per step at the played tier and material), all passed")
for _, name in { "F5 StarterSword", "F1 ArmingSword" } do
	local e = planBy[name]
	local runs = {}
	for i, ps in e.plan.steps do
		runs[i] = { score = C.q(meanScore(ps.family, ps.tier, ps.material, "Good"), 1e4), passed = true }
	end
	local o = C.compute(e.core, e.physics, e.plan, runs)
	local b = C.breakdown("Sword", o.inputs)
	print(fmt("%s: scores %.4f / %.4f / %.4f; H %.4f K %.4f; P %.4f h %.4f k %.4f; Sharp %.4f Dura %.4f; c %.4f F_mass %.4f F_edge %.4f F_forge %.4f; Damage %.4f; beta %.4f Balance %.4f; T %.4f",
		name, runs[1].score, runs[2].score, runs[3].score, o.inputs.hardness, o.inputs.toughness, b.purity, b.hEff, b.kEff, b.sharpness,
		b.durability, b.c, b.fMass, b.fEdge, b.fForge, b.damage, b.beta, b.balance, o.quality.materialTier))
	local terms = {}
	for _, t in o.quality.terms do
		table.insert(terms, fmt("%s %.2f*%.4f*%.4f=%.5f", t.step, t.weight, t.effectiveScore, t.multiplier, t.contribution))
	end
	print("   Q terms: " .. table.concat(terms, " + ") .. fmt(" -> Q %.4f, by score %s, cap %s, rarity %s", o.quality.q, o.rarity.byScore, o.rarity.cap, o.rarity.rarity))
	local st = {}
	for _, id in { "Damage", "Sharpness", "Durability", "Purity", "Balance", "Reach" } do
		table.insert(st, fmt("%s %.4f", id, o.stats[id]))
	end
	print("   stored stats: " .. table.concat(st, ", "))
end

-- stats per fixture and profile (S3 means at the fixture's tiers; a step below the pass line counts as failed)
print("## E3 Damage / Sharpness / Durability per fixture and profile (S3 mean scores; Perfect = 1.0)")
print("| Fixture | Poor | Average | Good | Elite | Perfect |")
print("|---|---|---|---|---|---|")
for _, name in { "F5 StarterSword", "F1 ArmingSword", "F2 MinimalSword", "F3 Rapier", "F4 Cleaver", "C06 Sabre (Steel)", "C08 Greatsword" } do
	local e = planBy[name]
	local cells = {}
	for _, prof in { "Poor", "Average", "Good", "Elite", "Perfect" } do
		local runs = {}
		for i, ps in e.plan.steps do
			local s = if prof == "Perfect" then 1 else C.q(meanScore(ps.family, ps.tier, ps.material, prof), 1e4)
			runs[i] = { score = s, passed = s >= 0.5 }
		end
		local o = C.compute(e.core, e.physics, e.plan, runs)
		table.insert(cells, fmt("%.1f / %.1f / %.1f", o.stats.Damage, o.stats.Sharpness, o.stats.Durability))
	end
	print(fmt("| %s (%s) | %s |", name, tiersOf(e.plan), table.concat(cells, " | ")))
end

-- golden outcome cases (synthetic plans: tiers and D given, all-Iron or all-Steel F5 geometry for T/H/K)
print("## E4 golden outcome cases (plan tiers/D given; T from the material; stats not shown)")
local function case(label: string, mat: string, tiers: { string }, D: { number }, scores: { number })
	local steps = {}
	local W = { 0.25, 0.40, 0.35 }
	local ids = { "Smelting", "Hammering", "Sharpening" }
	for i = 1, 3 do
		steps[i] = { index = i, step = ids[i], family = Defs.StepFamily[ids[i]], weight = W[i], tier = tiers[i], difficulty = D[i], material = mat }
	end
	local plan = { equipmentType = "Sword", steps = steps }
	local runs = {}
	for i = 1, 3 do
		runs[i] = { score = scores[i], passed = scores[i] >= 0.5 }
	end
	local T = Defs.material[mat].qualityTier
	local qr = C.quality(plan, runs, T)
	local rr = C.resolve(qr.q, plan, runs)
	local parts = {}
	for i, t in qr.terms do
		parts[i] = fmt("%.4f", t.multiplier)
	end
	print(fmt("| %s | %s | %s | %.4f / %.4f / %.4f | %.4f / %.4f / %.4f | d %s | T %.2f | Q %.4f | %s | %s%s | **%s** |", label, mat,
		table.concat(tiers, "/"), D[1], D[2], D[3], scores[1], scores[2], scores[3], table.concat(parts, " / "), T, qr.q, rr.byScore, rr.cap,
		if rr.capStep then " (" .. rr.capStep .. ")" else "", rr.rarity))
end
case("A Average, starter", "Iron", { "Normal", "Normal", "Normal" }, { 0.0288, 0.1037, 0.0989 }, { 0.62, 0.64, 0.63 })
case("B Good+, starter", "Iron", { "Normal", "Normal", "Normal" }, { 0.0288, 0.1037, 0.0989 }, { 0.82, 0.80, 0.90 })
case("C Perfect, Steel, every step just Normal (cap binds)", "Steel", { "Normal", "Normal", "Normal" }, { 0.1999, 0.1999, 0.1999 }, { 1.0, 1.0, 1.0 })
case("D Good, rapier", "Steel", { "Normal", "Hard", "Hard" }, { 0.0000, 0.4423, 0.6104 }, { 0.80, 0.72, 0.85 })
case("E As D, Sharpening failed", "Steel", { "Normal", "Hard", "Hard" }, { 0.0000, 0.4423, 0.6104 }, { 0.80, 0.72, 0.45 })
case("F Elite, cleaver", "Iron", { "Hard", "Normal", "Hard" }, { 0.4590, 0.1572, 0.3420 }, { 0.83, 0.86, 0.95 })
case("G As F, both Hard steps failed", "Iron", { "Hard", "Normal", "Hard" }, { 0.4590, 0.1572, 0.3420 }, { 0.48, 0.86, 0.49 })
case("H Good, Smelting Hard only", "Steel", { "Hard", "Normal", "Normal" }, { 0.2000, 0.1037, 0.0989 }, { 0.75, 0.79, 0.87 })
case("I Timed-out Hammering", "Iron", { "Normal", "Normal", "Normal" }, { 0.0288, 0.1037, 0.0989 }, { 0.80, 0.00, 0.87 })

-- R2-06: a 3-step record recomputed under a synthetic 6-step plan keeps its Q
do
	local core = planBy["F5 StarterSword"].core
	local physics = planBy["F5 StarterSword"].physics
	local plan = planBy["F5 StarterSword"].plan
	local runs = { { score = 1, passed = true }, { score = 1, passed = true }, { score = 1, passed = true } }
	local before = C.compute(core, physics, plan, runs).quality.q
	local saved = Defs.CraftPlans[1].steps
	Defs.CraftPlans[1].steps = {
		{ step = "Smelting", weight = 0.15, worksOn = "All", feeds = { "Purity" }, enabled = true },
		{ step = "Hammering", weight = 0.24, worksOn = "All", feeds = { "Damage", "Durability" }, enabled = true },
		{ step = "Sharpening", weight = 0.21, worksOn = { "Blade" }, feeds = { "Sharpness", "Damage" }, enabled = true },
		{ step = "Quenching", weight = 0.15, worksOn = { "Blade", "Guard" }, feeds = { "Durability" }, enabled = true },
		{ step = "Assembly", weight = 0.15, worksOn = "All", feeds = { "Balance" }, enabled = true },
		{ step = "Finishing", weight = 0.10, worksOn = "All", feeds = {}, enabled = true },
	}
	Defs.plan.Sword = Defs.CraftPlans[1]
	local records = {}
	for i, ps in plan.steps do
		records[i] = { step = ps.step, family = ps.family, tier = ps.tier, difficulty = ps.difficulty, material = ps.material }
	end
	local p2 = C.fromHistory(core, { physics = physics }, records)
	local after = C.compute(core, physics, p2, runs).quality.q
	print(fmt("## E5 R2-06: F5 flawless Q %.4f under the MVP plan, %.4f recomputed under a 6-step plan (weights renormalized over the 3 recorded steps: %.4f / %.4f / %.4f)",
		before, after, p2.steps[1].weight, p2.steps[2].weight, p2.steps[3].weight))
	Defs.CraftPlans[1].steps = saved
	Defs.plan.Sword = Defs.CraftPlans[1]
end
