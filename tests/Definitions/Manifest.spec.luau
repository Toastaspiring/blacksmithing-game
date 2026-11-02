--!strict
-- tests/Definitions/Manifest.spec.luau — Definitions/Manifest (SPEC §2.8, §14.9): the hashed list and its fields, the
-- exclusions, and Manifest.collect's selection (what T-BAL-01 hashes). The guard itself is BalanceGuard.spec.

local A = require("../lib/Assert")
local Dump = require("../lib/Dump")
local Prop = require("../lib/Prop")
local Test = require("../lib/Test")
local Tol = require("../lib/Tol")
local H = require("./DefsHelpers")
local Balance = require("../../src/shared/Definitions/Balance")
local CraftPlans = require("../../src/shared/Definitions/CraftPlans")
local EquipmentTypes = require("../../src/shared/Definitions/EquipmentTypes")
local Limits = require("../../src/shared/Definitions/Limits")
local Manifest = require("../../src/shared/Definitions/Manifest")
local Materials = require("../../src/shared/Definitions/Materials")
local MinigameFamilies = require("../../src/shared/Definitions/MinigameFamilies")
local Rarities = require("../../src/shared/Definitions/Rarities")
local Stats = require("../../src/shared/Definitions/Stats")
local Steps = require("../../src/shared/Definitions/Steps")
local Tiers = require("../../src/shared/Definitions/Tiers")

local MODULE_VALUES: { [string]: any } = {
	Materials = Materials,
	EquipmentTypes = EquipmentTypes,
	Steps = Steps,
	Tiers = Tiers,
	Rarities = Rarities,
	Stats = Stats,
	CraftPlans = CraftPlans,
	MinigameFamilies = MinigameFamilies,
	Balance = Balance,
	Limits = Limits,
}

local function text(values: { [string]: any }?): string
	return Dump.canonical(Manifest.collect(values))
end

local function dataOf(name: string, values: { [string]: any }?): any
	for _, c in Manifest.collect(values) do
		if c.module == name then
			return c.data
		end
	end
	error("not collected: " .. name)
end

-- module name, an edit of a hashed field, an edit of a field outside the hash (display text or ignored)
type Edit = { module: string, hashed: (m: any) -> (), unhashed: ((m: any) -> ())? }
local EDITS: { Edit } = {
	{ module = "Materials", hashed = function(m)
		m.ordered[1].density = 7.88
	end, unhashed = function(m)
		m.ordered[1].name = "Wrought iron"
		m.ordered[1].blurb = "x"
		m.ordered[1].color = { 1, 2, 3 }
		m.ordered[1].robloxMaterial = "Foil"
		m.ordered[1].reflectance = 0.5
	end },
	{ module = "Materials", hashed = function(m)
		m.ordered[2].allowedSlots = { "Blade" }
	end },
	{ module = "EquipmentTypes", hashed = function(m)
		m.ordered[1].slots[2].max = 7
	end, unhashed = function(m)
		m.ordered[1].name = "Blade weapon"
		m.ordered[1].slots[1].name = "Edge"
	end },
	{ module = "EquipmentTypes", hashed = function(m)
		m.ordered[1].geometry.refs[8].hi = 0.81
	end },
	{ module = "Steps", hashed = function(m)
		m.ordered[3].factorWeights[1].w = 0.41
	end, unhashed = function(m)
		m.ordered[1].order = 11
		m.ordered[1].name = "Smelt"
	end },
	{ module = "Steps", hashed = function(m)
		m.ordered[1].family = "TimingStrike"
	end },
	{ module = "Tiers", hashed = function(m)
		m.ordered[2].dMin = 0.21
	end, unhashed = function(m)
		m.ordered[2].risk = "Spicy"
		m.ordered[2].color = { 0, 0, 0 }
		m.ordered[2].name = "Harder"
	end },
	{ module = "Tiers", hashed = function(m)
		m.ordered[1].failScoreFactor = 0.7
	end },
	{ module = "Rarities", hashed = function(m)
		m.ordered[3].minQuality = 0.85
	end, unhashed = function(m)
		m.ordered[3].color = { 9, 9, 9 }
	end },
	{ module = "Stats", hashed = function(m)
		m.ordered[7].enabled = true
	end, unhashed = function(m)
		m.ordered[6].unit = "st"
		m.ordered[6].decimals = 2
		m.ordered[6].order = 60
	end },
	{ module = "CraftPlans", hashed = function(m)
		m.ordered[1].steps[1].weight = 0.26
	end },
	{ module = "CraftPlans", hashed = function(m)
		m.ordered[1].steps[3].worksOn = "All"
	end },
	{ module = "MinigameFamilies", hashed = function(m)
		m.ordered[1].params[1].base = 0.091
	end, unhashed = function(m)
		m.ordered[1].name = "Bellows"
	end },
	{ module = "MinigameFamilies", hashed = function(m)
		m.MAX_TIMELINE_BYTES = 14349
	end },
	{ module = "Balance", hashed = function(m)
		m.Geometry.EPS_GEOM = 2e-7
	end, unhashed = function(m)
		m.Display.MASS_UNIT_LABEL = "lb"
	end },
	{ module = "Balance", hashed = function(m)
		m.Quality.DESIGN_GAMMA = 0.16
	end },
	{ module = "Limits", hashed = function(m)
		m.MIN_DIM = 0.03
	end, unhashed = function(m)
		m.POS_ABS_MAX = 20
		m.MAX_ITEMS = 151
	end },
}

