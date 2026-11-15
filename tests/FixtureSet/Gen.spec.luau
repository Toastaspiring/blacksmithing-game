--!strict
-- tests/lib/Gen (SPEC §14.2, E-S8.5): what each generator promises, so the property suites that use it test the
-- module and not the generator. validSword designs are canonical, within every slot rule, inside the hitbox with
-- Gen.MARGIN and above the Dust floor, and cover the five shapes; garbage reaches every CanonError Canonical can
-- return and never makes it throw or mutate its input; the transforms keep designs canonical and within the rules.
-- Connectivity and S2's validity of validSword designs are T-VAL-04's (M2).

local Test = require("../lib/Test")
local A = require("../lib/Assert")
local Dump = require("../lib/Dump")
local Gen = require("../lib/Gen")
local Prop = require("../lib/Prop")
local TestRng = require("../lib/TestRng")
local Tol = require("../lib/Tol")
local Blueprints = require("../fixtures/Blueprints")
local Shape = require("./Shape")
local Balance = require("../../src/shared/Definitions/Balance")
local EquipmentTypes = require("../../src/shared/Definitions/EquipmentTypes")
local Limits = require("../../src/shared/Definitions/Limits")
local Materials = require("../../src/shared/Definitions/Materials")
local Versions = require("../../src/shared/Definitions/Versions")
local Canonical = require("../../src/shared/Blueprint/Canonical")
local Names = require("../../src/shared/Blueprint/Names")

local SWORD = EquipmentTypes.get("Sword") :: any
local DEFS: Shape.Defs = {
	limits = Limits,
	typeDef = SWORD,
	materials = Materials,
	schema = Versions.BLUEPRINT_SCHEMA,
	shapes = Gen.SHAPES,
}
local CTX = Gen.context(Limits, SWORD, Materials.enabled, Versions.BLUEPRINT_SCHEMA, Balance.Geometry)

local function expectCanonical(core: any, what: string)
	local problems = Shape.problems(core, DEFS)
	if #problems > 0 then
		A.fail(what .. ": " .. table.concat(problems, "; "))
	end
	local slots = Shape.slotProblems(core, SWORD)
	if #slots > 0 then
		A.fail(what .. ": " .. table.concat(slots, "; "))
	end
	A.truthy(Canonical.isCanonical(core), what .. ": Canonical.isCanonical")
end

-- A deep copy that keeps non-table leaves (buffers by identity), for P-NOMUT on garbage.
local function snapshot(v: any): any
	if type(v) ~= "table" then
		return v
	end
	local out = {}
	for k, x in v do
		out[k] = snapshot(x)
	end
	return out
end

local function totalVolume(core: any): number
	local v = 0
	for _, p in core.parts do
		v += Gen.volume(p)
	end
	return v
end

local function sweep(): { Gen.Core }
	local out: { Gen.Core } = {}
	for _, id in Blueprints.order do
		table.insert(out, Blueprints.core(id))
	end
	return out
end

