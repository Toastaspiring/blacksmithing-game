--!strict
-- tests/Blueprint/Drafts.luau — helpers shared by the Blueprint specs (T-BP-01…05, 12, 13, T-UD-01). Not a spec (the
-- runner loads *.spec.luau only).
--   f1, f2             raw drafts of fixtures F1 ArmingSword and F2 MinimalSword (E-S8.3; fresh tables per call; F2's
--                      parts in the client order 3, 1, 4, 2)
--   bitDiff, draftDiff deep comparison with numbers compared bit for bit (−0 ≠ +0), first differing path or nil;
--                      draftDiff is the fast field-wise form for two drafts Canonical built
--   tablesOf, ...      table-sharing checks ("no shared tables", §9.2 I5)
--   quat, validDraft   generators on tests/lib TestRng: drafts that pass §3.6 but are not yet canonical (shuffled ids,
--                      sloppy, threshold-hugging and qw = 0 quaternions, −0, unequal Ball / Cylinder sides, padded
--                      names), the mix of E-S1.1's canon2 prototype
--   editorDraft        what the editor produces: values S6's tools make (snapped moves cleaned as round(v·1e12)/1e12,
--                      typed decimals, mirrors, free drags; rotations composed with Blueprint/Quat), committed through
--                      Canonical as the editor does on every commit
--   garbage, mutate    hostile values and single corruptions of a valid draft (P-TOTAL, FUZZ_N_GARBAGE)
--   json               an encoder that writes what Roblox's HttpService:JSONEncode writes (shortest round-trip digits,
--                      ECMAScript number layout, "-0", {} → [], UTF-8 raw; Studio probe of E-S1.3, prototype
--                      S1/sizes2.luau) and a decoder for its output. @lune/serde is not used: it writes 1e-300 as 0.
--   planted, rows      a fresh instance of a src/shared module whose string requires resolve through a given map, so
--                      a spec can hand it Definitions that the MVP data cannot express (P-ORDER, MaterialNotAllowed);
--                      rows copies catalog rows (unfrozen, optionally reordered) to build such catalogs from
-- Trigonometry is fine here: tests are outside the authoritative folders of T-META-03.

local fs = require("@lune/fs")
local luau = require("@lune/luau")
local TestRng = require("../lib/TestRng")
local Dump = require("../lib/Dump")
local EquipmentTypes = require("../../src/shared/Definitions/EquipmentTypes")
local Limits = require("../../src/shared/Definitions/Limits")
local Materials = require("../../src/shared/Definitions/Materials")
local Versions = require("../../src/shared/Definitions/Versions")

type TestRng = TestRng.TestRng

local Drafts = {}

-- ── fixtures (E-S8.3) ─────────────────────────────────────────────────────────────────────────────────────────

local R = 0.70710678118654757
Drafts.R = R
Drafts.I = table.freeze({ 0, 0, 0, 1 })
Drafts.Z45 = table.freeze({ 0, 0, 0.38268343236508978, 0.92387953251128674 })
Drafts.Z90 = table.freeze({ 0, 0, R, R })
Drafts.Y90 = table.freeze({ 0, R, 0, R })

function Drafts.part(id: number, slot: string, shape: string, material: string, pos: { number }, rot: { number },
	size: { number }): any
	return {
		id = id,
		slot = slot,
		shape = shape,
		material = material,
		pos = { pos[1], pos[2], pos[3] },
		rot = { rot[1], rot[2], rot[3], rot[4] },
		size = { size[1], size[2], size[3] },
	}
end
local P = Drafts.part

-- F1 ArmingSword: Iron hilt, two-part Steel blade, 45° tip overlapping the blade.
function Drafts.f1(): any
	local I, Z45 = Drafts.I, Drafts.Z45
	return {
		schema = Versions.BLUEPRINT_SCHEMA,
		name = "F1 ArmingSword",
		type = "Sword",
		parts = {
			P(1, "Pommel", "Ball", "Iron", { 0, 0.17, 0 }, I, { 0.26, 0.26, 0.26 }),
			P(2, "Grip", "Block", "Iron", { 0, 0.75, 0 }, I, { 0.16, 0.90, 0.16 }),
			P(3, "Guard", "Block", "Iron", { 0, 1.29, 0 }, I, { 1.00, 0.18, 0.24 }),
			P(4, "Blade", "Block", "Steel", { 0, 2.68, 0 }, I, { 0.16, 2.60, 0.06 }),
			P(5, "Blade", "Block", "Steel", { 0, 3.98, 0 }, Z45, { 0.113, 0.113, 0.055 }),
		},
	}