return Test.suite("Definitions/Manifest", function(t)
	t.it("hashed = §2.8's table: modules, order and fields", function()
		local summary = {}
		for _, e in Manifest.hashed do
			table.insert(summary, { module = e.module, select = e.select, fields = e.fields, ignore = e.ignore, exclude = e.exclude })
		end
		local slotsButName: any = { field = "slots", fields = { "id", "required", "min", "max", "rank" } }
		local expected: { any } = {
			{ module = "Materials", select = "Rows", fields = { "id", "order", "enabled", "class", "density", "hardness",
				"toughness", "allowedSlots", "difficultyTerm", "qualityTier" } },
			{ module = "EquipmentTypes", select = "Rows", fields = { "id", "order", "enabled", "kind", slotsButName,
				"geometry" } },
			{ module = "Steps", select = "Rows", fields = { "id", "enabled", "family", "factorWeights" }, ignore = { "order" } },
			{ module = "Tiers", select = "Rows", fields = { "id", "order", "enabled", "dMin", "dMax", "rarityCap",
				"qualityMultiplier", "failScoreFactor", "failOutcome" } },
			{ module = "Rarities", select = "Rows", fields = { "id", "order", "enabled", "minQuality" } },
			{ module = "Stats", select = "Rows", fields = { "id", "enabled" }, ignore = { "order" } },
			{ module = "CraftPlans", select = "Keys", fields = { "ordered" }, ignore = { "Sword" } },
			{ module = "MinigameFamilies", select = "Data", exclude = { "name" } },
			{ module = "Balance", select = "Keys", fields = { "Geometry", "Difficulty", "Stats", "Quality" } },
			{ module = "Limits", select = "Keys", fields = { "MIN_DIM", "MAX_DIM", "EPS_CONTAIN", "CONTACT_TOL" } },
		}
		A.deepEq(summary, expected)
	end)

	t.it("excluded = §2.8: the non-outcome modules, the other Limits, Balance.Display and the display columns", function()
		local whole: { string } = {}
		local partial: { [string]: { string } } = {}
		for _, e in Manifest.excluded do
			A.truthy(type(e.why) == "string" and e.why ~= "", e.module .. " says why")
			if e.keys then
				partial[e.module] = e.keys
			else
				table.insert(whole, e.module)
			end
		end
		A.deepEq(whole, { "Types", "Catalog", "Versions", "Validate", "Manifest", "Network", "World", "Presentation", "Audio" })
		A.deepEq(partial.Balance, { "Display" })
		local otherLimits = {}
		for _, k in Dump.sortedKeys(Limits :: any) do
			if not table.find({ "MIN_DIM", "MAX_DIM", "EPS_CONTAIN", "CONTACT_TOL" }, k) then
				table.insert(otherLimits, k)
			end
		end
		local listed = table.clone(partial.Limits)
		table.sort(listed)
		A.deepEq(listed, otherLimits, "every other Limits key, by name")
		A.deepEq(Manifest.displayFields, { "name", "blurb", "color", "robloxMaterial", "reflectance", "risk", "unit", "decimals" })
	end)

	t.it("collect keeps exactly the listed fields of every row, in catalogue order", function()
		local mats = dataOf("Materials")
		A.eq(#mats, #Materials.ordered)
		for i, row in mats do
			local m = Materials.ordered[i]
			A.deepEq(row, {
				id = m.id, order = m.order, enabled = m.enabled, class = m.class, density = m.density,
				hardness = m.hardness, toughness = m.toughness, difficultyTerm = m.difficultyTerm,
				qualityTier = m.qualityTier,
			}, m.id)
		end
		local sword = dataOf("EquipmentTypes")[1]
		A.deepEq(Dump.sortedKeys(sword), { "enabled", "geometry", "id", "kind", "order", "slots" })
		A.deepEq(sword.slots[1], { id = "Blade", required = true, min = 1, max = 12, rank = 1 }, "slots without name")
		A.deepEq(sword.geometry, (EquipmentTypes.get("Sword") :: any).geometry)
		local steps = dataOf("Steps")
		A.deepEq(Dump.sortedKeys(steps[1]), { "enabled", "factorWeights", "family", "id" })
		local stats = dataOf("Stats")
		A.deepEq(stats[1], { id = "Damage", enabled = true })
	end)

	t.it("collect: CraftPlans whole, MinigameFamilies without the family names, the listed Balance and Limits keys", function()
		A.deepEq(dataOf("CraftPlans"), { ordered = CraftPlans.ordered })
		local fam = dataOf("MinigameFamilies")
		A.eq(fam.enabled, nil, "the catalog view `enabled` repeats `ordered`")
		A.eq(fam.byId, nil, "so does `byId`")
		A.eq(#fam.ordered, #MinigameFamilies.ordered)
		for i, row in fam.ordered do
			A.eq(row.name, nil, "display name dropped")
			A.eq(row.id, MinigameFamilies.ordered[i].id)
			A.deepEq(row.params, MinigameFamilies.ordered[i].params, row.id .. " params keep their names")
		end
		A.eq(fam.MAX_TIMELINE_BYTES, MinigameFamilies.MAX_TIMELINE_BYTES, "module constants are hashed")
		A.deepEq(Dump.sortedKeys(dataOf("Balance")), { "Difficulty", "Geometry", "Quality", "Stats" })
		A.deepEq(dataOf("Limits"), { MIN_DIM = 0.02, MAX_DIM = 6.0, EPS_CONTAIN = 1e-4, CONTACT_TOL = 0.01 })
	end)

	t.it("a hashed edit changes the selection; a display or ignored edit does not", function()
		local base = text()
		for i, edit in EDITS do
			local copy = H.deepCopy(MODULE_VALUES[edit.module])
			edit.hashed(copy)
			A.truthy(text({ [edit.module] = copy }) ~= base, string.format("edit %d (%s) must change the hash", i, edit.module))
			local unhashed = edit.unhashed
			if unhashed then
				local other = H.deepCopy(MODULE_VALUES[edit.module])
				unhashed(other)
				A.eq(text({ [edit.module] = other }), base, string.format("edit %d (%s) must not change the hash", i,
					edit.module))
			end
		end
	end)

	t.it("collect returns fresh, unfrozen, JSON-safe data that shares no table with Definitions", function()
		local got = Manifest.collect()
		local ok, bad = H.jsonSafe(got)
		A.truthy(ok, "not JSON-safe at " .. tostring(bad))
		A.falsy(table.isfrozen(got[1].data), "a fresh copy")
		got[1].data[1].density = 99
		A.eq(Materials.ordered[1].density, 7.87, "Definitions untouched")
		A.eq(dataOf("Materials")[1].density, 7.87, "the next collect is unchanged")
	end)

	t.it("P-NOMUT collect leaves the module values it is given unchanged", function()
		local values: { [string]: any } = {}
		for name, v in MODULE_VALUES do
			values[name] = H.deepCopy(v)
		end
		local before = H.deepCopy(values)
		Manifest.collect(values)
		A.deepEq(values, before)
	end)

	t.it("collect refuses modules it cannot select from", function()
		A.throws(function()
			Manifest.collect({ Materials = { nothing = true } })
		end, "no `ordered` rows")
		A.throws(function()
			Manifest.collect({ Limits = { MIN_DIM = 0.02 } })
		end, "Limits.MAX_DIM is missing")
		A.throws(function()
			Manifest.collect({ Balance = 5 })
		end, "is not a table")
	end)

	t.it("P-DET and P-ORDER modules rebuilt in shuffled key order hash the same", function()
		local base = text()
		A.eq(text(), base, "P-DET")
		Prop.check(Tol.PROP_N // 4, function(rng): { [string]: any }
			local values: { [string]: any } = {}
			for name, v in MODULE_VALUES do
				values[name] = H.reshuffled(H.deepCopy(v), rng)
			end
			return values
		end, function(values: { [string]: any })
			A.eq(text(values), base)
		end)
	end)

	t.it("entryOf finds a hashed entry by module name", function()
		local e = Manifest.entryOf("Tiers")
		assert(e)
		A.eq(e.select, "Rows")
		A.eq(Manifest.entryOf("Network"), nil, "excluded modules have no hashed entry")
		A.eq(Manifest.entryOf("Nope"), nil)
		A.truthy(table.isfrozen(Manifest) and table.isfrozen(Manifest.hashed[1]))
	end)
end)
