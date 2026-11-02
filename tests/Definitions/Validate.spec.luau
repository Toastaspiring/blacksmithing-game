--!strict
-- tests/Definitions/Validate.spec.luau — Definitions/Validate (SPEC §2.3, §14.5; T-DEF-00): validateAll() == {} on
-- the shipped Definitions, one planted error per base check D1–D7 (each reports only its own check), the injected
-- higher-layer checks, and the generic properties of check().

local A = require("../lib/Assert")
local Dump = require("../lib/Dump")
local Prop = require("../lib/Prop")
local Test = require("../lib/Test")
local TestRng = require("../lib/TestRng")
local Tol = require("../lib/Tol")
local H = require("./DefsHelpers")
local Balance = require("../../src/shared/Definitions/Balance")
local CraftPlans = require("../../src/shared/Definitions/CraftPlans")
local Validate = require("../../src/shared/Definitions/Validate")

type Plant = { check: string, what: string, edit: (b: any) -> () }

local function find(list: { any }, id: string): any
	for _, r in list do
		if r.id == id then
			return r
		end
	end
	error("no row " .. id)
end

local function withoutModule(list: { any }, name: string): { any }
	local out = {}
	for _, e in list do
		if e.module ~= name then
			table.insert(out, e)
		end
	end
	return out
end