end

-- F2 MinimalSword, with the parts in the client order 3, 1, 4, 2, so error paths name client indices.
function Drafts.f2(): any
	local I = Drafts.I
	return {
		schema = Versions.BLUEPRINT_SCHEMA,
		name = "F2 MinimalSword",
		type = "Sword",
		parts = {
			P(3, "Guard", "Block", "Iron", { 0, 1.45, 0 }, I, { 0.80, 0.20, 0.20 }),
			P(1, "Pommel", "Block", "Iron", { 0, 0.20, 0 }, I, { 0.30, 0.30, 0.30 }),
			P(4, "Blade", "Block", "Iron", { 0, 2.75, 0 }, I, { 0.20, 2.40, 0.08 }),
			P(2, "Grip", "Block", "Iron", { 0, 0.85, 0 }, I, { 0.20, 1.00, 0.20 }),
		},
	}
end

-- ── comparison and sharing ────────────────────────────────────────────────────────────────────────────────────

function Drafts.sameBits(a: number, b: number): boolean
	if a ~= a then
		return b ~= b
	end
	return a == b and (a ~= 0 or 1 / a == 1 / b)
end

local function child(path: string, k: any): string
	if type(k) == "string" and string.match(k, "^[%a_][%w_]*$") then
		return path .. "." .. k
	end
	return path .. "[" .. tostring(k) .. "]"
end

-- nil when a and b are structurally equal with numbers bit for bit (−0 ≠ +0), else the first differing path.
function Drafts.bitDiff(a: any, b: any, path: string?): string?
	local p = path or "$"
	if type(a) ~= type(b) then
		return p .. ": type " .. type(a) .. " ~= " .. type(b)
	end
	if type(a) == "number" then
		if Drafts.sameBits(a, b) then
			return nil
		end
		return string.format("%s: %.17g ~= %.17g%s", p, a, b, if a == b then " (sign of zero)" else "")
	elseif type(a) ~= "table" then
		if a == b then
			return nil
		end
		return p .. ": " .. Dump.short(a) .. " ~= " .. Dump.short(b)
	end
	for _, k in Dump.sortedKeys(a) do
		if b[k] == nil then
			return child(p, k) .. ": missing on the second side"
		end
		local d = Drafts.bitDiff(a[k], b[k], child(p, k))
		if d then
			return d
		end
	end
	for _, k in Dump.sortedKeys(b) do
		if a[k] == nil then
			return child(p, k) .. ": missing on the first side"
		end
	end
	return nil
end

-- The fast form of bitDiff for two drafts built by Canonical (known fields only): nil, or the first differing field.
function Drafts.draftDiff(a: any, b: any): string?
	for _, k in { "schema", "name", "type" } do
		if a[k] ~= b[k] then
			return k
		end
	end
	if #a.parts ~= #b.parts then
		return "#parts"
	end
	for i = 1, #a.parts do
		local p, q = a.parts[i], b.parts[i]
		for _, k in { "id", "slot", "shape", "material" } do
			if p[k] ~= q[k] then
				return "parts[" .. i .. "]." .. k
			end
		end
		for _, k in { "pos", "size", "rot" } do
			local x, y = p[k], q[k]
			if #x ~= #y then
				return "parts[" .. i .. "]." .. k
			end
			for c = 1, #x do
				if not Drafts.sameBits(x[c], y[c]) then
					return string.format("parts[%d].%s[%d]: %.17g ~= %.17g", i, k, c, x[c], y[c])
				end
			end
		end
	end
	return nil
end

-- Every table reachable from v (keys and values).
function Drafts.tablesOf(v: any, into: { [any]: boolean }?): { [any]: boolean }
	local seen = into or {}
	local function walk(x: any)
		if type(x) ~= "table" or seen[x] then
			return
		end
		seen[x] = true
		for k, c in x do
			walk(k)
			walk(c)
		end
	end
	walk(v)
	return seen
