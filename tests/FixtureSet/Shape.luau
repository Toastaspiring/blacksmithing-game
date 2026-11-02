--!strict
-- tests/FixtureSet/Shape.luau — the structural rules of a canonical BlueprintCore, restated for the fixture specs
-- (SPEC §3.3, §3.5 C1–C7, §3.6, §3.7) so that the fixture data is checked independently of Blueprint/Canonical:
-- known fields only, ids ascending in 1..MAX_PART_ID, catalogued ids, finite tuples of the right length, bounds,
-- ‖q‖² within QUAT_NORM_TOL of 1 (C3 keeps it), the hemisphere rule, no −0, the Ball and Cylinder size rule, and
-- (slotProblems) the slot counts. Specs pass the Definitions modules in; Lune-only helper (not a Rojo root).

export type Defs = {
	limits: any, -- Definitions/Limits
	typeDef: any, -- the EquipmentTypes row (Sword)
	materials: any, -- the Materials catalog
	schema: number, -- Versions.BLUEPRINT_SCHEMA
	shapes: { string },
}

local Shape = {}

Shape.PART_FIELDS = table.freeze({ "id", "slot", "shape", "material", "pos", "rot", "size" })
Shape.CORE_FIELDS = table.freeze({ "schema", "name", "type", "parts" })

local function finite(x: any): boolean
	return type(x) == "number" and x == x and x > -math.huge and x < math.huge
end

local function negativeZero(x: number): boolean
	return x == 0 and 1 / x < 0
end

local function tuple(v: any, n: number): boolean
	if type(v) ~= "table" then
		return false
	end
	local count = 0
	for _ in v do
		count += 1
	end
	if count ~= n or #v ~= n then
		return false
	end
	for k = 1, n do
		if not finite(v[k]) then
			return false
		end
	end
	return true
end

local function onlyFields(t: any, fields: { string }): string?
	for key in t do
		if type(key) ~= "string" or table.find(fields, key) == nil then
			return tostring(key)
		end
	end
	return nil
end

local function slotIds(typeDef: any): { string }
	local out: { string } = {}
	for _, s in typeDef.slots do
		table.insert(out, s.id)
	end
	return out
end

