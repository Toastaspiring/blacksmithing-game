--!strict
-- T-RND-01 ItemRender/RenderPlan (SPEC §13.7, §14.5, E-S7.4, E-S7.5): bounds of every fixture, against numbers worked
-- out by hand from E-S8.3's coordinates and against Gen's independent geometry; rotated cylinders against brute-force
-- sampling; the Wedge and CornerWedge vertex sets from §3.2's solids, tight; anchors, scale, non-unit quaternions,
-- every PlanError in order, determinism and the generic properties. The goldens of T-RND-01 wait for S-PAR-01 (§17.2:
-- the vertex sets must match the engine before they freeze); M6 blesses them.

local Test = require("../lib/Test")
local A = require("../lib/Assert")
local Dump = require("../lib/Dump")
local Gen = require("../lib/Gen")
local Prop = require("../lib/Prop")
local TestRng = require("../lib/TestRng")
local Tol = require("../lib/Tol")
local Blueprints = require("../fixtures/Blueprints")
local Drafts = require("../Blueprint/Drafts")
local Balance = require("../../src/shared/Definitions/Balance")
local EquipmentTypes = require("../../src/shared/Definitions/EquipmentTypes")
local Limits = require("../../src/shared/Definitions/Limits")
local Materials = require("../../src/shared/Definitions/Materials")
local Versions = require("../../src/shared/Definitions/Versions")
local Canonical = require("../../src/shared/Blueprint/Canonical")
local Quat = require("../../src/shared/Blueprint/Quat")
local Shapes = require("../../src/shared/Physics/Shapes")
local RenderPlan = require("../../src/shared/ItemRender/RenderPlan")

type TestRng = TestRng.TestRng
type Vec = { number }

-- Fixtures and generators hold plain strings, and hostile values on purpose: the module is called untyped here.
local fromBlueprint: (parts: any, opts: any?) -> (any, any) = RenderPlan.fromBlueprint :: any
local primitive: (part: any, anchor: any, scale: any) -> (any, any) = RenderPlan.primitive :: any

local CTX = Gen.context(Limits, EquipmentTypes.get("Sword"), Materials.enabled, Versions.BLUEPRINT_SCHEMA,
	Balance.Geometry)
local PLAN_ERRORS = {
	Empty = true,
	TooManyParts = true,
	BadShape = true,
	BadMaterial = true,
	NonFinite = true,
	BadSize = true,
}
local ANCHORS = { "BaseCenter", "Center", "Origin" }
local TIGHT = 1e-12 -- studs: rounding of the matrix and the sums, on coordinates up to POS_ABS_MAX

local R = 0.70710678118654757
local ID: Vec = { 0, 0, 0, 1 }
local P = Drafts.part

-- E-S7.4's arming sword (render_plan_partdata.luau): its bounds and Blade-slot bounds are the evidence's figures.
local function armingSword(): { any }
	return {
		P(1, "Pommel", "Ball", "Iron", { 0, 0.30, 0 }, ID, { 0.30, 0.30, 0.30 }),
		P(2, "Grip", "Cylinder", "Iron", { 0, 0.88, 0 }, { 0, 0, R, R }, { 0.90, 0.16, 0.16 }),
		P(3, "Guard", "Block", "Iron", { 0, 1.40, 0 }, ID, { 1.10, 0.16, 0.24 }),
		P(4, "Blade", "Block", "Steel", { 0, 2.65, 0 }, ID, { 0.20, 2.50, 0.06 }),
		P(5, "Blade", "Wedge", "Steel", { 0.05, 4.10, 0 }, { 0, -R, 0, R }, { 0.06, 0.40, 0.10 }),
		P(6, "Blade", "Wedge", "Steel", { -0.05, 4.10, 0 }, { 0, R, 0, R }, { 0.06, 0.40, 0.10 }),
	}
end