end

-- true when a table reachable from a is also reachable from b
function Drafts.sharesTable(a: any, b: any): boolean
	local inB = Drafts.tablesOf(b)
	for t in Drafts.tablesOf(a) do
		if inB[t] then
			return true
		end
	end
	return false
end

-- true when some table is reachable from v along two different references
function Drafts.repeatsTable(v: any): boolean
	local seen: { [any]: boolean } = {}
	local repeated = false
	local function walk(x: any)
		if type(x) ~= "table" then
			return
		end
		if seen[x] then
			repeated = true
			return
		end
		seen[x] = true
		for k, c in x do
			walk(k)
			walk(c)
		end
	end
	walk(v)
	return repeated
end

-- Copies keep every number's bits (−0 included).
function Drafts.deepCopy(v: any): any
	if type(v) ~= "table" then
		return v
	end
	local out = {}
	for k, c in v do
		out[Drafts.deepCopy(k)] = Drafts.deepCopy(c)
	end
	return out
end

-- ── generators ────────────────────────────────────────────────────────────────────────────────────────────────

local SWORD = EquipmentTypes.get("Sword") :: any
local SLOT_IDS: { string } = {}
for _, s in SWORD.slots do
	table.insert(SLOT_IDS, s.id)
end
local MATERIAL_IDS: { string } = {}
for _, m in Materials.enabled do
	table.insert(MATERIAL_IDS, m.id)
end
Drafts.SLOT_IDS = SLOT_IDS
Drafts.MATERIAL_IDS = MATERIAL_IDS
Drafts.SHAPE_IDS = { "Block", "Wedge", "CornerWedge", "Cylinder", "Ball" }

local function n2(q: { number }): number
	return q[1] * q[1] + q[2] * q[2] + q[3] * q[3] + q[4] * q[4]
end

local function scaled(q: { number }, f: number): { number }
	return { q[1] * f, q[2] * f, q[3] * f, q[4] * f }
end

-- An editor-like unit quaternion: a normal 4-vector divided by its norm (|‖q‖² − 1| ≈ 1e-16).
function Drafts.unitQuat(rng: TestRng): { number }
	local g = { rng:normal(0, 1), rng:normal(0, 1), rng:normal(0, 1), rng:normal(0, 1) }
	local s = math.sqrt(n2(g))
	return { g[1] / s, g[2] / s, g[3] / s, g[4] / s }
end

local H = math.sqrt(0.5)
local AXIS: { { number } } = {
	{ 0, 0, 0, 1 }, { H, 0, 0, H }, { 0, H, 0, H }, { 0, 0, H, H }, { 1, 0, 0, 0 }, { 0.5, 0.5, 0.5, 0.5 },
	{ 0, 0, -1, 0 }, { -0.0, 0, 0, -1 }, { 0, -1, 0, 0 }, { -0.0, -0.0, -1, 0 }, { -H, 0, 0, H }, { 0, 0, -0.0, 1 },
}

-- A quaternion that passes C1–C2, in the mix of E-S1.1: editor-like, sloppy (norm off by up to 4e-3), right at the
-- 1e-9 threshold, near the 1e-2 input tolerance, axis-aligned, qw exactly 0, and −q of any of them.
function Drafts.quat(rng: TestRng): { number }
	local mode = rng:int(1, 10)
	local q = Drafts.unitQuat(rng)
	if mode == 6 then
		q = scaled(q, 1 + (rng:float() * 2 - 1) * 4e-3)
	elseif mode == 7 then
		local side = if rng:float() < 0.5 then 1 else -1
		q = scaled(q, math.sqrt(1 + side * Limits.QUAT_NORM_TOL * (1 + (rng:float() - 0.5) * 1e-3)))
	elseif mode == 8 then
		q = scaled(q, math.sqrt(1 + (rng:float() * 2 - 1) * 0.0099))
	elseif mode == 9 then
		q = table.clone(rng:pick(AXIS))
	elseif mode == 10 then
		local a = { rng:normal(0, 1), rng:normal(0, 1), rng:normal(0, 1) }
		local t = math.sqrt(a[1] * a[1] + a[2] * a[2] + a[3] * a[3])
		q = { a[1] / t, a[2] / t, a[3] / t, 0 }
	end
	if rng:float() < 0.3 then
		q = { -q[1], -q[2], -q[3], -q[4] }
	end
	return q
