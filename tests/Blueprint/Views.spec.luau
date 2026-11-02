--!strict
-- T-BP-13 Blueprint/Views (SPEC §3.3, §3.11, E-S8.5): Views.snapshot is a deep copy that shares no table with its
-- record (§9.2) and carries only the core plus sourceId / sourceRevision; Views.summary carries no parts, counts them,
-- lists the distinct materials in Materials order and copies the analysis. Neither mutates the record.

local Test = require("../lib/Test")
local A = require("../lib/Assert")
local Dump = require("../lib/Dump")
local Prop = require("../lib/Prop")
local Tol = require("../lib/Tol")
local TestRng = require("../lib/TestRng")
local Drafts = require("./Drafts")
local Canonical = require("../../src/shared/Blueprint/Canonical")
local Views = require("../../src/shared/Blueprint/Views")
local Catalog = require("../../src/shared/Definitions/Catalog")
local Materials = require("../../src/shared/Definitions/Materials")

type TestRng = TestRng.TestRng

local GUID = "93E32E8A-59BA-4037-9A7F-AA5613CD6213"

local function canonical(raw: any): any
	local r: any = Canonical.draft(raw)
	assert(r.ok, "fixture must be canonical")
	return r.value
end

local function analysis(): any
	return {
		balanceVersion = 1,
		valid = true,
		issues = { "SlotTooMany", "Disconnected" },
		physics = { mass = 0.7925, balance = 0.6674, reach = 3.31 },
		steps = {
			{ step = "Smelting", difficulty = 0.0123, tier = "Normal" },
			{ step = "Hammering", difficulty = 0.1314, tier = "Normal" },
			{ step = "Sharpening", difficulty = 0.2, tier = "Hard" },
		},
	}
end

local function record(core: any, withAnalysis: boolean?): any
	local r = Drafts.deepCopy(core)
	r.id, r.revision, r.createdAt, r.updatedAt = GUID, 7, 1793404800, 1793491200
	if withAnalysis ~= false then
		r.analysis = analysis()
	end
	return r
end

local function keys(t: any): string
	local out = {}
	for _, k in Dump.sortedKeys(t) do
		table.insert(out, tostring(k))
	end
	return table.concat(out, ",")
end

local function noDiff(a: any, b: any, what: string)
	local diff = Drafts.bitDiff(a, b)
	A.truthy(diff == nil, what .. ": " .. tostring(diff))
end

