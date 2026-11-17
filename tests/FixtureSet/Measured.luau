--!strict
-- tests/FixtureSet/Measured.luau — the checks the measured fixture sets share (tests/fixtures/{Calibration, Regression,
-- Cost}, SPEC §14.7): records, structure against Definitions, the hitbox margin, the canonical fixed point, the port from
-- S2's prototype bit for bit (Lune only: the prototype is docs/, no Rojo root) and Physics' verdict (validity, cleaned
-- lists). Lune-only helper (not a spec, not a Rojo root); the specs pass their set in.

local A = require("../lib/Assert")
local Gen = require("../lib/Gen")
local Build = require("../fixtures/Build")
local Shape = require("./Shape")
local Balance = require("../../src/shared/Definitions/Balance")
local EquipmentTypes = require("../../src/shared/Definitions/EquipmentTypes")
local Limits = require("../../src/shared/Definitions/Limits")
local Materials = require("../../src/shared/Definitions/Materials")
local Steps = require("../../src/shared/Definitions/Steps")
local Tiers = require("../../src/shared/Definitions/Tiers")
local Versions = require("../../src/shared/Definitions/Versions")
local Canonical = require("../../src/shared/Blueprint/Canonical")
local Analyze = require("../../src/shared/Physics/Analyze")

type Measured = Build.Measured

-- Through a cast, so luau-lsp stays out of the prototype's loose types: it is reference data, not game code.
local Proto: any = (require :: any)("../../docs/spec/prototypes/S2/v2/fixtures")

local SWORD = EquipmentTypes.get("Sword") :: any
local DEFS: Shape.Defs = {
	limits = Limits,
	typeDef = SWORD,
	materials = Materials,
	schema = Versions.BLUEPRINT_SCHEMA,
	shapes = Gen.SHAPES,
}
local CTX = Gen.context(Limits, SWORD, Materials.enabled, Versions.BLUEPRINT_SCHEMA, Balance.Geometry)

local M = {}

M.SWORD = SWORD
M.DEFS = DEFS
M.CTX = CTX

-- The prototype's fixtures by this set's ids: calibration() in order (C02 twice, Iron then Steel), regression()'s
-- entries and the two union blades they are measured against, perf().
function M.prototype(): { [string]: any }
	local out: { [string]: any } = {}
	local cal = { "C01", "C02", "C02s", "C04", "C05", "C06", "C07", "C08", "C09", "C10", "C11", "C12", "C13", "C14", "C15" }
	for i, b in ipairs(Proto.calibration()) do
		out[cal[i]] = b
	end
	for _, r in ipairs(Proto.regression()) do
		out[r.id] = r.fixture
		if r.id == "X01" or r.id == "X02" then
			out[r.id .. "base"] = r.base
		end
	end
	for i, b in ipairs(Proto.perf()) do
		out["P" .. i] = b
	end
	return out
end