end

local function coordinate(rng: TestRng): number
	local mode = rng:int(1, 8)
	if mode == 1 then
		return -0.0
	elseif mode == 2 then
		return (if rng:float() < 0.5 then -1 else 1) * rng:range(1e-6, 1e-5) -- tiny: the longest JSON numbers
	elseif mode == 3 then
		return (if rng:float() < 0.5 then -1 else 1) * Limits.POS_ABS_MAX
	elseif mode == 4 then
		return rng:int(-320, 320) * 0.05
	end
	return rng:range(-Limits.POS_ABS_MAX, Limits.POS_ABS_MAX)
end

local function side(rng: TestRng): number
	local mode = rng:int(1, 6)
	if mode == 1 then
		return Limits.MIN_DIM
	elseif mode == 2 then
		return Limits.MAX_DIM
	elseif mode == 3 then
		return rng:int(1, 120) * 0.05
	end
	return Limits.MIN_DIM + rng:float() * (Limits.MAX_DIM - Limits.MIN_DIM)
end

local NAME_POOL = {
	"Sword", "   Big    Sword  ", "Épée du Roi", "Œuvre d'Ætheling", "Łódź Blade #2", "F1 ArmingSword",
	string.rep("a", 32), string.rep("é", 32), "Sword 7", "x", "Blade (copy)", "Ion: v2/b+c & d!",
}
local NAME_CHARS = "abcXYZ019 -_'.,!?&()#+:/"