-- Worked out by hand from E-S8.3's coordinates (each part's half extents about its centre; F1's and F5's tip is a
-- 0.113 square turned 45° about Z, half diagonal 0.0565·√2).
local TIP_TOP = 3.98 + 0.0565 * math.sqrt(2)
local FIXTURE_BOUNDS: { [string]: { min: Vec, max: Vec } } = {
	F1 = { min = { -0.5, 0.04, -0.13 }, max = { 0.5, TIP_TOP, 0.13 } },
	F2 = { min = { -0.4, 0.05, -0.15 }, max = { 0.4, 3.95, 0.15 } },
	F3 = { min = { -0.51, 0.02, -0.14 }, max = { 0.51, 4.98, 0.14 } },
	F4 = { min = { -0.25, 0.1, -0.15 }, max = { 0.6, 3.95, 0.15 } },
	F5 = { min = { -0.5, 0.04, -0.13 }, max = { 0.5, TIP_TOP, 0.13 } },
}

local function near(a: Vec, b: Vec, tol: number, what: string)
	for k = 1, #b do
		A.near(a[k], b[k], tol, what .. "[" .. k .. "]")
	end
end

local function nearBounds(got: any, lo: Vec, hi: Vec, tol: number, what: string)
	near(got.min, lo, tol, what .. " min")
	near(got.max, hi, tol, what .. " max")
end

-- The primitive as a record in plan space, so Gen's geometry can measure what was drawn: rot from the 9 components.
local function drawn(prim: any): any
	local c = prim.cf
	return {
		id = prim.partId,
		slot = prim.slot,
		shape = prim.shape,
		material = prim.material,
		pos = { c[1], c[2], c[3] },
		rot = Quat.fromMatrix(c[4], c[5], c[6], c[7], c[8], c[9], c[10], c[11], c[12]),
		size = prim.size,
	}
end

local function drawnBounds(plan: any): (Vec, Vec)
	local records = {}
	for i, prim in plan.primitives do
		records[i] = drawn(prim)
	end
	return Gen.bounds(records)
end

-- A random rotation, position inside the record bounds of §3.5, a side in [MIN_DIM, MAX_DIM] per axis, canonical sizes.
local function randomPart(rng: TestRng, shape: string?): any
	local s = shape or rng:pick(Gen.SHAPES)
	local function side(): number
		return Limits.MIN_DIM + rng:float() * (Limits.MAX_DIM - Limits.MIN_DIM)
	end
	return P(rng:int(1, Limits.MAX_PART_ID), rng:pick({ "Blade", "Guard", "Grip", "Pommel" }), s,
		rng:pick({ "Iron", "Steel" }), { rng:range(-8, 8), rng:range(-8, 8), rng:range(-8, 8) }, Drafts.unitQuat(rng),
		Canonical.canonicalSize(s :: any, { side(), side(), side() }))
end

local function walkNumbers(v: any, visit: (number) -> ())
	if type(v) == "number" then
		visit(v)
	elseif type(v) == "table" then
		for _, x in v do
			walkNumbers(x, visit)
		end
	end
end

-- Untrusted input: an error code or a plan with only finite numbers, never a throw.
local function expectTotal(plan: any, code: any, what: string)
	if plan == nil then
		A.truthy(PLAN_ERRORS[code], what .. ": unknown error " .. tostring(code))
	else
		A.eq(code, nil, what .. ": a plan and an error")
		walkNumbers(plan, function(x: number)
			A.finite(x, what)
		end)
	end
end

