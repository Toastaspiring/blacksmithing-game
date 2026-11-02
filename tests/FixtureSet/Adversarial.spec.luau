--!strict
-- The adversarial drafts A01–A24 (SPEC §14.7, E-S8.4): the set's shape (ids, variants, fresh deterministic drafts),
-- well-formed expectations, coverage of every CanonError, ValidationCode and wire code, each `save` against a model
-- of §10.3's Guard, the Definitions values the constructions assume, and the premises of each construction that the
-- test side can measure now (slot counts, exact containment, gaps, Dust volumes, enclosure, copies). The verdicts
-- themselves wait for their milestone: Canonical's in tests/FixtureSet/Canonical.spec.luau (M1), validation and
-- analysis in M2/M3, the wire answers in M7 (S-E2E-04).

local Test = require("../lib/Test")
local A = require("../lib/Assert")
local Dump = require("../lib/Dump")
local Gen = require("../lib/Gen")
local Adversarial = require("../fixtures/Adversarial")
local Blueprints = require("../fixtures/Blueprints")
local Shape = require("./Shape")
local Balance = require("../../src/shared/Definitions/Balance")
local EquipmentTypes = require("../../src/shared/Definitions/EquipmentTypes")
local Limits = require("../../src/shared/Definitions/Limits")
local Materials = require("../../src/shared/Definitions/Materials")
local Network = require("../../src/shared/Definitions/Network")
local Versions = require("../../src/shared/Definitions/Versions")

type Variant = Adversarial.Variant

local SWORD = EquipmentTypes.get("Sword") :: any
local DEFS: Shape.Defs = {
	limits = Limits,
	typeDef = SWORD,
	materials = Materials,
	schema = Versions.BLUEPRINT_SCHEMA,
	shapes = Gen.SHAPES,
}
local CTX = Gen.context(Limits, SWORD, Materials.enabled, Versions.BLUEPRINT_SCHEMA, Balance.Geometry)

-- SPEC §3.11 CanonError, §4.7 ValidationCode, and what a Save can answer (§10.2, §10.3)
local CANON_ERRORS = {
	"Malformed", "UnsupportedSchema", "UnknownId", "DisabledId", "SlotNotInType", "MaterialNotAllowed", "TooManyParts",
	"DuplicatePartId", "NonFinite", "OutOfRange", "BadRotation", "BadName",
}
local VALIDATION_CODES = { "SlotMissing", "SlotTooMany", "OutOfHitbox", "Disconnected", "BladeNotAboveGrip" }
local SAVES = { "Valid", "Invalid", "E_INVALID_BLUEPRINT", "E_BAD_REQUEST" }
local QUICK = { SlotMissing = true, SlotTooMany = true, OutOfHitbox = true } -- V1–V2 (SlotMissing without a reason)

local function isPath(path: string): boolean
	return path == "" or path == "schema" or path == "name" or path == "type" or path == "parts"
		or string.match(path, "^parts%[%d+%]$") ~= nil
		or (string.match(path, "^parts%[%d+%]%.(%a+)$") ~= nil
			and table.find(Shape.PART_FIELDS, string.match(path, "%.(%a+)$") :: string) ~= nil)
end

