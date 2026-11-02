--!strict
-- Definitions/MinigameFamilies (SPEC §6.5–§6.10, §10.6, §16.12, E-S3.3–E-S3.5; T-DEF-01/02/03/05/06/07): the six
-- family rows, every parameter column, the check thresholds and flag levels, and the timeline wire constants.
-- The resolver below applies §6.5's formula to the transcribed columns and must reproduce the values the evidence
-- prints (E-S3.3 resolved values, E-S3.4 grade bands, E-S3.5 travel times), so a slip in a base, material, tier,
-- design, clamp or quantum column fails here before M4's Params exists.

local Test = require("../lib/Test")
local A = require("../lib/Assert")
local Dump = require("../lib/Dump")
local DT = require("../../src/shared/Definitions/Types")
local CraftPlans = require("../../src/shared/Definitions/CraftPlans")
local Limits = require("../../src/shared/Definitions/Limits")
local Materials = require("../../src/shared/Definitions/Materials")
local MF = require("../../src/shared/Definitions/MinigameFamilies")
local Steps = require("../../src/shared/Definitions/Steps")
local Tiers = require("../../src/shared/Definitions/Tiers")

type ParamDef = MF.MinigameParamDef
type FamilyDef = MF.MinigameFamilyDef

-- append-only: a new family is appended, never renamed or reordered (§2.2)
local FAMILY_IDS = { "HoldZone", "TimingStrike", "RhythmSequence", "PrecisionTrace", "ReleaseTiming", "FitPuzzle" }
local MVP_FAMILIES = { "HoldZone", "TimingStrike", "PrecisionTrace" }
-- §2.2's FactorId order
local FACTOR_ORDER: { DT.FactorId } = {
	"PartCount", "Thinness", "Asymmetry", "SurfaceComplexity", "EdgeLength", "Joints", "MaterialMix", "Volume",
}
-- Minigames/Types' FlagId values, §6.2 order
local FLAG_IDS = { "HzInhumanRate", "TsLowVariance", "TsExactHits", "PtTooPrecise", "PtTooSmooth", "PtTeleport", "PtSparse" }
local PT_TRAVEL_MAX_MS = 30000 -- Minigames/PrecisionTrace (§16.22): the travel clamp
local TS_PERFECT_CORE_MIN_MS = 10 -- Minigames/TimingStrike (§16.21): the full-points core floor

local function family(id: string): FamilyDef
	local def = MF.get(id)
	if def == nil then
		A.fail("no family " .. id)
	end
	return def :: FamilyDef
end

local function param(familyId: string, name: string): ParamDef
	for _, p in family(familyId).params do
		if p.name == name then
			return p
		end
	end
	return A.fail(familyId .. " has no parameter " .. name)
end

local function check(familyId: string, name: string): number
	for _, c in family(familyId).checks do
		if c.name == name then
			return c.value
		end
	end
	return A.fail(familyId .. " has no check " .. name)
end

-- §6.5: p_final = round_q(clamp(base · m_material · m_tier · m_design, min, max)); every design factor at x
local function resolve(familyId: string, material: string, tier: string, x: number): { [string]: number }
	local tierDef = Tiers.get(tier)
	if tierDef == nil then
		return A.fail("no tier " .. tier)
	end
	local out: { [string]: number } = {}
	for _, p in family(familyId).params do
		local material_ = p.material
		local mMaterial = if material_ then (material_ :: any)[material] or 1 else 1
		local tierColumn = p.tier
		local mTier = if tierColumn then tierColumn[tierDef.order] else 1
		local mDesign = 1
		local design = p.design
		if design then
			local sum = 1
			for _, term in design do
				sum += term.k * math.clamp(x, 0, 1)
			end
			local c = p.designClamp :: { number }
			mDesign = math.clamp(sum, c[1], c[2])
		end
		local v = p.base * mMaterial * mTier * mDesign
		if p.min then
			v = math.max(v, p.min :: number)
		end
		if p.max then
			v = math.min(v, p.max :: number)
		end
		if p.quantum then
			local q = p.quantum :: number
			v = q * math.round(v / q)
		end
		out[p.name] = v
	end
	return out