local function name(rng: TestRng): string
	if rng:float() < 0.6 then
		return rng:pick(NAME_POOL)
	end
	local out = { "N" }
	for _ = 1, rng:int(0, 30) do
		local k = rng:int(1, #NAME_CHARS)
		table.insert(out, string.sub(NAME_CHARS, k, k))
	end
	return table.concat(out)
end

-- Unique integer ids in 1..MAX_PART_ID, in random order.
local function ids(rng: TestRng, n: number): { number }
	local out: { number } = {}
	local used: { [number]: boolean } = {}
	local sequential = rng:float() < 0.3
	for i = 1, n do
		local id = if sequential then i else rng:int(1, Limits.MAX_PART_ID)
		while used[id] do
			id = rng:int(1, Limits.MAX_PART_ID)
		end
		used[id] = true
		out[i] = id
	end
	for i = n, 2, -1 do -- Fisher–Yates
		local j = rng:int(1, i)
		out[i], out[j] = out[j], out[i]
	end
	return out
end

-- A random raw draft that passes every check of §3.6 (Canonical.draft returns ok) but is usually not canonical yet.
-- opts.parts fixes the part count (else 0..MAX_PARTS, mostly ≥ 1).
function Drafts.validDraft(rng: TestRng, opts: { parts: number? }?): any
	local n = if opts and opts.parts then opts.parts
		elseif rng:float() < 0.05 then 0
		else rng:int(1, Limits.MAX_PARTS)
	local partIds = ids(rng, n)
	local parts = {}
	for i = 1, n do
		local shape = rng:pick(Drafts.SHAPE_IDS)
		local size = { side(rng), side(rng), side(rng) }
		if shape == "Ball" and rng:float() < 0.5 then
			size = { size[1], size[1], size[1] }
		elseif shape == "Cylinder" and rng:float() < 0.5 then
			size = { size[1], size[2], size[2] }
		end
		parts[i] = {
			id = partIds[i],
			slot = rng:pick(SLOT_IDS),
			shape = shape,
			material = rng:pick(MATERIAL_IDS),
			pos = { coordinate(rng), coordinate(rng), coordinate(rng) },
			rot = Drafts.quat(rng),
			size = size,
		}
	end
	return { schema = Versions.BLUEPRINT_SCHEMA, name = name(rng), type = "Sword", parts = parts }
end

-- S6's snap cleaning (E-S6.3): a snapped value is cleaned as round(v·1e12)/1e12.
local function snapped(x0: number, step: number, k: number): number
	return math.round((x0 + k * step) * 1e12) / 1e12
end

local function axisAngle(ax: number, ay: number, az: number, radians: number): { number }
	local n = math.sqrt(ax * ax + ay * ay + az * az)
	local s = math.sin(radians / 2)
	return { ax / n * s, ay / n * s, az / n * s, math.cos(radians / 2) }
end

-- Values the editor's tools produce for one coordinate (blueprint space, inside the hitbox stage).
local function editorCoordinate(rng: TestRng, lo: number, hi: number): number
	local mode = rng:int(1, 5)
	local x: number
	if mode == 1 then
		x = snapped(rng:range(lo, hi), 0.05, rng:int(-20, 20)) -- Move with snapping from a free start
	elseif mode == 2 then
		x = tonumber(string.format("%.4f", rng:range(lo, hi))) :: number -- a typed decimal
	elseif mode == 3 then
		x = rng:int(math.ceil(lo / 0.05), math.floor(hi / 0.05)) * 0.05 -- snapped from a snapped start
	else
		x = rng:range(lo, hi) -- a free drag (raw double)
	end
	return math.clamp(x, lo, hi) -- the editor clamps every transform path (§3.6)
end

local function editorSide(rng: TestRng): number
	local mode = rng:int(1, 3)
	local x: number
	if mode == 1 then
		x = snapped(0, 0.05, rng:int(1, 60))
	elseif mode == 2 then
		x = tonumber(string.format("%.3f", rng:range(0.02, 3))) :: number
	else
		x = rng:range(0.02, 3)
	end
	return math.clamp(x, Limits.MIN_DIM, Limits.MAX_DIM)
end

-- An editor rotation: a typed or gizmo rotation composed with Quat.mul from axis-angle steps, as EditorCore/Rotation
-- and GizmoMath build them; sometimes the identity or an exact quarter turn.
function Drafts.editorRot(rng: TestRng, Quat: any): { number }
	local mode = rng:int(1, 4)
	if mode == 1 then
		return { 0, 0, 0, 1 }
	elseif mode == 2 then
		return rng:pick({ { 0, 0, R, R }, { 0, R, 0, R }, { R, 0, 0, R } })
	end
	local q = { 0, 0, 0, 1 }
	for _ = 1, rng:int(1, 4) do
		local step = axisAngle(rng:normal(0, 1), rng:normal(0, 1), rng:normal(0, 1), rng:range(-math.pi, math.pi))
		q = Quat.mul(step, q)
	end
	return q
end

-- One editor document's draft: raw editor values committed through Canonical.draft (the editor runs Canonical on
-- every commit, §11.5). Quat and Canonical are passed in by the spec.
function Drafts.editorDraft(rng: TestRng, Quat: any, Canonical: any): any
	local n = rng:int(1, Limits.MAX_PARTS)
	local partIds = ids(rng, n)
	local parts = {}
	for i = 1, n do
		local shape = rng:pick(Drafts.SHAPE_IDS)
		local size = { editorSide(rng), editorSide(rng), editorSide(rng) }
		if shape == "Ball" then
			size = { size[1], size[1], size[1] } -- edit time: Ball keeps x = y = z
		elseif shape == "Cylinder" then
			size = { size[1], size[2], size[2] } -- edit time: Cylinder y = z
		end
		local pos = { editorCoordinate(rng, -0.8, 0.8), editorCoordinate(rng, 0, 5), editorCoordinate(rng, -0.3, 0.3) }
		if rng:float() < 0.2 then
			pos[1] = -pos[1] -- the mirror tool reflects across x = 0
		end
		parts[i] = {
			id = partIds[i],
			slot = rng:pick(SLOT_IDS),
			shape = shape,
			material = rng:pick(MATERIAL_IDS),
			pos = pos,
			rot = Drafts.editorRot(rng, Quat),
			size = size,
		}
	end
	local raw = { schema = Versions.BLUEPRINT_SCHEMA, name = "Sword " .. rng:int(1, 99), type = "Sword", parts = parts }
	local result = Canonical.draft(raw)
	assert(result.ok, "editorDraft: the generated editor values must pass Canonical")
	return result.value
