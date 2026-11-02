--!strict
-- T-BP-01…05 Blueprint/Canonical (SPEC §3.5, §3.6, §3.11, §14.5, E-S8.5):
--   01 total, code + path: every check of §3.6 in its order; hostile values never throw (FUZZ_N_GARBAGE); the codes
--      the MVP data cannot reach (a disabled type, MaterialNotAllowed) and P-ORDER on planted Definitions
--   02 idempotent bit for bit (PROP_N drafts; 10^5 in the slow set, I11)
--   03 output: known fields, finite, ‖q‖² within 1e-9, hemisphere, sizes in [MIN_DIM, MAX_DIM], |pos| ≤ POS_ABS_MAX,
--      Ball/Cylinder rules, sorted ids, no shared tables
--   04 bounds rejected, never clamped (A11, A12), isCanonical, GUID ids
--   05 a 24-part draft ≤ S1's wire size (8,175 B, E-S1.4) and inside S5's Guard bounds
-- Generators: tests/Blueprint/Drafts on Prop's seeds (Tol.PROP_BASE_SEED).

local Test = require("../lib/Test")
local A = require("../lib/Assert")
local Dump = require("../lib/Dump")
local Prop = require("../lib/Prop")
local Tol = require("../lib/Tol")
local TestRng = require("../lib/TestRng")
local Drafts = require("./Drafts")
local Canonical = require("../../src/shared/Blueprint/Canonical")
local Names = require("../../src/shared/Blueprint/Names")
local Catalog = require("../../src/shared/Definitions/Catalog")
local EquipmentTypes = require("../../src/shared/Definitions/EquipmentTypes")
local Limits = require("../../src/shared/Definitions/Limits")
local Materials = require("../../src/shared/Definitions/Materials")
local Network = require("../../src/shared/Definitions/Network")
local Versions = require("../../src/shared/Definitions/Versions")

type TestRng = TestRng.TestRng

local CODES: { [string]: boolean } = {
	Malformed = true, UnsupportedSchema = true, UnknownId = true, DisabledId = true, SlotNotInType = true,
	MaterialNotAllowed = true, TooManyParts = true, DuplicatePartId = true, NonFinite = true, OutOfRange = true,
	BadRotation = true, BadName = true,
}

local WIRE_DRAFT_MAX_BYTES = 8175 -- S1's worst 24-part draft (E-S1.4, §3.10)

-- ── helpers ───────────────────────────────────────────────────────────────────────────────────────────────────

local function ok(raw: any): any
	local r: any = Canonical.draft(raw)
	if not r.ok then
		A.fail("expected ok, got " .. tostring(r.code) .. " at " .. Dump.quote(tostring(r.path)))
	end
	return r.value
end

local function refused(raw: any, code: string, path: string, what: string?)
	local r: any = Canonical.draft(raw)
	local label = if what then what .. ": " else ""
	if r.ok then
		A.fail(label .. "expected " .. code .. " at " .. Dump.quote(path) .. ", got ok")
	end
	if r.code ~= code or r.path ~= path then
		A.fail(string.format("%sexpected %s at %s, got %s at %s", label, code, Dump.quote(path), tostring(r.code),
			Dump.quote(tostring(r.path))))
	end
end

local function keys(t: any): string
	local out = {}
	for _, k in Dump.sortedKeys(t) do
		table.insert(out, tostring(k))
	end
	return table.concat(out, ",")
end

local function isTuple(t: any, n: number): boolean
	if type(t) ~= "table" or #t ~= n or #Dump.sortedKeys(t) ~= n then
		return false
	end
	for k = 1, n do
		local x = t[k]
		if type(x) ~= "number" or x ~= x or x == math.huge or x == -math.huge then
			return false
		end
	end
	return true
end

local function positiveZeros(t: { number }): boolean
	for k = 1, #t do
		if t[k] == 0 and 1 / t[k] < 0 then
			return false
		end
	end
	return true
end

local function inHemisphere(q: { number }): boolean
	if q[4] ~= 0 then
		return q[4] > 0
	end
	for k = 1, 3 do
		if q[k] ~= 0 then
			return q[k] > 0
		end
	end
	return false
end

