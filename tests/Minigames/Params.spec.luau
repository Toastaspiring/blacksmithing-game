--!strict
-- Minigames/Params (SPEC §6.5, §12.2, E-S3.3; T-MG-07): p_final = round_q(clamp(base · m_material · m_tier · m_design,
-- min, max)) on hand-worked rows and on planted rows that make each clamp and the quantum bite; E-S3.3's resolved
-- values; explain's columns and final = resolve; missing materials, columns and factors; x clamped to [0, 1]; the
-- trace band's 12 px floor; P-ORDER; and the S3 prototype's resolve bit for bit (M4's D1: the prototype made E-S3's
-- values and distributions). TimingStrike's full-points core ≥ 9 ms needs TimingStrike's TS_PERFECT_CORE_MIN_MS, so it
-- is TimingStrike.spec's (slice 3).

local Test = require("../lib/Test")
local A = require("../lib/Assert")
local Dump = require("../lib/Dump")
local Prop = require("../lib/Prop")
local TestRng = require("../lib/TestRng")
local Tol = require("../lib/Tol")
local DT = require("../../src/shared/Definitions/Types")
local MF = require("../../src/shared/Definitions/MinigameFamilies")
local Tiers = require("../../src/shared/Definitions/Tiers")
local Validate = require("../../src/shared/Definitions/Validate")
local Params = require("../../src/shared/Minigames/Params")
local Types = require("../../src/shared/Minigames/Types")

-- Through a cast, so luau-lsp stays out of the prototype's loose types: it is reference data, not game code.
local Proto: any = (require :: any)("../../docs/spec/prototypes/S3/v2/Params")

type FactorValue = Types.FactorValue
type FamilyDef = MF.MinigameFamilyDef

local MVP: { DT.FamilyId } = { "HoldZone", "TimingStrike", "PrecisionTrace" }
local MATERIALS: { DT.MaterialId } = { "Iron", "Steel", "Bronze" } -- Bronze has no column anywhere: × 1
local TIERS: { DT.TierId } = { "Normal", "Hard", "Expert", "Master", "Hell" }
local XS = { 0, 0.1, 0.3, 0.55, 1 }

-- the factors with one x each, in FactorId order
local function factorsOf(xs: { number }): { FactorValue }
	local out: { FactorValue } = {}
	for i, f in ipairs(Validate.FACTOR_ORDER) do
		out[i] = { factor = f :: DT.FactorId, raw = xs[i], x = xs[i] }
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

-- a planted family row of one parameter
local function rowOf(p: any): FamilyDef
	return { id = "HoldZone", name = "Planted", order = 1, enabled = true, params = { p }, checks = {}, flagLevels = {} }
end