return Test.suite("ItemRender/RenderPlan", function(t)
	t.it("T-RND-01 bounds of F1–F5 equal the numbers worked out by hand and Gen's independent geometry", function()
		for _, id in Blueprints.order do
			local core = Blueprints.get(id).core
			local plan, err = fromBlueprint(core.parts)
			A.truthy(plan, id .. ": " .. tostring(err))
			local want = FIXTURE_BOUNDS[id]
			nearBounds(plan.bounds, want.min, want.max, TIGHT, id)
			local lo, hi = Gen.bounds(core.parts)
			nearBounds(plan.bounds, lo, hi, TIGHT, id .. " vs Gen")
			A.eq(#plan.primitives, #core.parts, id .. " one primitive per part")
		end
	end)

	t.it("T-RND-01 slotBounds: F1's four by hand; each is its parts' AABB; together they are the bounds", function()
		local plan = fromBlueprint(Blueprints.get("F1").core.parts)
		nearBounds(plan.slotBounds.Pommel, { -0.13, 0.04, -0.13 }, { 0.13, 0.30, 0.13 }, TIGHT, "F1 Pommel")
		nearBounds(plan.slotBounds.Grip, { -0.08, 0.30, -0.08 }, { 0.08, 1.20, 0.08 }, TIGHT, "F1 Grip")
		nearBounds(plan.slotBounds.Guard, { -0.5, 1.20, -0.12 }, { 0.5, 1.38, 0.12 }, TIGHT, "F1 Guard")
		nearBounds(plan.slotBounds.Blade, { -0.08, 1.38, -0.03 }, { 0.08, TIP_TOP, 0.03 }, TIGHT, "F1 Blade")
		Prop.check(Tol.PROP_N, function(rng: TestRng): Gen.Core
			return Gen.validSword(rng, CTX)
		end, function(core: Gen.Core)
			local p = fromBlueprint(core.parts)
			local lo: Vec = { math.huge, math.huge, math.huge }
			local hi: Vec = { -math.huge, -math.huge, -math.huge }
			for _, slot in { "Blade", "Guard", "Grip", "Pommel" } do
				local mine = {}
				for _, part in core.parts do
					if part.slot == slot then
						table.insert(mine, part)
					end
				end
				if #mine == 0 then
					A.eq(p.slotBounds[slot], nil, slot .. " has no parts")
				else
					local a, b = Gen.bounds(mine)
					nearBounds(p.slotBounds[slot], a, b, TIGHT, slot)
					for k = 1, 3 do
						lo[k], hi[k] = math.min(lo[k], a[k]), math.max(hi[k], b[k])
					end
				end
			end
			nearBounds(p.bounds, lo, hi, TIGHT, "the union of the slots")
		end)
	end)

	t.it("E-S7.4's arming sword: bounds and Blade-slot bounds, max error 0 at the evidence's precision", function()
		local plan, err = fromBlueprint(armingSword())
		A.truthy(plan, tostring(err))
		nearBounds(plan.bounds, { -0.55, 0.15, -0.15 }, { 0.55, 4.30, 0.15 }, TIGHT, "bounds")
		nearBounds(plan.slotBounds.Blade, { -0.10, 1.40, -0.03 }, { 0.10, 4.30, 0.03 }, TIGHT, "Blade")
	end)

	t.it("T-RND-01 a rotated cylinder's closed form agrees with brute-force sampling, ≤ 1e-6", function()
		local rng = TestRng.new(Dump.fnv1a32("T-RND-01 cylinder"))
		local STEPS = 7200 -- a sampled circle's extent is short by at most r·(π/STEPS)²/2 = 2.9e-7 at r = 3
		for _ = 1, 20 do
			local part = randomPart(rng, "Cylinder")
			local plan = fromBlueprint({ part })
			local rot = part.rot
			local u, v, w = Quat.rotate(rot, { 1, 0, 0 }), Quat.rotate(rot, { 0, 1, 0 }), Quat.rotate(rot, { 0, 0, 1 })
			local hx, r = part.size[1] / 2, part.size[2] / 2
			local lo: Vec = { math.huge, math.huge, math.huge }
			local hi: Vec = { -math.huge, -math.huge, -math.huge }
			for cap = -1, 1, 2 do
				for i = 0, STEPS - 1 do
					local angle = 2 * math.pi * i / STEPS
					local c, s = r * math.cos(angle), r * math.sin(angle)
					for k = 1, 3 do
						local x = part.pos[k] + cap * hx * u[k] + c * v[k] + s * w[k]
						lo[k], hi[k] = math.min(lo[k], x), math.max(hi[k], x)
					end
				end
			end
			nearBounds(plan.bounds, lo, hi, 1e-6, "cylinder " .. Dump.short(part))
		end
	end)

	t.it("T-RND-01 Wedge, CornerWedge: bounds = the corners §3.2's solids keep, on §4's surfaces, tight", function()
		-- §3.2's inequalities on the normalized corner (a, b, c): which of the box's 8 corners stay in the solid
		local KEEPS: { [string]: (number, number, number) -> boolean } = {
			Wedge = function(_a: number, b: number, c: number): boolean
				return c >= b
			end,
			CornerWedge = function(a: number, b: number, c: number): boolean
				return b <= a and b <= -c
			end,
		}
		local COUNT = { Wedge = 6, CornerWedge = 5 } -- §13.7's vertex sets
		Prop.check(Tol.PROP_N, function(rng: TestRng): any
			return randomPart(rng, if rng:float() < 0.5 then "Wedge" else "CornerWedge")
		end, function(part: any)
			local keeps = KEEPS[part.shape]
			local prepared = Shapes.prepare(part, 1)
			local lo: Vec = { math.huge, math.huge, math.huge }
			local hi: Vec = { -math.huge, -math.huge, -math.huge }
			local kept = 0
			for _, a in { -1, 1 } do
				for _, b in { -1, 1 } do
					for _, c in { -1, 1 } do
						if keeps(a, b, c) then
							kept += 1
							local s = part.size
							local l = Quat.rotate(part.rot, { a * s[1] / 2, b * s[2] / 2, c * s[3] / 2 })
							local x, y, z = part.pos[1] + l[1], part.pos[2] + l[2], part.pos[3] + l[3]
							A.near(Shapes.sd(prepared, x, y, z), 0, TIGHT, "a vertex is on the solid's surface")
							lo = { math.min(lo[1], x), math.min(lo[2], y), math.min(lo[3], z) }
							hi = { math.max(hi[1], x), math.max(hi[2], y), math.max(hi[3], z) }
						end
					end
				end
			end
			A.eq(kept, COUNT[part.shape], part.shape .. " vertices")
			local plan = fromBlueprint({ part })
			nearBounds(plan.bounds, lo, hi, TIGHT, part.shape .. " bounds")
		end)
	end)

	t.it("T-RND-01 no point of a solid leaves its bounds, for any shape", function()
		Prop.check(Tol.PROP_N, function(rng: TestRng): any
			return { part = randomPart(rng), rng = rng }
		end, function(input: any)
			local part, rng = input.part, input.rng
			local plan = fromBlueprint({ part })
			local prepared = Shapes.prepare(part, 1)
			local lo, hi = plan.bounds.min, plan.bounds.max
			for _ = 1, 50 do
				local hx, hy, hz = prepared.hx, prepared.hy, prepared.hz
				local lx, ly, lz = rng:range(-hx, hx), rng:range(-hy, hy), rng:range(-hz, hz)
				local x, y, z = Shapes.toWorld(prepared, lx, ly, lz)
				if Shapes.sd(prepared, x, y, z) <= 0 then
					local q = { x, y, z }
					for k = 1, 3 do
						A.within(q[k], lo[k] - TIGHT, hi[k] + TIGHT, "a point of the solid, axis " .. k)
					end
				end
			end
		end)
	end)

	t.it("the primitive: part order, ids, slots, shapes, materials; cf through Quat.toMatrix; stored sizes", function()
		local parts = Blueprints.get("F3").core.parts
		local plan = fromBlueprint(parts, { anchor = "Origin" })
		for i, part in parts do
			local prim = plan.primitives[i]
			A.eq(prim.partId, part.id, "partId")
			A.eq(prim.slot, part.slot, "slot")
			A.eq(prim.shape, part.shape, "shape")
			A.eq(prim.material, part.material, "material")
			A.eq(#prim.cf, 12, "cf holds x, y, z, R00..R22")
			local cf = prim.cf
			A.truthy(Drafts.bitDiff({ cf[1], cf[2], cf[3] }, part.pos) == nil, "Origin: the stored position")
			local rows = { cf[4], cf[5], cf[6], cf[7], cf[8], cf[9], cf[10], cf[11], cf[12] }
			local diff = Drafts.bitDiff(rows, { Quat.toMatrix(part.rot) })
			A.truthy(diff == nil, "R00..R22: " .. tostring(diff))
			A.truthy(Drafts.bitDiff(prim.size, part.size) == nil, "the stored size")
		end
	end)

	t.it("the look comes from the Materials row, retired rows too; a plan shares no table with anything", function()
		for _, def in Materials.ordered do
			local part = P(7, "Blade", "Block", def.id, { 0, 1, 0 }, ID, { 1, 1, 1 })
			local plan, err = fromBlueprint({ part })
			A.truthy(plan, def.id .. ": " .. tostring(err))
			local prim = plan.primitives[1]
			A.deepEq(prim.color, def.color, def.id .. " color")
			A.eq(prim.robloxMaterial, def.robloxMaterial, def.id .. " robloxMaterial")
			A.eq(prim.reflectance, def.reflectance, def.id .. " reflectance")
			A.falsy(prim.color == def.color, "a copy of the row's color")
			A.falsy(table.isfrozen(prim.color), "a mutable copy")
			A.falsy(Drafts.sharesTable(plan, part), "nothing shared with the part")
			A.falsy(Drafts.repeatsTable(plan), "no table twice inside a plan")
		end
		A.falsy(Materials.isEnabled("Bronze"), "Bronze is a retired row in the MVP")
	end)

	t.it("T-RND-01 anchors: default Center, scale 1; Center centres, BaseCenter min Y at 0, Origin keeps pos", function()
		Prop.check(Tol.PROP_N, function(rng: TestRng): Gen.Core
			return Gen.validSword(rng, CTX)
		end, function(core: Gen.Core)
			local parts = core.parts
			local lo, hi = Gen.bounds(parts)
			local default = fromBlueprint(parts)
			A.eq(default.anchor, "Center", "default anchor")
			A.eq(default.scale, 1, "default scale")
			A.truthy(Drafts.bitDiff(default, (fromBlueprint(parts, {}))) == nil, "{} is the default")
			local named = fromBlueprint(parts, { anchor = "Center", scale = 1 })
			A.truthy(Drafts.bitDiff(default, named) == nil, "the default, named")

			local a, b = drawnBounds(default)
			for k = 1, 3 do
				A.near(a[k] + b[k], 0, TIGHT, "Center: the drawn item centres on the pivot, axis " .. k)
				A.near(b[k] - a[k], hi[k] - lo[k], TIGHT, "Center: extents, axis " .. k)
			end

			local base = fromBlueprint(parts, { anchor = "BaseCenter" })
			A.eq(base.anchor, "BaseCenter", "anchor kept")
			a, b = drawnBounds(base)
			A.near(a[2], 0, TIGHT, "BaseCenter: min Y at 0")
			A.near(b[2], hi[2] - lo[2], TIGHT, "BaseCenter: the item's height")
			A.near(a[1] + b[1], 0, TIGHT, "BaseCenter: centred in X")
			A.near(a[3] + b[3], 0, TIGHT, "BaseCenter: centred in Z")

			local origin = fromBlueprint(parts, { anchor = "Origin" })
			a, b = drawnBounds(origin)
			nearBounds({ min = a, max = b }, lo, hi, TIGHT, "Origin: blueprint coordinates")
			for _, anchor in ANCHORS do
				local plan = fromBlueprint(parts, { anchor = anchor })
				A.truthy(Drafts.bitDiff(plan.bounds, origin.bounds) == nil, "bounds are blueprint space for " .. anchor)
			end
		end)
	end)

	t.it("T-RND-01 anchors off the centre planes: position = scale·(p − anchor) on every axis", function()
		local part = P(1, "Blade", "Block", "Iron", { 0.3, 1, 0.2 }, ID, { 0.2, 0.4, 0.1 })
		local function at(opts: any): Vec
			local prim = fromBlueprint({ part }, opts).primitives[1]
			return { prim.cf[1], prim.cf[2], prim.cf[3] }
		end
		near(at({ anchor = "Center" }), { 0, 0, 0 }, TIGHT, "Center")
		near(at({ anchor = "BaseCenter", scale = 2 }), { 0, 0.4, 0 }, TIGHT, "BaseCenter")
		near(at({ anchor = "Origin", scale = 2 }), { 0.6, 2, 0.4 }, TIGHT, "Origin")
		local prim = primitive(part, { 0.1, 0.2, 0.3 }, 2)
		near({ prim.cf[1], prim.cf[2], prim.cf[3] }, { 0.4, 1.6, -0.2 }, TIGHT, "primitive")
	end)

	t.it("T-RND-01 scale k multiplies sizes and positions; rotations and bounds do not change", function()
		local parts = Blueprints.get("F4").core.parts
		for _, anchor in ANCHORS do
			local one = fromBlueprint(parts, { anchor = anchor })
			for _, k in { 0.05, 0.5, 1, 2, 3.7 } do
				local plan = fromBlueprint(parts, { anchor = anchor, scale = k })
				A.eq(plan.scale, k, "scale kept")
				A.truthy(Drafts.bitDiff(plan.bounds, one.bounds) == nil, "bounds unchanged")
				for i, prim in plan.primitives do
					local base = one.primitives[i]
					for c = 1, 3 do
						A.near(prim.size[c], k * base.size[c], TIGHT, "size")
						A.near(prim.cf[c], k * base.cf[c], TIGHT, "position")
					end
					for c = 4, 12 do
						A.eq(prim.cf[c], base.cf[c], "rotation")
					end
				end
			end
		end
	end)

	t.it("T-RND-01 toMatrix(k·q): a non-unit quaternion draws the same part", function()
		Prop.check(Tol.PROP_N, function(rng: TestRng): any
			return { part = randomPart(rng), k = rng:range(0.5, 2) }
		end, function(input: any)
			local part, k = input.part, input.k
			local plain = fromBlueprint({ part })
			local q = part.rot
			local scaled = table.clone(part)
			scaled.rot = { k * q[1], k * q[2], k * q[3], k * q[4] }
			local plan = fromBlueprint({ scaled })
			for c = 4, 12 do
				A.near(plan.primitives[1].cf[c], plain.primitives[1].cf[c], 1e-14, "R component")
			end
			nearBounds(plan.bounds, plain.bounds.min, plain.bounds.max, 1e-12, "bounds")
		end)
	end)

	t.it("primitive(part, anchor, scale) equals the plan's primitive at the plan's anchor point", function()
		Prop.check(Tol.PROP_N, function(rng: TestRng): any
			return { core = Gen.validSword(rng, CTX), k = rng:range(0.5, 2), anchor = rng:pick(ANCHORS) }
		end, function(input: any)
			local parts = input.core.parts
			local plan = fromBlueprint(parts, { anchor = input.anchor, scale = input.k })
			local lo, hi = plan.bounds.min, plan.bounds.max
			local cx, cy, cz = (lo[1] + hi[1]) / 2, (lo[2] + hi[2]) / 2, (lo[3] + hi[3]) / 2
			local point = if input.anchor == "Origin" then { 0, 0, 0 }
				elseif input.anchor == "BaseCenter" then { cx, lo[2], cz }
				else { cx, cy, cz }
			for i, part in parts do
				local prim, err = primitive(part, point, input.k)
				A.truthy(prim, tostring(err))
				local diff = Drafts.bitDiff(prim, plan.primitives[i])
				A.truthy(diff == nil, tostring(diff))
			end
		end)
	end)

	t.it("T-RND-01 every PlanError, from fromBlueprint and from primitive", function()
		local good = P(1, "Blade", "Block", "Iron", { 0, 1, 0 }, ID, { 1, 1, 1 })
		local function with(field: string, value: any): any
			local p = table.clone(good)
			p[field] = value
			return p
		end
		A.eq(select(2, fromBlueprint({})), "Empty", "no parts")
		local many = {}
		for i = 1, Limits.MAX_PARTS + 1 do
			many[i] = good
		end
		A.eq(select(2, fromBlueprint(many)), "TooManyParts", "MAX_PARTS + 1")
		many[Limits.MAX_PARTS + 1] = nil
		A.truthy((fromBlueprint(many)), "MAX_PARTS exactly")

		local CASES: { { field: string, value: any, code: string } } = {
			{ field = "shape", value = "Sphere", code = "BadShape" },
			{ field = "shape", value = "ball", code = "BadShape" },
			{ field = "shape", value = 5, code = "BadShape" },
			{ field = "slot", value = 3, code = "BadShape" },
			{ field = "material", value = "Adamant", code = "BadMaterial" },
			{ field = "material", value = false, code = "BadMaterial" },
			{ field = "id", value = "1", code = "NonFinite" },
			{ field = "id", value = 0 / 0, code = "NonFinite" },
			{ field = "pos", value = { 0, 0 / 0, 0 }, code = "NonFinite" },
			{ field = "pos", value = { 0, math.huge, 0 }, code = "NonFinite" },
			{ field = "pos", value = { 0, 0 }, code = "NonFinite" },
			{ field = "pos", value = "here", code = "NonFinite" },
			{ field = "rot", value = { 0, 0, 0 }, code = "NonFinite" },
			{ field = "rot", value = { 0, 0, 0, -math.huge }, code = "NonFinite" },
			{ field = "rot", value = { 0, 0, 0, 0 }, code = "NonFinite" }, -- no rotation at all: R(q) is NaN
			{ field = "rot", value = { 1e308, 0, 0, 0 }, code = "NonFinite" }, -- ‖q‖² overflows
			{ field = "size", value = { 1, 1, 0 / 0 }, code = "NonFinite" },
			{ field = "size", value = { 1, 1, 1, 1 }, code = "NonFinite" },
			{ field = "size", value = { Limits.MIN_DIM * 0.99, 1, 1 }, code = "BadSize" },
			{ field = "size", value = { 1, Limits.MAX_DIM * 1.01, 1 }, code = "BadSize" },
			{ field = "size", value = { 1, 1, -1 }, code = "BadSize" },
		}
		for k, case in CASES do
			local bad = with(case.field, case.value)
			local what = string.format("case %d %s = %s", k, case.field, Dump.short(case.value))
			A.eq(select(2, fromBlueprint({ bad })), case.code, what)
			A.eq(select(2, primitive(bad, { 0, 0, 0 }, 1)), case.code, "primitive, " .. what)
			A.eq(select(2, fromBlueprint({ good, bad })), case.code, "a bad part anywhere refuses the plan, " .. what)
		end
		-- a huge but finite position overflows only where it is scaled or summed
		local huge = with("pos", { 1e308, 0, 0 })
		A.eq(select(2, fromBlueprint({ huge, with("pos", { 1.7e308, 0, 0 }) })), "NonFinite", "Center's sum overflows")
		A.eq(select(2, fromBlueprint({ huge }, { anchor = "Origin", scale = 10 })), "NonFinite", "scale overflows")
		A.eq(select(2, primitive(huge, { 0, 0, 0 }, 10)), "NonFinite", "primitive: scale overflows")

		-- not even a part
		local JUNK: { any } = { 7, "x", true, {} }
		for _, junk in JUNK do
			local _, code = fromBlueprint({ junk })
			A.eq(code, "BadShape", "a junk part")
			local _, single = primitive(junk, { 0, 0, 0 }, 1)
			A.eq(single, "BadShape", "primitive: a junk part")
		end
		A.eq(select(2, fromBlueprint(nil)), "Empty", "nil")
		A.eq(select(2, fromBlueprint(7)), "Empty", "a number")
		A.eq(select(2, fromBlueprint({ a = good })), "Empty", "a map")

		-- sides exactly at the limits are fine
		A.truthy((fromBlueprint({ with("size", { Limits.MIN_DIM, Limits.MAX_DIM, 1 }) })), "the limits are inclusive")

		-- scale and anchor
		local BAD_SCALES: { any } = { 0 / 0, math.huge, -math.huge, "2" }
		for _, bad in BAD_SCALES do
			A.eq(select(2, fromBlueprint({ good }, { scale = bad })), "NonFinite", "scale " .. tostring(bad))
			A.eq(select(2, primitive(good, { 0, 0, 0 }, bad)), "NonFinite", "primitive, scale " .. tostring(bad))
		end
		for _, bad in { 0, -1 } do
			A.eq(select(2, fromBlueprint({ good }, { scale = bad })), "BadSize", "scale " .. tostring(bad))
			A.eq(select(2, primitive(good, { 0, 0, 0 }, bad)), "BadSize", "primitive, scale " .. tostring(bad))
		end
		A.eq(select(2, primitive(good, { 0, 0 }, 1)), "NonFinite", "an anchor of 2 numbers")
		A.eq(select(2, primitive(good, { 0, 0, 0 / 0 }, 1)), "NonFinite", "a NaN anchor")
		A.eq(select(2, primitive(good, nil, 1)), "NonFinite", "no anchor")
		A.throws(function()
			fromBlueprint({ good }, { anchor = "Middle" })
		end, "unknown anchor", "an unknown anchor name is a caller's bug")
	end)

	t.it("the checks run in §13.7's order, each over every part before the next", function()
		local good = P(1, "Blade", "Block", "Iron", { 0, 1, 0 }, ID, { 1, 1, 1 })
		local function with(fields: { [string]: any }): any
			local p = table.clone(good)
			for k, v in fields do
				p[k] = v
			end
			return p
		end
		local badSize = with({ size = { 0.001, 1, 1 } })
		local badNumber = with({ pos = { 0 / 0, 0, 0 } })
		local badMaterial = with({ material = "Adamant" })
		local badShape = with({ shape = "Sphere" })
		A.eq(select(2, fromBlueprint({ badSize, badNumber })), "NonFinite", "finite before size, across parts")
		A.eq(select(2, fromBlueprint({ badNumber, badMaterial })), "BadMaterial", "material before finite, across")
		A.eq(select(2, fromBlueprint({ badMaterial, badShape })), "BadShape", "shape before material, across parts")
		A.eq(select(2, fromBlueprint({ badSize }, { scale = 0 / 0 })), "NonFinite", "a NaN scale before size")
		local all = with({ shape = "Sphere", material = "Adamant", pos = { 0 / 0, 0, 0 }, size = { 0.001, 1, 1 } })
		A.eq(select(2, fromBlueprint({ all })), "BadShape", "one part, every fault")
		local many = {}
		for i = 1, Limits.MAX_PARTS + 1 do
			many[i] = all
		end
		A.eq(select(2, fromBlueprint(many)), "TooManyParts", "the count first")
		A.eq(select(2, primitive(all, { 0 / 0, 0, 0 }, 0 / 0)), "BadShape", "primitive: shape first")
		A.eq(select(2, primitive(badSize, { 0 / 0, 0, 0 }, 1)), "NonFinite", "primitive: finite before size")
	end)

	t.it("canonical data never fails: Canonical.draft's every output with parts draws", function()
		Prop.check(Tol.PROP_N, function(rng: TestRng): any
			return Drafts.validDraft(rng, { parts = rng:int(1, Limits.MAX_PARTS) })
		end, function(raw: any)
			local result = Canonical.draft(raw) :: any
			A.truthy(result.ok, "the generator's drafts pass Canonical")
			local plan, err = fromBlueprint(result.value.parts, { anchor = "BaseCenter" })
			A.truthy(plan, tostring(err))
			A.eq(#plan.primitives, #result.value.parts, "a primitive per part")
			expectTotal(plan, err, "canonical")
		end)
	end)

	t.it("P-DET, P-NOMUT: the same input gives the same plan, bit for bit; inputs stay as they were", function()
		for _, id in Blueprints.order do
			local parts = Blueprints.get(id).core.parts -- deep-frozen: a mutation would raise
			for _, anchor in ANCHORS do
				local a, b = fromBlueprint(parts, { anchor = anchor }), fromBlueprint(parts, { anchor = anchor })
				local diff = Drafts.bitDiff(a, b)
				A.truthy(diff == nil, id .. ": " .. tostring(diff))
				A.falsy(a == b or a.primitives == b.primitives or a.bounds == b.bounds, "fresh tables per call")
			end
		end
		Prop.check(Tol.PROP_N, function(rng: TestRng): Gen.Core
			return Gen.validSword(rng, CTX)
		end, function(core: Gen.Core)
			local before = Drafts.deepCopy(core)
			fromBlueprint(core.parts)
			for _, part in core.parts do
				primitive(part, { 1, 2, 3 }, 2)
			end
			local diff = Drafts.bitDiff(core, before)
			A.truthy(diff == nil, tostring(diff))
		end)
	end)

	t.it("P-TOTAL, P-FINITE: hostile values return an error or a finite plan, never throw (FUZZ_N_GARBAGE)", function()
		Prop.check(Tol.FUZZ_N_GARBAGE, function(rng: TestRng): any
			return Gen.garbage(rng, CTX)
		end, function(value: any)
			local plan, code = fromBlueprint(value)
			expectTotal(plan, code, "the value itself")
			if type(value) == "table" then
				plan, code = fromBlueprint(value.parts)
				expectTotal(plan, code, "its parts")
				if type(value.parts) == "table" then
					local first = value.parts[1]
					local prim, single = primitive(first, { 0, 0, 0 }, 1)
					expectTotal(prim, single, "its first part")
				end
			end
		end)
	end)

	t.it("P-TOTAL: hostile drafts of the Blueprint suite too (FUZZ_N_GARBAGE)", function()
		Prop.check(Tol.FUZZ_N_GARBAGE, function(rng: TestRng): any
			return Drafts.garbage(rng)
		end, function(value: any)
			local plan, code = fromBlueprint(if type(value) == "table" then value.parts else value)
			expectTotal(plan, code, "parts")
		end)
	end)
end)