-- T-BP-03: nil when d is a canonical draft, else the first problem.
local function outputProblem(d: any): string?
	if type(d) ~= "table" then
		return "the draft is not a table"
	end
	if keys(d) ~= "name,parts,schema,type" then
		return "draft keys " .. keys(d)
	end
	if d.schema ~= Versions.BLUEPRINT_SCHEMA then
		return "schema"
	end
	if type(d.name) ~= "string" or Names.sanitize(d.name) ~= d.name then
		return "name is not a sanitized name"
	end
	local typeDef: any = EquipmentTypes.get(d.type)
	if typeDef == nil or not typeDef.enabled then
		return "type"
	end
	local parts = d.parts
	if type(parts) ~= "table" or #Dump.sortedKeys(parts) ~= #parts or #parts > Limits.MAX_PARTS then
		return "parts is not an array of at most MAX_PARTS parts"
	end
	local lastId = 0
	for i = 1, #parts do
		local p = parts[i]
		local at = "parts[" .. i .. "]"
		if type(p) ~= "table" or keys(p) ~= "id,material,pos,rot,shape,size,slot" then
			return at .. " keys " .. (if type(p) == "table" then keys(p) else type(p))
		end
		if type(p.id) ~= "number" or p.id % 1 ~= 0 or p.id < 1 or p.id > Limits.MAX_PART_ID then
			return at .. ".id out of 1..MAX_PART_ID"
		end
		if p.id <= lastId then
			return at .. ".id not strictly ascending"
		end
		lastId = p.id
		local slotOk = false
		for _, s in typeDef.slots do
			slotOk = slotOk or s.id == p.slot
		end
		if not slotOk then
			return at .. ".slot not a slot of the type"
		end
		if table.find(Drafts.SHAPE_IDS, p.shape) == nil then
			return at .. ".shape unknown"
		end
		if not Materials.isEnabled(p.material) then
			return at .. ".material not enabled"
		end
		if not (isTuple(p.pos, 3) and isTuple(p.size, 3) and isTuple(p.rot, 4)) then
			return at .. " transform tuples are not exactly 3 / 3 / 4 finite numbers"
		end
		for k = 1, 3 do
			if math.abs(p.pos[k]) > Limits.POS_ABS_MAX then
				return at .. ".pos beyond POS_ABS_MAX"
			end
			if p.size[k] < Limits.MIN_DIM or p.size[k] > Limits.MAX_DIM then
				return at .. ".size outside [MIN_DIM, MAX_DIM]"
			end
		end
		if not (positiveZeros(p.pos) and positiveZeros(p.rot)) then
			return at .. " has a −0"
		end
		local s = p.size
		if p.shape == "Ball" and not (s[1] == s[2] and s[2] == s[3]) then
			return at .. " Ball sides differ"
		end
		if p.shape == "Cylinder" and s[2] ~= s[3] then
			return at .. " Cylinder Y ≠ Z"
		end
		local q = p.rot
		local m = q[1] * q[1] + q[2] * q[2] + q[3] * q[3] + q[4] * q[4]
		if math.abs(m - 1) > Limits.QUAT_NORM_TOL then
			return string.format("%s.rot |‖q‖² − 1| = %.3g > 1e-9", at, math.abs(m - 1))
		end
		if not inHemisphere(q) then
			return at .. ".rot outside the hemisphere"
		end
	end
	if Drafts.repeatsTable(d) then
		return "a table is referenced twice"
	end
	return nil
end

local function expectCanonical(d: any, what: string?)
	local problem = outputProblem(d)
	if problem then
		A.fail((if what then what .. ": " else "") .. problem)
	end
end

local function withPart(draft: any, i: number, field: string, value: any): any
	draft.parts[i][field] = value
	return draft
end

-- Iterating a table literal skips nil entries, so lists of values to try say NONE where they mean nil.
local NONE = table.freeze({})
local function val(x: any): any
	return if x == NONE then nil else x
end

-- The longest of a list of ids (the first one on a tie).
local function longest(ids: { string }): string
	local best = ids[1]
	for _, id in ids do
		if #id > #best then
			best = id
		end
	end
	return best
end