local PLANTS: { Plant } = {
	-- D1
	{ check = "D1", what = "a duplicate material id", edit = function(b)
		find(b.materials, "Steel").id = "Iron"
	end },
	{ check = "D1", what = "a duplicate step order", edit = function(b)
		find(b.steps, "Hammering").order = 10
	end },
	{ check = "D1", what = "rarity orders that are not 1..n", edit = function(b)
		find(b.rarities, "Common").order = 0
	end },
	{ check = "D1", what = "a tier id that is not PascalCase", edit = function(b)
		find(b.tiers, "Hard").id = "hard"
	end },
	{ check = "D1", what = "a non-boolean enabled", edit = function(b)
		find(b.stats, "Damage").enabled = 1
	end },
	{ check = "D1", what = "a catalog that is not an array", edit = function(b)
		b.stats = { Damage = b.stats[1] }
	end },
	-- D2
	{ check = "D2", what = "a step naming an unknown family", edit = function(b)
		find(b.steps, "Smelting").family = "Bellows"
	end },
	{ check = "D2", what = "an enabled step on a disabled family", edit = function(b)
		find(b.steps, "Smelting").family = "RhythmSequence"
	end },
	{ check = "D2", what = "an enabled tier capped at a disabled rarity", edit = function(b)
		find(b.tiers, "Hard").rarityCap = "Legendary"
	end },
	{ check = "D2", what = "a tier capped at an unknown rarity", edit = function(b)
		find(b.tiers, "Expert").rarityCap = "Shiny"
	end },
	{ check = "D2", what = "a material allowed in an unknown slot", edit = function(b)
		find(b.materials, "Iron").allowedSlots = { "Hilt" }
	end },
	{ check = "D2", what = "an empty allowedSlots list", edit = function(b)
		find(b.materials, "Bronze").allowedSlots = {}
	end },
	-- D3
	{ check = "D3", what = "a gap between tiers", edit = function(b)
		find(b.tiers, "Hard").dMin = 0.25
	end },
	{ check = "D3", what = "a last tier that stops short of 1", edit = function(b)
		find(b.tiers, "Hell").dMax = 0.95
	end },
	{ check = "D3", what = "a first tier that does not start at 0", edit = function(b)
		find(b.tiers, "Normal").dMin = 0.01
	end },
	{ check = "D3", what = "an enabled rarity after a disabled one", edit = function(b)
		find(b.rarities, "Mythic").enabled = true
	end },
	{ check = "D3", what = "a disabled first tier", edit = function(b)
		find(b.tiers, "Normal").enabled = false
		find(b.tiers, "Hard").enabled = false
	end },
	-- D4
	{ check = "D4", what = "a fractional hardness", edit = function(b)
		find(b.materials, "Iron").hardness = 45.5
	end },
	{ check = "D4", what = "a toughness above 100", edit = function(b)
		find(b.materials, "Wood").toughness = 101
	end },
	{ check = "D4", what = "an unknown Roblox material", edit = function(b)
		find(b.materials, "Steel").robloxMaterial = "Plastic"
	end },
	{ check = "D4", what = "a zero density", edit = function(b)
		find(b.materials, "Iron").density = 0
	end },
	{ check = "D4", what = "a reflectance above 1", edit = function(b)
		find(b.materials, "Mithril").reflectance = 1.5
	end },
	{ check = "D4", what = "an unknown material class", edit = function(b)
		find(b.materials, "Obsidian").class = "Crystal"
	end },
	{ check = "D4", what = "a tier colour out of 0–255", edit = function(b)
		find(b.tiers, "Normal").color = { 256, 0, 0 }
	end },
	{ check = "D4", what = "a rarity colour with two channels", edit = function(b)
		find(b.rarities, "Epic").color = { 1, 2 }
	end },
	-- D5
	{ check = "D5", what = "a slot max above MAX_PARTS", edit = function(b)
		find(b.equipmentTypes[1].slots, "Guard").max = 30
	end },
	{ check = "D5", what = "a grip slot that is not a slot of the type", edit = function(b)
		b.equipmentTypes[1].geometry.gripSlot = "Hilt"
	end },
	{ check = "D5", what = "a required flag that disagrees with min", edit = function(b)
		find(b.equipmentTypes[1].slots, "Blade").required = false
	end },
	{ check = "D5", what = "a hitbox beyond POS_ABS_MAX", edit = function(b)
		b.equipmentTypes[1].geometry.hitboxMax[2] = 20
	end },
	{ check = "D5", what = "a duplicate slot", edit = function(b)
		find(b.equipmentTypes[1].slots, "Pommel").id = "Guard"
	end },
	{ check = "D5", what = "partsMax above MAX_PARTS", edit = function(b)
		b.equipmentTypes[1].geometry.partsMax = 25
	end },
	{ check = "D5", what = "no required slot", edit = function(b)
		for _, s in b.equipmentTypes[1].slots do
			s.required = false
			s.min = 0
		end
	end },
	{ check = "D5", what = "a thickness axis that is not a unit vector", edit = function(b)
		b.equipmentTypes[1].geometry.thicknessAxis = { 0, 0, 2 }
	end },
	-- D6
	{ check = "D6", what = "step weights that sum to 1.1", edit = function(b)
		find(b.steps, "Hammering").factorWeights[1].w = 0.5
	end },
	{ check = "D6", what = "step weights out of FactorId order", edit = function(b)
		local fw = find(b.steps, "Sharpening").factorWeights
		fw[1], fw[3] = fw[3], fw[1]
	end },
	{ check = "D6", what = "an enabled step without weights", edit = function(b)
		find(b.steps, "Smelting").factorWeights = {}
	end },
	{ check = "D6", what = "an unknown factor", edit = function(b)
		find(b.steps, "Smelting").factorWeights[1].factor = "Weight"
	end },
	{ check = "D6", what = "rarity thresholds that fall", edit = function(b)
		find(b.rarities, "Rare").minQuality = 0.5
	end },
	{ check = "D6", what = "a first rarity above 0", edit = function(b)
		find(b.rarities, "Common").minQuality = 0.1
	end },
	{ check = "D6", what = "a material difficultyTerm above 1", edit = function(b)
		find(b.materials, "Iron").difficultyTerm = 2
	end },
	{ check = "D6", what = "a missing qualityTier", edit = function(b)
		find(b.materials, "Steel").qualityTier = nil
	end },
	{ check = "D6", what = "a tier multiplier that falls", edit = function(b)
		find(b.tiers, "Hard").qualityMultiplier = 0.9
	end },
	{ check = "D6", what = "a rarity cap that falls", edit = function(b)
		find(b.tiers, "Master").rarityCap = "Rare"
	end },
	{ check = "D6", what = "a fail factor above 1", edit = function(b)
		find(b.tiers, "Normal").failScoreFactor = 1.2
	end },
	{ check = "D6", what = "an unknown fail outcome", edit = function(b)
		find(b.tiers, "Hard").failOutcome = "Explode"
	end },
	{ check = "D6", what = "reference ranges out of FactorId order", edit = function(b)
		b.equipmentTypes[1].geometry.refs[2].factor = "Volume"
	end },
	{ check = "D6", what = "a reference range with lo ≥ hi", edit = function(b)
		b.equipmentTypes[1].geometry.refs[5].lo = 9
	end },
	{ check = "D6", what = "a stat without decimals", edit = function(b)
		find(b.stats, "Reach").decimals = 0.5
	end },
	{ check = "D6", what = "an enabled family without its pass line", edit = function(b)
		local params = find(b.families, "HoldZone").params
		for i = #params, 1, -1 do
			if params[i].name == "passThreshold" then
				table.remove(params, i)
			end
		end
	end },
	{ check = "D6", what = "a pass line above 1", edit = function(b)
		local params = find(b.families, "RhythmSequence").params -- a disabled row: its parameters are checked too
		params[1].base = 1.5
	end },
	{ check = "D6", what = "a tier column one factor short", edit = function(b)
		table.remove(find(b.families, "TimingStrike").params[1].tier)
	end },
	{ check = "D6", what = "design terms without their clamp", edit = function(b)
		find(b.families, "PrecisionTrace").params[1].designClamp = nil
	end },
	-- D7
	{ check = "D7", what = "a zero BALANCE_VERSION", edit = function(b)
		b.versions.BALANCE_VERSION = 0
	end },
	{ check = "D7", what = "a missing DATA_VERSION", edit = function(b)
		b.versions.DATA_VERSION = nil
	end },
	{ check = "D7", what = "a module the Manifest forgets", edit = function(b)
		b.manifest.excluded = withoutModule(b.manifest.excluded, "Audio")
	end },
	{ check = "D7", what = "a Definitions module the Manifest does not know", edit = function(b)
		table.insert(b.modules, "Ghost")
	end },
	{ check = "D7", what = "a Manifest entry naming no module", edit = function(b)
		b.manifest.hashed[1].module = "Mats"
	end },
	{ check = "D7", what = "a module hashed and excluded as a whole", edit = function(b)
		table.insert(b.manifest.excluded, { module = "Materials", why = "planted" })
	end },
}

