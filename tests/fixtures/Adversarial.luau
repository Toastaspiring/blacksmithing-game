--!strict
-- tests/fixtures/Adversarial.luau — the invalid and edge-case drafts A01–A24 and A28 (SPEC §14.7; constructions and expected
-- codes E-S8.4): together one draft per S1 CanonError, S2 ValidationCode and wire code. Each case holds variants;
-- variant.draft() builds a fresh raw draft on every call (the drafts are untrusted input: some are not even tables),
-- so the large ones (A15, A18) cost nothing until used. Most are F1 or F2 with one change.
--
-- Expected outcomes, per variant:
--   canon       Canonical.draft(draft()) (M1): {ok = false, code, path} with SPEC §3.6's first failing check and
--               the field it names ("" for the root, "parts[i].rot" with the draft's own 1-based index), or ok with
--               equals = "draft" (the draft is canonical: the value is the draft, bit for bit) or a fixture id (the
--               value is that fixture's core, bit for bit), or renormalized = {part, rot} (the draft, except that
--               C3 renormalized parts[part].rot to within 1e-12 of rot)
--   validation  Physics/Analyze's verdict (M2): valid, or the errors of the first failing stage in rule then part
--               order (SPEC §4.2)
--   analysis    what M3 measures: cleaned parts, D relations to the base fixture, Thinness, step tiers
--   save        what Blueprint.Save does (M7, S-E2E-04): "Valid" / "Invalid" = stored with valid = true / false;
--               "E_INVALID_BLUEPRINT" = Canonical refused it; "E_BAD_REQUEST" = the Guard refused it first (§10.3)
--   nil         not part of this variant's contract
--
-- Where E-S8.4's summary and the normative text differ, the expectation follows SPEC §3.5, §3.6 and §4.2, and the
-- variant's note says so (A02, A10, A12, A19). ASSUMED lists the Definitions values the constructions are built on;
-- tests/FixtureSet checks them against Definitions, so a changed limit fails there instead of going stale here.

local Build = require("./Build")
local Blueprints = require("./Blueprints")

type Part = Build.Part
type Core = Build.Core

export type CanonExpect = {
	ok: boolean,
	code: string?,
	path: string?,
	equals: string?,
	renormalized: { part: number, rot: { number } }?,
}
export type ValidationError = { code: string, partId: number?, slot: string?, reason: string? }
export type ValidationExpect = { valid: boolean, errors: { ValidationError } }
export type Cleaned = { partId: number, reason: string }
export type Analysis = {
	cleaned: { Cleaned }?,
	relation: { to: string, d: string, gTol: string?, mass: string? }?, -- d: "BitIdentical" | "NonIncreasing"
	thinness: { [string]: number }?, -- normalized Thinness per work set ("All", "Blade")
	steps: { [string]: { tier: string, d: number? } }?,
	finite: boolean?, -- every physics and factor value finite
}
export type Variant = {
	key: string,
	what: string,
	base: string?,
	draft: () -> any,
	canon: CanonExpect,
	validation: ValidationExpect?,
	analysis: Analysis?,
	save: string?,
	note: string?,
}
export type Case = { id: string, title: string, variants: { Variant } }

-- The values the constructions assume (SPEC §16.1, §16.2, §16.5, §16.10, §2.5).
local ASSUMED = {
	BLUEPRINT_SCHEMA = 1,
	EPS_CONTAIN = 1e-4,
	CONTACT_TOL = 0.01,
	MIN_DIM = 0.02,
	MAX_DIM = 6.0,
	POS_ABS_MAX = 16,
	MAX_PARTS = 24,
	MAX_PART_ID = 65535,
	QUAT_NORM_TOL = 1e-9,
	QUAT_INPUT_TOL = 1e-2,
	NAME_MAX_INPUT_BYTES = 256,
	MIN_PART_VOLUME = 0.0002, -- Balance.Geometry: the Dust floor (a 0.05 cube is 0.000125)
	HITBOX_MIN = { -0.80, 0.00, -0.30 },
	HITBOX_MAX = { 0.80, 5.00, 0.30 },
	SLOT_MAX = { Blade = 12, Guard = 8, Grip = 6, Pommel = 4 },
	DISABLED_MATERIAL = "Bronze", -- a Materials row with enabled = false
}

local P = Build.part
local I, Y45, Z45, Y90, Z180 = Build.I, Build.Y45, Build.Z45, Build.Y90, Build.Z180
local NAN = 0 / 0
local INF = math.huge

local function parts(id: string): { Part }
	return Blueprints.core(id).parts
end

local function core(name: string, list: { Part }): Core
	return Build.core(name, list)
end

local function canonOk(): CanonExpect
	return { ok = true, equals = "draft" }
end

local function canonEquals(id: string): CanonExpect
	return { ok = true, equals = id }
end

local function canonErr(code: string, path: string): CanonExpect
	return { ok = false, code = code, path = path }
end

local function valid(): ValidationExpect
	return { valid = true, errors = {} }
end

local function invalid(errors: { ValidationError }): ValidationExpect
	return { valid = false, errors = errors }
end

local CASES: { Case } = {}

local function case(id: string, title: string, variants: { Variant })
	table.insert(CASES, { id = id, title = title, variants = variants })
end

-- A canonical-error variant on a fresh F2 whose `edit` breaks one thing.
local function onF2(key: string, what: string, edit: (d: any) -> (), canon: CanonExpect, save: string?, note: string?): Variant
	return {
		key = key,
		what = what,
		base = "F2",
		draft = function(): any
			local d: any = core(key, parts("F2"))
			edit(d)
			return d
		end,
		canon = canon,
		save = save or "E_INVALID_BLUEPRINT",
		note = note,
	}
end

-- ── A01–A05 containment ───────────────────────────────────────────────────────────────────────────────────────

case("A01", "F2 with its blade top 0.01 above the hitbox", {
	{
		key = "A01",
		what = "blade lengthened from the guard's top face (y 1.55) to y 5.01: 3.46 long, centre y 3.28",
		base = "F2",
		draft = function(): any
			local list = parts("F2")
			list[4].pos[2] = 3.28
			list[4].size[2] = 3.46
			return core("A01", list)
		end,
		canon = canonOk(),
		validation = invalid({ { code = "OutOfHitbox", partId = 4 } }),
		save = "Invalid",
	},
})

case("A02", "F2 with its guard turned: corners out of the hitbox", {
	{
		key = "A02",
		what = "guard turned 45° about Y (the sword axis): its corners reach |z| = 0.354 > 0.30",
		base = "F2",
		draft = function(): any
			local list = parts("F2")
			list[3].rot = table.clone(Y45)
			return core("A02", list)
		end,
		canon = canonOk(),
		validation = invalid({ { code = "OutOfHitbox", partId = 3 } }),
		save = "Invalid",
		note = "E-S8.4 writes 'turned 30° about Z, a corner out', which cannot leave the 1.6-stud width: the turned "
			.. "0.8 × 0.2 guard reaches |x| = 0.396. Turned about the sword axis instead, its corners leave the 0.6-stud "
			.. "thickness.",
	},
})

case("A03", "a Cylinder at 45° near a wall: its box corners are out, the solid is in", {
	{
		key = "A03",
		what = "F2's pommel replaced by a disc (Cylinder 0.20 long, Ø 0.32) with its axis along Z, spun 45° about it, "
			.. "touching the grip: the solid spans y 0.03–0.35, the turned Size box reaches y = −0.036",
		base = "F2",
		draft = function(): any
			local list = parts("F2")
			list[1] = P(1, "Pommel", "Cylinder", "Iron", { 0, 0.19, 0 }, Build.hemisphere(Build.mul(Z45, Y90)),
				{ 0.20, 0.32, 0.32 })
			return core("A03", list)
		end,
		canon = canonOk(),
		validation = valid(),
		save = "Valid",
	},
})

case("A04", "a face flush with the hitbox walls", {
	{
		key = "A04",
		what = "F2's guard widened to 1.60: both end faces on x = ±0.80",
		base = "F2",
		draft = function(): any
			local list = parts("F2")
			list[3].size[1] = 1.6
			return core("A04", list)
		end,
		canon = canonOk(),
		validation = valid(),
		save = "Valid",
	},
})

case("A05", "within EPS_CONTAIN of the walls, and past it", {
	{
		key = "A05a",
		what = "F2's guard 1.6 + 2 · 0.5 · EPS_CONTAIN wide: each end 0.5 · EPS_CONTAIN past the wall",
		base = "F2",
		draft = function(): any
			local list = parts("F2")
			list[3].size[1] = 1.6 + 2 * (0.5 * ASSUMED.EPS_CONTAIN)
			return core("A05a", list)
		end,
		canon = canonOk(),
		validation = valid(),
		save = "Valid",
	},
	{
		key = "A05b",
		what = "F2's guard 1.6 + 2 · 2 · EPS_CONTAIN wide: each end 2 · EPS_CONTAIN past the wall",
		base = "F2",
		draft = function(): any
			local list = parts("F2")
			list[3].size[1] = 1.6 + 2 * (2 * ASSUMED.EPS_CONTAIN)
			return core("A05b", list)
		end,
		canon = canonOk(),
		validation = invalid({ { code = "OutOfHitbox", partId = 3 } }),
		save = "Invalid",
	},
})

-- ── A06–A09 connectivity, slots, orientation ──────────────────────────────────────────────────────────────────

-- F2 + a 0.1-stud Guard cube beside the guard's +X end face (x = 0.40), `gap` away from it.
local function besideGuard(key: string, gap: number): any
	local list = parts("F2")
	table.insert(list, P(5, "Guard", "Block", "Iron", { 0.4 + gap + 0.05, 1.45, 0 }, I, { 0.1, 0.1, 0.1 }))
	return core(key, list)
end

case("A06", "F2 + a Guard part 0.1 from the guard", {
	{
		key = "A06",
		what = "a 0.1 cube 0.1 beyond the guard's end face",
		base = "F2",
		draft = function(): any
			return besideGuard("A06", 0.1)
		end,
		canon = canonOk(),
		validation = invalid({ { code = "Disconnected", partId = 5 } }),
		save = "Invalid",
	},
})

case("A07", "gaps of 0.5 · CONTACT_TOL and 2 · CONTACT_TOL", {
	{
		key = "A07a",
		what = "the A06 cube 0.5 · CONTACT_TOL from the guard: connected",
		base = "F2",
		draft = function(): any
			return besideGuard("A07a", 0.5 * ASSUMED.CONTACT_TOL)
		end,
		canon = canonOk(),
		validation = valid(),
		save = "Valid",
	},
	{
		key = "A07b",
		what = "the A06 cube 2 · CONTACT_TOL from the guard",
		base = "F2",
		draft = function(): any
			return besideGuard("A07b", 2 * ASSUMED.CONTACT_TOL)
		end,
		canon = canonOk(),
		validation = invalid({ { code = "Disconnected", partId = 5 } }),
		save = "Invalid",
	},
})

case("A08", "F2 without its Grip; F2 upside down", {
	{
		key = "A08a",
		what = "F2 without part 2 (the grip): S2's whole list is the quick stage's",
		base = "F2",
		draft = function(): any
			return core("A08a", Build.without(parts("F2"), 2))
		end,
		canon = canonOk(),
		validation = invalid({ { code = "SlotMissing", slot = "Grip" } }),
		save = "Invalid",
	},
	{
		key = "A08b",
		what = "F2 turned upside down inside the hitbox (180° about Z, y → 5 − y): the blade below the grip",
		base = "F2",
		draft = function(): any
			local list = parts("F2")
			for _, p in list do
				p.pos = { 0 - p.pos[1], 5 - p.pos[2], p.pos[3] }
				p.rot = Build.mul(Z180, p.rot)
			end
			return core("A08b", list)
		end,
		canon = canonOk(),
		validation = invalid({ { code = "BladeNotAboveGrip" } }),
		save = "Invalid",
		note = "added so the set holds every ValidationCode (E-S2.10's upside-down case)",
	},
})

case("A09", "F2 without its Blade, its Guard, its Pommel", {
	{
		key = "A09a",
		what = "F2 without part 4 (the blade)",
		base = "F2",
		draft = function(): any
			return core("A09a", Build.without(parts("F2"), 4))
		end,
		canon = canonOk(),
		validation = invalid({ { code = "SlotMissing", slot = "Blade" } }),
		save = "Invalid",
	},
	{
		key = "A09b",
		what = "F2 without part 3 (the guard): the blade floats 0.2 above the grip",
		base = "F2",
		draft = function(): any
			return core("A09b", Build.without(parts("F2"), 3))
		end,
		canon = canonOk(),
		validation = invalid({ { code = "Disconnected", partId = 4 } }),
		save = "Invalid",
	},
	{
		key = "A09c",
		what = "F2 without part 1 (the pommel): Pommel is optional",
		base = "F2",
		draft = function(): any
			return core("A09c", Build.without(parts("F2"), 1))
		end,
		canon = canonOk(),
		validation = valid(),
		save = "Valid",
	},
})

-- ── A10–A13 numbers and rotations ─────────────────────────────────────────────────────────────────────────────

do
	local variants: { Variant } = {}
	local VALUES: { { label: string, value: number } } = {
		{ label = "NaN", value = NAN },
		{ label = "Inf", value = INF },
		{ label = "NegInf", value = -INF },
	}
	for _, field in { "pos", "size", "rot" } do
		local n = if field == "rot" then 4 else 3
		for k = 1, n do
			for _, v in VALUES do
				local key = string.format("A10-%s%d-%s", field, k, v.label)
				table.insert(variants, onF2(key, string.format("F2's guard with %s[%d] = %s", field, k, v.label),
					function(d: any)
						d.parts[3][field][k] = v.value
					end, canonErr("NonFinite", "parts[3]." .. field), "E_BAD_REQUEST",
					"§10.3's Guard.plain admits finite numbers only, so a Save is refused before Canonical runs; "
						.. "E-S8.6 lists A10 under E_INVALID_BLUEPRINT in S-E2E-04, and E-S8.4 writes Malformed, "
						.. "where §3.5 C1 gives NonFinite"))
			end
		end
	end
	case("A10", "NaN, +inf and −inf in each numeric component", variants)
end

do
	local variants: { Variant } = {}
	local A = ASSUMED
	local SIZES: { { label: string, value: number } } = {
		{ label = "Zero", value = 0 },
		{ label = "Negative", value = -0.2 },
		{ label = "BelowMin", value = A.MIN_DIM - 1e-6 },
		{ label = "AboveMax", value = A.MAX_DIM + 1e-6 },
	}
	for k = 1, 3 do
		for _, s in SIZES do
			local key = string.format("A11-size%d-%s", k, s.label)
			table.insert(variants, onF2(key, string.format("F2's guard with size[%d] = %.17g", k, s.value),
				function(d: any)
					d.parts[3].size[k] = s.value
				end, canonErr("OutOfRange", "parts[3].size")))
		end
		for _, sign in { 1, -1 } do
			local key = string.format("A11-pos%d-%s", k, if sign > 0 then "AboveMax" else "BelowMin")
			local value = sign * (A.POS_ABS_MAX + 1e-6)
			table.insert(variants, onF2(key, string.format("F2's guard with pos[%d] = %.17g", k, value), function(d: any)
				d.parts[3].pos[k] = value
			end, canonErr("OutOfRange", "parts[3].pos")))
		end
	end
	-- the bounds are inclusive: refused never means clamped, and the limit itself passes Canonical
	local EDGES: { { key: string, what: string, field: string, k: number, value: number } } = {
		{ key = "A11-size2-AtMin", what = "F2's guard with size[2] = MIN_DIM", field = "size", k = 2, value = A.MIN_DIM },
		{ key = "A11-size1-AtMax", what = "F2's guard with size[1] = MAX_DIM", field = "size", k = 1, value = A.MAX_DIM },
		{ key = "A11-pos1-AtMax", what = "F2's guard with pos[1] = POS_ABS_MAX", field = "pos", k = 1, value = A.POS_ABS_MAX },
		{ key = "A11-pos3-AtMin", what = "F2's guard with pos[3] = −POS_ABS_MAX", field = "pos", k = 3, value = -A.POS_ABS_MAX },
	}
	for _, e in EDGES do
		table.insert(variants, {
			key = e.key,
			what = e.what .. ": accepted (validation is another matter)",
			base = "F2",
			draft = function(): any
				local d: any = core(e.key, parts("F2"))
				d.parts[3][e.field][e.k] = e.value
				return d
			end,
			canon = canonOk(),
		})
	end
	case("A11", "sizes and positions out of range, and on the limits", variants)
end

do
	local variants: { Variant } = {}
	local function rotVariant(key: string, what: string, rot: { number }, canon: CanonExpect, save: string?, note: string?)
		table.insert(variants, {
			key = key,
			what = what,
			base = "F2",
			draft = function(): any
				local d: any = core(key, parts("F2"))
				d.parts[3].rot = table.clone(rot)
				return d
			end,
			canon = canon,
			save = save,
			note = note,
		})
	end
	local refusedNote = "E-S8.4 groups {0,0,0,2} with 'renormalized'; under §3.5 C2 its ‖q‖² = 4 is refused like any "
		.. "quaternion further than QUAT_INPUT_TOL from unit"
	rotVariant("A12-Zero", "F2's guard with q = {0, 0, 0, 0}", { 0, 0, 0, 0 }, canonErr("BadRotation", "parts[3].rot"),
		"E_INVALID_BLUEPRINT")
	rotVariant("A12-Tiny", "F2's guard with q = {1e-20, 0, 0, 0}", { 1e-20, 0, 0, 0 },
		canonErr("BadRotation", "parts[3].rot"), "E_INVALID_BLUEPRINT")
	rotVariant("A12-Double", "F2's guard with q = {0, 0, 0, 2}", { 0, 0, 0, 2 }, canonErr("BadRotation", "parts[3].rot"),
		"E_INVALID_BLUEPRINT", refusedNote)
	local s = math.sqrt(1 + 1e-3)
	rotVariant("A12-Sloppy", "F2's guard with q = {0, 0, 0, √1.001}: ‖q‖² = 1 + 1e-3, renormalized (C3), finite",
		{ 0, 0, 0, s }, { ok = true, renormalized = { part = 3, rot = { 0, 0, 0, 1 } } }, "Valid")
	rotVariant("A12-SloppyZ45", "F2's guard with q = −√1.001 · Z45: renormalized, then the hemisphere rule (C3, C4)",
		{ 0, 0, -s * Z45[3], -s * Z45[4] }, { ok = true, renormalized = { part = 3, rot = { 0, 0, Z45[3], Z45[4] } } })
	local inside = math.sqrt(1 + 0.99 * ASSUMED.QUAT_INPUT_TOL)
	local outside = math.sqrt(1 + 1.01 * ASSUMED.QUAT_INPUT_TOL)
	local insideLow = math.sqrt(1 - 0.99 * ASSUMED.QUAT_INPUT_TOL)
	local outsideLow = math.sqrt(1 - 1.01 * ASSUMED.QUAT_INPUT_TOL)
	rotVariant("A12-InputTolIn", "‖q‖² = 1 + 0.99 · QUAT_INPUT_TOL: accepted, renormalized", { 0, 0, 0, inside },
		{ ok = true, renormalized = { part = 3, rot = { 0, 0, 0, 1 } } }, "Valid")
	rotVariant("A12-InputTolOut", "‖q‖² = 1 + 1.01 · QUAT_INPUT_TOL: refused", { 0, 0, 0, outside },
		canonErr("BadRotation", "parts[3].rot"), "E_INVALID_BLUEPRINT")
	rotVariant("A12-InputTolInLow", "‖q‖² = 1 − 0.99 · QUAT_INPUT_TOL: accepted, renormalized", { 0, 0, 0, insideLow },
		{ ok = true, renormalized = { part = 3, rot = { 0, 0, 0, 1 } } }, "Valid")
	rotVariant("A12-InputTolOutLow", "‖q‖² = 1 − 1.01 · QUAT_INPUT_TOL: refused", { 0, 0, 0, outsideLow },
		canonErr("BadRotation", "parts[3].rot"), "E_INVALID_BLUEPRINT")
	rotVariant("A12-NormTolIn", "q = {0, 0, 0, 1 + 0.4 · QUAT_NORM_TOL}: ‖q‖² − 1 ≈ 0.8 · QUAT_NORM_TOL, kept bit "
		.. "for bit (C3 fires only above the threshold, so canonical data never drifts)",
		{ 0, 0, 0, 1 + 0.4 * ASSUMED.QUAT_NORM_TOL }, canonOk(), "Valid")
	case("A12", "degenerate, oversized and sloppy quaternions", variants)
end

case("A13", "F1 written non-canonically: canonical form gives F1 back", {
	{
		key = "A13",
		what = "F1 with every quaternion negated (−I = {−0, −0, −0, −1})",
		base = "F1",
		draft = function(): any
			local c = Blueprints.core("F1")
			for _, p in c.parts do
				p.rot = Build.neg(p.rot)
			end
			return c
		end,
		canon = canonEquals("F1"),
		save = "Valid",
	},
	{
		key = "A13b",
		what = "F1 with its parts in reverse order (C7 sorts by id)",
		base = "F1",
		draft = function(): any
			local c = Blueprints.core("F1")
			local reversed: { Part } = {}
			for i = #c.parts, 1, -1 do
				table.insert(reversed, c.parts[i])
			end
			c.parts = reversed
			return c
		end,
		canon = canonEquals("F1"),
		save = "Valid",
	},
	{
		key = "A13c",
		what = "F1 with −0 for every zero position component (C5)",
		base = "F1",
		draft = function(): any
			local c = Blueprints.core("F1")
			for _, p in c.parts do
				for k = 1, 3 do
					if p.pos[k] == 0 then
						p.pos[k] = -0
					end
				end
			end
			return c
		end,
		canon = canonEquals("F1"),
		save = "Valid",
	},
})

-- ── A14–A18 filler and size ───────────────────────────────────────────────────────────────────────────────────

-- The 19 dust cubes of A14 (0.05 stud, 0.000125 stud³ < MIN_PART_VOLUME), each flush on a face of F1's part in
-- its slot: 8 on the blade's ±Z faces, 6 on the guard's top face, 3 on the grip's +Z face, 2 against the pommel ball.
local function f1Dust(): { Part }
	local d = { 0.05, 0.05, 0.05 }
	local out: { Part } = {}
	local id = 5
	local function add(slot: string, pos: { number })
		id += 1
		table.insert(out, P(id, slot, "Block", "Iron", pos, I, d))
	end
	for _, z in { 0.055, -0.055 } do
		for _, y in { 1.7, 2.2, 2.7, 3.2 } do
			add("Blade", { 0, y, z })
		end
	end
	for _, x in { -0.4, -0.3, -0.2, 0.2, 0.3, 0.4 } do
		add("Guard", { x, 1.405, 0 })
	end
	for _, y in { 0.5, 0.75, 1.0 } do
		add("Grip", { 0, y, 0.105 })
	end
	add("Pommel", { 0.155, 0.17, 0 })
	add("Pommel", { -0.155, 0.17, 0 })
	return out
end

case("A14", "F1 + 19 attached dust cubes, every slot within its maximum (24 parts)", {
	{
		key = "A14",
		what = "F1 + 19 cubes of 0.05 stud flush on its parts (Blade 10, Guard 7, Grip 4, Pommel 3)",
		base = "F1",
		draft = function(): any
			local list = parts("F1")
			for _, p in f1Dust() do
				table.insert(list, p)
			end
			return core("A14", list)
		end,
		canon = canonOk(),
		validation = valid(),
		analysis = {
			cleaned = (function(): { Cleaned }
				local out: { Cleaned } = {}
				for id = 6, 24 do
					table.insert(out, { partId = id, reason = "Dust" })
				end
				return out
			end)(),
			relation = { to = "F1", d = "NonIncreasing", gTol = "TOL_DUST_G" },
		},
		save = "Valid",
	},
})

-- n extra parts with ids from firstId: 0.05 cubes on F1's blade face, or with a NaN position when `broken`.
local function extraParts(n: number, firstId: number, broken: boolean): { Part }
	local out: { Part } = table.create(n)
	for k = 0, n - 1 do
		local pos = if broken then { NAN, 2.0, 0.055 } else { 0, 1.5 + (k % 20) * 0.1, 0.055 }
		out[k + 1] = P(firstId + k, "Blade", "Block", "Iron", pos, I, { 0.05, 0.05, 0.05 })
	end
	return out
end

local function f1Plus(key: string, extra: { Part }): any
	local list = parts("F1")
	table.move(extra, 1, #extra, #list + 1, list)
	return core(key, list)
end

case("A15", "more parts than MAX_PARTS", {
	{
		key = "A15",
		what = "F1 + 2,000 parts whose positions are NaN: TooManyParts, before any per-part check",
		base = "F1",
		draft = function(): any
			return f1Plus("A15", extraParts(2000, 6, true))
		end,
		canon = canonErr("TooManyParts", "parts"),
		save = "E_BAD_REQUEST",
		note = "over the wire the Guard's node budget (MAX_PAYLOAD_NODES 6,000; ≈ 18 nodes per part) refuses it first",
	},
	{
		key = "A15b",
		what = "F1 + 20 well-formed cubes: MAX_PARTS + 1 = 25 parts",
		base = "F1",
		draft = function(): any
			return f1Plus("A15b", extraParts(20, 6, false))
		end,
		canon = canonErr("TooManyParts", "parts"),
		save = "E_INVALID_BLUEPRINT",
		note = "added: the MAX_PARTS + 1 boundary, small enough to pass the Guard",
	},
})

case("A16", "F1 + parts enclosed in its blade and its guard", {
	{
		key = "A16",
		what = "F1 + a Blade block inside the blade and a Guard block inside the guard (≥ 0.01 from every face)",
		base = "F1",
		draft = function(): any
			local list = parts("F1")
			table.insert(list, P(6, "Blade", "Block", "Steel", { 0, 2.68, 0 }, I, { 0.10, 1.00, 0.04 }))
			table.insert(list, P(7, "Guard", "Block", "Iron", { 0, 1.29, 0 }, I, { 0.60, 0.10, 0.16 }))
			return core("A16", list)
		end,
		canon = canonOk(),
		validation = valid(),
		analysis = {
			cleaned = { { partId = 6, reason = "Enclosed" }, { partId = 7, reason = "Enclosed" } },
			relation = { to = "F1", d = "BitIdentical", mass = "Identical" },
		},
		save = "Valid",
	},
})

case("A17", "F2 + 3 exact copies of its blade", {
	{
		key = "A17",
		what = "F2 + parts 5, 6, 7 = part 4 (duplicates are Enclosed; the lowest id is kept)",
		base = "F2",
		draft = function(): any
			local list = parts("F2")
			for id = 5, 7 do
				local copy = Build.copy(list[4])
				copy.id = id
				table.insert(list, copy)
			end
			return core("A17", list)
		end,
		canon = canonOk(),
		validation = valid(),
		analysis = {
			cleaned = {
				{ partId = 5, reason = "Enclosed" },
				{ partId = 6, reason = "Enclosed" },
				{ partId = 7, reason = "Enclosed" },
			},
			relation = { to = "F2", d = "BitIdentical", mass = "Identical" },
		},
		save = "Valid",
	},
})

local function nested(depth: number): any
	local t: any = { 0 }
	for _ = 2, depth do
		t = { t }
	end
	return t
end

case("A18", "oversize payloads: refused before per-part work", {
	{
		key = "A18a",
		what = "F1 + 10,000 parts",
		base = "F1",
		draft = function(): any
			return f1Plus("A18a", extraParts(10000, 6, false))
		end,
		canon = canonErr("TooManyParts", "parts"),
		save = "E_BAD_REQUEST",
	},
	{
		key = "A18b",
		what = "F1 named with a 1 MB string",
		base = "F1",
		draft = function(): any
			local c: any = Blueprints.core("F1")
			c.name = string.rep("A", 1048576)
			return c
		end,
		canon = canonErr("BadName", "name"),
		save = "E_BAD_REQUEST",
	},
	{
		key = "A18c",
		what = "F1 whose parts[1].pos is a 100-deep nest",
		base = "F1",
		draft = function(): any
			local c: any = Blueprints.core("F1")
			c.parts[1].pos = nested(100)
			return c
		end,
		canon = canonErr("Malformed", "parts[1].pos"),
		save = "E_BAD_REQUEST",
	},
	{
		key = "A18d",
		what = "F1 with an unknown field holding a 100-deep nest: Canonical never reads it, the Guard refuses it",
		base = "F1",
		draft = function(): any
			local c: any = Blueprints.core("F1")
			c.extra = nested(100)
			return c
		end,
		canon = canonEquals("F1"),
		save = "E_BAD_REQUEST",
	},
})

-- ── A19–A20 structure and ids ─────────────────────────────────────────────────────────────────────────────────

do
	local v: { Variant } = {}
	local function add(key: string, what: string, edit: (d: any) -> (), canon: CanonExpect)
		table.insert(v, onF2(key, what, edit, canon))
	end
	local function whole(key: string, what: string, make: () -> any, canon: CanonExpect, save: string?, note: string?)
		table.insert(v, {
			key = key,
			what = what,
			base = "F2",
			draft = make,
			canon = canon,
			save = save or "E_INVALID_BLUEPRINT",
			note = note,
		})
	end
	whole("A19-String", "the draft is a string", function(): any
		return "Minimal Sword"
	end, canonErr("Malformed", ""))
	whole("A19-Number", "the draft is a number", function(): any
		return 42
	end, canonErr("Malformed", ""))
	whole("A19-Array", "the draft is an array holding F2's core (it has no schema)", function(): any
		return { core("A19-Array", parts("F2")) }
	end, canonErr("UnsupportedSchema", "schema"), "E_BAD_REQUEST",
		"the array adds a level (depth 5 > MAX_DRAFT_DEPTH 4), so §10.3's Guard refuses a Save first; on its own, "
			.. "Canonical answers UnsupportedSchema, because §3.6 check 1 only asks for a table (E-S8.4 writes Malformed)")
	whole("A19-ArrayFlat", "the draft is a flat array { \"Minimal Sword\", 1 } (added: an array the Guard admits)",
		function(): any
			local flat: { any } = { "Minimal Sword", 1 }
			return flat
		end, canonErr("UnsupportedSchema", "schema"), "E_INVALID_BLUEPRINT",
		"§3.6 check 1 only asks for a table, so check 2 answers UnsupportedSchema (E-S8.4 writes Malformed)")
	add("A19-PartsMap", "parts is a map keyed by slot names", function(d: any)
		local map: { [string]: any } = {}
		for _, p in d.parts do
			map[string.lower(p.slot)] = p
		end
		d.parts = map
	end, canonErr("Malformed", "parts"))

	local function field(key: string, name: string, value: any, canon: CanonExpect)
		add(key, string.format("%s = %s", name, if value == nil then "nil" else tostring(value)), function(d: any)
			d[name] = value
		end, canon)
	end
	field("A19-SchemaString", "schema", "1", canonErr("UnsupportedSchema", "schema"))
	field("A19-SchemaNext", "schema", 2, canonErr("UnsupportedSchema", "schema"))
	field("A19-SchemaNil", "schema", nil, canonErr("UnsupportedSchema", "schema"))
	field("A19-NameNumber", "name", 5, canonErr("BadName", "name"))
	field("A19-NameNil", "name", nil, canonErr("BadName", "name"))
	field("A19-TypeNumber", "type", 5, canonErr("UnknownId", "type"))
	field("A19-TypeNil", "type", nil, canonErr("UnknownId", "type"))
	field("A19-PartsString", "parts", "x", canonErr("Malformed", "parts"))
	field("A19-PartsNumber", "parts", 5, canonErr("Malformed", "parts"))
	field("A19-PartsNil", "parts", nil, canonErr("Malformed", "parts"))

	local function part(key: string, value: any)
		add(key, "parts[2] = " .. tostring(value), function(d: any)
			d.parts[2] = value
		end, canonErr("Malformed", "parts[2]"))
	end
	part("A19-PartNumber", 5)
	part("A19-PartString", "Grip")
	part("A19-PartBoolean", true)

	local function partField(key: string, name: string, value: any, canon: CanonExpect)
		add(key, string.format("parts[2].%s = %s", name, if type(value) == "table" then "a table" else tostring(value)),
			function(d: any)
				d.parts[2][name] = value
			end, canon)
	end
	local idErr = canonErr("Malformed", "parts[2].id")
	partField("A19-IdString", "id", "2", idErr)
	partField("A19-IdFraction", "id", 2.5, idErr)
	partField("A19-IdZero", "id", 0, idErr)
	partField("A19-IdAboveMax", "id", ASSUMED.MAX_PART_ID + 1, idErr)
	table.insert(v, onF2("A19-IdNaN", "parts[2].id = nan", function(d: any)
		d.parts[2].id = NAN
	end, idErr, "E_BAD_REQUEST",
		"§10.3's Guard.plain admits finite numbers only, so a Save is refused before Canonical runs; E-S8.6 lists A19 "
			.. "under E_INVALID_BLUEPRINT in S-E2E-04. On its own, Canonical answers Malformed (§3.6 check 6: the id "
			.. "is not an integer), as E-S8.4 writes"))
	partField("A19-IdNil", "id", nil, idErr)
	partField("A19-SlotNumber", "slot", 5, canonErr("SlotNotInType", "parts[2].slot"))
	partField("A19-SlotNil", "slot", nil, canonErr("SlotNotInType", "parts[2].slot"))
	partField("A19-ShapeNumber", "shape", 5, canonErr("UnknownId", "parts[2].shape"))
	partField("A19-ShapeNil", "shape", nil, canonErr("UnknownId", "parts[2].shape"))
	partField("A19-MaterialNumber", "material", 5, canonErr("UnknownId", "parts[2].material"))
	partField("A19-MaterialNil", "material", nil, canonErr("UnknownId", "parts[2].material"))
	local posErr = canonErr("Malformed", "parts[2].pos")
	partField("A19-PosString", "pos", "0, 0.85, 0", posErr)
	partField("A19-PosTwo", "pos", { 0, 0.85 }, posErr)
	partField("A19-PosFour", "pos", { 0, 0.85, 0, 0 }, posErr)
	partField("A19-PosStringComponent", "pos", { 0, "0.85" :: any, 0 }, posErr)
	partField("A19-PosMap", "pos", { x = 0, y = 0.85, z = 0 }, posErr)
	partField("A19-PosNil", "pos", nil, posErr)
	partField("A19-SizeTwo", "size", { 0.2, 1.0 }, canonErr("Malformed", "parts[2].size"))
	partField("A19-RotThree", "rot", { 0, 0, 1 }, canonErr("Malformed", "parts[2].rot"))
	partField("A19-RotFive", "rot", { 0, 0, 0, 1, 0 }, canonErr("Malformed", "parts[2].rot"))
	partField("A19-RotNil", "rot", nil, canonErr("Malformed", "parts[2].rot"))

	add("A19-DuplicateId", "parts[3].id = 2, the id of parts[2] (added: DuplicatePartId names the later copy)",
		function(d: any)
			d.parts[3].id = 2
		end, canonErr("DuplicatePartId", "parts[3].id"))
	table.insert(v, {
		key = "A19-IdAtMax",
		what = "parts[4].id = MAX_PART_ID: accepted",
		base = "F2",
		draft = function(): any
			local d = core("A19-IdAtMax", parts("F2"))
			d.parts[4].id = ASSUMED.MAX_PART_ID
			return d
		end,
		canon = canonOk(),
		save = "Valid",
	})
	table.insert(v, {
		key = "A19-UnknownFields",
		what = "F2 with unknown fields on the draft and its parts (a record's id, revision, analysis; extras): dropped",
		base = "F2",
		draft = function(): any
			local d: any = Blueprints.core("F2")
			d.id = "0D7F2C9E-4B1A-4C3D-9E8F-1A2B3C4D5E6F"
			d.revision = 7
			d.analysis = { valid = true, issues = {} }
			d.extra = { 1, 2, 3 }
			d.parts[1].label = "Pommel"
			d.parts[2].mirrored = true
			return d
		end,
		canon = canonEquals("F2"),
		save = "Valid",
		note = "E-S8.4 writes 'unknown fields → Malformed'; §3.6 rebuilds the draft from its known fields and never "
			.. "pairs-iterates a client table, so unknown fields are dropped (T-BP-03: the output has known fields only)",
	})
	case("A19", "malformed drafts: wrong shapes and types, never a throw", v)
end

do
	local v: { Variant } = {}
	local function id(key: string, what: string, name: string, value: string, canon: CanonExpect)
		table.insert(v, onF2(key, what, function(d: any)
			d.parts[1][name] = value
		end, canon))
	end
	id("A20-ShapeSphere", "parts[1].shape = \"Sphere\"", "shape", "Sphere", canonErr("UnknownId", "parts[1].shape"))
	id("A20-ShapeCase", "parts[1].shape = \"block\" (ids are case-sensitive)", "shape", "block",
		canonErr("UnknownId", "parts[1].shape"))
	id("A20-SlotHilt", "parts[1].slot = \"Hilt\"", "slot", "Hilt", canonErr("SlotNotInType", "parts[1].slot"))
	id("A20-SlotForeign", "parts[1].slot = \"Head\" (a reserved slot of another type)", "slot", "Head",
		canonErr("SlotNotInType", "parts[1].slot"))
	id("A20-MaterialDisabled", "parts[1].material = " .. ASSUMED.DISABLED_MATERIAL .. " (a disabled row)", "material",
		ASSUMED.DISABLED_MATERIAL, canonErr("DisabledId", "parts[1].material"))
	id("A20-MaterialUnknown", "parts[1].material = \"Adamant\"", "material", "Adamant",
		canonErr("UnknownId", "parts[1].material"))
	table.insert(v, onF2("A20-TypeReserved", "type = \"Axe\" (an id reserved for Phase 3, no row)", function(d: any)
		d.type = "Axe"
	end, canonErr("UnknownId", "type")))
	case("A20", "unknown, foreign and disabled ids", v)
end

-- ── A21–A24 slot rules and thin parts ─────────────────────────────────────────────────────────────────────────

case("A21", "13 Blade parts", {
	{
		key = "A21",
		what = "F2 with its blade cut into 13 flush segments (ids 4–16): one over the Blade maximum",
		base = "F2",
		draft = function(): any
			local list = parts("F2")
			local blade = table.remove(list, 4) :: Part
			local n = ASSUMED.SLOT_MAX.Blade + 1
			local length = blade.size[2] / n
			local bottom = blade.pos[2] - blade.size[2] / 2
			for k = 0, n - 1 do
				table.insert(list, P(4 + k, "Blade", "Block", blade.material, { 0, bottom + (k + 0.5) * length, 0 }, I,
					{ blade.size[1], length, blade.size[3] }))
			end
			return core("A21", list)
		end,
		canon = canonOk(),
		validation = invalid({ { code = "SlotTooMany", slot = "Blade" } }),
		save = "Invalid",
	},
})

case("A22", "a required slot whose only part is cleaned", {
	{
		key = "A22a",
		what = "F2 whose only Blade part is a 0.05 dust cube on the guard",
		base = "F2",
		draft = function(): any
			local list = Build.without(parts("F2"), 4)
			table.insert(list, P(4, "Blade", "Block", "Iron", { 0, 1.575, 0 }, I, { 0.05, 0.05, 0.05 }))
			return core("A22a", list)
		end,
		canon = canonOk(),
		validation = invalid({ { code = "SlotMissing", slot = "Blade", reason = "Cleaned" } }),
		analysis = { cleaned = { { partId = 4, reason = "Dust" } } },
		save = "Invalid",
	},
	{
		key = "A22b",
		what = "F2 whose only Blade part is enclosed in the guard",
		base = "F2",
		draft = function(): any
			local list = Build.without(parts("F2"), 4)
			table.insert(list, P(4, "Blade", "Block", "Iron", { 0, 1.45, 0 }, I, { 0.30, 0.10, 0.10 }))
			return core("A22b", list)
		end,
		canon = canonOk(),
		validation = invalid({ { code = "SlotMissing", slot = "Blade", reason = "Cleaned" } }),
		analysis = { cleaned = { { partId = 4, reason = "Enclosed" } } },
		save = "Invalid",
	},
	{
		key = "A22c",
		what = "F2 whose only Grip part is enclosed in a pommel grown around it (the pommel touches the guard)",
		base = "F2",
		draft = function(): any
			local list = parts("F2")
			list[1] = P(1, "Pommel", "Block", "Iron", { 0, 0.70, 0 }, I, { 0.30, 1.30, 0.30 })
			list[2] = P(2, "Grip", "Block", "Iron", { 0, 0.80, 0 }, I, { 0.20, 0.90, 0.20 })
			return core("A22c", list)
		end,
		canon = canonOk(),
		validation = invalid({ { code = "SlotMissing", slot = "Grip", reason = "Cleaned" } }),
		analysis = { cleaned = { { partId = 2, reason = "Enclosed" } } },
		save = "Invalid",
	},
})

case("A23", "a side exactly MIN_DIM", {
	{
		key = "A23",
		what = "F2 + a 0.10 × 1.20 × MIN_DIM plate flush on the blade's +Z face",
		base = "F2",
		draft = function(): any
			local list = parts("F2")
			table.insert(list, P(5, "Blade", "Block", "Iron", { 0, 2.40, 0.04 + ASSUMED.MIN_DIM / 2 }, I,
				{ 0.10, 1.20, ASSUMED.MIN_DIM }))
			return core("A23", list)
		end,
		canon = canonOk(),
		validation = valid(),
		analysis = { finite = true },
		save = "Valid",
	},
})

case("A24", "a needle blade of MIN_DIM × 3.0 × MIN_DIM", {
	{
		key = "A24",
		what = "F2 with its blade replaced by a 0.02 × 3.0 × 0.02 needle standing on the guard",
		base = "F2",
		draft = function(): any
			local list = Build.without(parts("F2"), 4)
			table.insert(list, P(4, "Blade", "Block", "Iron", { 0, 1.55 + 1.5, 0 }, I,
				{ ASSUMED.MIN_DIM, 3.0, ASSUMED.MIN_DIM }))
			return core("A24", list)
		end,
		canon = canonOk(),
		validation = valid(),
		analysis = {
			finite = true,
			thinness = { All = 1, Blade = 1 }, -- saturated, never above 1
			steps = { Hammering = { tier = "Hard", d = 0.40 } },
		},
		save = "Valid",
	},
})

-- A25–A27 are M3's hidden-grip variants (SPEC §14.7).
case("A28", "a design past the verdicts' cap", {
	{
		key = "A28",
		what = "24 thin rods in one bundle, 0.004 apart across and 0.01 deep: their verdicts pass VERDICT_WORK_MAX",
		draft = function(): any
			local list: { Part } = {}
			for i = 1, ASSUMED.MAX_PARTS do
				local slot, y = "Blade", 2.55
				if i > ASSUMED.SLOT_MAX.Blade + 6 then
					slot, y = "Grip", 2.45
				elseif i > ASSUMED.SLOT_MAX.Blade then
					slot, y = "Guard", 2.5
				end
				table.insert(list, P(i, slot, "Cylinder", "Iron", { 0.004 * ((i - 1) % 8), y, 0.01 * ((i - 1) // 8) }, Build.Z90,
					{ 1.2, ASSUMED.MIN_DIM, ASSUMED.MIN_DIM }))
			end
			return core("A28", list)
		end,
		canon = canonOk(),
		validation = invalid({ { code = "TooComplex" } }),
		save = "Invalid",
		note = "valid but for the cap: V1–V4 hold, so TooComplex is the only error (SPEC §4.4, §4.9)",
	},
})

-- ── index ─────────────────────────────────────────────────────────────────────────────────────────────────────

local BY_ID: { [string]: Case } = {}
local ORDER: { string } = {}
local VARIANTS: { Variant } = {}
for _, c in CASES do
	BY_ID[c.id] = c
	table.insert(ORDER, c.id)
	for _, variant in c.variants do
		table.insert(VARIANTS, variant)
	end
end

local Adversarial = {
	ASSUMED = ASSUMED,
	order = ORDER, -- {"A01", …, "A24", "A28"}
	list = CASES,
	variants = VARIANTS, -- every variant of every case, in case order
}

-- The case with this id; errors on an unknown id (a test bug).
function Adversarial.get(id: string): Case
	local c = BY_ID[id]
	if c == nil then
		error("Adversarial.get: no case " .. tostring(id), 2)
	end
	return c
end

-- The variant with this key; errors on an unknown key.
function Adversarial.variant(key: string): Variant
	for _, variant in VARIANTS do
		if variant.key == key then
			return variant
		end
	end
	error("Adversarial.variant: no variant " .. tostring(key), 2)
end

Build.freeze(CASES)
table.freeze(ORDER)
table.freeze(VARIANTS)
Build.freeze(ASSUMED)
return table.freeze(Adversarial)