end

-- ── hostile values ────────────────────────────────────────────────────────────────────────────────────────────

local SPECIAL_NUMBERS: { number } = {
	0, -0.0, 0 / 0, math.huge, -math.huge, 1, -1, 0.5, 1.5, 1e308, -1e308, 5e-324, 9007199254740992, 65535, 65536,
	1e-20, 16.000000000000004, -16.000000000000004, 0.019999999999999997, 6.000000000000001, 2, 3, 4, 24, 25,
}
local SPECIAL_STRINGS: { string } = {
	"", "Sword", "Axe", "Armor", "Blade", "Hilt", "Head", "Iron", "Steel", "Mithril", "Bronze", "Gold", "Block",
	"Sphere", "Ball", "\0", "\255\254", string.rep("x", 300), "<b>Sword</b>", "  ", "schema", "parts",
	"93e32e8a-59ba-4037-9a7f-aa5613cd6213", "1", "nan",
}
Drafts.SPECIAL_NUMBERS = SPECIAL_NUMBERS
Drafts.SPECIAL_STRINGS = SPECIAL_STRINGS

local function bytes(rng: TestRng): string
	local out = {}
	for i = 1, rng:int(0, 40) do
		out[i] = string.char(rng:int(0, 255))
	end
	return table.concat(out)
end

