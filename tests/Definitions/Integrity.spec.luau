--!strict
-- tests/Definitions/Integrity.spec.luau — properties every Definitions catalog shares (SPEC §2.2, §2.3, §14.5;
-- T-DEF-01, T-DEF-03, T-DEF-06): append-only ids against a golden id list, the catalog views, and frozen, finite,
-- JSON-safe rows.

local A = require("../lib/Assert")
local Golden = require("../lib/Golden")
local Test = require("../lib/Test")
local H = require("./DefsHelpers")
local Balance = require("../../src/shared/Definitions/Balance")
local Catalog = require("../../src/shared/Definitions/Catalog")
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
local Types = require("../../src/shared/Definitions/Types")
local Validate = require("../../src/shared/Definitions/Validate")
local Versions = require("../../src/shared/Definitions/Versions")

local IDS_GOLDEN = "definition_ids"

type AnyCatalog = Catalog.Catalog<any>
local CATALOGS: { { name: string, catalog: AnyCatalog } } = {
	{ name = "Materials", catalog = Materials :: any },
	{ name = "EquipmentTypes", catalog = EquipmentTypes :: any },
	{ name = "Steps", catalog = Steps :: any },
	{ name = "Tiers", catalog = Tiers :: any },
	{ name = "Rarities", catalog = Rarities :: any },
	{ name = "Stats", catalog = Stats :: any },
	{ name = "MinigameFamilies", catalog = MinigameFamilies :: any },
}

local function currentIds(): { [string]: { string } }
	local ids: { [string]: { string } } = {}
	for _, c in CATALOGS do
		ids[c.name] = H.ids(c.catalog.ordered)
	end
	for _, et in EquipmentTypes.ordered do
		ids["Slots." .. et.id] = H.ids(et.slots)
	end
	ids.Factors = table.clone(Validate.FACTOR_ORDER)
	ids.CraftPlans = {}
	for _, plan in CraftPlans.ordered do
		table.insert(ids.CraftPlans, plan.type)
		local steps: { string } = {}
		for _, row in plan.steps do
			table.insert(steps, row.step)
		end
		ids["CraftPlans." .. plan.type] = steps
	end
	return ids
end

return Test.suite("Definitions/Integrity", function(t)
	t.it("T-DEF-01 ids are PascalCase and unique per catalog", function()
		for name, list in currentIds() do
			local seen: { [string]: boolean } = {}
			for _, id in list do
				A.truthy(type(id) == "string" and string.match(id, "^%u%w*$") ~= nil, name .. ": " .. tostring(id))
				if not string.match(name, "^CraftPlans%.") then
					A.falsy(seen[id], name .. ": duplicate " .. id)
				end
				seen[id] = true
			end
		end
	end)

	t.it("T-DEF-01 ids are append-only: no id of the golden list is ever renamed or removed (golden id lists)", function()
		local now = currentIds()
		local old = Golden.read(IDS_GOLDEN)
		if old ~= nil then
			for name, list in old :: { [string]: { string } } do
				local present: { [string]: boolean } = {}
				local current: { string } = now[name] or {}
				for _, id in current do
					present[id] = true
				end
				for _, id in list do
					A.truthy(present[id], name .. ": the id " .. id .. " was renamed or removed (ids are append-only, §2.2; "
						.. "retire a row with enabled = false); --bless cannot accept this")
				end
				if string.match(name, "^CraftPlans%.") then
					for i, id in list do
						A.eq(now[name][i], id, name .. ": plan rows are never reordered or deleted (§7.1)")
					end
				end
			end
		end
		Golden.check(IDS_GOLDEN, now) -- new ids need -- --bless (after the append-only check above)
	end)

	t.it("T-DEF-03 catalog views: ordered ascending, enabled = the enabled rows, byId and get find every row", function()
		for _, c in CATALOGS do
			local cat = c.catalog
			local last = -math.huge
			local enabledIds: { string } = {}
			for _, row in cat.ordered do
				A.truthy(row.order > last, c.name .. ": ordered ascending at " .. row.id)
				last = row.order
				A.eq(cat.byId[row.id], row, c.name .. ".byId." .. row.id)
				A.eq(cat.get(row.id), row, c.name .. ".get(" .. row.id .. ")")
				A.eq(cat.isEnabled(row.id), row.enabled, c.name .. ".isEnabled(" .. row.id .. ")")
				if row.enabled then
					table.insert(enabledIds, row.id)
				end
			end
			A.deepEq(H.ids(cat.enabled), enabledIds, c.name .. ".enabled")
			A.truthy(#cat.enabled > 0, c.name .. " enables something")
		end
	end)

	t.it("T-DEF-03 references resolve: families, rarity caps, plan steps and stats", function()
		for _, s in Steps.ordered do
			A.truthy(MinigameFamilies.get(s.family) ~= nil, s.id .. " → " .. s.family)
		end
		for _, tier in Tiers.ordered do
			A.truthy(Rarities.get(tier.rarityCap) ~= nil, tier.id .. " → " .. tier.rarityCap)
		end
		for _, plan in CraftPlans.ordered do
			for _, row in plan.steps do
				A.truthy(Steps.get(row.step) ~= nil, plan.type .. " → " .. row.step)
				for _, stat in row.feeds do
					A.truthy(Stats.get(stat) ~= nil, row.step .. " → " .. stat)
				end
			end
		end
		A.truthy(Tiers.get(Balance.Quality.FAILED_STEP_CAP_TIER) ~= nil, "FAILED_STEP_CAP_TIER")
	end)

	t.it("T-DEF-06 every module is deep-frozen", function()
		local modules: { [string]: any } = {
			Types = Types, Catalog = Catalog, Versions = Versions, Limits = Limits, Materials = Materials,
			EquipmentTypes = EquipmentTypes, Steps = Steps, Tiers = Tiers, Rarities = Rarities, Stats = Stats,
			Balance = Balance, Validate = Validate, Manifest = Manifest, CraftPlans = CraftPlans,
		}
		for name, m in modules do
			local frozen, at = H.isDeepFrozen(m)
			A.truthy(frozen, name .. " is not frozen at " .. tostring(at))
		end
	end)

	t.it("T-DEF-06 rows and tunables are finite and JSON-safe", function()
		for _, c in CATALOGS do
			for _, row in c.catalog.ordered do
				local ok, bad = H.jsonSafe(row)
				A.truthy(ok, c.name .. "." .. row.id .. " is not JSON-safe at " .. tostring(bad))
			end
		end
		local tunables: { [string]: any } = {
			Balance = Balance,
			Limits = Limits,
			Versions = Versions,
			CraftPlans = CraftPlans.ordered,
		}
		for name, v in tunables do
			local ok, bad = H.jsonSafe(v)
			A.truthy(ok, name .. " is not JSON-safe at " .. tostring(bad))
		end
		local ok, bad = H.jsonSafe({ hashed = Manifest.hashed, excluded = Manifest.excluded, display = Manifest.displayFields })
		A.truthy(ok, "Manifest lists are not JSON-safe at " .. tostring(bad))
	end)

	t.it("P-PURE every Definitions module loads under Lune and validateAll passes", function()
		A.deepEq(Validate.validateAll(), {})
	end)
end)
