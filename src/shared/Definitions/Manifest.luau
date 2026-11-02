--!strict
-- Definitions/Manifest (SPEC §2.8, §14.9; owner S1): the outcome-affecting Definitions data. S8's T-BAL-01 hashes
-- exactly what Manifest.collect() selects ({version, bytes, fnv1a32} over its Dump.canonical text), so changed data
-- under an unchanged BALANCE_VERSION fails; T-BAL-02 checks that every Definitions module, every catalog column
-- and every top-level key is either hashed here or excluded (Manifest.excluded, Manifest.displayFields).
--
--   Manifest.hashed      the entries T-BAL-01 hashes, in this order:
--     select "Rows"      the catalog rows (`ordered`) with `fields` per row; a nested selector keeps some fields of
--                        each record of a nested array; `ignore` lists row fields that are neither hashed nor
--                        display text (catalogue order where play order lives in CraftPlans)
--     select "Keys"      the listed top-level keys, whole; `ignore` lists keys that only alias hashed data
--     select "Data"      every plain-data key of the module, whole (functions and the catalog views `enabled` and
--                        `byId`, which repeat `ordered`, are dropped), with `exclude` removed from each `ordered` row
--   Manifest.excluded    whole modules (keys = nil) or the listed keys of a module, never hashed
--   Manifest.displayFields  catalog columns that are display only: a colour edit never forces a rebalance
--   Manifest.collect(values?)  the selected data, { {module, data} } in hashed order; `values[name]` replaces a
--                        module's value (tests plant changes that way); pure, deterministic, shares no table with
--                        Definitions

local Balance = require("./Balance")
local Catalog = require("./Catalog")
local CraftPlans = require("./CraftPlans")
local EquipmentTypes = require("./EquipmentTypes")
local Limits = require("./Limits")
local Materials = require("./Materials")
local MinigameFamilies = require("./MinigameFamilies")
local Rarities = require("./Rarities")
local Stats = require("./Stats")
local Steps = require("./Steps")
local Tiers = require("./Tiers")

export type FieldSelector = string | { field: string, fields: { string } }
export type HashedEntry = {
	module: string,
	select: "Rows" | "Keys" | "Data",
	fields: { FieldSelector }?,
	ignore: { string }?,
	exclude: { string }?,
}
export type ExcludedEntry = { module: string, keys: { string }?, why: string }
export type Collected = { module: string, data: any }

local SLOTS_BUT_NAME: FieldSelector = { field = "slots", fields = { "id", "required", "min", "max", "rank" } }
local EQUIPMENT_FIELDS: { FieldSelector } = { "id", "order", "enabled", "kind", SLOTS_BUT_NAME, "geometry" }

local hashed: { HashedEntry } = {
	{
		module = "Materials",
		select = "Rows",
		fields = {
			"id", "order", "enabled", "class", "density", "hardness", "toughness", "allowedSlots", "difficultyTerm",
			"qualityTier",
		},
	},
	{
		module = "EquipmentTypes",
		select = "Rows",
		fields = EQUIPMENT_FIELDS, -- slots: all but name
	},
	{
		module = "Steps",
		select = "Rows",
		fields = { "id", "enabled", "family", "factorWeights" },
		ignore = { "order" }, -- catalogue order; play order is CraftPlans'
	},
	{
		module = "Tiers",
		select = "Rows",
		fields = {
			"id", "order", "enabled", "dMin", "dMax", "rarityCap", "qualityMultiplier", "failScoreFactor", "failOutcome",
		},
	},
	{
		module = "Rarities",
		select = "Rows",
		fields = { "id", "order", "enabled", "minQuality" },
	},
	{
		module = "Stats",
		select = "Rows",
		fields = { "id", "enabled" },
		ignore = { "order" }, -- display order; items key stats by StatId
	},
	{
		module = "CraftPlans",
		select = "Keys",
		fields = { "ordered" }, -- all
		ignore = { "Sword" }, -- = ordered[1]
	},
	{
		module = "MinigameFamilies",
		select = "Data", -- all but display text
		exclude = { "name" },
	},
	{
		module = "Balance",
		select = "Keys",
		fields = { "Geometry", "Difficulty", "Stats", "Quality" },
	},
	{
		module = "Limits",
		select = "Keys",
		fields = { "MIN_DIM", "MAX_DIM", "EPS_CONTAIN", "CONTACT_TOL" },
	},
}