return Test.suite("FixtureSet/Gen", function(t)
	t.it("Gen.context reads Definitions and refuses an incomplete one", function()
		A.eq(CTX.schema, Versions.BLUEPRINT_SCHEMA)
		A.eq(CTX.typeId, "Sword")
		A.eq(CTX.minDim, Limits.MIN_DIM)
		A.eq(CTX.maxParts, Limits.MAX_PARTS)
		A.eq(CTX.dustVolume, Balance.Geometry.MIN_PART_VOLUME)
		A.eq(#CTX.slots, #SWORD.slots)
		A.eq(table.concat(CTX.materials, " "), "Iron Steel", "enabled materials in catalogue order")
		A.throws(function()
			Gen.context({ MAX_DIM = 6 }, SWORD, Materials.enabled, 1, Balance.Geometry)
		end, "MIN_DIM")
	end)

	t.it("validSword is deterministic per seed and varies across seeds", function()
		local a = Dump.canonical(Gen.validSword(TestRng.new(7), CTX))
		A.eq(Dump.canonical(Gen.validSword(TestRng.new(7), CTX)), a, "same seed, same bits")
		A.truthy(Dump.canonical(Gen.validSword(TestRng.new(8), CTX)) ~= a, "another seed, another sword")
	end)

	t.it("validSword designs are canonical, within the slot rules, inside the hitbox, above the Dust floor", function()
		Prop.check(Tol.FUZZ_N_VALID, function(rng)
			return Gen.validSword(rng, CTX)
		end, function(core: Gen.Core)
			expectCanonical(core, "validSword")
			A.eq(Names.sanitize(core.name), core.name, "the name is a sanitized name")
			local tables: { [any]: boolean } = {}
			for _, p in core.parts do
				for _, v in { p, p.pos, p.rot, p.size } :: { any } do
					A.falsy(tables[v], "part " .. p.id .. " shares a table with another part")
					tables[v] = true
				end
			end
			A.truthy(Gen.margin(CTX, core.parts) >= Gen.MARGIN - 1e-9, "inside the hitbox with Gen.MARGIN")
			for _, p in core.parts do
				A.truthy(Gen.volume(p) >= 2 * CTX.dustVolume, "part " .. p.id .. " above twice the Dust floor")
			end
			-- the stack: every Blade part above every Grip part (V4 by construction)
			local gripTop, bladeBottom = -math.huge, math.huge
			for _, p in core.parts do
				local lo, hi = Gen.aabb(p)
				if p.slot == "Grip" then
					gripTop = math.max(gripTop, hi[2])
				elseif p.slot == "Blade" then
					bladeBottom = math.min(bladeBottom, lo[2])
				end
			end
			A.truthy(bladeBottom >= gripTop - 1e-9, "the blade stands above the grip")
		end)
	end)

	-- About 1 design in 25,000 used to come out with a finial inside an offset blade, and Enclosed. Whether that happened
	-- to be drawn should not decide T-VAL-04, so the promise is checked at its cause, on every design: a blade block is the
	-- only part tall and wide enough to swallow a finial, and it never stands over one in X.
	t.it("validSword stands no blade block over a CornerWedge finial (nothing enclosed, by construction)", function()
		local finials = 0
		Prop.check(Tol.FUZZ_N_VALID, function(rng)
			return Gen.validSword(rng, CTX)
		end, function(core: Gen.Core)
			for _, finial in core.parts do
				if finial.shape == "CornerWedge" then
					finials += 1
					local lo, hi = Gen.aabb(finial)
					for _, blade in core.parts do
						if blade.slot == "Blade" and blade.shape == "Block" then
							local bladeLo, bladeHi = Gen.aabb(blade)
							-- the same height range: higher segments stand clear of a finial on the bar
							if bladeLo[2] < hi[2] and bladeHi[2] > lo[2] then
								A.truthy(hi[1] <= bladeLo[1] or lo[1] >= bladeHi[1], "finial " .. finial.id .. " under blade " .. blade.id)
							end
						end
					end
				end
			end
		end)
		A.truthy(finials > 0, "no finial was generated")
	end)

	t.it("validSword covers every shape, both materials, rotations and the optional slots", function()
		local shapes: { [string]: number } = {}
		local materials: { [string]: number } = {}
		local counts: { [string]: { [number]: boolean } } = { Blade = {}, Guard = {}, Grip = {}, Pommel = {} }
		local rotated, mixed = 0, 0
		local rng = TestRng.new(Tol.PROP_BASE_SEED)
		for _ = 1, Tol.FUZZ_N_VALID do
			local core = Gen.validSword(rng:fork(1), CTX)
			local seen: { [string]: boolean } = {}
			for _, p in core.parts do
				shapes[p.shape] = (shapes[p.shape] or 0) + 1
				materials[p.material] = (materials[p.material] or 0) + 1
				seen[p.material] = true
				if p.rot[4] ~= 1 then
					rotated += 1
				end
			end
			if seen.Iron and seen.Steel then
				mixed += 1
			end
			for slot, set in counts do
				set[Shape.count(core, slot)] = true
			end
		end
		for _, s in Gen.SHAPES do
			A.truthy((shapes[s] or 0) > 0, "no " .. s .. " generated")
		end
		A.truthy((materials.Iron or 0) > 0 and (materials.Steel or 0) > 0 and mixed > 0, "both materials, and mixed")
		A.truthy(rotated > 0, "rotated parts")
		A.truthy(counts.Pommel[0] and counts.Pommel[2], "with and without pommels")
		A.truthy(counts.Guard[0] and counts.Guard[3], "no guard up to three guard parts")
		A.truthy(counts.Blade[1] and counts.Blade[4], "one to four blade parts")
	end)

	t.it("garbage never crashes the generator (regression: a non-table parts[1] at seed 4241708328)", function()
		A.truthy((pcall(Gen.garbage, TestRng.new(4241708328), CTX)), "seed 4241708328")
	end)

	t.it("garbage: Canonical.draft answers every value without throwing or mutating it (P-TOTAL, P-NOMUT)", function()
		local codes: { [string]: number } = {}
		local kinds: { [string]: number } = {}
		local accepted = 0
		Prop.check(Tol.FUZZ_N_GARBAGE, function(rng)
			return Gen.garbage(rng, CTX)
		end, function(raw: any)
			kinds[type(raw)] = (kinds[type(raw)] or 0) + 1
			local before = snapshot(raw)
			local ok, r = pcall(Canonical.draft, raw)
			A.truthy(ok, "Canonical.draft threw: " .. tostring(r))
			A.eq(Shape.bitDifference(raw, before), nil, "the input is unchanged")
			A.eq(type(r), "table", "a result table")
			if r.ok then
				accepted += 1
				A.truthy(Canonical.isCanonical(r.value), "an accepted value is canonical")
			else
				A.eq(type(r.path), "string", "a path")
				codes[r.code] = (codes[r.code] or 0) + 1
			end
		end)
		for _, code in {
			"Malformed", "UnsupportedSchema", "UnknownId", "SlotNotInType", "TooManyParts", "DuplicatePartId",
			"NonFinite", "OutOfRange", "BadRotation", "BadName",
		} do
			A.truthy(codes[code], "garbage never reached " .. code)
		end
		-- DisabledId needs a disabled id: Bronze is among the strings garbage plants
		A.truthy(codes.DisabledId, "garbage never reached DisabledId")
		A.truthy(accepted > 0, "some garbage is accepted (a harmless fault, an unknown field)")
		for _, kind in { "nil", "boolean", "number", "string", "table", "buffer" } do
			A.truthy(kinds[kind], "garbage never produced a " .. kind)
		end
	end)

	t.it("withFiller adds Dust, Enclosed and Duplicate parts within the rules", function()
		for _, kind: Gen.FillerKind in { "Dust", "Enclosed", "Duplicate" } :: { Gen.FillerKind } do
			local added = 0
			Prop.check(Tol.PROP_N, function(rng)
				local base = Gen.validSword(rng, CTX)
				local out, ids = Gen.withFiller(rng, CTX, base, kind)
				return { base = base, out = out, ids = ids }
			end, function(c: any)
				expectCanonical(c.out, kind)
				A.eq(#c.out.parts, #c.base.parts + #c.ids, "parts added")
				for _, id in c.ids do
					added += 1
					local filler: any = nil
					for _, p in c.out.parts do
						if p.id == id then
							filler = p
						end
					end
					A.truthy(filler ~= nil, "added part " .. id)
					A.truthy(Gen.margin(CTX, { filler }) >= 0, "filler inside the hitbox")
					local v = Gen.volume(filler)
					if kind == "Dust" then
						A.truthy(v < CTX.dustVolume, "Dust is below the floor")
					else
						A.truthy(v >= CTX.dustVolume, kind .. " is not Dust")
						local twin = false
						for _, p in c.base.parts do
							local same = p.shape == filler.shape and p.slot == filler.slot
								and Shape.bitDifference(p.rot, filler.rot) == nil and Shape.bitDifference(p.pos, filler.pos) == nil
							if same and kind == "Duplicate" then
								twin = twin or Shape.bitDifference(p.size, filler.size) == nil
							elseif same then
								twin = twin or (filler.size[1] <= p.size[1] - 0.02 + 1e-12
									and filler.size[2] <= p.size[2] - 0.02 + 1e-12 and filler.size[3] <= p.size[3] - 0.02 + 1e-12)
							end
						end
						A.truthy(twin, kind .. " part " .. id .. " has its host")
					end
				end
			end)
			A.truthy(added > Tol.PROP_N, kind .. ": " .. added .. " parts added over the run")
		end
		local f1, ids = Gen.withFiller(TestRng.new(3), CTX, Blueprints.core("F1"), "Enclosed")
		expectCanonical(f1, "F1 with filler")
		A.truthy(#ids > 0, "fixtures take filler too")
	end)

	t.it("segmented re-cuts Blade blocks flush: same volume and bounds, within the rules", function()
		local cutAny = 0
		Prop.check(Tol.PROP_N, function(rng)
			local base = Gen.validSword(rng, CTX)
			local out, cut = Gen.segmented(rng, CTX, base)
			return { base = base, out = out, cut = cut }
		end, function(c: any)
			expectCanonical(c.out, "segmented")
			A.rel(totalVolume(c.out), totalVolume(c.base), 1e-12, "volume")
			local alo, ahi = Gen.bounds(c.out.parts)
			local blo, bhi = Gen.bounds(c.base.parts)
			for k = 1, 3 do
				A.near(alo[k], blo[k], 1e-12, "bounds min")
				A.near(ahi[k], bhi[k], 1e-12, "bounds max")
			end
			if #c.cut > 0 then
				cutAny += 1
				A.truthy(#c.out.parts > #c.base.parts, "pieces added")
			end
			for _, p in c.out.parts do
				A.truthy(Gen.volume(p) >= 2 * CTX.dustVolume, "no piece is Dust")
			end
		end)
		A.truthy(cutAny > Tol.PROP_N / 2, "most swords had a blade to cut: " .. cutAny)
		for _, core in sweep() do
			local out = Gen.segmented(TestRng.new(5), CTX, core)
			expectCanonical(out, core.name .. " segmented")
		end
	end)

	t.it("translated moves in Y and Z only and stays inside the hitbox", function()
		Prop.check(Tol.PROP_N, function(rng)
			local base = Gen.validSword(rng, CTX)
			local out, delta = Gen.translated(rng, CTX, base)
			return { base = base, out = out, delta = delta }
		end, function(c: any)
			expectCanonical(c.out, "translated")
			A.eq(c.delta[1], 0, "no X shift")
			A.truthy(Gen.margin(CTX, c.out.parts) >= -1e-12, "inside the hitbox")
			for i, p in c.out.parts do
				local q = c.base.parts[i]
				A.eq(p.pos[1], q.pos[1], "x unchanged")
				A.eq(p.pos[2], q.pos[2] + c.delta[2], "y moved")
				A.eq(p.pos[3], q.pos[3] + c.delta[3], "z moved")
				A.eq(Shape.bitDifference(p.rot, q.rot), nil, "rotation unchanged")
			end
		end)
		local moved = Gen.translate(Blueprints.core("F1"), 0.27, 0.05) -- C14's move
		expectCanonical(moved, "F1 moved (0, +0.27, +0.05)")
		A.truthy(Gen.margin(CTX, moved.parts) >= 0, "F1 moved stays inside")
	end)
end)