-- Small drafts only: the A15/A18 drafts are compared by size.
local function fingerprint(d: any): string
	if type(d) == "table" and type(d.parts) == "table" and (#d.parts > 100 or (type(d.name) == "string" and #d.name > 1000)) then
		return string.format("parts=%d name=%d", #d.parts, if type(d.name) == "string" then #d.name else -1)
	end
	return Dump.canonical(d)
end

local function partById(d: any, id: number): Gen.Part
	for _, p in d.parts do
		if p.id == id then
			return p
		end
	end
	error("no part " .. id)
end

-- How far each part's exact AABB reaches past the hitbox (≤ 0 when inside), by part id.
local function overshoot(d: any): { [number]: number }
	local out: { [number]: number } = {}
	for _, p in d.parts do
		local lo, hi = Gen.aabb(p)
		local worst = -math.huge
		for k = 1, 3 do
			worst = math.max(worst, CTX.hitboxMin[k] - lo[k], hi[k] - CTX.hitboxMax[k])
		end
		out[p.id] = worst
	end
	return out
end

-- SPEC §10.3's Guard for Blueprint.Save, modelled until Net/Guard lands (M7): G.rec({ blueprintId = G.guid(),
-- draft = G.plain(MAX_DRAFT_DEPTH) }) within MAX_PAYLOAD_NODES. plain admits nil, booleans, finite numbers, strings
-- of at most 256 B and tables with string or integer keys nested at most MAX_DRAFT_DEPTH tables deep; every value
-- it visits spends one node, and the record and its id spend one each. Why the Guard refuses a draft, or nil.
local PLAIN_STRING_MAX_BYTES = 256
local function guardRefusal(draft: any): string?
	local budget = Network.MAX_PAYLOAD_NODES - 2
	local function walk(x: any, path: string, depth: number): string?
		budget -= 1
		if budget < 0 then
			return path .. ": payload too large"
		end
		local kind = type(x)
		if kind == "nil" or kind == "boolean" then
			return nil
		elseif kind == "number" then
			return if x == x and x ~= math.huge and x ~= -math.huge then nil else path .. ": non-finite number"
		elseif kind == "string" then
			return if #x <= PLAIN_STRING_MAX_BYTES then nil else path .. ": string over 256 B"
		elseif kind ~= "table" then
			return path .. ": unsupported type " .. kind
		end
		if depth >= Network.MAX_DRAFT_DEPTH then
			return path .. ": too deep"
		end
		for k, c in x do
			if not (type(k) == "string" or (type(k) == "number" and k % 1 == 0)) then
				return path .. ": bad key"
			end
			local err = walk(c, path .. "." .. tostring(k), depth + 1)
			if err then
				return err
			end
		end
		return nil
	end
	return walk(draft, "draft", 0)
end

-- The gap between two axis-aligned Blocks along x (positive when apart).
local function gapX(a: Gen.Part, b: Gen.Part): number
	local alo, ahi = Gen.aabb(a)
	local blo, bhi = Gen.aabb(b)
	return math.max(blo[1] - ahi[1], alo[1] - bhi[1])
end