-- ids, labels and the index, as Blueprints.spec's first case.
function M.records(set: any, count: number)
	A.eq(#set.list, count, "fixtures")
	A.eq(#set.order, count, "order")
	local seen: { [string]: boolean } = {}
	for i, f in set.list do
		A.eq(f.id, set.order[i], "list order")
		A.falsy(seen[f.id], "duplicate id " .. f.id)
		seen[f.id] = true
		A.eq(set.get(f.id), f, "get(" .. f.id .. ")")
		A.truthy(#f.label > #f.id and #f.what > 0 and #f.core.name > 0, f.id .. " is labelled and described")
	end
	A.throws(function()
		set.get("F1")
	end, "no fixture F1")
end

-- The records' expectations, well-formed: every enabled step a played tier that is enabled and a tierRaw that exists
-- (the played one clamped to the last enabled tier), the save following validity, cleaned lists in part order.
function M.expectations(set: any)
	local tierIds: { string } = {}
	for _, row in Tiers.ordered do
		table.insert(tierIds, row.id)
	end
	for _, f in set.list do
		local e = f.expect
		A.eq(e.canon.ok, true, f.id)
		A.eq(e.canon.equals, "draft", f.id)
		A.eq(e.validation.valid, #e.validation.errors == 0, f.id .. " valid ⇔ no errors")
		A.eq(e.save, if e.validation.valid then "Valid" else "Invalid", f.id .. " save follows validation")
		local n = 0
		for _ in e.tiers do
			n += 1
		end
		A.eq(n, #Steps.enabled, f.id .. " one tier per enabled step")
		for _, step in Steps.enabled do
			local played = e.tiers[step.id]
			A.truthy(played and Tiers.isEnabled(played), f.id .. " " .. step.id .. " plays an enabled tier")
			local raw = e.tierRaw[step.id]
			A.truthy(raw and table.find(tierIds, raw) ~= nil, f.id .. " " .. step.id .. " tierRaw")
			if raw ~= played then
				A.eq(played, Tiers.enabled[#Tiers.enabled].id, f.id .. " " .. step.id .. " clamps to the last enabled tier")
			end
		end
		local last = 0
		for _, c in e.cleaned do
			A.truthy(c.reason == "Dust" or c.reason == "Enclosed", f.id .. " cleaned reason")
			A.truthy(c.partId > last, f.id .. " cleaned in part order")
			last = c.partId
		end
	end
end

-- Canonical BlueprintCores within Definitions' limits and slot rules, every part at least 0.02 stud inside the hitbox
-- (SPEC §14.7) but those in exempt, whose margin is given.
function M.structure(set: any, exempt: { [string]: number }?)
	for _, f in set.list do
		A.eq(table.concat(Shape.problems(f.core, DEFS), "; "), "", f.id)
		A.eq(table.concat(Shape.slotProblems(f.core, SWORD), "; "), "", f.id .. " slot counts")
		local margin = Gen.margin(CTX, f.core.parts)
		local floor = if exempt and exempt[f.id] then exempt[f.id] else 0.02
		A.truthy(margin >= floor - 1e-12, string.format("%s margin %.17g", f.id, margin))
	end
end

-- Canonical.draft(core) is ok and returns core bit for bit.
function M.canonical(set: any)
	for _, f in set.list do
		local ok, result = pcall(Canonical.draft, f.core)
		A.truthy(ok, f.id .. " Canonical.draft threw: " .. tostring(result))
		local r: any = result
		A.truthy(r.ok, f.id .. " accepted")
		A.eq(Shape.bitDifference(r.value, f.core), nil, f.id .. " canonical value = the fixture, bit for bit")
		A.truthy(Canonical.isCanonical(f.core :: any), f.id .. " isCanonical")
	end
end

-- Each fixture's parts are the prototype's, field by field and bit for bit (its labels aside).
function M.port(set: any, ids: { string })
	local proto = M.prototype()
	for _, id in ids do
		local f = set.get(id)
		local b = proto[id]
		A.truthy(b ~= nil, id .. " has a prototype")
		A.eq(#f.core.parts, #b.parts, id .. " part count")
		for i, p in f.core.parts do
			local q = b.parts[i]
			local theirs = { id = q.id, slot = q.slot, shape = q.shape, material = q.material, pos = q.pos, rot = q.rot,
				size = q.size }
			A.eq(Shape.bitDifference(p, theirs), nil, id .. " part " .. i)
		end
	end
end

-- Physics' verdict: the expected validation errors (codes and parts) and cleaned list, from Analyze.run without
-- measureInvalid.
function M.verdicts(set: any)
	for _, f in set.list do
		local report = Analyze.run(f.core :: any)
		local errors: { { code: string, partId: number? } } = {}
		for _, e in report.validation.errors do
			local code: string = e.code
			table.insert(errors, { code = code, partId = e.partId })
		end
		A.eq(report.validation.ok, f.expect.validation.valid, f.id .. " valid")
		A.deepEq(errors, f.expect.validation.errors, f.id .. " errors")
		A.deepEq(report.cleaned, f.expect.cleaned, f.id .. " cleaned")
	end
end

-- Deep-frozen; core(id) hands out a fresh mutable copy.
function M.frozen(set: any)
	for _, f in set.list do
		A.truthy(table.isfrozen(f.core) and table.isfrozen(f.core.parts) and table.isfrozen(f.core.parts[1].pos)
			and table.isfrozen(f.expect.tiers), f.id .. " frozen")
		local copy = set.core(f.id)
		A.eq(Shape.bitDifference(copy, f.core), nil, f.id .. " copy equals")
		A.truthy(copy ~= f.core and copy.parts[1] ~= f.core.parts[1], f.id .. " copy shares no table")
	end
end

return table.freeze(M)
