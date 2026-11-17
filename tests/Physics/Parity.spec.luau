--!strict
-- S-PAR-02's Lune digest (SPEC §14.10, §17.2 S8, E-S8.6; the M3 plan's [8.5] with the lead's L17): Analyze.run, with
-- measureInvalid, on every fixture of tests/fixtures/Parity and on Tol.PARITY_DESIGNS Gen.validSword designs drawn in
-- turn from TestRng.new(Tol.PARITY_SEED). One line per design: its name, a tab, Dump.canonical of the analysis, a
-- newline. An Adversarial variant goes through Blueprint/Canonical.draft first and is dropped when Canonical refuses it.
--   parity.bv<N>.digest.txt         per group ("fixtures", "generated"): the designs, the bytes and the fnv1a32 of its
--                                   lines; tests/studio/e2e/S-PAR-02.luau computes the same in the Studio Server and
--                                   Client data models and compares (≤ 1 KB, §14.2)
--   parity_designs.bv<N>.golden.txt every design's name and the fnv1a32 of its line, for a diff against the hashes a
--                                   Studio FAIL prints
-- The digest is slow (about 2.4 s); its list is checked fast. M5 adds Pipeline.analyze, judged bot runs and T-CR-08's
-- outcomes beside `analyze` (§18), under their own keys.

local Test = require("../lib/Test")
local A = require("../lib/Assert")
local Dump = require("../lib/Dump")
local Gen = require("../lib/Gen")
local Golden = require("../lib/Golden")
local TestRng = require("../lib/TestRng")
local Tol = require("../lib/Tol")
local Adversarial = require("../fixtures/Adversarial")
local Blueprints = require("../fixtures/Blueprints")
local Calibration = require("../fixtures/Calibration")
local Cost = require("../fixtures/Cost")
local Parity = require("../fixtures/Parity")
local Regression = require("../fixtures/Regression")
local WorstDesigns = require("../fixtures/WorstDesigns")
local Balance = require("../../src/shared/Definitions/Balance")
local EquipmentTypes = require("../../src/shared/Definitions/EquipmentTypes")
local Limits = require("../../src/shared/Definitions/Limits")
local Materials = require("../../src/shared/Definitions/Materials")
local Versions = require("../../src/shared/Definitions/Versions")
local Canonical = require("../../src/shared/Blueprint/Canonical")
local Analyze = require("../../src/shared/Physics/Analyze")

local CTX = Gen.context(Limits, EquipmentTypes.get("Sword") :: any, Materials.enabled, Versions.BLUEPRINT_SCHEMA,
	Balance.Geometry)
local DIGEST = string.format("parity.bv%d", Versions.BALANCE_VERSION)
local DESIGNS = string.format("parity_designs.bv%d", Versions.BALANCE_VERSION)
local VERSION = 1 -- the digest's layout; the snippet writes the same

type Entry = { bytes: number, designs: number, fnv1a32: number }
type Hashed = { name: string, fnv1a32: number }

local function lineOf(name: string, core: any): string
	return name .. "\t" .. Dump.canonical(Analyze.run(core, { measureInvalid = true })) .. "\n"
end

-- The core an entry of Parity's list stands for, or nil when Canonical refuses its draft.
local function coreOf(entry: Parity.Entry): any
	if entry.core then
		return entry.core
	end
	local draft = entry.draft :: () -> any
	local result = Canonical.draft(draft())
	return if result.ok then result.value else nil
end

-- A group's digest entry and every design's own hash, from its lines and names in order.
local function digestOf(lines: { string }, names: { string }): (Entry, { Hashed })
	local text = table.concat(lines)
	local hashed: { Hashed } = table.create(#lines)
	for i, line in lines do
		hashed[i] = { name = names[i], fnv1a32 = Dump.fnv1a32(line) }
	end
	return { bytes = #text, designs = #lines, fnv1a32 = Dump.fnv1a32(text) }, hashed
end

return Test.suite("Physics/Parity", function(t)
	t.it("Parity's list: every fixture once, in its sets' order; the A variants Canonical accepts are their records'", function()
		local want: { string } = {}
		for _, id in Blueprints.order do
			table.insert(want, id)
		end
		for _, id in Calibration.order do
			table.insert(want, id)
		end
		for _, v in Adversarial.variants do
			table.insert(want, v.key)
		end
		for _, set in { Regression.order, Cost.order } do
			for _, id in set do
				table.insert(want, id)
			end
		end
		for k in WorstDesigns.valid do
			table.insert(want, "Worst valid " .. k)
		end
		for k in WorstDesigns.tooComplex do
			table.insert(want, "TooComplex " .. k)
		end
		A.eq(#Parity.list, #want, "entries")
		local seen: { [string]: boolean } = {}
		local accepted = 0
		for i, entry in Parity.list do
			A.eq(entry.name, want[i], "entry " .. i)
			A.falsy(seen[entry.name], "a name once: " .. entry.name)
			seen[entry.name] = true
			A.truthy((entry.core == nil) ~= (entry.draft == nil), entry.name .. ": a core or a draft")
			if entry.draft then
				local canon = Adversarial.variant(entry.name).canon
				A.eq(coreOf(entry) ~= nil, canon.ok, entry.name .. ": Canonical as its record says")
				accepted += if canon.ok then 1 else 0
			else
				A.truthy(Canonical.isCanonical(entry.core :: any), entry.name .. ": canonical as it is")
			end
		end
		A.eq(accepted, 43, "the A variants digested (of " .. #Adversarial.variants .. ")")
	end)

	t.slow("the digest: every Parity fixture and PARITY_DESIGNS Gen swords, = parity.bv<N>.digest (S-PAR-02)", function()
		local fixtureLines, fixtureNames, dropped = {}, {}, 0
		for _, entry in Parity.list do
			local core = coreOf(entry)
			if core == nil then
				dropped += 1
			else
				table.insert(fixtureLines, lineOf(entry.name, core))
				table.insert(fixtureNames, entry.name)
			end
		end
		local genLines, genNames = {}, {}
		local rng = TestRng.new(Tol.PARITY_SEED)
		for k = 1, Tol.PARITY_DESIGNS do
			local name = "Gen " .. k
			table.insert(genLines, lineOf(name, Gen.validSword(rng, CTX)))
			table.insert(genNames, name)
		end
		A.eq(dropped, #Adversarial.variants - 43, "the drafts Canonical refuses")
		local fixtures, fixtureHashes = digestOf(fixtureLines, fixtureNames)
		local generated, genHashes = digestOf(genLines, genNames)
		A.eq(generated.designs, Tol.PARITY_DESIGNS, "Gen designs")
		Golden.digest(DIGEST, { version = VERSION, analyze = { fixtures = fixtures, generated = generated } })
		Golden.check(DESIGNS, { fixtures = fixtureHashes, generated = genHashes })
	end)
end)
