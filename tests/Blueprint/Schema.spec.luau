--!strict
-- T-BP-01…05 Blueprint/Schema (SPEC §3.3): a types-only module. Its contract is checked twice: luau-lsp (pass B of
-- scripts/verify, strict) type-checks the typed values below against the exported types, so a renamed or retyped
-- field fails the gate; at run time the module loads under Lune (P-PURE), holds nothing, and Canonical's output and
-- the Views fit the types field for field.

local Test = require("../lib/Test")
local A = require("../lib/Assert")
local Dump = require("../lib/Dump")
local Drafts = require("./Drafts")
local Canonical = require("../../src/shared/Blueprint/Canonical")
local Schema = require("../../src/shared/Blueprint/Schema")
local Views = require("../../src/shared/Blueprint/Views")
local DT = require("../../src/shared/Definitions/Types")

local GUID = "93E32E8A-59BA-4037-9A7F-AA5613CD6213"
-- luau-lsp's checker widens a string literal inside a table checked against an intersection type (BlueprintRecord,
-- BlueprintSnapshot) to string, so the type id goes in through a typed local.
local SWORD: DT.EquipmentTypeId = "Sword"

-- Typed values: every field of every exported type, as §3.3 declares it.
local part: Schema.PartData = {
	id = 4,
	slot = "Blade",
	shape = "Block",
	material = "Steel",
	pos = { 0, 2.68, 0 } :: Schema.Vec3,
	rot = { 0, 0, 0, 1 } :: Schema.Quat,
	size = { 0.16, 2.6, 0.06 },
}
local core: Schema.BlueprintCore = { schema = 1, name = "F1 ArmingSword", type = "Sword", parts = { part } }
local draft: Schema.BlueprintDraft = core
local physics: Schema.PhysicsView = { mass = 0.7925, balance = 0.6674, reach = 3.31 }
local preview: Schema.StepPreview = { step = "Sharpening", difficulty = 0.132, tier = "Normal" }
local analysis: Schema.BlueprintAnalysis = {
	balanceVersion = 1,
	valid = true,
	issues = {},
	physics = physics,
	steps = { preview },
}
local record: Schema.BlueprintRecord = {
	schema = 1,
	name = "F1 ArmingSword",
	type = SWORD,
	parts = { part },
	id = GUID :: Schema.BlueprintId,
	revision = 1,
	createdAt = 1793404800,
	updatedAt = 1793404800,
	analysis = analysis,
}
local snapshot: Schema.BlueprintSnapshot = {
	schema = 1,
	name = "F1 ArmingSword",
	type = SWORD,
	parts = { part },
	sourceId = GUID,
	sourceRevision = 1,
}
local summary: Schema.BlueprintSummary = {
	id = GUID,
	name = "F1 ArmingSword",
	type = "Sword",
	revision = 1,
	updatedAt = 1793404800,
	partCount = 1,
	materials = { "Steel" },
	analysis = nil,
}

local function keys(t: any): string
	local out = {}
	for _, k in Dump.sortedKeys(t) do
		table.insert(out, tostring(k))
	end
	return table.concat(out, ",")
end

return Test.suite("Blueprint/Schema", function(t)
	t.it("T-BP-01 Schema is types only: it loads under Lune and holds nothing (P-PURE)", function()
		A.eq(type(Schema), "table")
		A.eq(next(Schema), nil, "no runtime fields")
		A.truthy(table.isfrozen(Schema), "frozen")
	end)

	t.it("T-BP-03 the typed values fit §3.3, and Canonical's output has exactly those fields", function()
		A.eq(keys(part), "id,material,pos,rot,shape,size,slot")
		A.eq(keys(draft), "name,parts,schema,type")
		A.eq(keys(record), "analysis,createdAt,id,name,parts,revision,schema,type,updatedAt")
		A.eq(keys(snapshot), "name,parts,schema,sourceId,sourceRevision,type")
		A.eq(keys(summary), "id,materials,name,partCount,revision,type,updatedAt")
		local r: any = Canonical.draft(core)
		A.truthy(r.ok, "the typed core is a valid draft")
		local out: Schema.BlueprintDraft = r.value
		A.eq(keys(out), keys(draft), "Canonical returns a BlueprintDraft")
		A.eq(keys(out.parts[1]), keys(part), "with PartData parts")
		local diff = Drafts.bitDiff(out, core)
		A.truthy(diff == nil, "the typed core is canonical: " .. tostring(diff))
		local s: Schema.BlueprintSnapshot = Views.snapshot(record)
		A.eq(keys(s), keys(snapshot), "Views.snapshot returns a BlueprintSnapshot")
		local sum: Schema.BlueprintSummary = Views.summary(record)
		A.eq(keys(sum), "analysis," .. keys(summary), "Views.summary returns a BlueprintSummary")
	end)
end)