-- The worst 24-part draft of E-S1.4 (S1/sizes2.luau) that Canonical accepts: 25-character positions and quaternion
-- components, 20-character sizes, 5-digit ids, a 64-byte name, the longest slot, shape and enabled material ids
-- (S1 measured 8,175 B with Obsidian, a disabled Phase 2 row; the MVP's longest enabled id is Steel).
local POS_W = -0.0000021366226676248005
local SIZE_W = 0.036324661366823635
local function worstDraft(): any
	local qw = math.sqrt(1 - 3 * POS_W * POS_W)
	local slot, shape, material = longest(Drafts.SLOT_IDS), longest(Drafts.SHAPE_IDS), longest(Drafts.MATERIAL_IDS)
	local parts = {}
	for i = 1, Limits.MAX_PARTS do
		parts[i] = Drafts.part(Limits.MAX_PART_ID - Limits.MAX_PARTS + i, slot, shape, material,
			{ POS_W, POS_W, POS_W }, { POS_W, POS_W, POS_W, qw }, { SIZE_W, SIZE_W, SIZE_W })
	end
	return { schema = Versions.BLUEPRINT_SCHEMA, name = string.rep("é", 32), type = "Sword", parts = parts }
end

-- Canonical on planted Definitions (Drafts.planted): the real modules, except the catalogs passed in.
local CANONICAL_PATH = "src/shared/Blueprint/Canonical.luau"
local function plantedCanonical(equipmentTypes: any, materials: any): any
	return Drafts.planted(CANONICAL_PATH, {
		["../Definitions/Types"] = require("../../src/shared/Definitions/Types"),
		["../Definitions/EquipmentTypes"] = equipmentTypes,
		["../Definitions/Limits"] = Limits,
		["../Definitions/Materials"] = materials,
		["../Definitions/Versions"] = Versions,
		["./Names"] = Names,
		["./Quat"] = require("../../src/shared/Blueprint/Quat"),
		["./Schema"] = require("../../src/shared/Blueprint/Schema"),
	})
end

-- Guard-style node count (every table and leaf once) and table nesting depth (the value itself = 1).
local function nodes(v: any): number
	if type(v) ~= "table" then
		return 1
	end
	local n = 1
	for _, c in v do
		n += nodes(c)
	end
	return n
end
local function depth(v: any): number
	if type(v) ~= "table" then
		return 0
	end
	local d = 0
	for _, c in v do
		d = math.max(d, depth(c))
	end
	return d + 1
end

return Test.suite("Blueprint/Canonical", function(t)
	-- ── T-BP-01 ───────────────────────────────────────────────────────────────────────────────────────────────

	t.it("T-BP-01 every check of §3.6 refuses with its code and the client's path", function()
		local f2 = Drafts.f2 -- client order: ids 3, 1, 4, 2
		ok(f2())
		-- 1 not a table
		for _, raw in ({ "draft", 5, true, false, NONE, 0 / 0 } :: { any }) do
			refused(val(raw), "Malformed", "", Dump.short(val(raw)))
		end
		-- 2 schema
		for _, schema in ({ 0, 2, "1", NONE, 0 / 0, 1.5, {} } :: { any }) do
			local d = f2()
			d.schema = val(schema)
			refused(d, "UnsupportedSchema", "schema", Dump.short(val(schema)))
		end
		-- 3 name
		for _, name in ({ "<b>Sword</b>", "", "   ", "...", string.rep("a", 33), 5, NONE, "Tab\tName" } :: { any }) do
			local d = f2()
			d.name = val(name)
			refused(d, "BadName", "name", Dump.short(val(name)))
		end
		-- 4 type
		for _, ty in ({ "Axe", "Dagger", "sword", 5, NONE, {} } :: { any }) do
			local d = f2()
			d.type = val(ty)
			refused(d, "UnknownId", "type", Dump.short(val(ty)))
		end
		-- 5 parts
		for _, parts in ({ "parts", 5, NONE, true, { a = 1 }, { [2] = {} } } :: { any }) do
			local d = f2()
			d.parts = val(parts)
			refused(d, "Malformed", "parts", Dump.short(val(parts)))
		end
		do
			local d = f2()
			for i = 5, Limits.MAX_PARTS + 1 do
				d.parts[i] = Drafts.part(i, "Blade", "Block", "Iron", { 0, 3, 0 }, Drafts.I, { 0.1, 0.1, 0.1 })
			end
			refused(d, "TooManyParts", "parts", "MAX_PARTS + 1 parts")
			table.remove(d.parts)
			ok(d) -- exactly MAX_PARTS
		end
		-- 6 identity fields
		for _, part in ({ "part", 5, true } :: { any }) do
			local d = f2()
			d.parts[2] = part
			refused(d, "Malformed", "parts[2]", Dump.short(part))
		end
		for _, id in ({ 0, -1, 1.5, Limits.MAX_PART_ID + 1, "1", 0 / 0, math.huge, NONE, -0.0 } :: { any }) do
			refused(withPart(f2(), 2, "id", val(id)), "Malformed", "parts[2].id", "id " .. Dump.short(val(id)))
		end
		ok(withPart(f2(), 2, "id", Limits.MAX_PART_ID))
		for _, slot in ({ "Hilt", "Head", "blade", 5, NONE } :: { any }) do
			refused(withPart(f2(), 3, "slot", val(slot)), "SlotNotInType", "parts[3].slot", Dump.short(val(slot)))
		end
		for _, shape in ({ "Sphere", "block", 5, NONE } :: { any }) do
			refused(withPart(f2(), 1, "shape", val(shape)), "UnknownId", "parts[1].shape", Dump.short(val(shape)))
		end
		for _, material in ({ "Gold", "iron", 5, NONE } :: { any }) do
			local m = val(material)
			refused(withPart(f2(), 4, "material", m), "UnknownId", "parts[4].material", Dump.short(m))
		end
		for _, def in Materials.ordered do
			if not def.enabled then
				refused(withPart(f2(), 4, "material", def.id), "DisabledId", "parts[4].material", def.id)
			end
		end
		-- 7 tuples
		local tupleCases: { { any } } = {
			{ "pos", { 0, 1 } }, { "pos", { 0, 1, 2, 3 } }, { "pos", { 0, "1", 2 } :: { any } }, { "pos", NONE },
			{ "pos", "0,1,2" }, { "size", { 1, 1 } }, { "size", { 1, 1, 1, 1 } }, { "size", { 1, true, 1 } :: { any } },
			{ "size", NONE }, { "rot", { 0, 0, 1 } }, { "rot", { 0, 0, 0, 1, 0 } }, { "rot", { x = 0, y = 0, z = 0, w = 1 } },
			{ "rot", NONE },
		}
		for _, case in tupleCases do
			local field = case[1] :: string
			local v = val(case[2])
			refused(withPart(f2(), 2, field, v), "Malformed", "parts[2]." .. field, field .. " " .. Dump.short(v))
		end
		-- 8 C1, C2, C7
		local finiteCases: { { any } } = { { "pos", 2 }, { "size", 1 }, { "rot", 4 } }
		for _, case in finiteCases do
			for _, bad in { 0 / 0, math.huge, -math.huge } do
				local d = f2()
				local field = case[1] :: string
				d.parts[3][field][case[2] :: number] = bad
				refused(d, "NonFinite", "parts[3]." .. field, field .. " " .. tostring(bad))
			end
		end
		refused(withPart(f2(), 1, "pos", { 0, 16.000000000000004, 0 }), "OutOfRange", "parts[1].pos")
		refused(withPart(f2(), 1, "size", { 0.3, 0, 0.3 }), "OutOfRange", "parts[1].size")
		refused(withPart(f2(), 1, "rot", { 0, 0, 0, 2 }), "BadRotation", "parts[1].rot")
		refused(withPart(f2(), 4, "id", 3), "DuplicatePartId", "parts[4].id", "the later copy in client order")
		refused(withPart(f2(), 2, "id", 4), "DuplicatePartId", "parts[3].id", "parts[3] repeats parts[2]")
	end)

	t.it("T-BP-01 checks run in order, each over every part before the next one starts", function()
		local f2 = Drafts.f2
		local function both(changes: { (any) -> () }): any
			local d = f2()
			for _, change in changes do
				change(d)
			end
			return d
		end
		refused(both({
			function(d)
				d.schema = 2
			end,
			function(d)
				d.name = "<x>"
			end,
		}), "UnsupportedSchema", "schema")
		refused(both({
			function(d)
				d.name = ""
			end,
			function(d)
				d.type = "Axe"
			end,
		}), "BadName", "name")
		refused(both({
			function(d)
				d.type = "Axe"
			end,
			function(d)
				d.parts = "x"
			end,
		}), "UnknownId", "type")
		-- a check-8 fault in part 1 loses to a check-6 fault in part 3
		refused(both({
			function(d)
				d.parts[1].pos[1] = 0 / 0
			end,
			function(d)
				d.parts[3].shape = "Sphere"
			end,
		}), "UnknownId", "parts[3].shape")
		-- check 7 in part 1 loses to check 6 in part 4
		refused(both({
			function(d)
				d.parts[1].rot = { 0, 0, 1 }
			end,
			function(d)
				d.parts[4].material = "Mithril"
			end,
		}), "DisabledId", "parts[4].material")
		-- C2 in part 1 loses to C1 in part 4
		refused(both({
			function(d)
				d.parts[1].size = { 9, 9, 9 }
			end,
			function(d)
				d.parts[4].rot = { 0, 0, 0 / 0, 1 }
			end,
		}), "NonFinite", "parts[4].rot")
		-- C7 comes last
		refused(both({
			function(d)
				d.parts[4].id = 3
			end,
			function(d)
				d.parts[2].rot = { 0, 0, 0, 0 }
			end,
		}), "BadRotation", "parts[2].rot")
		-- within a part: pos, size, rot
		refused(both({
			function(d)
				d.parts[2].rot = { 0, 0, 0, 0 / 0 }
			end,
			function(d)
				d.parts[2].size = { 1, math.huge, 1 }
			end,
		}), "NonFinite", "parts[2].size")
		refused(both({
			function(d)
				d.parts[2].rot = { 0, 0, 0, 3 }
			end,
			function(d)
				d.parts[2].size = { 1, 7, 1 }
			end,
		}), "OutOfRange", "parts[2].size")
		refused(both({
			function(d)
				d.parts[2].size = { 1, 7, 1 }
			end,
			function(d)
				d.parts[2].pos = { 0, 17, 0 }
			end,
		}), "OutOfRange", "parts[2].pos")
	end)

	t.it("T-BP-01 total: FUZZ_N_GARBAGE hostile values never throw; a refusal carries a CanonError and a path", function()
		Prop.check(Tol.FUZZ_N_GARBAGE, function(rng: TestRng): any
			return Drafts.garbage(rng)
		end, function(v: any)
			local okCall, r = pcall(Canonical.draft, v)
			A.truthy(okCall, "Canonical.draft threw: " .. tostring(r))
			A.eq(type(r), "table", "result is a table")
			if r.ok == true then
				expectCanonical(r.value, "accepted value")
			else
				A.eq(r.ok, false, "ok is a boolean")
				A.truthy(CODES[r.code], "code is a CanonError: " .. tostring(r.code))
				A.eq(type(r.path), "string", "path is a string")
			end
			for _, opts in ({ NONE, { bounds = false }, { bounds = true } } :: { any }) do
				local okIs, isC = pcall(Canonical.isCanonical, v, val(opts))
				A.truthy(okIs, "isCanonical threw: " .. tostring(isC))
				A.eq(type(isC), "boolean", "isCanonical returns a boolean")
			end
			local okG, g = pcall(Canonical.guid, v)
			A.truthy(okG and (g == nil or type(g) == "string"), "guid never throws")
		end)
	end)

	t.it("T-BP-01 single corruptions of valid drafts: refused or still canonical, input untouched (PROP_N)", function()
		Prop.check(Tol.PROP_N, function(rng: TestRng): any
			return Drafts.mutate(rng, Drafts.validDraft(rng))
		end, function(raw: any)
			local before = Drafts.deepCopy(raw)
			local okCall, r = pcall(Canonical.draft, raw)
			A.truthy(okCall, "Canonical.draft threw: " .. tostring(r))
			if r.ok then
				expectCanonical(r.value)
				A.falsy(Drafts.sharesTable(r.value, raw), "the output shares no table with the input")
			else
				A.truthy(CODES[r.code] and type(r.path) == "string", "a CanonError and a path")
			end
			local diff = Drafts.bitDiff(raw, before)
			A.truthy(diff == nil, "P-NOMUT: the input changed at " .. tostring(diff))
		end)
	end)

	t.it("T-BP-04 a stored record using a row retired later stays canonical with bounds = false (§2.2 rule 1)", function()
		local rows = Drafts.rows(Materials.ordered)
		for _, row in rows do
			if row.id == "Iron" then
				row.enabled = false
			end
		end
		local C = plantedCanonical(EquipmentTypes, Catalog.build(rows))
		local core = (Canonical.draft(Drafts.f2()) :: any).value
		A.falsy(C.isCanonical(core), "new data may not use a retired row")
		A.truthy(C.isCanonical(core, { bounds = false }), "a stored record keeps its retired row")
	end)

	t.it("T-BP-01 codes the MVP data cannot reach, on planted Definitions: DisabledId type, MaterialNotAllowed", function()
		-- MVP: Sword is the only type and enabled; Iron and Steel allow every slot (allowedSlots = nil)
		local typeRows = Drafts.rows(EquipmentTypes.ordered)
		local axe = Drafts.deepCopy(typeRows[1])
		axe.id, axe.name, axe.order, axe.enabled = "Axe", "Axe", 2, false
		axe.slots = { { id = "Head", name = "Head", required = true, min = 1, max = 4, rank = 1 },
			{ id = "Haft", name = "Haft", required = true, min = 1, max = 4, rank = 2 } }
		table.insert(typeRows, axe)
		local materialRows = Drafts.rows(Materials.ordered)
		for _, row in materialRows do
			if row.id == "Steel" then
				row.allowedSlots = { "Blade", "Guard" }
			end
		end
		local C = plantedCanonical(Catalog.build(typeRows), Catalog.build(materialRows))
		local function code(raw: any): (string?, string?)
			local r = C.draft(raw)
			return r.code, r.path
		end
		local d = Drafts.f2()
		d.type = "Axe"
		A.eq(table.concat({ code(d) }, " "), "DisabledId type", "a disabled type")
		d = Drafts.f2()
		d.parts[1].material = "Steel" -- client parts[1] is the Guard: allowed
		A.truthy(C.draft(d).ok, "Steel allowed in the Guard")
		d.parts[2].material = "Steel" -- the Pommel: not allowed
		A.eq(table.concat({ code(d) }, " "), "MaterialNotAllowed parts[2].material", "Steel in the Pommel")
		A.eq(Canonical.draft(d).ok, true, "the real Definitions allow it")
	end)

	t.it("T-BP-01 P-ORDER: Definitions rebuilt in shuffled order give bit-identical results (PROP_N)", function()
		local rng = TestRng.new(Tol.PROP_BASE_SEED)
		local function shuffled(n: number): { number }
			local order = {}
			for i = 1, n do
				order[i] = i
			end
			for i = n, 2, -1 do
				local j = rng:int(1, i)
				order[i], order[j] = order[j], order[i]
			end
			return order
		end
		local typeRows = Drafts.rows(EquipmentTypes.ordered, shuffled(#EquipmentTypes.ordered))
		for _, row in typeRows do
			local slots = row.slots
			local order = shuffled(#slots)
			local copy = table.clone(slots)
			for i = 1, #slots do
				slots[i] = copy[order[i]]
			end
		end
		local C = plantedCanonical(Catalog.build(typeRows),
			Catalog.build(Drafts.rows(Materials.ordered, shuffled(#Materials.ordered))))
		Prop.check(Tol.PROP_N, function(g: TestRng): any
			return if g:float() < 0.5 then Drafts.validDraft(g) else Drafts.mutate(g, Drafts.validDraft(g))
		end, function(raw: any)
			local diff = Drafts.bitDiff(C.draft(raw), Canonical.draft(raw))
			A.truthy(diff == nil, "the result changed with the Definitions order at " .. tostring(diff))
		end)
	end)

	t.it("T-BP-01 unknown fields are dropped, never stored", function()
		local d = Drafts.f2()
		d.analysis = { valid = true }
		d.revision = 99
		d.id = "93E32E8A-59BA-4037-9A7F-AA5613CD6213"
		d.parts[1].extra = { 1, 2, 3 }
		d.parts[2].label = "Pommel"
		d.parts[3].pos.w = 4
		local v = ok(d)
		expectCanonical(v)
		A.eq(keys(v), "name,parts,schema,type")
	end)

	-- ── T-BP-02 ───────────────────────────────────────────────────────────────────────────────────────────────

	t.it("T-BP-02 idempotent bit for bit, deterministic, input untouched (PROP_N drafts)", function()
		Prop.check(Tol.PROP_N, function(rng: TestRng): any
			return Drafts.validDraft(rng)
		end, function(raw: any)
			local before = Drafts.deepCopy(raw)
			local once = ok(raw)
			local twice = ok(once)
			local diff = Drafts.bitDiff(twice, once)
			A.truthy(diff == nil, "Canonical(Canonical(x)) differs at " .. tostring(diff))
			A.truthy(Drafts.bitDiff(ok(raw), once) == nil, "P-DET: same input, same bits")
			A.truthy(Drafts.bitDiff(raw, before) == nil, "P-NOMUT: the input changed")
			A.truthy(Canonical.isCanonical(once), "isCanonical(Canonical(x))")
			A.truthy(Canonical.isCanonical(once, { bounds = false }), "isCanonical(Canonical(x), {bounds = false})")
			-- the slow case's fast comparator agrees with bitDiff
			A.eq(Drafts.draftDiff(twice, once), nil, "draftDiff of equal drafts")
			if #once.parts > 0 then
				local moved = Drafts.deepCopy(once)
				moved.parts[#moved.parts].pos[1] = if moved.parts[#moved.parts].pos[1] == 0 then -0.0 else 0
				A.truthy(Drafts.draftDiff(moved, once) ~= nil, "draftDiff sees a changed bit")
			end
		end)
	end)

	t.it("T-BP-02 C3 renormalizes only above QUAT_NORM_TOL, once", function()
		local base = { 0.1, -0.2, 0.3, 0.9 }
		local s = math.sqrt(base[1] * base[1] + base[2] * base[2] + base[3] * base[3] + base[4] * base[4])
		local unit = { base[1] / s, base[2] / s, base[3] / s, base[4] / s }
		local function scaledTo(m: number): { number }
			local f = math.sqrt(m)
			return { unit[1] * f, unit[2] * f, unit[3] * f, unit[4] * f }
		end
		local function n2(q: { number }): number
			return q[1] * q[1] + q[2] * q[2] + q[3] * q[3] + q[4] * q[4]
		end
		-- inside the threshold: kept bit for bit
		for _, m in { 1, 1 + 0.5e-9, 1 - 0.5e-9 } do
			local q = scaledTo(m)
			A.truthy(math.abs(n2(q) - 1) <= Limits.QUAT_NORM_TOL)
			local c = Canonical.quat(q)
			A.truthy(Drafts.bitDiff(c, q) == nil, string.format("kept at ‖q‖² = %.12g", m))
		end
		-- above it: renormalized once, then stable
		for _, m in { 1 + 2e-9, 1 - 2e-9, 1 + 4e-3, 1 - 0.0099 } do
			local q = scaledTo(m)
			local c = Canonical.quat(q)
			A.truthy(math.abs(n2(c) - 1) <= 1e-15, string.format("renormalized at ‖q‖² = %.12g", m))
			A.truthy(Drafts.bitDiff(Canonical.quat(c), c) == nil, "a second pass keeps it")
		end
		-- C4 and C5 after C3
		local negated = Canonical.quat({ -unit[1], -unit[2], -unit[3], -unit[4] })
		A.truthy(Drafts.bitDiff(negated, Canonical.quat(unit)) == nil, "−q canonicalizes to the bits of q")
		A.throws(function()
			Canonical.quat({ 0, 0, 0, 2 })
		end, "QUAT_INPUT_TOL")
		A.throws(function()
			Canonical.quat({ 0, 0, 0 / 0, 1 })
		end, "QUAT_INPUT_TOL")
		local q = { 0, 0, 0, 1 }
		A.falsy(Canonical.quat(q) == q, "a new table")
	end)

	t.slow("T-BP-02 idempotent bit for bit on 10^5 drafts (I11)", function()
		local rng = TestRng.new(Tol.PROP_BASE_SEED)
		for i = 1, 100000 do
			local raw = Drafts.validDraft(rng:fork(i))
			local once: any = Canonical.draft(raw)
			if not once.ok then
				A.fail(string.format("draft %d refused: %s at %s", i, once.code, once.path))
			end
			local twice: any = Canonical.draft(once.value)
			local diff = if twice.ok then Drafts.draftDiff(twice.value, once.value) else "refused"
			if diff ~= nil then
				A.fail(string.format("draft %d not idempotent: %s", i, diff))
			end
		end
	end)

	-- ── T-BP-03 ───────────────────────────────────────────────────────────────────────────────────────────────

	t.it("T-BP-03 output: known fields, finite, unit, hemisphere, bounds, shape rules, sorted ids, no sharing", function()
		Prop.check(Tol.PROP_N, function(rng: TestRng): any
			return Drafts.validDraft(rng)
		end, function(raw: any)
			local v = ok(raw)
			expectCanonical(v)
			A.falsy(Drafts.sharesTable(v, raw), "the output shares no table with the input")
			A.eq(#v.parts, #raw.parts, "every part kept")
		end)
		expectCanonical(ok(Drafts.f1()), "F1")
		expectCanonical(ok(Drafts.f2()), "F2")
		local empty = ok({ schema = Versions.BLUEPRINT_SCHEMA, name = "Empty", type = "Sword", parts = {} })
		expectCanonical(empty, "no parts")
		A.eq(#empty.parts, 0)
	end)

	t.it("T-BP-03 C6: Ball sides = min side, Cylinder Y = Z = min(Y, Z), others unchanged", function()
		local cases: { { any } } = {
			{ "Ball", { 0.3, 0.5, 0.4 }, { 0.3, 0.3, 0.3 } },
			{ "Ball", { 0.5, 0.4, 0.3 }, { 0.3, 0.3, 0.3 } },
			{ "Cylinder", { 1, 0.3, 0.2 }, { 1, 0.2, 0.2 } },
			{ "Cylinder", { 0.1, 0.2, 0.3 }, { 0.1, 0.2, 0.2 } },
			{ "Block", { 1, 0.3, 0.2 }, { 1, 0.3, 0.2 } },
			{ "Wedge", { 1, 0.3, 0.2 }, { 1, 0.3, 0.2 } },
			{ "CornerWedge", { 1, 0.3, 0.2 }, { 1, 0.3, 0.2 } },
		}
		for _, c in cases do
			local shape, size, want = c[1] :: any, c[2] :: { number }, c[3] :: { number }
			local got = Canonical.canonicalSize(shape, size)
			A.truthy(Drafts.bitDiff(got, want) == nil, shape .. " " .. Dump.short(size) .. " → " .. Dump.short(got))
			A.truthy(Drafts.bitDiff(Canonical.canonicalSize(shape, got), got) == nil, shape .. " idempotent")
			A.falsy(got == size, "a new table")
			local d = Drafts.f2()
			d.parts[1].shape, d.parts[1].size = shape, table.clone(size)
			local part = nil
			for _, p in ok(d).parts do
				if p.id == d.parts[1].id then
					part = p
				end
			end
			A.truthy(Drafts.bitDiff((part :: any).size, want) == nil, "Canonical.draft applies the hook to " .. shape)
		end
	end)

	t.it("T-BP-03 C4, C5: hemisphere and −0 → +0; F1 with every q negated is F1 (A13)", function()
		local d = Drafts.f2()
		d.parts[1].pos = { -0.0, 0.2, -0.0 }
		d.parts[1].rot = { -0.0, 0, -0.0, 1 }
		d.parts[2].rot = { 0, 0, 0, -1 }
		d.parts[3].rot = { -1, -0.0, -0.0, -0.0 } -- qw = 0: the first non-zero component decides
		d.parts[4].rot = { -0.0, 0, -1, 0 }
		local v = ok(d)
		expectCanonical(v)
		local byId: { [number]: any } = {}
		for _, p in v.parts do
			byId[p.id] = p
		end
		-- client parts[1..4] are ids 3, 1, 4, 2; bitDiff tells −0 from +0
		A.truthy(Drafts.bitDiff(byId[3].pos, { 0, 0.2, 0 } :: any) == nil, "pos −0 → +0")
		A.eq(1 / byId[3].pos[1], math.huge, "pos[1] is +0")
		A.truthy(Drafts.bitDiff(byId[3].rot, { 0, 0, 0, 1 } :: any) == nil, "rot −0 components → +0")
		A.truthy(Drafts.bitDiff(byId[1].rot, { 0, 0, 0, 1 } :: any) == nil, "{0, 0, 0, −1} → identity")
		A.truthy(Drafts.bitDiff(byId[4].rot, { 1, 0, 0, 0 } :: any) == nil, "{−1, −0, −0, −0} → {1, 0, 0, 0}")
		A.truthy(Drafts.bitDiff(byId[2].rot, { 0, 0, 1, 0 } :: any) == nil, "{−0, 0, −1, 0} → {0, 0, 1, 0}")
		-- A13
		local f1 = ok(Drafts.f1())
		local negated = Drafts.f1()
		for _, p in negated.parts do
			p.rot = { -p.rot[1], -p.rot[2], -p.rot[3], -p.rot[4] }
		end
		local diff = Drafts.bitDiff(ok(negated), f1)
		A.truthy(diff == nil, "A13: F1 with every q negated differs at " .. tostring(diff))
	end)

	t.it("T-BP-03 C7: parts sorted by id; the client's order does not matter", function()
		local v = ok(Drafts.f2())
		for i, p in v.parts do
			A.eq(p.id, i, "sorted ids")
		end
		local rng = TestRng.new(Tol.PROP_BASE_SEED)
		local base = Drafts.validDraft(rng, { parts = 24 })
		local want = ok(base)
		for _ = 1, 20 do
			local shuffled = Drafts.deepCopy(base)
			local parts = shuffled.parts
			for i = #parts, 2, -1 do
				local j = rng:int(1, i)
				parts[i], parts[j] = parts[j], parts[i]
			end
			A.truthy(Drafts.bitDiff(ok(shuffled), want) == nil, "a shuffled client order gives the same bits")
		end
	end)

	-- ── T-BP-04 ───────────────────────────────────────────────────────────────────────────────────────────────

	t.it("T-BP-04 bounds are rejected, never clamped (A11); the bounds themselves pass", function()
		local f2 = Drafts.f2
		for _, s in { 0, -0.2, Limits.MIN_DIM - 1e-6, Limits.MAX_DIM + 1e-6, 0.019999999999999997, 6.000000000000001 } do
			for axis = 1, 3 do
				local size = { 0.2, 0.2, 0.2 }
				size[axis] = s
				refused(withPart(f2(), 2, "size", size), "OutOfRange", "parts[2].size", string.format("size %.17g", s))
			end
		end
		for _, x in { Limits.POS_ABS_MAX + 1e-6, -(Limits.POS_ABS_MAX + 1e-6), 16.000000000000004, -16.000000000000004 } do
			for axis = 1, 3 do
				local pos = { 0, 1, 0 }
				pos[axis] = x
				refused(withPart(f2(), 3, "pos", pos), "OutOfRange", "parts[3].pos", string.format("pos %.17g", x))
			end
		end
		local edge = f2()
		edge.parts[1].pos = { Limits.POS_ABS_MAX, -Limits.POS_ABS_MAX, Limits.POS_ABS_MAX }
		edge.parts[2].size = { Limits.MIN_DIM, Limits.MAX_DIM, Limits.MIN_DIM }
		local v = ok(edge)
		local byId: { [number]: any } = {}
		for _, p in v.parts do
			byId[p.id] = p
		end
		A.truthy(Drafts.bitDiff(byId[3].pos, { 16, -16, 16 } :: any) == nil, "±POS_ABS_MAX kept")
		A.truthy(Drafts.bitDiff(byId[1].size, { 0.02, 6, 0.02 } :: any) == nil, "MIN_DIM and MAX_DIM kept")
	end)

	t.it("T-BP-04 the quaternion input tolerance (A12): refused, or renormalized, never NaN", function()
		local spun = { { 0, 0, 0, 0 }, { 1e-20, 0, 0, 0 }, { 0, 0, 0, 2 }, { 0, 0, 0, math.sqrt(1.011) }, { 1e200, 0, 0, 0 } }
		for _, q in spun do
			refused(withPart(Drafts.f2(), 2, "rot", q), "BadRotation", "parts[2].rot", Dump.short(q))
		end
		for _, m in { 1 + 1e-3, 1 - 1e-3, 1.0099, 0.9901 } do
			local d = withPart(Drafts.f2(), 2, "rot", { 0, 0, 0, math.sqrt(m) })
			local v = ok(d)
			expectCanonical(v, string.format("‖q‖² = %.6g", m))
			for _, p in v.parts do
				for k = 1, 4 do
					A.finite(p.rot[k])
				end
			end
		end
	end)

	t.it("T-BP-04 isCanonical: fixed points only; bounds = false keeps a record that breaks only a bound", function()
		local v = ok(Drafts.f1())
		A.truthy(Canonical.isCanonical(v))
		local record = Drafts.deepCopy(v)
		record.id, record.revision, record.createdAt, record.updatedAt = "93E32E8A-59BA-4037-9A7F-AA5613CD6213", 3, 1, 2
		record.analysis = { balanceVersion = 1, valid = true, issues = {}, steps = {} }
		A.truthy(Canonical.isCanonical(record), "a record's other keys are ignored")
		local snapshot = Drafts.deepCopy(v)
		snapshot.sourceId, snapshot.sourceRevision = record.id, 3
		A.truthy(Canonical.isCanonical(snapshot), "a snapshot's other keys are ignored")
		-- not fixed points
		A.falsy(Canonical.isCanonical(Drafts.f2()), "unsorted ids")
		local padded = Drafts.deepCopy(v)
		padded.name = " " .. v.name
		A.falsy(Canonical.isCanonical(padded), "a name sanitize would change")
		local negZero = Drafts.deepCopy(v)
		negZero.parts[1].pos[1] = -0.0
		A.falsy(Canonical.isCanonical(negZero), "−0 is not +0")
		local flipped = Drafts.deepCopy(v)
		flipped.parts[5].rot = { -flipped.parts[5].rot[1], -flipped.parts[5].rot[2], -flipped.parts[5].rot[3],
			-flipped.parts[5].rot[4] }
		A.falsy(Canonical.isCanonical(flipped), "the other hemisphere")
		local sloppy = Drafts.deepCopy(v)
		sloppy.parts[2].rot = { 0, 0, 0, 1 + 1e-6 }
		A.falsy(Canonical.isCanonical(sloppy), "a norm C3 would fix")
		local ball = Drafts.deepCopy(v)
		ball.parts[1].size = { 0.26, 0.27, 0.26 }
		A.falsy(Canonical.isCanonical(ball), "unequal Ball sides")
		A.falsy(Canonical.isCanonical(nil :: any), "nil")
		A.falsy(Canonical.isCanonical("x" :: any), "a string")
		-- bounds
		local small = Drafts.deepCopy(v)
		small.parts[2].size = { 0.01, 0.9, 0.16 } -- below MIN_DIM: a later, tighter bound
		small.parts[3].pos = { 0, 17, 0 } -- beyond POS_ABS_MAX
		A.falsy(Canonical.isCanonical(small), "bounds checked by default")
		A.falsy(Canonical.isCanonical(small, { bounds = true }), "bounds = true")
		A.truthy(Canonical.isCanonical(small, { bounds = false }), "bounds = false skips POS_ABS_MAX, MIN_DIM, MAX_DIM")
		local spun = Drafts.deepCopy(v)
		spun.parts[2].rot = { 0, 0, 0, 2 }
		A.falsy(Canonical.isCanonical(spun, { bounds = false }), "the rotation tolerance is always checked")
	end)

	t.it("T-BP-04 Canonical.guid: an 8-4-4-4-12 hex GUID, upper-cased, else nil", function()
		local G = "93E32E8A-59BA-4037-9A7F-AA5613CD6213"
		A.eq(Canonical.guid(G), G)
		A.eq(Canonical.guid(string.lower(G)), G)
		A.eq(Canonical.guid("93e32E8a-59Ba-4037-9a7F-aA5613cd6213"), G)
		A.eq(Canonical.guid("00000000-0000-0000-0000-000000000000"), "00000000-0000-0000-0000-000000000000")
		A.eq(Canonical.guid("abcdefab-cdef-abcd-efab-cdefabcdefab"), "ABCDEFAB-CDEF-ABCD-EFAB-CDEFABCDEFAB")
		local badIds: { any } = {
			"{" .. G .. "}", string.sub(G, 2), G .. "0", "93E32E8A59BA40379A7FAA5613CD6213", "93E32E8A-59BA-4037-9A7F-AA5613CD621G",
			"93E32E8A_59BA_4037_9A7F_AA5613CD6213", "93E32E8A-59BA-4037-9A7F-AA5613CD621 ", " 3E32E8A-59BA-4037-9A7F-AA5613CD6213",
			"93E32E8A-59BA-4037-9A7FA-A5613CD6213", "93E32E8A-59BA-4037-9A7F-AA5613CD62\0" .. "3", "", "x", 5, true, {},
			string.rep("A", 36), "93E32E8A-59BA-4037-9A7F-AA5613CD6213\n", NONE,
		}
		for _, bad in badIds do
			A.eq(Canonical.guid(val(bad)), nil, "refuses " .. Dump.short(val(bad)))
		end
	end)

	-- ── T-BP-05 ───────────────────────────────────────────────────────────────────────────────────────────────

	t.it("T-BP-05 the worst 24-part draft is at most 8,175 B on the wire and inside the Guard bounds", function()
		local raw = worstDraft()
		local v = ok(raw)
		A.truthy(Drafts.bitDiff(v, raw) == nil, "the worst draft is canonical as built")
		local text = Drafts.jsonEncode(v)
		A.truthy(#text <= WIRE_DRAFT_MAX_BYTES, string.format("worst draft %d B > %d B", #text, WIRE_DRAFT_MAX_BYTES))
		local shorter = #"Obsidian" - #v.parts[1].material -- S1's material id against the longest enabled one
		A.eq(#text, WIRE_DRAFT_MAX_BYTES - Limits.MAX_PARTS * shorter, "the worst case reproduces S1's measurement")
		local args = { blueprintId = "93E32E8A-59BA-4037-9A7F-AA5613CD6213", draft = v }
		A.eq(#Drafts.jsonEncode(args), #text + 63, "the Save envelope adds the 36-character id and two keys")
		A.truthy(depth(v) <= Network.MAX_DRAFT_DEPTH, string.format("depth %d > MAX_DRAFT_DEPTH", depth(v)))
		A.eq(nodes(args), 439, "a 24-part Save is 439 nodes (§16.13)")
		A.truthy(nodes(args) <= Network.MAX_PAYLOAD_NODES, "inside MAX_PAYLOAD_NODES")
	end)

	t.it("T-BP-05 random 24-part canonical drafts stay within the worst case (PROP_N)", function()
		Prop.check(Tol.PROP_N, function(rng: TestRng): any
			return Drafts.validDraft(rng, { parts = Limits.MAX_PARTS })
		end, function(raw: any)
			local v = ok(raw)
			local bytes = #Drafts.jsonEncode(v)
			A.truthy(bytes <= WIRE_DRAFT_MAX_BYTES, string.format("%d B > %d B", bytes, WIRE_DRAFT_MAX_BYTES))
			A.truthy(depth(v) <= Network.MAX_DRAFT_DEPTH, "inside MAX_DRAFT_DEPTH")
		end)
	end)
end)