end

-- printed to `dp` decimals in the evidence: within half a unit of the last printed digit
local function printed(actual: number, expected: number, dp: number, what: string)
	local unit = 1
	for _ = 1, dp do
		unit /= 10
	end
	A.near(actual, expected, unit / 2 * (1 + 1e-9) + 1e-12, what)
end

local function isPascal(s: string): boolean
	return string.match(s, "^%u%w*$") ~= nil and string.find(s, "_", 1, true) == nil
end

local function isCamel(s: string): boolean
	return string.match(s, "^%l%w*$") ~= nil
end

local function isUpperSnake(s: string): boolean
	return string.match(s, "^%u[%u%d_]*$") ~= nil
end

-- every number finite, every table frozen, keys strings or a dense array, no table reachable twice
local function walkData(v: any, path: string, seen: { [any]: string })
	if type(v) == "number" then
		A.finite(v, path)
	elseif type(v) == "table" then
		if seen[v] then
			A.fail(path .. " shares a table with " .. seen[v])
		end
		seen[v] = path
		A.truthy(table.isfrozen(v), path .. " is frozen")
		local n = #v
		for k, child in v do
			if type(k) == "number" then
				A.truthy(k % 1 == 0 and k >= 1 and k <= n, path .. ": array keys are dense")
			else
				A.eq(type(k), "string", path .. ": keys are strings or array indices")
			end
			walkData(child, path .. "." .. tostring(k), seen)
		end
	elseif type(v) ~= "string" and type(v) ~= "boolean" then
		A.fail(path .. " holds a " .. type(v))
	end
end

