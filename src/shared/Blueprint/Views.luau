--!strict
-- Blueprint/Views (SPEC §3.3, §3.11; owner S1): the views built from a stored BlueprintRecord. Pure.
--   snapshot  the blueprint an item keeps (BlueprintSnapshot = core + sourceId, sourceRevision), taken at forge: a
--             deep copy that shares no table with the record, since no table may be shared between two records of
--             Profile.Data (§9.2); id, revision, times and analysis stay behind
--   summary   the library row (BlueprintSummary, the join snapshot's blueprint list, §3.10): no parts; partCount;
--             materials = the distinct part materials in Materials order; analysis copied when present
-- Both read only the known fields of the record and never mutate it.

local DT = require("../Definitions/Types")
local Materials = require("../Definitions/Materials")
local Schema = require("./Schema")

type PartData = Schema.PartData
type BlueprintAnalysis = Schema.BlueprintAnalysis

local Views = {}

local function copyNumbers(t: { number }): { number }
	local out = table.create(#t)
	for k = 1, #t do
		out[k] = t[k]
	end
	return out
end

local function copyParts(parts: { PartData }): { PartData }
	local out: { PartData } = table.create(#parts)
	for i = 1, #parts do
		local p = parts[i]
		out[i] = {
			id = p.id,
			slot = p.slot,
			shape = p.shape,
			material = p.material,
			pos = copyNumbers(p.pos),
			rot = copyNumbers(p.rot),
			size = copyNumbers(p.size),
		}
	end
	return out
end

local function copyAnalysis(a: BlueprintAnalysis): BlueprintAnalysis
	local issues: { string } = table.create(#a.issues)
	for k = 1, #a.issues do
		issues[k] = a.issues[k]
	end
	local steps: { Schema.StepPreview } = table.create(#a.steps)
	for k = 1, #a.steps do
		local s = a.steps[k]
		steps[k] = { step = s.step, difficulty = s.difficulty, tier = s.tier }
	end
	local physics = a.physics
	return {
		balanceVersion = a.balanceVersion,
		valid = a.valid,
		issues = issues,
		physics = if physics then { mass = physics.mass, balance = physics.balance, reach = physics.reach } else nil,
		steps = steps,
	}
end

function Views.snapshot(r: Schema.BlueprintRecord): Schema.BlueprintSnapshot
	return {
		schema = r.schema,
		name = r.name,
		type = r.type,
		parts = copyParts(r.parts),
		sourceId = r.id,
		sourceRevision = r.revision,
	}
end

function Views.summary(r: Schema.BlueprintRecord): Schema.BlueprintSummary
	local present: { [string]: boolean } = {}
	for i = 1, #r.parts do
		present[r.parts[i].material] = true
	end
	local materials: { DT.MaterialId } = {}
	local ordered = Materials.ordered
	for k = 1, #ordered do
		if present[ordered[k].id] then
			table.insert(materials, ordered[k].id)
		end
	end
	local analysis = r.analysis
	return {
		id = r.id,
		name = r.name,
		type = r.type,
		revision = r.revision,
		updatedAt = r.updatedAt,
		partCount = #r.parts,
		materials = materials,
		analysis = if analysis then copyAnalysis(analysis) else nil,
	}
end

return table.freeze(Views)