-- Problems with core as a canonical BlueprintCore (empty when it is one).
function Shape.problems(core: any, d: Defs): { string }
	local out: { string } = {}
	local function bad(fmt: string, ...: any)
		table.insert(out, string.format(fmt, ...))
	end
	if type(core) ~= "table" then
		return { "not a table" }
	end
	local extra = onlyFields(core, Shape.CORE_FIELDS)
	if extra then
		bad("unknown field %s", extra)
	end
	if core.schema ~= d.schema then
		bad("schema %s, expected %d", tostring(core.schema), d.schema)
	end
	if type(core.name) ~= "string" or core.name == "" then
		bad("name must be a non-empty string")
	end
	if core.type ~= d.typeDef.id then
		bad("type %s, expected %s", tostring(core.type), d.typeDef.id)
	end
	local parts = core.parts
	if type(parts) ~= "table" then
		bad("parts is not a table")
		return out
	end
	local keys = 0
	for _ in parts do
		keys += 1
	end
	if keys ~= #parts then
		bad("parts is not an array")
		return out
	end
	if #parts > d.limits.MAX_PARTS then
		bad("%d parts > MAX_PARTS %d", #parts, d.limits.MAX_PARTS)
	end
	local slots = slotIds(d.typeDef)
	local lastId = 0
	for i, p in parts do
		local at = string.format("parts[%d]", i)
		if type(p) ~= "table" then
			bad("%s is not a table", at)
			continue
		end
		local unknown = onlyFields(p, Shape.PART_FIELDS)
		if unknown then
			bad("%s has the unknown field %s", at, unknown)
		end
		local id = p.id
		if not (finite(id) and id % 1 == 0 and id >= 1 and id <= d.limits.MAX_PART_ID) then
			bad("%s.id %s is not an integer in 1..MAX_PART_ID", at, tostring(id))
		elseif id <= lastId then
			bad("%s.id %d does not ascend (previous %d)", at, id, lastId)
		else
			lastId = id
		end
		if table.find(slots, p.slot) == nil then
			bad("%s.slot %s is not a slot of %s", at, tostring(p.slot), d.typeDef.id)
		end
		if table.find(d.shapes, p.shape) == nil then
			bad("%s.shape %s is not a ShapeId", at, tostring(p.shape))
		end
		if not d.materials.isEnabled(p.material) then
			bad("%s.material %s is not an enabled material", at, tostring(p.material))
		end
		if not (tuple(p.pos, 3) and tuple(p.size, 3) and tuple(p.rot, 4)) then
			bad("%s: pos and size need exactly 3 finite numbers, rot exactly 4", at)
			continue
		end
		for k = 1, 3 do
			if math.abs(p.pos[k]) > d.limits.POS_ABS_MAX then
				bad("%s.pos[%d] = %.17g beyond POS_ABS_MAX", at, k, p.pos[k])
			end
			if p.size[k] < d.limits.MIN_DIM or p.size[k] > d.limits.MAX_DIM then
				bad("%s.size[%d] = %.17g outside [MIN_DIM, MAX_DIM]", at, k, p.size[k])
			end
			if negativeZero(p.pos[k]) then
				bad("%s.pos[%d] is −0 (C5)", at, k)
			end
		end
		local q = p.rot
		local n2 = q[1] * q[1] + q[2] * q[2] + q[3] * q[3] + q[4] * q[4]
		if math.abs(n2 - 1) > d.limits.QUAT_NORM_TOL then
			bad("%s.rot: |‖q‖² − 1| = %.3g > QUAT_NORM_TOL (C3 would renormalize it)", at, math.abs(n2 - 1))
		end
		local first = 0
		for k = 1, 3 do
			if q[k] ~= 0 then
				first = q[k]
				break
			end
		end
		if q[4] < 0 or (q[4] == 0 and first < 0) then
			bad("%s.rot is in the wrong hemisphere (C4)", at)
		end
		for k = 1, 4 do
			if negativeZero(q[k]) then
				bad("%s.rot[%d] is −0 (C5)", at, k)
			end
		end
		local s = p.size
		if p.shape == "Ball" and not (s[1] == s[2] and s[2] == s[3]) then
			bad("%s: a Ball's sides must be equal (C6)", at)
		elseif p.shape == "Cylinder" and s[2] ~= s[3] then
			bad("%s: a Cylinder's Y and Z sizes must be equal (C6)", at)
		end
	end
	return out
end

-- Problems with the slot counts (SPEC §3.7): every slot within [min, max].
function Shape.slotProblems(core: any, typeDef: any): { string }
	local out: { string } = {}
	for _, s in typeDef.slots do
		local n = Shape.count(core, s.id)
		if n < s.min or n > s.max then
			table.insert(out, string.format("%d %s parts, the rule is %d..%d", n, s.id, s.min, s.max))
		end
	end
	return out
end

function Shape.count(core: any, slot: string): number
	local n = 0
	for _, p in core.parts do
		if p.slot == slot then
			n += 1
		end
	end
	return n
end

-- Bit for bit: numbers compared with ==, and the sign of a zero too (NaN equals NaN); other non-table values by
-- identity. nil when equal, else the first differing path.
function Shape.bitDifference(a: any, b: any, path: string?): string?
	local here = path or "$"
	if type(a) ~= type(b) then
		return here .. ": type " .. type(a) .. " ~= " .. type(b)
	end
	if type(a) == "number" then
		if a ~= a and b ~= b then
			return nil
		end
		if a ~= b or (a == 0 and 1 / a ~= 1 / b) then
			return string.format("%s: %.17g ~= %.17g%s", here, a, b, if a == 0 and b == 0 then " (signed zeros)" else "")
		end
		return nil
	elseif type(a) ~= "table" then
		return if a == b then nil else here .. ": " .. tostring(a) .. " ~= " .. tostring(b)
	end
	for k, v in a do
		local diff = Shape.bitDifference(v, b[k], here .. "." .. tostring(k))
		if diff then
			return diff
		end
	end
	for k in b do
		if a[k] == nil then
			return here .. "." .. tostring(k) .. ": missing on the left"
		end
	end
	return nil
end

return table.freeze(Shape)