return Test.suite("Definitions/MinigameFamilies", function(t)
	t.it("T-DEF-01 family ids are PascalCase, unique and append-only; orders 1..6", function()
		A.eq(#MF.ordered, #FAMILY_IDS, "six families")
		local seen: { [string]: boolean } = {}
		for i, row in MF.ordered do
			A.eq(row.id, FAMILY_IDS[i], "family " .. i)
			A.eq(row.order, i, row.id .. ".order")
			A.truthy(isPascal(row.id), row.id .. " is PascalCase")
			A.falsy(seen[row.id], row.id .. " is unique")
			seen[row.id] = true
			A.truthy(type(row.name) == "string" and row.name ~= "", row.id .. " has a display name")
		end
	end)

	t.it("T-DEF-02 MVP enables HoldZone, TimingStrike and PrecisionTrace, the families of the enabled steps", function()
		local enabled: { string } = {}
		for _, row in MF.enabled do
			table.insert(enabled, row.id)
		end
		A.deepEq(enabled, MVP_FAMILIES, "enabled families")
		for _, id in FAMILY_IDS do
			A.eq(MF.isEnabled(id), table.find(MVP_FAMILIES, id) ~= nil, id .. " enabled")
		end
		-- every enabled step plays an enabled family (D2) and the MVP steps map as §6.1 says
		for _, step in Steps.enabled do
			A.truthy(MF.isEnabled(step.family), step.id .. " plays an enabled family")
		end
		local plan: { [string]: string } = {}
		for _, step in Steps.ordered do
			plan[step.id] = step.family
		end
		A.eq(plan.Smelting, "HoldZone")
		A.eq(plan.Hammering, "TimingStrike")
		A.eq(plan.Sharpening, "PrecisionTrace")
		-- every step of the sword plan has its family's parameters
		for _, s in CraftPlans.Sword.steps do
			A.truthy(#family(plan[s.step]).params > 0, s.step .. "'s family has parameters")
		end
	end)

	t.it("T-DEF-03 catalog views agree with the rows", function()
		for i, row in MF.ordered do
			A.eq(MF.byId[row.id], row, row.id .. " byId")
			A.eq(MF.get(row.id), row, row.id .. " get")
			if i > 1 then
				A.truthy(MF.ordered[i - 1].order < row.order, "ordered ascends")
			end
		end
		A.eq(MF.get("Smelting"), nil, "a step id is not a family")
		A.eq(MF.get((42 :: any) :: string), nil, "non-string id")
		A.falsy(MF.isEnabled("RhythmSequence"), "Phase 2 family disabled")
	end)

	t.it("T-DEF-03 parameter columns: materials, five tier columns, design terms in FactorId order", function()
		for _, row in MF.ordered do
			local names: { [string]: boolean } = {}
			if not row.enabled then
				A.eq(#row.params, 1, row.id .. ": Phase 2 rows carry only the pass line yet")
				A.eq(row.params[1].name, "passThreshold", row.id .. ": its one parameter is the pass line")
				A.eq(#row.checks, 0, row.id .. ": no checks")
				A.eq(#row.flagLevels, 0, row.id .. ": no flags")
			end
			for _, p in row.params do
				local where = row.id .. "." .. p.name
				A.truthy(isCamel(p.name), where .. " is camelCase")
				A.falsy(names[p.name], where .. " is unique")
				names[p.name] = true
				A.finite(p.base, where .. ".base")
				local material = p.material
				if material then
					for id, m in material do
						A.truthy(Materials.isEnabled(id), where .. ": material column " .. id .. " is an enabled material")
						A.truthy(m > 0, where .. ": material factor positive")
						A.truthy(id ~= "Iron", where .. ": Iron is the base (no column)")
					end
				end
				local tierColumn = p.tier
				if tierColumn then
					A.eq(#tierColumn, #Tiers.ordered, where .. ": one tier column per tier")
					A.eq(tierColumn[1], 1, where .. ": Normal is the base")
					for _, m in tierColumn do
						A.truthy(m > 0, where .. ": tier factor positive")
					end
				end
				local design = p.design
				A.eq(design ~= nil, p.designClamp ~= nil, where .. ": design terms come with a clamp")
				if design then
					local last = 0
					local lo, hi = 1, 1
					for _, term in design do
						local at = table.find(FACTOR_ORDER, term.factor)
						A.truthy(at ~= nil and at > last, where .. ": design factors in FactorId order")
						last = at :: number
						A.truthy(term.k ~= 0, where .. ": a design term moves its parameter")
						if term.k < 0 then
							lo += term.k
						else
							hi += term.k
						end
					end
					-- the clamp is exactly the reachable range for x in [0, 1]: a typo in k or the clamp fails here
					local clamp = p.designClamp :: { number }
					A.eq(#clamp, 2, where .. ".designClamp is {lo, hi}")
					A.near(clamp[1], lo, 1e-12, where .. ".designClamp[1]")
					A.near(clamp[2], hi, 1e-12, where .. ".designClamp[2]")
					A.within(lo, 0.5, 1, where .. ": design moves a parameter by at most 50 %")
					A.within(hi, 1, 1.5, where .. ": design moves a parameter by at most 50 %")
				end
				if p.quantum then
					A.truthy((p.quantum :: number) > 0, where .. ".quantum")
					A.eq(p.base % (p.quantum :: number), 0, where .. ": the base sits on its quantum")
				end
				if p.min and p.max then
					A.truthy((p.min :: number) <= (p.max :: number), where .. ": min ≤ max")
				end
				A.truthy(p.min == nil or p.base >= (p.min :: number), where .. ": base ≥ min")
				A.truthy(p.max == nil or p.base <= (p.max :: number), where .. ": base ≤ max")
			end
		end
	end)

	t.it("T-DEF-03 design factor sets per step (§5.2, §6.5)", function()
		local expected: { [string]: { string } } = {
			HoldZone = { "Volume" },
			TimingStrike = { "Thinness", "Asymmetry", "SurfaceComplexity" },
			PrecisionTrace = { "Asymmetry", "SurfaceComplexity" }, -- EdgeLength acts through the path length
		}
		for _, id in MVP_FAMILIES do
			local used: { [string]: boolean } = {}
			for _, p in family(id).params do
				local design = p.design
				if design then
					for _, term in design do
						used[term.factor] = true
					end
				end
			end
			local list: { string } = {}
			for _, f in FACTOR_ORDER do
				if used[f] then
					table.insert(list, f)
				end
			end
			A.deepEq(list, expected[id], id .. " design factors")
		end
	end)

	t.it("T-DEF-03 parameter names per family (§6.8–§6.10) and one pass line 0.50 (Q8)", function()
		local expected: { [string]: { string } } = {
			HoldZone = {
				"zoneWidth", "driftSpeed", "heatDecay", "fullHeat", "strokeGain", "refillMs", "fireDecayMs", "targetMin",
				"targetMax", "segMinMs", "segMaxMs", "holdChance", "durationMs", "rampMs", "softFrac", "passThreshold",
			},
			TimingStrike = {
				"strikes", "beatMs", "windowMs", "perfectFrac", "edgePoints", "tempoJitter", "offsetMin", "offsetMax",
				"missPadMs", "tailMs", "passThreshold",
			},
			PrecisionTrace = {
				"halfWidth", "pacerSpeed", "paceTol", "paceFall", "perturbAmp", "bumpDensity", "bumpWidth", "coreFrac",
				"wAccuracy", "leadInMs", "tailMs", "passThreshold",
			},
			-- Phase 2 rows: only the pass line so far (§16.12 "every family")
			RhythmSequence = { "passThreshold" },
			ReleaseTiming = { "passThreshold" },
			FitPuzzle = { "passThreshold" },
		}
		A.eq(#MF.ordered, #FAMILY_IDS, "six rows")
		for _, id in FAMILY_IDS do
			local names: { string } = {}
			for _, p in family(id).params do
				table.insert(names, p.name)
			end
			A.deepEq(names, expected[id], id .. " parameters")
			-- §6.5 / §16.12: passThreshold = 0.50 on every family, with no column that could move it
			local pass = param(id, "passThreshold")
			A.eq(pass.base, 0.50, id .. " pass line")
			A.truthy(pass.material == nil and pass.tier == nil and pass.design == nil and pass.designClamp == nil
				and pass.quantum == nil and pass.min == nil and pass.max == nil, id .. ": one pass line everywhere")
		end
	end)

	t.it("T-DEF-03 base values and columns = §6.8–§6.10", function()
		local function cols(familyId: string, name: string): { any }
			local p = param(familyId, name)
			local out: { any } = { p.base, p.material, p.tier, p.design, p.designClamp, p.quantum, p.min, p.max }
			return out
		end
		local S = function(v: number): any
			return { Steel = v }
		end
		local function d(factor: string, k: number): any
			return { { factor = factor, k = k } }
		end
		local rows: { { any } } = {
			-- family, name, base, Steel, tier columns N/H/E/M/Hell, design, clamp, quantum, min, max
			{ "HoldZone", "zoneWidth", 0.090, S(0.98), { 1, 0.96, 0.88, 0.80, 0.72 }, d("Volume", -0.10), { 0.9, 1 } },
			{ "HoldZone", "driftSpeed", 0.21, S(1.01), { 1, 1.05, 1.15, 1.25, 1.35 }, d("Volume", 0.15), { 1, 1.15 } },
			{ "HoldZone", "heatDecay", 1.0, nil, { 1, 1.05, 1.12, 1.20, 1.28 } },
			{ "HoldZone", "fullHeat", 2.4 },
			{ "HoldZone", "strokeGain", 0.25 },
			{ "HoldZone", "refillMs", 250, nil, nil, nil, nil, 10 },
			{ "HoldZone", "fireDecayMs", 600, nil, nil, nil, nil, 10 },
			{ "HoldZone", "targetMin", 0.40, S(1.08) },
			{ "HoldZone", "targetMax", 0.80, S(1.04) },
			{ "HoldZone", "segMinMs", 900, nil, { 1, 0.9, 0.8, 0.7, 0.6 }, nil, nil, 10 },
			{ "HoldZone", "segMaxMs", 2200, nil, { 1, 0.9, 0.8, 0.7, 0.6 }, nil, nil, 10 },
			{ "HoldZone", "holdChance", 0.25, nil, { 1, 0.8, 0.6, 0.4, 0.2 } },
			{ "HoldZone", "durationMs", 15000, nil, { 1, 1, 1.1, 1.2, 1.3 }, d("Volume", 0.20), { 1, 1.2 }, 10 },
			{ "HoldZone", "rampMs", 3000, nil, nil, nil, nil, 10 },
			{ "HoldZone", "softFrac", 0.5 },
			{ "TimingStrike", "strikes", 12, nil, { 1, 1.25, 1.5, 1.75, 2 }, nil, nil, 1, 8, 32 },
			{ "TimingStrike", "beatMs", 900, S(0.98), { 1, 0.85, 0.75, 0.65, 0.58 }, d("SurfaceComplexity", -0.10), { 0.9, 1 }, 1, 450 },
			{ "TimingStrike", "windowMs", 110, S(0.98), { 1, 0.94, 0.80, 0.70, 0.60 }, d("Thinness", -0.15), { 0.85, 1 }, 1, 20 },
			{ "TimingStrike", "perfectFrac", 0.12, nil, { 1, 0.80, 0.70, 0.60, 0.50 } },
			{ "TimingStrike", "edgePoints", 0.20, nil, { 1, 0.50, 0.40, 0.30, 0.20 } },
			{ "TimingStrike", "tempoJitter", 0.08, nil, { 1, 1.5, 2, 2.5, 3 }, d("Asymmetry", 0.5), { 1, 1.5 }, nil, nil, 0.30 },
			{ "TimingStrike", "offsetMin", 0.40 },
			{ "TimingStrike", "offsetMax", 0.75 },
			{ "TimingStrike", "missPadMs", 90, nil, nil, nil, nil, 1 },
			{ "TimingStrike", "tailMs", 400, nil, nil, nil, nil, 10 },
			{ "PrecisionTrace", "halfWidth", 0.041, S(0.98), { 1, 0.95, 0.85, 0.76, 0.68 }, d("SurfaceComplexity", -0.10), { 0.9, 1 }, nil, 0.012 },
			{ "PrecisionTrace", "pacerSpeed", 0.30, S(1.01), { 1, 1.05, 1.15, 1.25, 1.35 }, d("Asymmetry", 0.15), { 1, 1.15 } },
			{ "PrecisionTrace", "paceTol", 0.12, nil, { 1, 0.85, 0.7, 0.6, 0.5 } },
			{ "PrecisionTrace", "paceFall", 0.24, nil, { 1, 0.85, 0.7, 0.6, 0.5 } },
			{ "PrecisionTrace", "perturbAmp", 0.020, nil, { 1, 1.25, 1.5, 1.75, 2 }, d("SurfaceComplexity", 0.5), { 1, 1.5 } },
			{ "PrecisionTrace", "bumpDensity", 1.0, nil, { 1, 1.3, 1.6, 1.9, 2.2 } },
			{ "PrecisionTrace", "bumpWidth", 0.25, nil, { 1, 0.9, 0.8, 0.7, 0.6 } },
			{ "PrecisionTrace", "coreFrac", 0.10 },
			{ "PrecisionTrace", "wAccuracy", 0.70 },
			{ "PrecisionTrace", "leadInMs", 600, nil, nil, nil, nil, 20 },
			{ "PrecisionTrace", "tailMs", 400, nil, nil, nil, nil, 20 },
		}
		for _, r in rows do
			local expected = { r[3], r[4], r[5], r[6], r[7], r[8], r[9], r[10] }
			A.deepEq(cols(r[1], r[2]), expected, r[1] .. "." .. r[2])
		end
	end)

	t.it("T-DEF-03 resolved values = E-S3.3 (Iron/Steel × Normal/Hard, every factor at x = 0 and x = 1)", function()
		-- {family, param, decimals, {Iron/Normal, Iron/Hard, Steel/Normal, Steel/Hard} × {x = 0, x = 1}}
		local cells = { { "Iron", "Normal" }, { "Iron", "Hard" }, { "Steel", "Normal" }, { "Steel", "Hard" } }
		local expected: { { any } } = {
			{ "HoldZone", "zoneWidth", 4, { { 0.090, 0.081 }, { 0.0864, 0.0778 }, { 0.0882, 0.0794 }, { 0.0847, 0.0762 } } },
			{ "HoldZone", "driftSpeed", 4, { { 0.210, 0.2415 }, { 0.2205, 0.2536 }, { 0.2121, 0.2439 }, { 0.2227, 0.2561 } } },
			{ "HoldZone", "durationMs", 0, { { 15000, 18000 }, { 15000, 18000 }, { 15000, 18000 }, { 15000, 18000 } } },
			{ "TimingStrike", "windowMs", 0, { { 110, 94 }, { 103, 88 }, { 108, 92 }, { 101, 86 } } },
			{ "TimingStrike", "beatMs", 0, { { 900, 810 }, { 765, 689 }, { 882, 794 }, { 750, 675 } } },
			{ "TimingStrike", "tempoJitter", 4, { { 0.08, 0.12 }, { 0.12, 0.18 }, { 0.08, 0.12 }, { 0.12, 0.18 } } },
			{ "TimingStrike", "strikes", 0, { { 12, 12 }, { 15, 15 }, { 12, 12 }, { 15, 15 } } },
			{ "PrecisionTrace", "halfWidth", 4, { { 0.0410, 0.0369 }, { 0.0390, 0.0351 }, { 0.0402, 0.0362 }, { 0.0382, 0.0344 } } },
			{ "PrecisionTrace", "pacerSpeed", 3, { { 0.300, 0.345 }, { 0.315, 0.362 }, { 0.303, 0.348 }, { 0.318, 0.366 } } },
			{ "PrecisionTrace", "perturbAmp", 4, { { 0.020, 0.030 }, { 0.025, 0.0375 }, { 0.020, 0.030 }, { 0.025, 0.0375 } } },
		}
		for _, e in expected do
			for c, cell in cells do
				for xi, x in { 0, 1 } do
					local v = resolve(e[1], cell[1], cell[2], x)[e[2]]
					local what = string.format("%s.%s %s/%s x = %d", e[1], e[2], cell[1], cell[2], x)
					printed(v, e[4][c][xi], e[3], what)
				end
			end
		end
		-- §6.5's worked example: windowMs for Iron at Hard with Thinness 0.30 = 110 × 0.94 × 0.955 = 98.7 → 99 ms
		A.eq(resolve("TimingStrike", "Iron", "Hard", 0.30).windowMs, 99, "§6.5 example")
	end)

	t.it("T-DEF-03 TimingStrike grade bands = E-S3.4, PrecisionTrace travel = E-S3.5", function()
		-- Perfect ≥ 0.9 and Good ≥ 0.6 points: |e| ≤ core + (1 − points)·(W − core)/(1 − edgePoints)
		local function bands(material: string, tier: string, x: number): (number, number, number)
			local p = resolve("TimingStrike", material, tier, x)
			local W = p.windowMs
			local core = math.min(W, math.max(p.perfectFrac * W, TS_PERFECT_CORE_MIN_MS))
			local slope = (W - core) / (1 - p.edgePoints)
			return W, core + 0.1 * slope, core + 0.4 * slope
		end
		for _, e in
			{
				{ "Iron", "Normal", 0, 110, 25.3, 61.6 },
				{ "Iron", "Normal", 1, 94, 21.6, 52.6 },
				{ "Iron", "Hard", 0, 103, 20.3, 51.3 },
				{ "Iron", "Hard", 1, 88, 18.7, 44.7 },
				{ "Steel", "Hard", 1, 86, 18.4, 43.8 },
			} :: { { any } }
		do
			local W, perfect, good = bands(e[1], e[2], e[3])
			local what = string.format("%s/%s x = %d", e[1], e[2], e[3])
			A.eq(W, e[4], what .. " W")
			printed(perfect, e[5], 1, what .. " Perfect band")
			printed(good, e[6], 1, what .. " Good band")
		end
		local golden = resolve("TimingStrike", "Iron", "Normal", 0) -- E-S3.4 golden: core 13.2, M = W + pad = 200
		A.near(golden.perfectFrac * golden.windowMs, 13.2, 1e-9, "core")
		A.eq(golden.windowMs + golden.missPadMs, 200, "M")
		-- travelMs = clamp(ceil(L/pacerSpeed·50)·20, 6000, 30000); durationMs = leadInMs + travelMs + tailMs
		local pt = resolve("PrecisionTrace", "Iron", "Normal", 0)
		local travel = math.clamp(math.ceil(3.3526 / pt.pacerSpeed * 50) * 20, 6000, PT_TRAVEL_MAX_MS)
		A.eq(travel, 11180, "reference arming edge travel (L 3.3526 u)")
		A.eq(pt.leadInMs + travel + pt.tailMs, 12180, "reference arming edge duration")
		-- the narrowest MVP band stays ≥ 12 px at 720p (halfWidth ≥ 0.0156, E-S6.10); the MVP minimum is 0.034
		local narrowest = math.huge
		for _, material in { "Iron", "Steel" } do
			for _, tier in { "Normal", "Hard" } do
				narrowest = math.min(narrowest, resolve("PrecisionTrace", material, tier, 1).halfWidth)
			end
		end
		A.within(narrowest, 0.034, 0.035, "the MVP minimum halfWidth")
		A.truthy(narrowest >= 0.0156, "trace band ≥ 12 px at 720p")
	end)

	t.it("T-DEF-05 check thresholds = §10.6 / §16.12", function()
		local expected: { [string]: { { any } } } = {
			HoldZone = { { "HZ_RATE_WINDOW_MS", 1000 }, { "HZ_RATE_MAX_PRESSES", 30 } },
			TimingStrike = {
				{ "TS_MIN_JUDGED", 8 }, { "TS_MIN_SD_MS", 1.5 }, { "TS_EXACT_MS", 1 }, { "TS_EXACT_FRAC", 0.90 },
			},
			PrecisionTrace = {
				{ "PT_PRECISE_MIN_SAMPLES", 40 }, { "PT_PRECISE_MEAN_DEV", 0.0008 }, { "PT_SMOOTH_MIN_TRIPLETS", 150 },
				{ "PT_SMOOTH_MEAN_JERK", 0.0002 }, { "PT_SMOOTH_MIN_MOVE", 0.002 }, { "PT_TELEPORT_DIST", 0.25 },
				{ "PT_TELEPORT_MAX_DT", 40 }, { "PT_TELEPORT_COUNT", 3 }, { "PT_SPARSE_FRAC", 0.5 },
			},
		}
		local prefix = { HoldZone = "HZ_", TimingStrike = "TS_", PrecisionTrace = "PT_" }
		for _, id in MVP_FAMILIES do
			local got: { { any } } = {}
			for _, c in family(id).checks do
				A.truthy(isUpperSnake(c.name), c.name .. " is UPPER_SNAKE")
				A.eq(string.sub(c.name, 1, 3), prefix[id], c.name .. " belongs to " .. id)
				A.truthy(c.value > 0, c.name .. " positive")
				local entry: { any } = { c.name, c.value }
				table.insert(got, entry)
			end
			A.deepEq(got, expected[id], id .. " checks")
		end
		-- the variance check can run on every TimingStrike: at least TS_MIN_JUDGED strikes are played
		A.truthy((param("TimingStrike", "strikes").min :: number) >= check("TimingStrike", "TS_MIN_JUDGED"),
			"strikes ≥ TS_MIN_JUDGED")
		A.truthy(check("TimingStrike", "TS_EXACT_FRAC") <= 1, "a fraction")
		-- humans peak at 9 presses per window (E-S3.8); §14.8 asks for a 3 × margin
		A.truthy(check("HoldZone", "HZ_RATE_MAX_PRESSES") / 3 >= 9, "HzInhumanRate margin")
	end)

	t.it("T-DEF-05 flag levels = §10.6: every FlagId once, HIGH clamps, medium is telemetry", function()
		local expected: { [string]: { { string } } } = {
			HoldZone = { { "HzInhumanRate", "High" } },
			TimingStrike = { { "TsLowVariance", "High" }, { "TsExactHits", "High" } },
			PrecisionTrace = {
				{ "PtTooPrecise", "High" }, { "PtTooSmooth", "Medium" }, { "PtTeleport", "Medium" }, { "PtSparse", "Medium" },
			},
		}
		local prefix = { HoldZone = "Hz", TimingStrike = "Ts", PrecisionTrace = "Pt" }
		local all: { string } = {}
		local most = 0
		for _, id in MVP_FAMILIES do
			local got: { { string } } = {}
			for _, f in family(id).flagLevels do
				A.truthy(isPascal(f.flag), f.flag .. " is PascalCase")
				A.eq(string.sub(f.flag, 1, 2), prefix[id], f.flag .. " belongs to " .. id)
				A.truthy(f.level == "High" or f.level == "Medium", f.flag .. " level")
				table.insert(got, { f.flag, f.level })
				table.insert(all, f.flag)
			end
			A.deepEq(got, expected[id], id .. " flag levels")
			most = math.max(most, #got)
		end
		A.deepEq(all, FLAG_IDS, "the seven FlagIds, once each, in §6.2 order")
		-- S3's 7 flags plus S5's LateSubmit and ScoreMismatch fit a step record (§10.6); at most 4 co-occur (Trace)
		A.truthy(#all + 2 <= Limits.MAX_STEP_FLAGS, "9 flag kinds ≤ MAX_STEP_FLAGS")
		A.eq(most, 4, "at most 4 S3 flags per family")
	end)

	t.it("T-DEF-07 timeline constants: MAX_TIMELINE_BYTES = header + largest family cap", function()
		A.eq(MF.TIMELINE_FORMAT_VERSION, 1)
		A.eq(MF.TIMELINE_HEADER_BYTES, 12)
		A.deepEq(MF.FAMILY_CODE, { HoldZone = 1, TimingStrike = 2, PrecisionTrace = 3 }, "FAMILY_CODE")
		A.deepEq(MF.RECORD_BYTES, { HoldZone = 3, TimingStrike = 2, PrecisionTrace = 7 }, "RECORD_BYTES")
		A.deepEq(MF.MAX_RECORDS, { HoldZone = 1024, TimingStrike = 512, PrecisionTrace = 2048 }, "MAX_RECORDS")
		local caps: { [string]: number } = {}
		local largest = 0
		local codes: { [number]: boolean } = {}
		for _, row in MF.enabled do
			local code, size, n = MF.FAMILY_CODE[row.id], MF.RECORD_BYTES[row.id], MF.MAX_RECORDS[row.id]
			A.truthy(code ~= nil and size ~= nil and n ~= nil, row.id .. " has wire constants")
			A.falsy(codes[code], row.id .. ": family codes are distinct")
			codes[code] = true
			A.within(code, 1, 255, row.id .. ": the code fits header byte 1 (u8)")
			A.truthy(n <= 65535, row.id .. ": the count fits the header's u16")
			caps[row.id] = MF.TIMELINE_HEADER_BYTES + n * size
			largest = math.max(largest, caps[row.id])
		end
		A.deepEq(caps, { HoldZone = 3084, TimingStrike = 1036, PrecisionTrace = 14348 }, "family caps (§6.7)")
		A.eq(MF.MAX_TIMELINE_BYTES, largest, "MAX_TIMELINE_BYTES = header + largest cap")
		A.eq(MF.MAX_TIMELINE_BYTES, 14348)
		-- every honest timeline fits: Trace records one sample per 20 ms over the longest step (1,551 records)
		local longest = param("PrecisionTrace", "leadInMs").base + PT_TRAVEL_MAX_MS + param("PrecisionTrace", "tailMs").base
		A.eq(longest // 20 + 1, 1551, "Trace honest maximum")
		local trace: DT.FamilyId = "PrecisionTrace"
		A.truthy(1551 <= MF.MAX_RECORDS[trace], "the Trace cap is above every honest maximum")
	end)

	t.it("T-DEF-06 finite, frozen, JSON-safe data", function()
		A.truthy(table.isfrozen(MF), "module frozen")
		local data = {}
		for k, v in MF do
			if type(v) ~= "function" and k ~= "byId" and k ~= "enabled" then
				data[k] = v
			end
		end
		local seen: { [any]: string } = {}
		for _, k in Dump.sortedKeys(data) do
			walkData(data[k], "MinigameFamilies." .. k, seen)
		end
	end)
end)
