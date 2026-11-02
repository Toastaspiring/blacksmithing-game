--!strict
-- tests/Definitions/BalanceGuard.spec.luau — the BALANCE guard (SPEC §2.8, §14.9).
--   T-BAL-01  tests/golden/balance_fingerprint.golden.txt = {version, bytes, fnv1a32} over the Dump.canonical text of
--             exactly what Definitions/Manifest selects. Changed data under an unchanged BALANCE_VERSION fails, even
--             with --bless; a bumped version fails a plain run and passes --bless; versions strictly increase.
--             Workflow: edit → bump BALANCE_VERSION → lune run tests/run -- --bless → review the diff → commit.
--   T-BAL-02  every Definitions module is hashed or excluded, and every catalog column and module key is hashed,
--             ignored on purpose, display only or excluded: nothing outcome-affecting can escape the hash unnoticed.

local fs = require("@lune/fs")
local A = require("../lib/Assert")
local Dump = require("../lib/Dump")
local Golden = require("../lib/Golden")
local Test = require("../lib/Test")
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
local Validate = require("../../src/shared/Definitions/Validate")
local Versions = require("../../src/shared/Definitions/Versions")

local GOLDEN = "balance_fingerprint"
local DIR = "src/shared/Definitions"

-- every module Manifest.hashed names, so T-BAL-02 can read its keys (a new hashed module must be added here)
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

type Fingerprint = { version: number, bytes: number, fnv1a32: number }