-- a copy of a family row with its params in another order, each material map rebuilt in another insertion order
local function reordered(def: FamilyDef, rng: TestRng.TestRng): FamilyDef
	local params: { any } = {}
	for _, p in ipairs(def.params) do
		local copy: any = table.clone(p)
		if p.material then
			local keys = Dump.sortedKeys(p.material :: any)
			local map: { [string]: number } = {}
			for k = #keys, 1, -1 do
				map[keys[k]] = (p.material :: any)[keys[k]]
			end
			map.Wood = 1 -- a column for another material, which no case reads
			copy.material = map
		end
		table.insert(params, rng:int(1, #params + 1), copy)
	end
	local copy: any = table.clone(def)
	copy.params = params
	return copy
end

return Test.suite("Minigames/Params", function(t)
	t.it("T-MG-07 §6.5's example: windowMs for Iron at Hard, Thinness 0.30 = 110 · 1 · 0.94 · 0.955 = 98.7 → 99", function()
		local factors = factorsOf({ 0, 0.30, 0, 0, 0, 0, 0, 0 })
		local e = Params.explain("TimingStrike", "Iron", "Hard", factors).windowMs
		A.eq(e.base, 110)
		A.eq(e.mMaterial, 1)
		A.eq(e.mTier, 0.94)
		A.near(e.mDesign, 0.955, 1e-12, "clamp(1 − 0.15 · 0.30, 0.85, 1)")
		A.near(e.base * e.mMaterial * e.mTier * e.mDesign, 98.747, 1e-9, "the product")
		A.eq(e.final, 99, "rounded to its 1 ms quantum")
		A.eq(Params.resolve("TimingStrike", "Iron", "Hard", factors).windowMs, 99)
	end)

	t.it("T-MG-07 each clamp and the quantum bite, in §6.5's order: min, then max, then the quantum", function()
		local none: { FactorValue } = {}
		local function one(p: any, x: number?): number
			return Params.resolveDef(rowOf(p), "Iron", "Normal", factorsOf(table.create(8, x or 0))).p
		end
		A.eq(one({ name = "p", base = 7, quantum = 10 }), 10, "the quantum rounds")
		A.eq(one({ name = "p", base = 14, quantum = 10 }), 10, "down to its nearest multiple")
		A.eq(one({ name = "p", base = 15, quantum = 10 }), 20, "halves away from zero")
		A.eq(one({ name = "p", base = 0.5, min = 1 }), 1, "min bites")
		A.eq(one({ name = "p", base = 5, max = 3 }), 3, "max bites")
		A.eq(one({ name = "p", base = 16, max = 14, quantum = 10 }), 10, "clamp first: 14 → 10, not 20 → 14")
		A.eq(one({ name = "p", base = 4, min = 6, quantum = 5 }), 5, "the quantum comes last, even below min")
		A.eq(one({ name = "p", base = 2, min = 3, max = 1 }), 1, "max after min")
		-- the design sum is clamped to designClamp
		local design = { name = "p", base = 10, design = { { factor = "Volume", k = 0.5 } }, designClamp = { 1, 1.2 } }
		A.eq(one(design, 1), 12, "1 + 0.5 → 1.2")
		A.eq(one(design, 0.2), 11, "1 + 0.1, inside the clamp")
		local shrink = { name = "p", base = 10, design = { { factor = "Volume", k = -0.5 } }, designClamp = { 0.9, 1 } }
		A.eq(one(shrink, 1), 9, "1 − 0.5 → 0.9")
		-- several terms sum from 1 in their order
		local two = { name = "p", base = 1, design = { { factor = "Thinness", k = 0.25 }, { factor = "Volume", k = 0.5 } },
			designClamp = { 1, 2 } }
		A.eq(Params.resolveDef(rowOf(two), "Iron", "Normal", factorsOf({ 0, 1, 0, 0, 0, 0, 0, 0.5 })).p, 1.5)
		-- x outside [0, 1] reads as its clamp (under a design clamp too wide to hide it: 1 + 0.5·1.7 would give 18.5,
		-- 1 − 0.5·0.4 would give 8); a missing factor reads 0
		local wide = { name = "p", base = 10, design = { { factor = "Volume", k = 0.5 } }, designClamp = { 0, 3 } }
		A.eq(one(wide, 1.7), 15, "x above 1 reads 1")
		A.eq(one(wide, -0.4), 10, "x below 0 reads 0")
		A.eq(Params.resolveDef(rowOf(design), "Iron", "Normal", none).p, 10, "no factors: x = 0")
		-- the first FactorValue naming a factor wins
		local dup: { FactorValue } = { { factor = "Volume", raw = 0.2, x = 0.2 }, { factor = "Volume", raw = 1, x = 1 } }
		A.eq(Params.resolveDef(rowOf(design), "Iron", "Normal", dup).p, 11, "the first Volume")
	end)

	t.it("T-MG-07 a material without a column, and a parameter without a column, multiply by 1", function()
		for _, family: DT.FamilyId in MVP do
			for _, tier: DT.TierId in { "Normal", "Hard" } :: { DT.TierId } do
				local factors = Params.refFactors(0.3)
				local bronze = Params.explain(family, "Bronze", tier, factors)
				local iron = Params.resolve(family, "Iron", tier, factors)
				for name, e in bronze do
					A.eq(e.mMaterial, 1, family .. "." .. name .. ": Bronze has no column")
					A.eq(e.final, iron[name], family .. "." .. name .. ": Bronze plays as Iron")
				end
			end
		end
		local e = Params.explain("HoldZone", "Steel", "Hard", Params.refFactors(1)).fullHeat
		A.truthy(e.mMaterial == 1 and e.mTier == 1 and e.mDesign == 1 and e.final == e.base, "fullHeat has no columns")
	end)

	t.it("T-MG-07 E-S3.3's resolved values (Iron/Steel × Normal/Hard, every factor at x = 0 and x = 1)", function()
		local cells = { { "Iron", "Normal" }, { "Iron", "Hard" }, { "Steel", "Normal" }, { "Steel", "Hard" } }
		-- {family, param, decimals (0: an integer, exact), {Iron/Normal, Iron/Hard, Steel/Normal, Steel/Hard} × {x = 0, 1}}
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
					local v = Params.resolve(e[1], cell[1] :: DT.MaterialId, cell[2] :: DT.TierId, Params.refFactors(x))[e[2]]
					local what = string.format("%s.%s %s/%s x = %d", e[1], e[2], cell[1], cell[2], x)
					if e[3] == 0 then
						A.eq(v, e[4][c][xi], what)
					else
						printed(v, e[4][c][xi], e[3], what)
					end
				end
			end
		end
	end)

	t.it("T-MG-07 explain: base and the three modifiers of every parameter, final = resolve", function()
		for _, family: DT.FamilyId in MVP do
			local def = MF.get(family) :: FamilyDef
			for _, material: DT.MaterialId in MATERIALS do
				for _, tier: DT.TierId in TIERS do
					for _, x in XS do
						local factors = Params.refFactors(x)
						local resolved = Params.resolve(family, material, tier, factors)
						local explained = Params.explain(family, material, tier, factors)
						local what = string.format("%s %s/%s x = %s", family, material, tier, tostring(x))
						local names = 0
						for _, p in ipairs(def.params) do
							names += 1
							local e = explained[p.name]
							A.eq(e.final, resolved[p.name], what .. " " .. p.name .. ": final = resolve")
							A.eq(e.base, p.base, what .. " " .. p.name .. ".base")
							local column = if p.material then (p.material :: any)[material] else nil
							A.eq(e.mMaterial, column or 1, what .. " " .. p.name .. ".mMaterial")
							local tierColumn = p.tier
							local order = (Tiers.get(tier) :: DT.TierDef).order
							A.eq(e.mTier, if tierColumn then tierColumn[order] else 1, what .. " " .. p.name .. ".mTier")
							A.within(e.mDesign, 0.5, 1.5, what .. " " .. p.name .. ".mDesign")
						end
						local keys = 0
						for _ in resolved do
							keys += 1
						end
						A.eq(keys, names, what .. ": one value per parameter")
					end
				end
			end
		end
	end)

	t.it("T-MG-07 the trace band stays ≥ 0.0156 u (12 px at 720p) on every MVP config; the minimum is Steel/Hard x = 1", function()
		local narrowest, at = math.huge, ""
		for _, material: DT.MaterialId in { "Iron", "Steel" } :: { DT.MaterialId } do
			for _, tier: DT.TierId in { "Normal", "Hard" } :: { DT.TierId } do
				for _, x in XS do
					local w = Params.resolve("PrecisionTrace", material, tier, Params.refFactors(x)).halfWidth
					if w < narrowest then
						narrowest, at = w, string.format("%s/%s x = %s", material, tier, tostring(x))
					end
				end
			end
		end
		A.truthy(narrowest >= 0.0156, "trace band ≥ 12 px at 720p (§17.2 S3)")
		printed(narrowest, 0.0344, 4, "the MVP minimum")
		A.eq(at, "Steel/Hard x = 1", "where the minimum is")
	end)

	t.it("T-MG-07 resolve and explain refuse a disabled or unknown family and an unknown tier", function()
		local factors = Params.refFactors(0)
		for _, family in { "RhythmSequence", "ReleaseTiming", "FitPuzzle", "Smelting", "NoSuchFamily" } do
			A.throws(function()
				Params.resolve(family :: any, "Iron", "Normal", factors)
			end, "not an enabled minigame family", family)
			A.throws(function()
				Params.explain(family :: any, "Iron", "Normal", factors)
			end, "not an enabled minigame family", family)
		end
		A.throws(function()
			Params.resolve("HoldZone", "Iron", "Legendary" :: any, factors)
		end, "no tier Legendary")
	end)

	t.it("T-MG-07 refFactors: the 8 factors in FactorId order (Definitions/Validate's list), raw = x = x", function()
		for _, x in { 0, 0.1, 0.3, 1 } do
			local fs = Params.refFactors(x)
			A.eq(#fs, #Validate.FACTOR_ORDER, "8 factors")
			for i, fv in ipairs(fs) do
				A.eq(fv.factor, Validate.FACTOR_ORDER[i], "factor " .. i)
				A.eq(fv.raw, x)
				A.eq(fv.x, x)
			end
		end
		A.truthy(Params.refFactors(0) ~= Params.refFactors(0), "a fresh array per call")
	end)

	t.it("T-MG-07 P-ORDER: params shuffled, factor arrays shuffled, material maps rebuilt → bit-identical", function()
		Prop.check(Tol.PROP_N, function(rng: TestRng.TestRng): { any }
			local xs: { number } = {}
			for i = 1, 8 do
				xs[i] = rng:float()
			end
			return { family = rng:pick(MVP), material = rng:pick(MATERIALS), tier = rng:pick(TIERS), xs = xs,
				salt = rng:u32() }
		end, function(c: any)
			local rng = TestRng.new(c.salt)
			local factors = factorsOf(c.xs)
			local shuffled: { FactorValue } = {}
			for _, fv in ipairs(factors) do
				table.insert(shuffled, rng:int(1, #shuffled + 1), fv)
			end
			local base = Params.resolve(c.family, c.material, c.tier, factors)
			A.deepEq(Params.resolve(c.family, c.material, c.tier, shuffled), base, "factor array shuffled")
			local def = MF.get(c.family) :: FamilyDef
			A.deepEq(Params.resolveDef(def, c.material, c.tier, factors), base, "resolveDef = resolve")
			A.deepEq(Params.resolveDef(reordered(def, rng), c.material, c.tier, shuffled), base, "params and maps reordered")
		end)
	end)

	t.it("Params = the S3 prototype's resolve, bit for bit, on every family, material, tier and x (D1)", function()
		local rng = TestRng.new(0x5EED0004)
		local cases: { { number } } = {}
		for _, x in XS do
			table.insert(cases, table.create(8, x))
		end
		for _ = 1, 20 do
			local xs: { number } = {}
			for i = 1, 8 do
				xs[i] = rng:float()
			end
			table.insert(cases, xs)
		end
		-- and x beyond [0, 1], which both clamp
		for _ = 1, 5 do
			local xs: { number } = {}
			for i = 1, 8 do
				xs[i] = rng:range(-0.5, 1.5)
			end
			table.insert(cases, xs)
		end
		for _, family: DT.FamilyId in MVP do
			for _, material: DT.MaterialId in MATERIALS do
				for _, tier: DT.TierId in TIERS do
					for _, xs in cases do
						local factors = factorsOf(xs)
						local mine = Params.resolve(family, material, tier, factors)
						local theirs = Proto.resolve(family, material, tier, factors)
						local diff = Dump.firstDifference(mine, theirs)
						if diff then
							A.fail(string.format("%s %s/%s x = {%s}: %s", family, material, tier, table.concat(xs, ", "), diff))
						end
					end
				end
			end
		end
	end)
end)