local function planted(edit: (b: any) -> ()): { string }
	local b = H.deepCopy(Validate.current())
	edit(b)
	return Validate.check(b)
end

-- A stand-in for S4's Plan.validateDefs (Crafting, M5): the tests inject higher-layer checks the same way.
local function planWeightsCheck(): { string }
	local out: { string } = {}
	for _, plan in CraftPlans.ordered do
		local sum = 0
		for _, row in plan.steps do
			if row.enabled then
				sum += row.weight
			end
		end
		if math.abs(sum - 1) > Balance.Quality.WEIGHT_SUM_TOL then
			table.insert(out, "P1 CraftPlans: " .. plan.type .. " weights sum to " .. tostring(sum))
		end
	end
	return out
end

return Test.suite("Definitions/Validate", function(t)
	t.it("T-DEF-00 validateAll() == {} on the shipped Definitions", function()
		A.deepEq(Validate.validateAll(), {})
		A.deepEq(Validate.check(Validate.current()), {})
	end)

	t.it("T-DEF-00 one planted error per check: each reports its own check, and only it", function()
		local covered: { [string]: boolean } = {}
		for _, plant in PLANTS do
			local problems = planted(plant.edit)
			A.truthy(#problems > 0, plant.check .. " " .. plant.what .. ": nothing reported")
			for _, p in problems do
				A.eq(string.sub(p, 1, #plant.check + 1), plant.check .. " ", plant.check .. " " .. plant.what .. " reported: " .. p)
			end
			covered[plant.check] = true
		end
		for _, check in { "D1", "D2", "D3", "D4", "D5", "D6", "D7" } do
			A.truthy(covered[check], check .. " has a planted case")
		end
	end)

	t.it("problems name the check, the module and the row", function()
		local problems = planted(function(b)
			find(b.materials, "Steel").id = "Iron"
		end)
		A.deepEq(problems, { "D1 Materials: duplicate id Iron" })
		local weights = planted(function(b)
			find(b.steps, "Hammering").factorWeights[1].w = 0.5
		end)
		A.eq(#weights, 1)
		A.contains(weights[1], "D6 Steps: Hammering: weights sum to 1.1")
	end)

	t.it("injected higher-layer checks: problems appended in order, a raising check reported, never rethrown", function()
		A.deepEq(Validate.validateAll({}), {})
		A.deepEq(Validate.validateAll({ planWeightsCheck }), {}, "S4's plan check stand-in passes")
		A.deepEq(Validate.validateAll({
			function(): { string }
				return { "P1 first" }
			end,
			function(): { string }
				return { "P2 second", "P2 third" }
			end,
		}), { "P1 first", "P2 second", "P2 third" })
		local raised = Validate.validateAll({
			function(): { string }
				error("boom")
			end,
		})
		A.eq(#raised, 1)
		A.contains(raised[1], "extra check 1 raised")
		A.contains(raised[1], "boom")
		local wrong = Validate.validateAll({ (function()
			return 5
		end :: any) })
		A.eq(#wrong, 1)
		A.contains(wrong[1], "extra check 1 returned a number")
	end)

	t.it("constants: KNOWN_PART_MATERIALS (§16.3), FactorId order, the §1.2 module list", function()
		A.deepEq(Validate.KNOWN_PART_MATERIALS, { "Metal", "Foil", "Glass", "Wood", "Leather" })
		A.deepEq(Validate.FACTOR_ORDER, {
			"PartCount", "Thinness", "Asymmetry", "SurfaceComplexity", "EdgeLength", "Joints", "MaterialMix", "Volume",
		})
		A.deepEq(Validate.MODULES, {
			"Types", "Catalog", "Versions", "Limits", "Materials", "EquipmentTypes", "Steps", "Tiers", "Rarities",
			"Stats", "Balance", "Validate", "Manifest", "MinigameFamilies", "CraftPlans", "Network", "World",
			"Presentation", "Audio",
		})
		A.truthy(table.isfrozen(Validate) and table.isfrozen(Validate.MODULES))
	end)

	t.slow("P-TOTAL check never throws and never hits an internal error on garbage bundles", function()
		local rng = TestRng.new(0x7A11DA7E)
		local fields = { "materials", "equipmentTypes", "steps", "tiers", "rarities", "stats", "families", "versions",
			"limits", "weightSumTol", "manifest", "modules" }
		local function assertClean(b: any, what: string)
			local ok, problems = pcall(Validate.check, b)
			A.truthy(ok, what .. ": check threw")
			A.eq(type(problems), "table", what)
			for _, p in problems do
				A.eq(type(p), "string", what)
				A.falsy(string.find(p, "internal error", 1, true), what .. ": " .. p)
			end
		end
		for i = 1, Tol.FUZZ_N_GARBAGE do
			assertClean(H.garbage(rng), "whole bundle " .. i)
			local b: any = H.deepCopy(Validate.current())
			b[fields[rng:int(1, #fields)]] = H.garbage(rng)
			assertClean(b, "one field " .. i)
			local c: any = H.deepCopy(Validate.current())
			local list = c[fields[rng:int(1, 7)]]
			if type(list) == "table" and #list > 0 then
				local row = list[rng:int(1, #list)]
				local keys = Dump.sortedKeys(row)
				row[keys[rng:int(1, #keys)]] = H.garbage(rng)
			end
			assertClean(c, "one row field " .. i)
		end
	end)

	t.it("P-NOMUT check leaves its bundle unchanged", function()
		local b: any = H.deepCopy(Validate.current())
		find(b.tiers, "Hard").dMin = 0.25
		local before = H.deepCopy(b)
		Validate.check(b)
		A.deepEq(b, before)
	end)

	t.it("P-DET and P-ORDER bundles rebuilt in shuffled key order give the same problems", function()
		local plantsByIndex = PLANTS
		Prop.check(Tol.PROP_N, function(rng): { index: number, seed: number }
			return { index = rng:int(0, #plantsByIndex), seed = rng:u32() }
		end, function(c: { index: number, seed: number })
			local b: any = H.deepCopy(Validate.current())
			if c.index > 0 then
				plantsByIndex[c.index].edit(b)
			end
			local expected = Validate.check(b)
			A.deepEq(Validate.check(b), expected, "P-DET")
			A.deepEq(Validate.check(H.reshuffled(b, TestRng.new(c.seed))), expected, "P-ORDER")
		end)
	end)
end)