return Test.suite("Blueprint/Views", function(t)
	t.it("T-BP-13 snapshot: the core and its source, a deep copy sharing no table", function()
		local r = record(canonical(Drafts.f1()))
		local before = Drafts.deepCopy(r)
		local s: any = Views.snapshot(r)
		A.eq(keys(s), "name,parts,schema,sourceId,sourceRevision,type", "only the core and the source")
		A.eq(s.sourceId, GUID)
		A.eq(s.sourceRevision, 7)
		A.eq(s.schema, r.schema)
		A.eq(s.name, r.name)
		A.eq(s.type, r.type)
		noDiff(s.parts, r.parts, "parts copied bit for bit")
		A.falsy(Drafts.sharesTable(s, r), "no table shared with the record")
		A.falsy(Drafts.repeatsTable(s), "no table repeated inside the snapshot")
		noDiff(r, before, "P-NOMUT: the record is untouched")
		A.truthy(Canonical.isCanonical(s), "the snapshot is canonical")
		-- writing to the snapshot never reaches the record
		s.parts[1].pos[1] = 99
		s.parts[2].rot[4] = -1
		table.insert(s.parts, s.parts[1])
		noDiff(r, before, "the record after editing the snapshot")
		noDiff(Views.snapshot(r), Views.snapshot(r), "P-DET")
	end)

	t.it("T-BP-13 summary: no parts, partCount, materials in Materials order, the analysis copied", function()
		local r = record(canonical(Drafts.f1()))
		local before = Drafts.deepCopy(r)
		local s: any = Views.summary(r)
		A.eq(keys(s), "analysis,id,materials,name,partCount,revision,type,updatedAt")
		A.eq(s.id, GUID)
		A.eq(s.name, r.name)
		A.eq(s.type, "Sword")
		A.eq(s.revision, 7)
		A.eq(s.updatedAt, 1793491200)
		A.eq(s.partCount, 5)
		noDiff(s.materials, { "Iron", "Steel" }, "F1: Iron hilt, Steel blade")
		noDiff(s.analysis, r.analysis, "analysis copied")
		A.falsy(Drafts.sharesTable(s, r), "no table shared with the record")
		noDiff(r, before, "P-NOMUT: the record is untouched")
		noDiff(Views.summary(r), s, "P-DET")
	end)

	t.it("T-BP-13 summary materials follow Materials order, not part order", function()
		local d = Drafts.f2() -- four Iron parts
		local s: any = Views.summary(record(canonical(d)))
		noDiff(s.materials, { "Iron" }, "all Iron")
		d.parts[1].material = "Steel"
		s = Views.summary(record(canonical(d)))
		noDiff(s.materials, { "Iron", "Steel" }, "Steel in a later part than Iron")
		for _, p in d.parts do
			p.material = "Steel"
		end
		s = Views.summary(record(canonical(d)))
		noDiff(s.materials, { "Steel" }, "all Steel")
		local empty = { schema = 1, name = "Empty", type = "Sword", parts = {} }
		s = Views.summary(record(canonical(empty), false))
		A.eq(s.partCount, 0)
		noDiff(s.materials, {}, "no parts, no materials")
		A.eq(s.analysis, nil, "no analysis on the record, none in the summary")
		A.eq(Materials.ordered[1].id, "Iron", "Materials order puts Iron first")
	end)

	t.it("T-BP-13 summary materials come from the catalog's order (planted Definitions, P-ORDER)", function()
		local rows = Drafts.rows(Materials.ordered, { 7, 6, 5, 4, 3, 2, 1 }) -- reversed input: same catalog
		local function plantedViews(materials: any): any
			return Drafts.planted("src/shared/Blueprint/Views.luau", {
				["../Definitions/Types"] = require("../../src/shared/Definitions/Types"),
				["../Definitions/Materials"] = materials,
				["./Schema"] = require("../../src/shared/Blueprint/Schema"),
			})
		end
		local r = record(canonical(Drafts.f1()))
		local same = plantedViews(Catalog.build(rows)) -- Catalog.build freezes the rows it is given
		noDiff(same.summary(r), Views.summary(r), "rows in another input order")
		local reordered = Drafts.rows(Materials.ordered)
		for _, row in reordered do
			if row.id == "Steel" then
				row.order = 0 -- Steel before Iron
			end
		end
		local steelFirst = plantedViews(Catalog.build(reordered))
		noDiff(steelFirst.summary(r).materials, { "Steel", "Iron" }, "the catalog order decides")
	end)

	t.it("T-BP-13 summary copies an analysis without physics as it is", function()
		local r = record(canonical(Drafts.f2()))
		r.analysis = { balanceVersion = 1, valid = false, issues = { "OutOfHitbox" }, steps = {} }
		local s: any = Views.summary(r)
		noDiff(s.analysis, r.analysis, "invalid analysis")
		A.eq(s.analysis.physics, nil)
		A.falsy(Drafts.sharesTable(s, r), "no table shared")
	end)

	t.it("T-BP-13 snapshot and summary on PROP_N generated records", function()
		Prop.check(Tol.PROP_N, function(rng: TestRng): any
			return record(canonical(Drafts.validDraft(rng)), rng:float() < 0.7)
		end, function(r: any)
			local before = Drafts.deepCopy(r)
			local s: any = Views.snapshot(r)
			noDiff(s.parts, r.parts, "snapshot parts")
			A.falsy(Drafts.sharesTable(s, r), "snapshot shares no table")
			A.truthy(Canonical.isCanonical(s), "snapshot canonical")
			local sum: any = Views.summary(r)
			A.eq(sum.partCount, #r.parts)
			local present: { [string]: boolean } = {}
			for _, p in r.parts do
				present[p.material] = true
			end
			local want = {}
			for _, m in Materials.ordered do
				if present[m.id] then
					table.insert(want, m.id)
				end
			end
			noDiff(sum.materials, want, "materials")
			A.falsy(Drafts.sharesTable(sum, r), "summary shares no table")
			noDiff(r, before, "P-NOMUT")
		end)
	end)
end)