return Test.suite("FixtureSet/Adversarial", function(t)
	t.it("A01–A24 in order, every case with variants, keys unique", function()
		A.eq(#Adversarial.list, 24, "cases")
		local seen: { [string]: boolean } = {}
		local count = 0
		for i, c in Adversarial.list do
			A.eq(c.id, string.format("A%02d", i), "case order")
			A.eq(Adversarial.order[i], c.id)
			A.eq(Adversarial.get(c.id), c)
			A.truthy(#c.title > 0 and #c.variants > 0, c.id .. " has a title and variants")
			for _, v in c.variants do
				count += 1
				A.falsy(seen[v.key], "duplicate key " .. v.key)
				seen[v.key] = true
				A.eq(string.sub(v.key, 1, 3), c.id, v.key .. " starts with its case id")
				A.eq(Adversarial.variant(v.key), v)
				A.truthy(#v.what > 0, v.key .. " says what it is")
				A.truthy(v.base == nil or v.base == "F1" or v.base == "F2", v.key .. " base")
				A.eq(type(v.draft), "function", v.key)
			end
		end
		A.eq(#Adversarial.variants, count, "flattened variants")
		A.throws(function()
			Adversarial.get("A25")
		end, "no case A25")
	end)

	t.it("draft() builds a fresh, identical draft on every call", function()
		for _, v in Adversarial.variants do
			local a, b = v.draft(), v.draft()
			if type(a) == "table" then
				A.truthy(a ~= b, v.key .. " fresh table")
				if type(a.parts) == "table" and type(b.parts) == "table" and #a.parts > 0 then
					A.truthy(a.parts[1] ~= b.parts[1], v.key .. " fresh parts")
				end
			end
			A.eq(fingerprint(a), fingerprint(b), v.key .. " deterministic")
		end
	end)

	t.it("expected outcomes are well-formed and agree with each other", function()
		for _, v in Adversarial.variants do
			local c = v.canon
			if c.ok then
				A.truthy(c.code == nil and c.path == nil, v.key .. " an accepted draft has no code")
				A.truthy((c.equals ~= nil) ~= (c.renormalized ~= nil), v.key .. " ok: equals or renormalized")
				if c.equals and c.equals ~= "draft" then
					Blueprints.get(c.equals) -- errors on an unknown fixture
				end
			else
				A.truthy(table.find(CANON_ERRORS, c.code or "") ~= nil, v.key .. " code " .. tostring(c.code))
				A.truthy(type(c.path) == "string" and isPath(c.path :: string), v.key .. " path " .. tostring(c.path))
				A.truthy(c.equals == nil and c.renormalized == nil and v.validation == nil and v.analysis == nil,
					v.key .. " a refused draft has no later verdicts")
				A.truthy(v.save == "E_INVALID_BLUEPRINT" or v.save == "E_BAD_REQUEST", v.key .. " refused by the wire")
			end
			A.truthy(v.save == nil or table.find(SAVES, v.save) ~= nil, v.key .. " save " .. tostring(v.save))
			local val = v.validation
			if val then
				A.eq(val.valid, #val.errors == 0, v.key .. " valid ⇔ no errors")
				A.eq(v.save, if val.valid then "Valid" else "Invalid", v.key .. " save follows validation")
				local quick, full = 0, 0
				for _, e in val.errors do
					A.truthy(table.find(VALIDATION_CODES, e.code) ~= nil, v.key .. " code " .. e.code)
					local needsPart = e.code == "OutOfHitbox" or e.code == "Disconnected"
					local needsSlot = e.code == "SlotMissing" or e.code == "SlotTooMany"
					A.eq(e.partId ~= nil, needsPart, v.key .. " " .. e.code .. " partId")
					A.eq(e.slot ~= nil, needsSlot, v.key .. " " .. e.code .. " slot")
					A.truthy(e.reason == nil or (e.code == "SlotMissing" and e.reason == "Cleaned"), v.key .. " reason")
					if QUICK[e.code] and e.reason == nil then
						quick += 1
					else
						full += 1
					end
				end
				A.truthy(quick == 0 or full == 0, v.key .. " errors come from one stage (SPEC §4.2)")
			end
			if v.analysis and v.analysis.cleaned then
				for _, cl in v.analysis.cleaned do
					A.truthy(cl.reason == "Dust" or cl.reason == "Enclosed", v.key .. " cleaned reason")
				end
			end
		end
	end)

	t.it("the set holds every CanonError, ValidationCode and wire answer (SPEC §14.7)", function()
		local canon: { [string]: number } = {}
		local validation: { [string]: number } = {}
		local saves: { [string]: number } = {}
		for _, v in Adversarial.variants do
			if not v.canon.ok then
				canon[v.canon.code :: string] = (canon[v.canon.code :: string] or 0) + 1
			end
			if v.validation then
				for _, e in v.validation.errors do
					local key = e.code .. (if e.reason then "(" .. e.reason .. ")" else "")
					validation[key] = (validation[key] or 0) + 1
				end
			end
			if v.save then
				saves[v.save] = (saves[v.save] or 0) + 1
			end
		end
		for _, code in CANON_ERRORS do
			if code ~= "MaterialNotAllowed" then
				A.truthy(canon[code], "no draft refused with " .. code)
			end
		end
		-- MaterialNotAllowed needs an enabled material that restricts its slots; the MVP has none, so no draft can
		-- reach it (Canonical's own tests plant it). A material with allowedSlots needs a draft here.
		for _, m in Materials.enabled do
			A.eq((m :: any).allowedSlots, nil, m.id .. " restricts its slots: add a MaterialNotAllowed draft")
		end
		for _, code in VALIDATION_CODES do
			A.truthy(validation[code], "no draft fails validation with " .. code)
		end
		A.truthy(validation["SlotMissing(Cleaned)"], "no draft with SlotMissing{reason = Cleaned}")
		for _, s in SAVES do
			A.truthy(saves[s], "no draft whose Save answers " .. s)
		end
	end)

	t.it("save is E_BAD_REQUEST exactly when §10.3's Guard refuses the draft", function()
		local refused, admitted = 0, 0
		for _, v in Adversarial.variants do
			if v.save == nil then
				continue
			end
			local why = guardRefusal(v.draft())
			if why then
				refused += 1
			else
				admitted += 1
			end
			A.eq(v.save == "E_BAD_REQUEST", why ~= nil, string.format("%s save = %s, but the Guard %s", v.key,
				tostring(v.save), if why then "refuses it (" .. why .. ")" else "admits it"))
		end
		A.truthy(refused >= 30 and admitted >= 90, string.format("refused %d, admitted %d", refused, admitted))
		-- the model itself: F2, MAX_DRAFT_DEPTH levels and MAX_PAYLOAD_NODES nodes are admitted; one level or one node
		-- more, a NaN, a fractional key or a 257-byte string is refused
		A.eq(guardRefusal(Blueprints.core("F2")), nil, "F2 admitted")
		A.eq(guardRefusal({ { { { 0 } } } }), nil, "MAX_DRAFT_DEPTH levels admitted")
		A.truthy(guardRefusal({ { { { { 0 } } } } }) ~= nil, "MAX_DRAFT_DEPTH + 1 levels refused")
		A.truthy(guardRefusal({ name = 0 / 0 }) ~= nil, "NaN refused")
		A.truthy(guardRefusal({ [1.5] = true }) ~= nil, "a fractional key refused")
		A.truthy(guardRefusal(string.rep("A", 257)) ~= nil, "a 257-byte string refused")
		local wide: { number } = table.create(Network.MAX_PAYLOAD_NODES - 3, 0)
		A.eq(guardRefusal(wide), nil, "MAX_PAYLOAD_NODES nodes admitted")
		table.insert(wide, 0)
		A.truthy(guardRefusal(wide) ~= nil, "MAX_PAYLOAD_NODES + 1 nodes refused")
	end)

	t.it("ASSUMED matches Definitions", function()
		local a = Adversarial.ASSUMED
		A.eq(a.BLUEPRINT_SCHEMA, Versions.BLUEPRINT_SCHEMA, "BLUEPRINT_SCHEMA")
		for _, key in {
			"EPS_CONTAIN", "CONTACT_TOL", "MIN_DIM", "MAX_DIM", "POS_ABS_MAX", "MAX_PARTS", "MAX_PART_ID", "QUAT_NORM_TOL",
			"QUAT_INPUT_TOL", "NAME_MAX_INPUT_BYTES",
		} do
			A.eq((a :: any)[key], (Limits :: any)[key], key)
		end
		A.eq(a.MIN_PART_VOLUME, Balance.Geometry.MIN_PART_VOLUME, "MIN_PART_VOLUME")
		A.deepEq(Dump.canonical(a.HITBOX_MIN), Dump.canonical(SWORD.geometry.hitboxMin), "HITBOX_MIN")
		A.deepEq(Dump.canonical(a.HITBOX_MAX), Dump.canonical(SWORD.geometry.hitboxMax), "HITBOX_MAX")
		for _, s in SWORD.slots do
			A.eq((a.SLOT_MAX :: any)[s.id], s.max, "slot maximum " .. s.id)
		end
		local disabled = Materials.get(a.DISABLED_MATERIAL)
		A.truthy(disabled ~= nil and disabled.enabled == false, a.DISABLED_MATERIAL .. " is a disabled row")
	end)

	t.it("drafts Canonical must keep as they are are canonical BlueprintCores", function()
		local checked = 0
		for _, v in Adversarial.variants do
			if v.canon.ok and v.canon.equals == "draft" then
				checked += 1
				A.eq(table.concat(Shape.problems(v.draft(), DEFS), "; "), "", v.key)
			end
		end
		A.truthy(checked >= 20, "canonical drafts checked: " .. checked)
	end)

	t.it("V1–V2 expectations agree with the slot counts and the exact containment", function()
		local checked = 0
		for _, v in Adversarial.variants do
			local val = v.validation
			if val == nil then
				continue
			end
			checked += 1
			local d = v.draft()
			-- what the quick stage must find: slot counts outside their rule, then parts past EPS_CONTAIN
			local quick: { string } = {}
			for _, s in SWORD.slots do
				local n = Shape.count(d, s.id)
				if n < s.min then
					table.insert(quick, "SlotMissing:" .. s.id)
				elseif n > s.max then
					table.insert(quick, "SlotTooMany:" .. s.id)
				end
			end
			local over = overshoot(d)
			for _, p in d.parts do
				if over[p.id] > Limits.EPS_CONTAIN then
					table.insert(quick, "OutOfHitbox#" .. p.id)
				end
			end
			local expected: { string } = {}
			for _, e in val.errors do
				if QUICK[e.code] and e.reason == nil then
					table.insert(expected, e.code .. (if e.slot then ":" .. e.slot else "#" .. tostring(e.partId)))
				end
			end
			A.eq(table.concat(expected, ","), table.concat(quick, ","), v.key .. " quick-stage errors")
		end
		A.truthy(checked >= 20, "variants with a validation expectation: " .. checked)
	end)

	t.it("construction premises: A03's box, A04/A05 walls, A06/A07 gaps", function()
		-- A03: the exact solid is inside with 0.03 to spare, the turned Size box is not
		local a03 = Adversarial.variant("A03").draft()
		local disc = partById(a03, 1)
		local lo, hi = Gen.aabb(disc)
		A.near(lo[2], 0.03, 1e-12, "A03 solid bottom")
		A.near(hi[2], 0.35, 1e-12, "A03 solid top touches the grip")
		local box = table.clone(disc)
		box.shape = "Block"
		local blo = Gen.aabb(box)
		A.truthy(blo[2] < -0.03, string.format("A03 the box corners are out (y %.4f)", blo[2]))
		-- A04 flush, A05a within EPS_CONTAIN, A05b past it
		local eps = Limits.EPS_CONTAIN
		A.eq(overshoot(Adversarial.variant("A04").draft())[3], 0, "A04 flush")
		A.near(overshoot(Adversarial.variant("A05a").draft())[3], 0.5 * eps, 1e-12, "A05a 0.5 · EPS_CONTAIN out")
		A.near(overshoot(Adversarial.variant("A05b").draft())[3], 2 * eps, 1e-12, "A05b 2 · EPS_CONTAIN out")
		A.near(overshoot(Adversarial.variant("A01").draft())[4], 0.01, 1e-12, "A01 0.01 out")
		A.truthy(overshoot(Adversarial.variant("A02").draft())[3] > 0.05, "A02 corners out")
		local gaps: { { key: string, gap: number } } = {
			{ key = "A06", gap = 0.1 },
			{ key = "A07a", gap = 0.5 * Limits.CONTACT_TOL },
			{ key = "A07b", gap = 2 * Limits.CONTACT_TOL },
		}
		for _, g in gaps do
			local d = Adversarial.variant(g.key).draft()
			A.near(gapX(partById(d, 3), partById(d, 5)), g.gap, 1e-12, g.key .. " gap")
		end
	end)

	t.it("construction premises: Dust, enclosure and copies (A14, A16, A17, A22)", function()
		local dust = Balance.Geometry.MIN_PART_VOLUME
		local a14 = Adversarial.variant("A14").draft()
		A.eq(#a14.parts, Limits.MAX_PARTS, "A14 fills MAX_PARTS")
		for _, cl in (Adversarial.variant("A14").analysis :: any).cleaned do
			A.truthy(Gen.volume(partById(a14, cl.partId)) < dust, "A14 part " .. cl.partId .. " is Dust")
		end
		A.truthy(Gen.volume(partById(Adversarial.variant("A22a").draft(), 4)) < dust, "A22a's blade is Dust")
		-- enclosed parts: inside their host by at least 0.01 on every side, and not Dust
		local function enclosed(key: string, inner: number, host: number)
			local d = Adversarial.variant(key).draft()
			local ilo, ihi = Gen.aabb(partById(d, inner))
			local hlo, hhi = Gen.aabb(partById(d, host))
			for k = 1, 3 do
				A.truthy(ilo[k] >= hlo[k] + 0.01 - 1e-12 and ihi[k] <= hhi[k] - 0.01 + 1e-12,
					string.format("%s part %d inside part %d (axis %d)", key, inner, host, k))
			end
			A.truthy(Gen.volume(partById(d, inner)) >= dust, key .. " part " .. inner .. " is not Dust")
		end
		enclosed("A16", 6, 4)
		enclosed("A16", 7, 3)
		enclosed("A22b", 4, 3)
		enclosed("A22c", 2, 1)
		local a17 = Adversarial.variant("A17").draft()
		for id = 5, 7 do
			local copy = table.clone(partById(a17, id))
			copy.id = 4
			A.eq(Shape.bitDifference(copy, partById(a17, 4)), nil, "A17 part " .. id .. " copies part 4")
		end
	end)
end)