local function fingerprint(): Fingerprint
	local text = Dump.canonical(Manifest.collect())
	return { version = Versions.BALANCE_VERSION, bytes = #text, fnv1a32 = Dump.fnv1a32(text) }
end

-- The guard's rule. "ok": the golden matches; "write": --bless records the new fingerprint; "fail": the message says why.
local function decide(old: any, new: Fingerprint, bless: boolean): (string, string?)
	if old == nil then
		if bless then
			return "write", nil
		end
		return "fail", "golden missing: tests/golden/" .. GOLDEN .. ".golden.txt (run lune run tests/run -- --bless)"
	end
	if type(old) ~= "table" or type(old.version) ~= "number" or type(old.bytes) ~= "number"
		or type(old.fnv1a32) ~= "number"
	then
		return "fail", "the golden is not {version, bytes, fnv1a32}: " .. Dump.short(old)
	end
	if new.version < old.version then
		return "fail", string.format("BALANCE_VERSION went down from %d to %d: versions strictly increase", old.version,
			new.version)
	end
	if new.version == old.version then
		if new.bytes == old.bytes and new.fnv1a32 == old.fnv1a32 then
			return "ok", nil
		end
		return "fail", string.format("the BALANCE Manifest data changed under BALANCE_VERSION %d (bytes %d → %d, fnv1a32 "
			.. "%d → %d): bump BALANCE_VERSION in Definitions/Versions, then run -- --bless and review the diff (--bless "
			.. "alone never accepts this)", new.version, old.bytes, new.bytes, old.fnv1a32, new.fnv1a32)
	end
	if bless then
		return "write", nil
	end
	return "fail", string.format("BALANCE_VERSION bumped from %d to %d: run lune run tests/run -- --bless, review the "
		.. "diff and commit the new fingerprint", old.version, new.version)
end

local function diskModules(): { string }
	local names: { string } = {}
	for _, f in fs.readDir(DIR) do
		if string.sub(f, -5) == ".luau" and fs.isFile(DIR .. "/" .. f) then
			table.insert(names, string.sub(f, 1, -6))
		end
	end
	table.sort(names)
	return names
end

local function set(list: { string }?): { [string]: boolean }
	local s: { [string]: boolean } = {}
	local items: { string } = list or {}
	for _, v in items do
		s[v] = true
	end
	return s
end

local function excludedKeys(module: string): { [string]: boolean }
	local s: { [string]: boolean } = {}
	for _, e in Manifest.excluded do
		if e.module == module and e.keys then
			for _, k in e.keys do
				s[k] = true
			end
		end
	end
	return s
end

return Test.suite("Definitions/BalanceGuard", function(t)
	t.it("T-BAL-01 the BALANCE fingerprint matches its golden at the current BALANCE_VERSION", function()
		local fp = fingerprint()
		local verdict, why = decide(Golden.read(GOLDEN), fp, Golden.bless)
		if verdict == "fail" then
			A.fail(why or "?")
		end
		Golden.check(GOLDEN, fp) -- "ok": compares (bless rewrites the same text); "write": records it under --bless
	end)

	t.it("T-BAL-01 the guard's rules: changed data needs a bump, a bump needs --bless, versions only rise", function()
		local v1 = { version = 1, bytes = 100, fnv1a32 = 7 }
		local same = { version = 1, bytes = 100, fnv1a32 = 7 }
		local changed = { version = 1, bytes = 100, fnv1a32 = 8 }
		local resized = { version = 1, bytes = 101, fnv1a32 = 7 }
		local bumped = { version = 2, bytes = 100, fnv1a32 = 8 }
		local bumpedSame = { version = 2, bytes = 100, fnv1a32 = 7 }
		local lowered = { version = 0, bytes = 100, fnv1a32 = 7 }
		local cases: { { any } } = {
			{ v1, same, false, "ok" },
			{ v1, same, true, "ok" },
			{ v1, changed, false, "fail" },
			{ v1, changed, true, "fail" }, -- even with --bless
			{ v1, resized, true, "fail" },
			{ v1, bumped, false, "fail" }, -- a plain run refuses a bump
			{ v1, bumped, true, "write" },
			{ v1, bumpedSame, true, "write" }, -- a bump without a data change is allowed (outcome code changed)
			{ v1, lowered, false, "fail" },
			{ v1, lowered, true, "fail" },
			{ nil, same, false, "fail" },
			{ nil, same, true, "write" },
			{ { version = "1" }, same, true, "fail" },
		}
		for i, c in cases do
			local verdict = decide(c[1], c[2], c[3])
			A.eq(verdict, c[4], "case " .. i)
		end
		local _, why = decide(v1, changed, true)
		A.contains(why or "", "bump BALANCE_VERSION")
	end)

	t.it("T-BAL-01 the fingerprint follows the data: a hashed edit changes it, a colour edit does not", function()
		local base = Dump.canonical(Manifest.collect())
		local mats: any = table.clone(Materials)
		local rows = table.clone(Materials.ordered) :: { any }
		local iron = table.clone(rows[1]) :: any
		iron.hardness = 46
		rows[1] = iron
		mats.ordered = rows
		A.truthy(Dump.canonical(Manifest.collect({ Materials = mats })) ~= base, "hardness is outcome data")
		local recolour = table.clone(Materials.ordered[1]) :: any
		recolour.color = { 0, 0, 0 }
		local rows2 = table.clone(Materials.ordered) :: { any }
		rows2[1] = recolour
		local mats2: any = table.clone(Materials)
		mats2.ordered = rows2
		A.eq(Dump.canonical(Manifest.collect({ Materials = mats2 })), base, "a colour edit never forces a rebalance")
	end)

	t.it("T-BAL-02 every Definitions module on disk is hashed or excluded, and the Manifest names only those", function()
		local disk = diskModules()
		local named: { [string]: boolean } = {}
		for _, e in Manifest.hashed do
			named[e.module] = true
		end
		for _, e in Manifest.excluded do
			named[e.module] = true
		end
		local onDisk = set(disk)
		for _, name in disk do
			A.truthy(named[name], DIR .. "/" .. name .. ".luau is in neither Manifest.hashed nor Manifest.excluded")
		end
		for name in named do
			A.truthy(onDisk[name], "the Manifest names " .. name .. ", which is not in " .. DIR)
		end
		local modules = table.clone(Validate.MODULES)
		table.sort(modules)
		A.deepEq(disk, modules, "the Definitions folder = SPEC §1.2's module list (Validate.MODULES)")
		for _, e in Manifest.hashed do
			A.truthy(MODULE_VALUES[e.module] ~= nil, e.module .. " is hashed: add it to this spec's MODULE_VALUES")
		end
	end)

	t.it("T-BAL-02 every catalog column and module key is hashed, ignored, display only or excluded", function()
		local display = set(Manifest.displayFields)
		for _, e in Manifest.hashed do
			local value = MODULE_VALUES[e.module]
			local ignore = set(e.ignore)
			local excluded = excludedKeys(e.module)
			if e.select == "Rows" then
				local fields: { [string]: boolean } = {}
				local nested: { [string]: { [string]: boolean } } = {}
				local selectors: { Manifest.FieldSelector } = e.fields or {}
				for _, sel in selectors do
					if type(sel) == "string" then
						fields[sel] = true
					else
						fields[sel.field] = true
						nested[sel.field] = set(sel.fields)
					end
				end
				for k, v in value do
					A.truthy(type(v) == "function" or k == "ordered" or k == "enabled" or k == "byId",
						e.module .. "." .. tostring(k) .. ": a data key outside the catalog views escapes the hash")
				end
				for _, row in value.ordered do
					for k, v in row do
						A.truthy(fields[k] or ignore[k] or display[k], e.module .. "." .. row.id .. "." .. k
							.. " is not classified: hash it, or list it as display text or ignored")
						A.falsy(fields[k] and (ignore[k] or display[k]), e.module .. "." .. k .. " is hashed and excluded")
						if nested[k] then
							for _, item in v do
								for nk in item do
									A.truthy(nested[k][nk] or display[nk], e.module .. "." .. row.id .. "." .. k .. "." .. nk
										.. " is not classified")
								end
							end
						end
					end
				end
				for k in ignore do
					A.truthy(value.ordered[1][k] ~= nil, e.module .. ": ignored field " .. k .. " does not exist")
				end
			elseif e.select == "Keys" then
				local fields = set(e.fields :: any)
				for k, v in value do
					if type(v) ~= "function" then
						A.truthy(fields[k] or ignore[k] or excluded[k], e.module .. "." .. tostring(k)
							.. " is not classified: hash it or exclude it")
						A.falsy(fields[k] and excluded[k], e.module .. "." .. k .. " is hashed and excluded")
					end
				end
				for k in fields do
					A.truthy(value[k] ~= nil, e.module .. "." .. k .. " is hashed but missing")
				end
				for k in excluded do
					A.truthy(value[k] ~= nil, e.module .. "." .. k .. " is excluded but missing")
				end
			else
				local dropped: { string } = e.exclude or {}
				for _, k in dropped do
					A.truthy(display[k], e.module .. ": only display text may be dropped, not " .. k)
				end
			end
		end
		for _, x in Manifest.excluded do
			if x.keys then
				A.truthy(Manifest.entryOf(x.module) ~= nil, x.module .. ": partial exclusions belong to hashed modules")
			else
				A.eq(Manifest.entryOf(x.module), nil, x.module .. " is excluded as a whole and hashed")
			end
		end
	end)
end)