local excluded: { ExcludedEntry } = {
	{ module = "Types", why = "types only" },
	{ module = "Catalog", why = "catalog construction code" },
	{ module = "Versions", why = "the version stamps themselves" },
	{ module = "Validate", why = "boot self-checks" },
	{ module = "Manifest", why = "this list" },
	{ module = "Network", why = "server and protocol tunables never change outcomes (§1.3 L5)" },
	{ module = "World", why = "world layout" },
	{ module = "Presentation", why = "rendering and camera values" },
	{ module = "Audio", why = "sound cues" },
	{
		module = "Limits",
		keys = {
			"POS_ABS_MAX", "MAX_PARTS", "MAX_PART_ID", "QUAT_NORM_TOL", "QUAT_INPUT_TOL", "NAME_MIN_CP", "NAME_MAX_CP",
			"NAME_MAX_INPUT_BYTES", "MAX_ISSUES_STORED", "MAX_STEP_FLAGS", "MAX_BLUEPRINTS", "MAX_ITEMS", "MAX_UI_FLAGS",
			"UI_FLAG_KEY_MAX_BYTES", "DATASTORE_VALUE_LIMIT", "KEY_WRITE_BYTES_PER_MIN", "PROFILE_SIZE_WARN_BYTES",
			"PROFILE_SIZE_BLOCK_BYTES", "PROFILE_STORE_NAME", "PROFILE_KEY_PREFIX",
		},
		why = "structural, wire and storage bounds: what may be saved, not what a valid design scores",
	},
	{ module = "Balance", keys = { "Display" }, why = "display labels" },
}

local displayFields: { string } = {
	"name", "blurb", "color", "robloxMaterial", "reflectance", "risk", "unit", "decimals",
}

local LOADED: { [string]: any } = {
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

-- ── selection ─────────────────────────────────────────────────────────────────────────────────────────────────

-- A fresh copy of plain data: functions are dropped, tables copied (keys and values), cycles refused.
local function copyData(v: any, path: string, depth: number): any
	if type(v) == "function" then
		return nil
	elseif type(v) ~= "table" then
		return v
	end
	if depth > 32 then
		error("Manifest.collect: data nested deeper than 32 levels at " .. path)
	end
	local out = {}
	for k, child in v do
		if type(child) ~= "function" then
			out[copyData(k, path, depth + 1)] = copyData(child, path .. "." .. tostring(k), depth + 1)
		end
	end
	return out
end

local function selectRow(row: any, fields: { FieldSelector }, path: string): any
	local out = {}
	for _, sel in fields do
		if type(sel) == "string" then
			out[sel] = copyData(row[sel], path .. "." .. sel, 0)
		else
			local nested = row[sel.field]
			if nested ~= nil then
				if type(nested) ~= "table" then
					error(string.format("Manifest.collect: %s.%s must be an array of records", path, sel.field))
				end
				local list = {}
				for i = 1, #nested do
					list[i] = selectRow(nested[i], sel.fields, string.format("%s.%s[%d]", path, sel.field, i))
				end
				out[sel.field] = list
			end
		end
	end
	return out
end

local function rowsOf(value: any, name: string): { any }
	local rows = if type(value) == "table" then value.ordered else nil
	if type(rows) ~= "table" then
		error("Manifest.collect: " .. name .. " has no `ordered` rows")
	end
	return rows
end

local function selectEntry(entry: HashedEntry, value: any): any
	local name = entry.module
	if type(value) ~= "table" then
		error("Manifest.collect: module " .. name .. " is not a table")
	end
	if entry.select == "Rows" then
		local rows = rowsOf(value, name)
		local fields = entry.fields or {}
		local out = {}
		for i = 1, #rows do
			out[i] = selectRow(rows[i], fields, string.format("%s[%d]", name, i))
		end
		return out
	elseif entry.select == "Keys" then
		local out = {}
		local fields: { FieldSelector } = entry.fields or {}
		for _, sel in fields do
			if type(sel) ~= "string" then
				error("Manifest.collect: " .. name .. " selects top-level keys by name only")
			end
			if value[sel] == nil then
				error("Manifest.collect: " .. name .. "." .. sel .. " is missing")
			end
			out[sel] = copyData(value[sel], name .. "." .. sel, 0)
		end
		return out
	else
		local out = {}
		for k, v in value do
			if type(v) ~= "function" and k ~= "enabled" and k ~= "byId" then
				out[k] = copyData(v, name .. "." .. tostring(k), 0)
			end
		end
		local rows = out.ordered
		local exclude: { string } = entry.exclude or {}
		if type(rows) == "table" then
			for i = 1, #rows do
				if type(rows[i]) == "table" then
					for _, field in exclude do
						rows[i][field] = nil
					end
				end
			end
		end
		return out
	end
end

local function collect(values: { [string]: any }?): { Collected }
	local out: { Collected } = {}
	for _, entry in hashed do
		local value = if values and values[entry.module] ~= nil then values[entry.module] else LOADED[entry.module]
		table.insert(out, { module = entry.module, data = selectEntry(entry, value) })
	end
	return out
end

-- The hashed entry for a module name, or nil.
local function entryOf(name: string): HashedEntry?
	for _, entry in hashed do
		if entry.module == name then
			return entry
		end
	end
	return nil
end

export type Manifest = {
	hashed: { HashedEntry },
	excluded: { ExcludedEntry },
	displayFields: { string },
	collect: (values: { [string]: any }?) -> { Collected },
	entryOf: (name: string) -> HashedEntry?,
}

local Manifest: Manifest = {
	hashed = hashed,
	excluded = excluded,
	displayFields = displayFields,
	collect = collect,
	entryOf = entryOf,
}

table.freeze(LOADED)
return Catalog.deepFreeze(Manifest)