-- A hostile value: primitives, odd numbers and strings, arrays, maps, deep chains, corrupted drafts.
function Drafts.garbage(rng: TestRng, depth: number?): any
	local d = depth or 3
	local k = rng:int(1, if d > 0 then 11 else 6)
	if k == 1 then
		return nil
	elseif k == 2 then
		return rng:float() < 0.5
	elseif k == 3 then
		return rng:pick(SPECIAL_NUMBERS)
	elseif k == 4 then
		return rng:range(-100, 100)
	elseif k == 5 then
		return rng:pick(SPECIAL_STRINGS)
	elseif k == 6 then
		return bytes(rng)
	elseif k == 7 then
		local t = {}
		for i = 1, rng:int(0, 6) do
			t[i] = Drafts.garbage(rng, d - 1)
		end
		return t
	elseif k == 8 then
		local t = {}
		for _ = 1, rng:int(1, 5) do
			local key: any = if rng:float() < 0.6 then rng:pick(SPECIAL_STRINGS) else rng:int(-3, 30)
			if key ~= nil and key == key then
				t[key] = Drafts.garbage(rng, d - 1)
			end
		end
		return t
	elseif k == 9 then
		local t: any = {}
		local cur = t
		for _ = 1, rng:int(1, 100) do -- deep nesting (A18's 100 levels)
			cur.parts = {}
			cur = cur.parts
		end
		return t
	end
	return Drafts.mutate(rng, Drafts.validDraft(rng))
end

local FIELDS = { "id", "slot", "shape", "material", "pos", "rot", "size" }

-- One random corruption of a deep copy of draft (the input is not changed). The result may still be valid (an
-- unknown field, a harmless value), in which case Canonical must accept it.
function Drafts.mutate(rng: TestRng, draft: any): any
	local d = Drafts.deepCopy(draft)
	local parts = d.parts
	local n = #parts
	local k = rng:int(1, 14)
	if k == 1 then
		d[rng:pick({ "schema", "name", "type", "parts" })] = Drafts.garbage(rng, 1)
	elseif k == 2 then
		d[rng:pick(SPECIAL_STRINGS)] = Drafts.garbage(rng, 1) -- an unknown (or a known) top-level key
	elseif k == 3 then
		local map = {}
		for i = 1, n do
			map["p" .. i] = parts[i]
		end
		d.parts = map -- parts as a map
	elseif k == 4 then
		for _ = 1, rng:int(1, 30) do
			table.insert(parts, Drafts.deepCopy(parts[1] or {})) -- too many parts, duplicate ids
		end
	elseif n > 0 then
		local i = rng:int(1, n)
		local p = parts[i]
		if k == 5 then
			parts[i] = Drafts.garbage(rng, 1)
		elseif k == 6 then
			p[rng:pick(FIELDS)] = Drafts.garbage(rng, 1)
		elseif k == 7 then
			p[rng:pick(FIELDS)] = nil
		elseif k == 8 then
			local f = rng:pick({ "pos", "rot", "size" })
			local t = p[f]
			t[rng:int(1, #t)] = rng:pick(SPECIAL_NUMBERS) -- NaN, ±inf, out-of-range or harmless numbers
		elseif k == 9 then
			local f = rng:pick({ "pos", "rot", "size" })
			table.insert(p[f], 0) -- one number too many
		elseif k == 10 then
			local f = rng:pick({ "pos", "rot", "size" })
			table.remove(p[f]) -- one number too few
		elseif k == 11 then
			p.id = parts[rng:int(1, n)].id -- maybe a duplicate id
		elseif k == 12 then
			parts[n + 2] = Drafts.deepCopy(p) -- a hole
		elseif k == 13 then
			p.rot = { 0, 0, 0, rng:pick({ 0, 2, 1e-20, 1.0049, 0.99 }) }
		else
			p.extra = Drafts.garbage(rng, 1) -- an unknown part field
		end
	end
	return d
end

-- ── planted modules ───────────────────────────────────────────────────────────────────────────────────────────

-- Loads path (repo-relative, the runner's working directory) as a new module instance whose require(spec) returns
-- modules[spec]; a require the map does not answer errors, so a module that gains a dependency fails loudly here.
function Drafts.planted(path: string, modules: { [string]: any }): any
	local source = fs.readFile(path)
	local env = {
		require = function(spec: string): any
			local m = modules[spec]
			if m == nil then
				error(string.format("Drafts.planted(%s): no module planted for require(%q)", path, spec), 2)
			end
			return m
		end,
	}
	return luau.load(source, { debugName = path .. " (planted)", environment = env })()
end

-- An unfrozen deep copy of catalog rows, in the given order (Catalog.build sorts them by `order` again).
function Drafts.rows(list: { any }, order: { number }?): { any }
	local out = {}
	for i = 1, #list do
		out[i] = Drafts.deepCopy(list[if order then order[i] else i])
	end
	return out
end

-- ── JSON as Roblox writes it ──────────────────────────────────────────────────────────────────────────────────

-- shortest round-trip significant digits of x ≠ 0: sign, digit string, decimal exponent n (x = 0.d × 10^n). If p
-- digits round-trip, so do p + 1 (the correctly rounded longer decimal is at least as close), so a binary search over
-- 1..17 finds the shortest; 17 always round-trips.
local function digitsOf(x: number): (string, string, number)
	local function text(p: number): string
		return string.format("%." .. (p - 1) .. "e", x)
	end
	local lo, hi = 1, 17
	while lo < hi do
		local mid = (lo + hi) // 2
		if tonumber(text(mid)) == x then
			hi = mid
		else
			lo = mid + 1
		end
	end
	local s = text(lo)
	assert(tonumber(s) == x, "no round trip for " .. tostring(x))
	local sign, m, e = string.match(s, "^(%-?)(%d[%.%d]*)e([%-+]%d+)$")
	assert(sign and m and e, s)
	local digits = string.gsub(m :: string, "%.", "")
	digits = string.gsub(digits, "0+$", "")
	if digits == "" then
		digits = "0"
	end
	return sign :: string, digits, (tonumber(e) :: number) + 1
end

-- ECMAScript Number::toString layout: plain for 1e-6 ≤ |x| < 1e21, else d.ddde±N without "+"; "-0" for −0.
function Drafts.jsonNumber(x: number): string
	assert(x == x and x ~= math.huge and x ~= -math.huge, "JSON number must be finite")
	if x == 0 then
		return if 1 / x < 0 then "-0" else "0"
	end
	local sign, d, n = digitsOf(x)
	local k = #d
	if k <= n and n <= 21 then
		return sign .. d .. string.rep("0", n - k)
	elseif 0 < n and n <= 21 then
		return sign .. string.sub(d, 1, n) .. "." .. string.sub(d, n + 1)
	elseif -6 < n and n <= 0 then
		return sign .. "0." .. string.rep("0", -n) .. d
	end
	local e = n - 1
	local es = if e < 0 then "-" .. tostring(-e) else tostring(e)
	if k == 1 then
		return sign .. d .. "e" .. es
	end
	return sign .. string.sub(d, 1, 1) .. "." .. string.sub(d, 2) .. "e" .. es
end

local function jsonString(s: string): string
	local out = string.gsub(s, '[%c"\\]', function(c: string): string
		if c == '"' then
			return '\\"'
		elseif c == "\\" then
			return "\\\\"
		end
		return string.format("\\u%04x", string.byte(c))
	end)
	return '"' .. out .. '"'
end

-- Arrays (#v > 0) as [...], other tables as objects with byte-sorted keys; {} → [] (as JSONEncode does).
function Drafts.jsonEncode(v: any): string
	local t = type(v)
	if t == "number" then
		return Drafts.jsonNumber(v)
	elseif t == "string" then
		return jsonString(v)
	elseif t == "boolean" then
		return if v then "true" else "false"
	elseif t == "table" then
		local n = #v
		if n > 0 then
			local parts = table.create(n)
			for i = 1, n do
				parts[i] = Drafts.jsonEncode(v[i])
			end
			return "[" .. table.concat(parts, ",") .. "]"
		end
		local keys = Dump.sortedKeys(v)
		if #keys == 0 then
			return "[]"
		end
		local parts = {}
		for _, key in keys do
			assert(type(key) == "string", "JSON object keys must be strings")
			table.insert(parts, jsonString(key) .. ":" .. Drafts.jsonEncode(v[key]))
		end
		return "{" .. table.concat(parts, ",") .. "}"
	end
	error("jsonEncode: unsupported " .. t)
end

-- Decodes what jsonEncode writes (no whitespace); numbers through tonumber.
function Drafts.jsonDecode(s: string): any
	local pos = 1
	local value: () -> any
	local function str(): string
		assert(string.sub(s, pos, pos) == '"', "string expected at " .. pos)
		pos += 1
		local out = {}
		while true do
			local c = string.sub(s, pos, pos)
			if c == '"' then
				pos += 1
				return table.concat(out)
			elseif c == "\\" then
				local e = string.sub(s, pos + 1, pos + 1)
				if e == "u" then
					table.insert(out, utf8.char(tonumber(string.sub(s, pos + 2, pos + 5), 16) :: number))
					pos += 6
				else
					table.insert(out, e)
					pos += 2
				end
			elseif c == "" then
				error("unterminated string")
			else
				table.insert(out, c)
				pos += 1
			end
		end
	end
	value = function(): any
		local c = string.sub(s, pos, pos)
		if c == "{" then
			pos += 1
			local t = {}
			if string.sub(s, pos, pos) == "}" then
				pos += 1
				return t
			end
			while true do
				local key = str()
				assert(string.sub(s, pos, pos) == ":", "':' expected at " .. pos)
				pos += 1
				t[key] = value()
				local sep = string.sub(s, pos, pos)
				pos += 1
				if sep == "}" then
					return t
				end
				assert(sep == ",", "',' expected at " .. (pos - 1))
			end
		elseif c == "[" then
			pos += 1
			local t = {}
			if string.sub(s, pos, pos) == "]" then
				pos += 1
				return t
			end
			while true do
				table.insert(t, value())
				local sep = string.sub(s, pos, pos)
				pos += 1
				if sep == "]" then
					return t
				end
				assert(sep == ",", "',' expected at " .. (pos - 1))
			end
		elseif c == '"' then
			return str()
		elseif string.sub(s, pos, pos + 3) == "true" then
			pos += 4
			return true
		elseif string.sub(s, pos, pos + 4) == "false" then
			pos += 5
			return false
		end
		local from, to = string.find(s, "^%-?%d+%.?%d*[eE]?[%-+]?%d*", pos)
		assert(from, "value expected at " .. pos)
		local text = string.sub(s, from :: number, to :: number)
		pos = (to :: number) + 1
		return tonumber(text)
	end
	local v = value()
	assert(pos == #s + 1, "trailing characters at " .. pos)
	return v
end

return Drafts
