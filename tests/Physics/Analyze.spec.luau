--!strict
-- T-VAL-01, 02, 04 Physics/Analyze (SPEC §4.1, §4.2, §4.7, §4.9, E-S2.10, E-S8.4, E-S8.5): the V-rules on the A fixtures'
-- exact lists in fixed order, containment against brute force, valid designs valid, floating components, what run
-- leaves for M3, and the execution model: checkpoints, cancellation, re-entrancy, no module-level state. T-VAL-03 lives
-- in Gjk.spec, T-PHY in MassProps.spec and Shapes.spec, T-PERF-01 with M3's fixtures; the cap's TooComplex here, the cap
-- itself in Cover.spec.

local fs = require("@lune/fs")
local luau = require("@lune/luau")
local Test = require("../lib/Test")
local A = require("../lib/Assert")
local Dump = require("../lib/Dump")
local Gen = require("../lib/Gen")
local Prop = require("../lib/Prop")
local TestRng = require("../lib/TestRng")
local Tol = require("../lib/Tol")
local Drafts = require("../Blueprint/Drafts")
local Adversarial = require("../fixtures/Adversarial")
local Blueprints = require("../fixtures/Blueprints")
local Build = require("../fixtures/Build")
local H = require("./PhysicsHelpers")
local Balance = require("../../src/shared/Definitions/Balance")
local Catalog = require("../../src/shared/Definitions/Catalog")
local EquipmentTypes = require("../../src/shared/Definitions/EquipmentTypes")
local Limits = require("../../src/shared/Definitions/Limits")
local Materials = require("../../src/shared/Definitions/Materials")
local Types = require("../../src/shared/Definitions/Types")
local Versions = require("../../src/shared/Definitions/Versions")
local Canonical = require("../../src/shared/Blueprint/Canonical")
local Schema = require("../../src/shared/Blueprint/Schema")
local Analyze = require("../../src/shared/Physics/Analyze")
local Gjk = require("../../src/shared/Physics/Gjk")
local MassProps = require("../../src/shared/Physics/MassProps")
local Sampling = require("../../src/shared/Physics/Sampling")
local Shapes = require("../../src/shared/Physics/Shapes")

type Rng = TestRng.TestRng

local Geo = Balance.Geometry
local SWORD: any = EquipmentTypes.get("Sword")
local CTX = Gen.context(Limits, SWORD, Materials.enabled, Versions.BLUEPRINT_SCHEMA, Geo)
local EPS = Limits.EPS_CONTAIN

local function run(core: any, opts: any?): any
	return Analyze.run(core, opts)
end

local function quick(core: any, opts: any?): any
	return Analyze.quick(core, opts)
end

-- The canonical core of an A variant's draft.
local function canonicalOf(variant: any): any
	local result = Canonical.draft(variant.draft()) :: any
	A.truthy(result.ok, variant.key .. ": Canonical must accept it, got " .. Dump.short(result))
	return result.value
end

local function errorList(codes: { any }): string
	return Dump.short(codes)
end

return Test.suite("Physics/Analyze", function(t)
	t.it("T-VAL-01 every A variant with a validation verdict: the exact error list, in fixed order", function()
		local checked = 0
		for _, variant in ipairs(Adversarial.variants) do
			if variant.validation then
				checked += 1
				local core = canonicalOf(variant)
				local report = run(core)
				A.eq(report.validation.ok, variant.validation.valid, variant.key .. " verdict " .. errorList(report.validation.errors))
				A.deepEq(report.validation.errors, variant.validation.errors, variant.key)
			end
		end
		A.truthy(checked >= 20, "variants checked: " .. checked)
	end)

	t.it("T-VAL-01 every draft Canonical accepts: its save verdict holds, and analysis never throws", function()
		local judged = 0
		for _, variant in ipairs(Adversarial.variants) do
			if variant.canon.ok then
				local core = canonicalOf(variant)
				local report = run(core, { measureInvalid = true })
				H.finite(report, variant.key)
				if variant.save == "Valid" or variant.save == "Invalid" then
					judged += 1
					A.eq(report.validation.ok, variant.save == "Valid", variant.key .. " " .. errorList(report.validation.errors))
				end
			end
		end
		A.truthy(judged >= 25, "variants judged: " .. judged)
	end)

	t.it("T-VAL-01 the set holds every ValidationCode, with and without a reason", function()
		local seen: { [string]: boolean } = {}
		for _, variant in ipairs(Adversarial.variants) do
			if variant.validation then
				for _, e in ipairs(variant.validation.errors) do
					seen[e.code .. (if e.reason then "/" .. e.reason else "")] = true
				end
			end
		end
		for _, code in ipairs({ "SlotMissing", "SlotMissing/Cleaned", "SlotTooMany", "OutOfHitbox", "Disconnected", "BladeNotAboveGrip", "TooComplex" }) do
			A.truthy(seen[code], "no variant reaches " .. code)
		end
	end)

	t.it("T-VAL-01 A14, A16, A17, A22: the cleaned lists, valid or not", function()
		for _, variant in ipairs(Adversarial.variants) do
			if variant.analysis and variant.analysis.cleaned then
				local report = run(canonicalOf(variant))
				A.deepEq(report.cleaned, variant.analysis.cleaned, variant.key)
			end
		end
	end)

	t.it("T-VAL-01 A16 and A17: mass, COM, balance and reach bit-identical to their base; A23 and A24: valid, finite", function()
		for _, variant in ipairs(Adversarial.variants) do
			local analysis = variant.analysis
			if analysis and analysis.relation and analysis.relation.mass == "Identical" then
				local base = run(Blueprints.get(analysis.relation.to).core).physics
				local report = run(canonicalOf(variant)).physics
				for _, field in ipairs({ "mass", "volume", "balance", "balanceFromHand", "guardPos", "reach", "bladeLength" }) do
					A.eq(report[field], base[field], variant.key .. " " .. field)
				end
				A.deepEq(report.com, base.com, variant.key .. " COM")
			end
			if analysis and analysis.finite then
				local report = run(canonicalOf(variant))
				A.truthy(report.validation.ok, variant.key)
				H.finite(report.physics, variant.key)
			end
		end
	end)

	t.it("T-VAL-01 Analyze.quick agrees with run on every variant its first stage decides", function()
		for _, variant in ipairs(Adversarial.variants) do
			if variant.validation then
				local core = canonicalOf(variant)
				local full, fast = run(core).validation, quick(core)
				local stops = false
				for _, e in ipairs(full.errors) do
					stops = stops or e.code == "SlotMissing" and e.reason == nil or e.code == "SlotTooMany" or e.code == "OutOfHitbox"
				end
				if stops then
					A.deepEq(fast.errors, full.errors, variant.key)
					A.falsy(fast.ok, variant.key)
				else
					A.eq(#fast.errors, 0, variant.key .. ": the full stage's errors are not quick's")
					A.truthy(fast.ok, variant.key)
				end
			end
		end
	end)

	t.it("§4.1 the quick stage stops the pipeline: no measurement, no cleaning, whatever measureInvalid says", function()
		local core = canonicalOf(Adversarial.variant("A01"))
		for _, opts in ipairs({ {}, { measureInvalid = true } }) do
			local report = run(core, opts)
			A.falsy(report.validation.ok)
			A.deepEq(report.cleaned, {})
			A.eq(report.physics, nil)
			A.eq(report.edge, nil)
			A.eq(report.steps, nil)
			A.deepEq(report.budget, { hSurf = 0, hVol = 0, edgeCell = 0, surfSamples = 0, volSamples = 0 })
			A.deepEq(report.validation.components, {})
		end
	end)

	t.it("§4.2 an invalid design stores the validation only; measureInvalid measures it anyway", function()
		local core = canonicalOf(Adversarial.variant("A06"))
		local plain = run(core)
		A.falsy(plain.validation.ok)
		A.eq(plain.physics, nil)
		A.truthy(plain.budget.hSurf > 0, "exposure ran")
		A.eq(plain.budget.hVol, 0, "measurement did not")
		local measured = run(core, { measureInvalid = true })
		A.deepEq(measured.validation, plain.validation, "the verdict is the same")
		A.truthy(measured.physics ~= nil, "measured anyway")
		A.truthy(measured.budget.hVol > 0)
		H.finite(measured.physics, "A06 physics")
	end)

	t.it("§4.2 every full-stage error together, in rule order: V3, V4, V5", function()
		-- F2 upside down, whose pommel floats, whose only grip is enclosed: all three of the full stage's rules
		local core = Blueprints.core("F2")
		for _, p in ipairs(core.parts) do
			p.pos = { -p.pos[1], 5 - p.pos[2], p.pos[3] }
			p.rot = H.axisAngle(0, 0, 1, 180)
		end
		core.parts[1].pos[2] += 0.04 -- the pommel, now on top, off the grip
		-- a grip hidden in a guard grown around it: Grip part 2 stays connected, and enclosed
		core.parts[3].size = { 0.8, 1.2, 0.4 }
		core.parts[3].pos = { 0, 3.65, 0 }
		core.parts[2].size = { 0.2, 1.0, 0.2 }
		core.parts[2].pos = { 0, 3.65, 0 }
		local report = run(core)
		local expected: { any } = {
			{ code = "Disconnected", partId = 1 },
			{ code = "BladeNotAboveGrip" },
			{ code = "SlotMissing", slot = "Grip", reason = "Cleaned" },
		}
		A.deepEq(report.validation.errors, expected, errorList(report.validation.errors))
		A.deepEq(report.cleaned, { { partId = 2, reason = "Enclosed" } })
	end)

	-- Analyze on planted Balance.Geometry fields: its Sampling and that Sampling's Cover (H.plantedSampling).
	local function plantedAnalyze(overrides: { [string]: any }): any
		return Drafts.planted("src/shared/Physics/Analyze.luau", {
			["../Definitions/Types"] = Types,
			["../Definitions/EquipmentTypes"] = EquipmentTypes,
			["../Definitions/Limits"] = Limits,
			["../Definitions/Versions"] = Versions,
			["../Blueprint/Schema"] = Schema,
			["./Gjk"] = Gjk,
			["./MassProps"] = MassProps,
			["./Sampling"] = H.plantedSampling(overrides),
			["./Shapes"] = Shapes,
		})
	end

	-- Past VERDICT_WORK_MAX there is no verdict: no part to clean, no kept row for V5, nothing to measure. The design is invalid,
	-- TooComplex (no part, slot or reason), unmeasured whatever measureInvalid says; V3 and V4 report before it, as ever.
	t.it("§4.2 TooComplex: past the verdicts' cap a design is invalid and unmeasured, before V5, whatever measureInvalid says", function()
		local core = canonicalOf(Adversarial.variant("A28"))
		for _, opts in ipairs({ {}, { measureInvalid = true } }) do
			local report = run(core, opts)
			A.deepEq(report.validation, { ok = false, errors = { { code = "TooComplex" } }, components = {} })
			A.deepEq(report.cleaned, {}, "no verdict, nothing cleaned")
			A.eq(report.physics, nil)
			A.eq(report.edge, nil)
			A.eq(report.steps, nil)
			A.deepEq(report.budget, { hSurf = 0, hVol = 0, edgeCell = 0, surfSamples = 0, volSamples = 0 })
			A.eq(report.balanceVersion, Versions.BALANCE_VERSION)
		end
		-- a cap planted under F2's verdicts: F2 is TooComplex; the design whose grip V5 finds cleaned reports V3 and V4, then
		-- TooComplex where V5 stood
		local capped = plantedAnalyze({ VERDICT_WORK_MAX = 100 })
		A.deepEq(capped.run(Blueprints.get("F2").core, { measureInvalid = true }).validation.errors, { { code = "TooComplex" } }, "F2")
		local core3 = Blueprints.core("F2")
		for _, p in ipairs(core3.parts) do
			p.pos = { -p.pos[1], 5 - p.pos[2], p.pos[3] }
			p.rot = H.axisAngle(0, 0, 1, 180)
		end
		core3.parts[1].pos[2] += 0.04
		core3.parts[3].size = { 0.8, 1.2, 0.4 }
		core3.parts[3].pos = { 0, 3.65, 0 }
		core3.parts[2].size = { 0.2, 1.0, 0.2 }
		core3.parts[2].pos = { 0, 3.65, 0 }
		A.deepEq(run(core3).validation.errors[3], { code = "SlotMissing", slot = "Grip", reason = "Cleaned" }, "under the real cap")
		local report = capped.run(core3)
		local expected: { any } = { { code = "Disconnected", partId = 1 }, { code = "BladeNotAboveGrip" }, { code = "TooComplex" } }
		A.deepEq(report.validation.errors, expected)
		A.deepEq(report.cleaned, {})
		-- the planted cap reaches the verdict and nothing else: lifted, F2 is the real F2
		A.eq(Dump.canonical(plantedAnalyze({}).run(Blueprints.get("F2").core)), Dump.canonical(run(Blueprints.get("F2").core)))
	end)

	t.it("T-VAL-02 containment against exact brute force, 1,000 parts around the walls", function()
		local rng = TestRng.new(Tol.PROP_BASE_SEED)
		local SHAPES = { "Block", "Wedge", "CornerWedge", "Cylinder", "Ball" }
		local lo, hi = SWORD.geometry.hitboxMin, SWORD.geometry.hitboxMax
		local base = Blueprints.core("F2")
		local outside, inside = 0, 0
		for n = 1, 1000 do
			local shape = SHAPES[(n - 1) % 5 + 1]
			local side = rng:range(0.05, 0.25)
			local size = { rng:range(0.05, 0.25), rng:range(0.05, 0.25), rng:range(0.05, 0.25) }
			if shape == "Ball" then
				size = { side, side, side }
			elseif shape == "Cylinder" then
				size = { size[1], side, side }
			end
			local rot = H.randomQuat(rng)
			-- brute-force extents around the origin: vertices, or both caps' rims in 1,024 directions (error r·5e-6)
			local probe = H.solid(5, shape, { 0, 0, 0 }, rot, size, "Guard")
			local emin, emax = { math.huge, math.huge, math.huge }, { -math.huge, -math.huge, -math.huge }
			local function see(x: number, y: number, z: number)
				for k, v in ipairs({ x, y, z }) do
					emin[k], emax[k] = math.min(emin[k], v), math.max(emax[k], v)
				end
			end
			local verts = Gen.vertices(probe)
			if verts then
				for _, v in ipairs(verts) do
					see(v[1], v[2], v[3])
				end
			elseif shape == "Ball" then
				see(-side / 2, -side / 2, -side / 2)
				see(side / 2, side / 2, side / 2)
			else
				local m = Gen.matrix(rot)
				for _, s in ipairs({ -1, 1 }) do
					for d = 0, 1023 do
						local a = 2 * Shapes.PI * d / 1024
						local y, z = side / 2 * math.cos(a), side / 2 * math.sin(a)
						local x = s * size[1] / 2
						see(m[1] * x + m[2] * y + m[3] * z, m[4] * x + m[5] * y + m[6] * z, m[7] * x + m[8] * y + m[9] * z)
					end
				end
			end
			-- put the part against one wall, its brute-force extent `past` beyond it, centred on the other axes
			local axis = rng:int(1, 3)
			local upper = rng:float() < 0.5
			local past = rng:pick({ -2 * EPS, -0.5 * EPS, 0.5 * EPS, 2 * EPS })
			local pos = {
				(lo[1] + hi[1]) / 2 - (emin[1] + emax[1]) / 2,
				(lo[2] + hi[2]) / 2 - (emin[2] + emax[2]) / 2,
				(lo[3] + hi[3]) / 2 - (emin[3] + emax[3]) / 2,
			}
			pos[axis] = if upper then hi[axis] + past - emax[axis] else lo[axis] - past - emin[axis]
			local part = H.solid(5, shape, pos, rot, size, "Guard")
			local core = Drafts.deepCopy(base)
			table.insert(core.parts, part)
			local verdict = quick(core)
			if past > EPS then
				outside += 1
				A.deepEq(verdict.errors, { { code = "OutOfHitbox", partId = 5 } }, shape .. " past the wall by " .. past)
			else
				inside += 1
				A.deepEq(verdict.errors, {}, shape .. " within EPS_CONTAIN: " .. past)
			end
			-- and S6's call agrees with the brute force, within its error
			local minOf, maxOf = Shapes.aabb(part)
			for k = 1, 3 do
				A.near(minOf[k], pos[k] + emin[k], 1e-5, shape .. " extent")
				A.near(maxOf[k], pos[k] + emax[k], 1e-5, shape .. " extent")
			end
		end
		A.truthy(outside > 150 and inside > 150, "both verdicts seen: " .. outside .. " / " .. inside)
	end)

	t.it("§4.2 containment is exact: flush with a wall passes, a cylinder's box corners may leave", function()
		A.truthy(quick(canonicalOf(Adversarial.variant("A03"))).ok, "A03")
		A.truthy(quick(canonicalOf(Adversarial.variant("A04"))).ok, "A04")
		A.truthy(quick(canonicalOf(Adversarial.variant("A05a"))).ok, "A05a")
		A.falsy(quick(canonicalOf(Adversarial.variant("A05b"))).ok, "A05b")
		-- a wall on each side, one at a time
		local core = Blueprints.core("F2")
		core.parts[4].pos = { 0, 2.75, 0.30 - 0.04 + 2 * EPS }
		A.deepEq(quick(core).errors, { { code = "OutOfHitbox", partId = 4 } })
		core.parts[4].pos = { 0, 2.75, -0.30 + 0.04 - 2 * EPS }
		A.deepEq(quick(core).errors, { { code = "OutOfHitbox", partId = 4 } })
		core.parts[4].pos = { 0.8 - 0.1 + 2 * EPS, 2.75, 0 }
		A.deepEq(quick(core).errors, { { code = "OutOfHitbox", partId = 4 } })
		core.parts[4].pos = { -0.8 + 0.1 - 2 * EPS, 2.75, 0 }
		A.deepEq(quick(core).errors, { { code = "OutOfHitbox", partId = 4 } })
		core.parts[4].pos = { 0, 2.75, 0 }
		core.parts[1].pos = { 0, 0.15 - 2 * EPS, 0 }
		A.deepEq(quick(core).errors, { { code = "OutOfHitbox", partId = 1 } })
		core.parts[1].pos = { 0, 0.15, 0 }
		A.deepEq(quick(core).errors, {}, "flush with y = 0")
	end)

	t.it("§4.2 containment is inclusive at exactly EPS_CONTAIN past a wall; one ulp more is out", function()
		local core = Blueprints.core("F2")
		core.parts[3].size[1] = 2 * (0.8 + EPS) -- centred: both ends on ±(0.8 + EPS), bit for bit
		A.deepEq(quick(core).errors, {}, "on the limit, both X walls")
		core.parts[3].size[1] = 2 * (0.8 + EPS) * (1 + 2 ^ -52)
		A.deepEq(quick(core).errors, { { code = "OutOfHitbox", partId = 3 } }, "one ulp past it")
		local thick = Blueprints.core("F2")
		thick.parts[3].size[3] = 2 * (0.3 + EPS)
		A.deepEq(quick(thick).errors, {}, "on the limit, both Z walls")
		thick.parts[3].size[3] = 2 * (0.3 + EPS) * (1 + 2 ^ -52)
		A.deepEq(quick(thick).errors, { { code = "OutOfHitbox", partId = 3 } }, "one ulp past it")
	end)

	t.it("§4.2 V1: per slot min and max, in the slots' order; an empty design", function()
		local empty = H.core("empty", {})
		A.deepEq(quick(empty).errors, { { code = "SlotMissing", slot = "Blade" }, { code = "SlotMissing", slot = "Grip" } })
		A.deepEq(run(empty).validation.errors, quick(empty).errors, "run stops at the same list")
		local core = Blueprints.core("F2")
		for k = 1, 5 do
			table.insert(core.parts, H.part(10 + k, "Pommel", "Block", "Iron", { 0, 0.2, 0 }, H.I, { 0.1, 0.1, 0.1 }))
		end
		for k = 1, 9 do
			table.insert(core.parts, H.part(20 + k, "Guard", "Block", "Iron", { 0, 1.45, 0 }, H.I, { 0.1, 0.1, 0.1 }))
		end
		A.deepEq(quick(core).errors, { { code = "SlotTooMany", slot = "Guard" }, { code = "SlotTooMany", slot = "Pommel" } })
	end)

	t.it("§4.2 quick's connectivity option: V3 joins the list; the components come back; V1 and V2 do not hide it", function()
		local floating = canonicalOf(Adversarial.variant("A06"))
		A.truthy(quick(floating).ok, "plain quick does not look")
		A.deepEq(quick(floating).components, {})
		local live = quick(floating, { connectivity = true })
		A.falsy(live.ok)
		A.deepEq(live.errors, { { code = "Disconnected", partId = 5 } })
		A.eq(#live.components, 1)
		A.truthy(quick(Blueprints.get("F1").core, { connectivity = true }).ok, "F1 is connected")
		-- a part dragged out of the hitbox: what floats still shows, behind the earlier rules
		local both = Blueprints.core("F2")
		table.insert(both.parts, H.part(5, "Guard", "Block", "Iron", { 0.76, 1.45, 0 }, H.I, { 0.1, 0.1, 0.1 }))
		A.deepEq(quick(both, { connectivity = true }).errors, {
			{ code = "OutOfHitbox", partId = 5 },
			{ code = "Disconnected", partId = 5 },
		})
		local none = H.core("empty", {})
		A.deepEq(quick(none, { connectivity = true }).components, {}, "no parts, no components")
	end)

	t.it("§4.2 floating components: closest pair, gap, direction toward the main component (E-S2.10)", function()
		-- F2's pommel 0.03 below the grip (dropping it below y = 0 would leave the hitbox: lift the rest instead)
		local core = Blueprints.core("F2")
		for k = 2, 4 do
			core.parts[k].pos[2] += 0.03
		end
		local v = run(core).validation
		A.deepEq(v.errors, { { code = "Disconnected", partId = 1 } })
		A.eq(#v.components, 1)
		local c = v.components[1]
		A.deepEq(c.partIds, { 1 })
		A.near(c.gap, 0.03, 1e-9, "gap")
		A.near(c.dir[1], 0, 1e-9)
		A.near(c.dir[2], 1, 1e-9, "dir: up toward the grip")
		A.near(c.dir[3], 0, 1e-9)
		A.eq(c.nearestPartId, 2, "the grip")
		-- a gap along no axis: dir is the unit vector of the closest pair (block corner to ball centre: 0.2, 0.2, 0.1)
		local diagonal = H.core("diagonal", {
			H.part(1, "Grip", "Block", "Iron", { 0, 1, 0 }, H.I, { 0.2, 1, 0.2 }),
			H.part(2, "Blade", "Ball", "Iron", { 0.3, 1.7, 0.2 }, H.I, { 0.1, 0.1, 0.1 }),
		})
		local apart = quick(diagonal, { connectivity = true }).components[1]
		A.near(apart.gap, 0.25, 1e-9, "the corner to the ball's surface")
		A.near(apart.dir[1], -2 / 3, 1e-6, "dir x")
		A.near(apart.dir[2], -2 / 3, 1e-6, "dir y")
		A.near(apart.dir[3], -1 / 3, 1e-6, "dir z")
		-- moving it along dir by gap − CONTACT_TOL/2 connects it (S6's Snap to touch)
		local snapped = Drafts.deepCopy(core)
		snapped.parts[1].pos[2] += c.dir[2] * (c.gap - Limits.CONTACT_TOL / 2)
		A.truthy(run(snapped).validation.ok, "Snap to touch")
	end)

	t.it("§4.2 the main component: the most Grip volume, else the largest volume, else the lowest index", function()
		-- three islands: a pommel, a big blade, a small grip: the grip's island is main however small
		local core = H.core("islands", {
			H.part(1, "Pommel", "Block", "Iron", { 0, 0.1, 0 }, H.I, { 0.2, 0.2, 0.2 }),
			H.part(2, "Blade", "Block", "Iron", { 0, 1.5, 0 }, H.I, { 0.4, 2.0, 0.2 }),
			H.part(3, "Grip", "Block", "Iron", { 0, 3.5, 0 }, H.I, { 0.1, 0.2, 0.1 }),
		})
		local v = quick(core, { connectivity = true })
		A.deepEq(v.errors, { { code = "Disconnected", partId = 1 }, { code = "Disconnected", partId = 2 } })
		A.eq(#v.components, 2, "each floating island reports")
		A.deepEq(v.components[1].partIds, { 1 }, "in lowest-index order")
		A.deepEq(v.components[2].partIds, { 2 })
		A.eq(v.components[1].nearestPartId, 3)
		A.near(v.components[2].gap, 3.4 - 2.5, 1e-9, "the blade's top to the grip's bottom")
		-- no Grip on either island of a connected pair: the larger one is main
		local noGrip = H.core("noGrip", {
			H.part(1, "Pommel", "Block", "Iron", { 0, 0.2, 0 }, H.I, { 0.1, 0.1, 0.1 }),
			H.part(2, "Blade", "Block", "Iron", { 0, 2, 0 }, H.I, { 0.4, 1, 0.2 }),
		})
		local noGripErrors: { any } = {
			{ code = "SlotMissing", slot = "Grip" },
			{ code = "Disconnected", partId = 1 },
		}
		A.deepEq(quick(noGrip, { connectivity = true }).errors, noGripErrors)
		-- equal volumes: the lowest index
		local tie = H.core("tie", {
			H.part(1, "Blade", "Block", "Iron", { 0, 1, 0 }, H.I, { 0.2, 0.2, 0.2 }),
			H.part(2, "Blade", "Block", "Iron", { 0, 3, 0 }, H.I, { 0.2, 0.2, 0.2 }),
		})
		local tieErrors: { any } = {
			{ code = "SlotMissing", slot = "Grip" },
			{ code = "Disconnected", partId = 2 },
		}
		A.deepEq(quick(tie, { connectivity = true }).errors, tieErrors)
		-- a Grip part in each island: the most Grip volume wins, with several parts in a component
		local two = H.core("two", {
			H.part(1, "Grip", "Block", "Iron", { 0, 0.5, 0 }, H.I, { 0.1, 0.4, 0.1 }),
			H.part(2, "Blade", "Block", "Iron", { 0, 1, 0 }, H.I, { 0.2, 0.6, 0.1 }),
			H.part(3, "Grip", "Block", "Iron", { 0, 3, 0 }, H.I, { 0.2, 0.4, 0.2 }),
		})
		local w = quick(two, { connectivity = true })
		A.deepEq(w.errors, { { code = "Disconnected", partId = 1 }, { code = "Disconnected", partId = 2 } })
		A.eq(#w.components, 1)
		A.deepEq(w.components[1].partIds, { 1, 2 })
		-- the most Grip volume, not the most Grip parts: two small grips on one island, one large grip on the other
		local grips = H.core("grips", {
			H.part(1, "Grip", "Block", "Iron", { 0, 0.5, 0 }, H.I, { 0.1, 0.1, 0.1 }),
			H.part(2, "Grip", "Block", "Iron", { 0, 0.6, 0 }, H.I, { 0.1, 0.1, 0.1 }),
			H.part(3, "Grip", "Block", "Iron", { 0, 3, 0 }, H.I, { 0.3, 0.5, 0.3 }),
			H.part(4, "Blade", "Block", "Iron", { 0, 4, 0 }, H.I, { 0.1, 1.5, 0.1 }),
		})
		A.deepEq(quick(grips, { connectivity = true }).errors, { { code = "Disconnected", partId = 1 }, { code = "Disconnected", partId = 2 } })
	end)

	-- The fixtures number their parts 1…n, so an index in place of an id passes everywhere else.
	t.it("§4.2 errors, components and cleaned lists name part ids, not array indices", function()
		local out = H.core("ids", {
			H.part(7, "Blade", "Block", "Iron", { 0.9, 2, 0 }, H.I, { 0.1, 0.5, 0.1 }),
			H.part(9, "Grip", "Block", "Iron", { 0, 1, 0 }, H.I, { 0.1, 0.5, 0.1 }),
		})
		A.deepEq(quick(out).errors, { { code = "OutOfHitbox", partId = 7 } })
		local floating = H.core("ids", {
			H.part(10, "Grip", "Block", "Iron", { 0, 1, 0 }, H.I, { 0.1, 1, 0.1 }),
			H.part(20, "Blade", "Block", "Iron", { 0, 2, 0 }, H.I, { 0.1, 1, 0.1 }),
			H.part(30, "Guard", "Block", "Iron", { 0.5, 4, 0 }, H.I, { 0.1, 0.1, 0.1 }),
			H.part(40, "Pommel", "Block", "Iron", { 0.5, 4.1, 0 }, H.I, { 0.1, 0.1, 0.1 }),
		})
		local v = quick(floating, { connectivity = true })
		A.deepEq(v.errors, { { code = "Disconnected", partId = 30 }, { code = "Disconnected", partId = 40 } })
		A.deepEq(v.components[1].partIds, { 30, 40 })
		A.eq(v.components[1].nearestPartId, 20)
		-- connectivity only when asked for by name
		A.deepEq(quick(floating, { connectivity = false }).errors, {}, "connectivity = false does not look")
		A.deepEq(quick(floating, {}).errors, {}, "neither does an empty options table")
		local cleaned = H.core("ids", {
			H.part(11, "Grip", "Block", "Iron", { 0, 1, 0 }, H.I, { 0.1, 1, 0.1 }),
			H.part(21, "Blade", "Block", "Iron", { 0, 2.5, 0 }, H.I, { 0.4, 2, 0.2 }),
			H.part(31, "Blade", "Block", "Iron", { 0, 2.5, 0 }, H.I, { 0.2, 0.5, 0.1 }), -- enclosed in part 21
			H.part(41, "Pommel", "Block", "Iron", { 0.075, 1, 0 }, H.I, { 0.05, 0.05, 0.05 }), -- dust on the grip
		})
		A.deepEq(run(cleaned).cleaned, { { partId = 31, reason = "Enclosed" }, { partId = 41, reason = "Dust" } })
	end)

	t.it("§4.2 V3 at the tolerance, through Analyze: 1.2 × CONTACT_TOL is Disconnected, 0.8 × connects", function()
		-- turned 45°, so their AABBs overlap by far more than the broad phase's margin: only GJK can tell these apart
		local q = H.axisAngle(0, 0, 1, 45)
		local function pair(gap: number): any
			local d = (0.4 + gap) * math.sqrt(0.5) -- along their common local X: 0.4 between the centres, plus the gap
			return H.core("diagonal", {
				H.part(1, "Grip", "Block", "Iron", { 0, 1, 0 }, q, { 0.2, 0.8, 0.1 }),
				H.part(2, "Blade", "Block", "Iron", { d, 1 + d, 0 }, q, { 0.6, 0.8, 0.1 }),
			})
		end
		local TOL = Limits.CONTACT_TOL
		A.deepEq(quick(pair(1.2 * TOL), { connectivity = true }).errors, { { code = "Disconnected", partId = 2 } }, "1.2 ×")
		A.deepEq(quick(pair(0.8 * TOL), { connectivity = true }).errors, {}, "0.8 ×")
	end)

	t.it("§4.2 contact's broad phase keeps its margin in all six directions and both index orders", function()
		for axis = 1, 3 do
			for _, sign in { 1, -1 } do
				for _, cubeFirst in { true, false } do
					local pos = { 0, 2, 0 }
					pos[axis] += sign * (0.1 + 0.05 + 0.005) -- half of each, and a gap of half CONTACT_TOL
					local block = H.part(if cubeFirst then 2 else 1, "Guard", "Block", "Iron", { 0, 2, 0 }, H.I, { 0.2, 0.2, 0.2 })
					local cube = H.part(if cubeFirst then 1 else 2, "Guard", "Block", "Iron", pos, H.I, { 0.1, 0.1, 0.1 })
					local core = H.core("six", if cubeFirst then { cube, block } else { block, cube })
					A.deepEq(quick(core, { connectivity = true }).components, {}, string.format("axis %d, sign %d", axis, sign))
				end
			end
		end
	end)

	t.it("§4.2 Snap to touch on a thin pair: the gap and dir are the closest pair's (Gjk's cycle read 0.3307 here)", function()
		local grip = H.part(1, "Grip", "Cylinder", "Iron", { 0.16789538225807898, 2.0522677955758892, -0.083330587949603796 },
			{ 0, 0, 0.17001612042532047, 0.98544128125196939 }, { 0.5, 0.1, 0.1 })
		local blade = H.part(2, "Blade", "CornerWedge", "Iron", { -0.0082194630211466415, 1.8871406099707502, -0.21584628688869995 },
			{ 0, 0, -0.43203281863819104, 0.90185788438064896 }, { 2.5, 0.02, 0.15 })
		local v = quick(H.core("thin", { grip, blade }), { connectivity = true })
		A.deepEq(v.errors, { { code = "Disconnected", partId = 2 } })
		local c = v.components[1]
		A.near(c.gap, 0.013823519646990247, 1e-9, "the gap")
		A.eq(c.nearestPartId, 1)
		local step = c.gap - Limits.CONTACT_TOL / 2
		local snapped = table.clone(blade)
		snapped.pos = { blade.pos[1] + c.dir[1] * step, blade.pos[2] + c.dir[2] * step, blade.pos[3] + c.dir[3] * step }
		A.deepEq(quick(H.core("snapped", { grip, snapped }), { connectivity = true }).errors, {}, "moved along dir, it connects")
	end)

	t.it("§4.2 V4: the blade's volume-weighted centroid beyond the grip point along the physics axis", function()
		local upside = canonicalOf(Adversarial.variant("A08b"))
		A.deepEq(run(upside).validation.errors, { { code = "BladeNotAboveGrip" } })
		-- a blade level with the grip point is not beyond it
		local level = H.core("level", {
			H.part(1, "Grip", "Block", "Iron", { 0, 1, 0 }, H.I, { 0.1, 1, 0.1 }),
			H.part(2, "Blade", "Block", "Iron", { 0.3, 1, 0 }, H.I, { 0.5, 0.2, 0.1 }),
		})
		A.deepEq(run(level).validation.errors, { { code = "BladeNotAboveGrip" } })
		level.parts[2].pos[2] = 1.001
		A.deepEq(run(level).validation.errors, {}, "a hair above")
		-- along the tilted physics axis, not along +Y: axis (−sin 40°, cos 40°)
		local tilted = H.core("tilted", {
			H.part(1, "Grip", "Block", "Iron", { 0, 1, 0 }, H.axisAngle(0, 0, 1, 40), { 0.1, 1, 0.1 }),
			H.part(2, "Blade", "Block", "Iron", { -0.1, 1.05, 0 }, H.I, { 0.2, 0.1, 0.1 }),
		})
		A.deepEq(run(tilted).validation.errors, {}, "up the axis: beyond the grip point")
		tilted.parts[2].pos = { 0.1, 1.05, 0 }
		A.deepEq(run(tilted).validation.errors, { { code = "BladeNotAboveGrip" } }, "higher in Y, but behind along the axis")
		-- off the plane x = 0: the grip point's x counts along a tilted axis as well as its y
		local offset = H.core("offset", {
			H.part(1, "Grip", "Block", "Iron", { 0.3, 1, 0 }, H.axisAngle(0, 0, 1, 40), { 0.1, 1, 0.1 }),
			H.part(2, "Blade", "Block", "Iron", { 0.2, 1.05, 0 }, H.I, { 0.2, 0.1, 0.1 }),
		})
		A.deepEq(run(offset).validation.errors, {}, "up the axis, off x = 0")
		offset.parts[2].pos = { 0.4, 1.05, 0 }
		A.deepEq(run(offset).validation.errors, { { code = "BladeNotAboveGrip" } }, "behind along the axis, off x = 0")
		-- the centroid, not the centre: a Wedge's lies hy/3 below its centre
		local wedge = H.core("wedge", {
			H.part(1, "Grip", "Block", "Iron", { 0, 1, 0 }, H.I, { 0.1, 1, 0.1 }),
			H.part(2, "Blade", "Wedge", "Iron", { 0.15, 1.05, 0 }, H.I, { 0.2, 0.6, 0.1 }),
		})
		A.deepEq(run(wedge).validation.errors, { { code = "BladeNotAboveGrip" } }, "the centre above, the centroid below")
		wedge.parts[2].pos[2] = 1.15
		A.deepEq(run(wedge).validation.errors, {}, "both above")
		-- the first part counts too: every fixture numbers its pommel first
		local first = H.core("first", {
			H.part(1, "Blade", "Block", "Iron", { 0, 0.4, 0 }, H.I, { 0.2, 0.2, 0.1 }),
			H.part(2, "Grip", "Block", "Iron", { 0, 1, 0 }, H.I, { 0.1, 1, 0.1 }),
		})
		A.deepEq(run(first).validation.errors, { { code = "BladeNotAboveGrip" } }, "a Blade part with the lowest id")
		-- weighted by volume: a large Blade part below the grip point outweighs a small one far above it, whose unweighted
		-- centroids would pass
		local weighted = H.core("weighted", {
			H.part(1, "Grip", "Block", "Iron", { 0, 1.5, 0 }, H.I, { 0.1, 1, 0.1 }),
			H.part(2, "Blade", "Block", "Iron", { 0.25, 1.35, 0 }, H.I, { 0.4, 0.5, 0.1 }),
			H.part(3, "Blade", "Block", "Iron", { 0.25, 2.5, 0 }, H.I, { 0.04, 0.5, 0.1 }),
			H.part(4, "Guard", "Block", "Iron", { 0.25, 1.95, 0 }, H.I, { 0.04, 0.8, 0.1 }),
		})
		A.deepEq(run(weighted).validation.errors, { { code = "BladeNotAboveGrip" } }, "the volume-weighted centroid is below")
	end)

	t.it("T-VAL-04 F1–F5 are valid and keep every part", function()
		for _, id in ipairs(Blueprints.order) do
			local report = run(Blueprints.get(id).core)
			A.truthy(report.validation.ok, id .. " " .. errorList(report.validation.errors))
			A.deepEq(report.cleaned, {}, id)
			A.deepEq(report.validation.components, {}, id)
			A.eq(report.budget.hSurf, Geo.H_SURF, id)
			A.eq(report.budget.hVol, Geo.H_VOL, id)
		end
	end)

	local function validSwords(count: number)
		Prop.check(count, function(rng: Rng): any
			return Gen.validSword(rng, CTX)
		end, function(core: any)
			local report = run(core)
			A.truthy(report.validation.ok, errorList(report.validation.errors))
			A.deepEq(report.cleaned, {}, "nothing cleaned")
			H.finite(report.physics, "physics")
		end)
	end
	t.it("T-VAL-04 generated swords are valid, 60 designs", function()
		validSwords(60)
	end)
	t.slow("T-VAL-04 generated swords are valid, FUZZ_N_VALID designs", function()
		validSwords(Tol.FUZZ_N_VALID)
	end)

	-- Whatever the design: run never throws, the verdict and the measurements hold together, every number is finite.
	local function anyDesigns(count: number)
		Prop.check(count, H.anyDesign, function(core: any)
			local report = run(core, { measureInvalid = true })
			A.eq(report.validation.ok, #report.validation.errors == 0, "valid ⇔ no error")
			A.deepEq(quick(core).errors, {}, "the generator stays within the quick stage")
			local p = report.physics
			H.finite(report, "analysis")
			A.eq(#p.kept, #core.parts)
			A.eq(#p.ownedVolume, #core.parts)
			A.truthy(p.mass > 0 and p.volume > 0, "mass and volume")
			local cleaned = 0
			for i, part in ipairs(core.parts) do
				A.truthy(p.ownedVolume[i] >= 0, "part " .. part.id .. " owns no negative volume")
				cleaned += if p.kept[i] then 0 else 1
			end
			A.eq(cleaned, #report.cleaned, "kept and cleaned agree")
			A.truthy(p.reach >= 0, "reach")
			A.within(p.gripAxis[1] * p.gripAxis[1] + p.gripAxis[2] * p.gripAxis[2], 1 - 1e-12, 1 + 1e-12, "unit axis")
			A.truthy(p.gripAxis[2] >= Geo.AXIS_MAX_TILT_COS - 1e-12, "the axis tilts at most 45°")
		end)
	end
	t.it("§4.9 any design inside the hitbox: no throw, finite, consistent, 30 designs", function()
		anyDesigns(30)
	end)
	t.slow("§4.9 any design inside the hitbox: no throw, finite, consistent, PROP_N designs", function()
		anyDesigns(Tol.PROP_N)
	end)

	t.it("§4.7 the report: balance version, physics fields, nil edge and steps until M3, per-part arrays in part order", function()
		local report = run(Blueprints.get("F1").core)
		A.eq(report.balanceVersion, Versions.BALANCE_VERSION)
		A.eq(report.edge, nil, "M3")
		A.eq(report.steps, nil, "M3")
		local p = report.physics
		for _, field in ipairs({ "mass", "volume", "guardPos", "balance", "balanceFromHand", "reach", "bladeLength", "totalLength",
			"comOffAxis", "edgeLength", "cutIndex" }) do
			A.finite(p[field], field)
		end
		A.eq(p.edgeLength, 0, "M3")
		A.eq(p.cutIndex, 0, "M3")
		A.eq(#p.com, 3)
		A.eq(#p.gripPoint, 3)
		A.eq(#p.gripAxis, 2)
		A.eq(#p.kept, 5)
		A.eq(#p.ownedVolume, 5)
		A.eq(report.budget.edgeCell, 0, "M3")
		A.truthy(report.budget.surfSamples > 0)
		A.truthy(report.budget.volSamples > 0)
		A.eq(Analyze.CHECK_UNITS, 500, "§16.18")
	end)

	t.it("§4.7 every return path carries the balance version", function()
		local quickStop = canonicalOf(Adversarial.variant("A01"))
		A.falsy(run(quickStop).validation.ok)
		A.eq(run(quickStop).balanceVersion, Versions.BALANCE_VERSION, "the quick stage's stop")
		local fullStop = H.core("v5", {
			H.part(1, "Guard", "Block", "Iron", { 0, 2, 0 }, H.I, { 1, 1, 0.5 }),
			H.part(2, "Blade", "Block", "Iron", { 0, 2.2, 0 }, H.I, { 0.2, 0.2, 0.2 }),
			H.part(3, "Grip", "Block", "Iron", { 0, 1.8, 0 }, H.I, { 0.2, 0.2, 0.2 }),
		})
		A.falsy(run(fullStop).validation.ok)
		A.truthy(run(fullStop).budget.hSurf > 0 and run(fullStop).budget.hVol == 0, "stopped after exposure, before the probes")
		A.eq(run(fullStop).balanceVersion, Versions.BALANCE_VERSION, "the full stage's stop")
	end)

	t.it("§4.9 budgets: 24 large overlapping blocks stay within every budget", function()
		local report = run(H.p1())
		A.truthy(report.validation.ok, errorList(report.validation.errors))
		A.truthy(report.budget.hSurf > Geo.H_SURF, "the surface grid coarsened")
		A.truthy(report.budget.volSamples <= Geo.N_VOL_TOTAL, "volume samples: " .. report.budget.volSamples)
		H.finite(report.physics, "P1 physics")
		A.truthy(#report.cleaned > 0, "the buried blocks are Enclosed")
		local cleanedIds: { [number]: boolean } = {}
		for _, c in ipairs(report.cleaned) do
			A.eq(c.reason, "Enclosed")
			cleanedIds[c.partId] = true
		end
		for i, id in ipairs(report.physics.kept) do
			A.eq(id, not cleanedIds[i], "kept and cleaned agree, part " .. i)
		end
	end)

	t.it("§4.9 checkpoints: between phases and through long loops", function()
		local function countOf(core: any): number
			local n = 0
			run(core, { checkpoint = function()
				n += 1
			end })
			return n
		end
		A.eq(countOf(canonicalOf(Adversarial.variant("A01"))), 0, "the quick stage's stop comes before the first")
		local small = countOf(Blueprints.get("F2").core)
		A.truthy(small >= 4, "≥ one per phase: " .. small)
		local big = countOf(H.p1())
		A.truthy(big > 100, "work units, not only phases: " .. big)
		-- the phases alone leave the design's analysis unchanged
		local a, b = run(H.p1()), run(H.p1(), { checkpoint = function() end })
		A.eq(Dump.canonical(a), Dump.canonical(b), "a checkpoint changes no result")
	end)

	t.it("§4.9 a checkpoint between phases, whatever the work units say", function()
		-- Analyze with a cadence no design reaches: every checkpoint left comes from a phase boundary
		local source, replaced = string.gsub(fs.readFile("src/shared/Physics/Analyze.luau"), "local CHECK_UNITS = %d+", "local CHECK_UNITS = 1e12")
		A.eq(replaced, 1, "the constant's line")
		local modules: { [string]: any } = {
			["../Definitions/Types"] = Types,
			["../Definitions/EquipmentTypes"] = EquipmentTypes,
			["../Definitions/Limits"] = Limits,
			["../Definitions/Versions"] = Versions,
			["../Blueprint/Schema"] = Schema,
			["./Gjk"] = Gjk,
			["./MassProps"] = MassProps,
			["./Sampling"] = Sampling,
			["./Shapes"] = Shapes,
		}
		local environment: { [string]: any } = {
			require = function(spec: string): any
				return modules[spec]
			end,
		}
		local phasesOnly: any = luau.load(source, { debugName = "Analyze (phases only)", environment = environment })()
		local count = 0
		phasesOnly.run(Blueprints.get("F2").core, { checkpoint = function()
			count += 1
		end })
		A.eq(count, 5, "after quick, V3 and V4, exposure, mass properties, volume probes")
	end)

	-- The cases above count checkpoints in total: dropping one phase's spend passes them, and so does a counter that stops
	-- resetting. Here each long loop must be on the stack at some checkpoint.
	t.it("§4.9 each long loop reaches a checkpoint, at the cadence", function()
		local function callers(core: any): ({ [string]: boolean }, number)
			local seen: { [string]: boolean } = {}
			local count = 0
			run(core, { measureInvalid = true, checkpoint = function()
				count += 1
				for level = 2, 6 do
					local name = debug.info(level, "n")
					if name and name ~= "" then
						seen[name] = true
					end
				end
			end })
			return seen, count
		end
		local seen = callers(H.p1())
		for _, name in ipairs({ "connectivity", "exposure", "shown", "subtract", "surfaceSamples", "exposedWeight", "ownership", "sampledOverlap", "volumeProbes", "volumeSamples" }) do
			A.truthy(seen[name], "no checkpoint from " .. name)
		end
		-- exact overlaps: 3 tilted blocks through a fourth
		local parts = { H.part(1, "Grip", "Block", "Iron", { 0, 2, 0 }, H.axisAngle(0, 0, 1, 10), { 0.6, 2, 0.3 }) }
		for k = 2, 4 do
			table.insert(parts, H.part(k, "Blade", "Block", "Iron", { 0, 1.4 + (k - 2) * 0.6, 0 }, H.axisAngle(1, 0, 0, 5 * k), { 0.8, 0.5, 0.3 }))
		end
		A.truthy(callers(H.core("exact", parts)).exactOverlap, "no checkpoint from exactOverlap")
		-- 12 connected parts, 10 floating: 120 Gjk.distance calls, all between the phases' checkpoints
		local floating = { H.part(1, "Grip", "Block", "Iron", { 0, 0.5, 0 }, H.I, { 0.2, 0.9, 0.2 }) }
		for k = 2, 12 do
			table.insert(floating, H.part(k, "Blade", "Block", "Iron", { 0, 0.5 + k * 0.1, 0 }, H.I, { 0.1, 0.1, 0.1 }))
		end
		for k = 13, 18 do
			table.insert(floating, H.part(k, "Guard", "Block", "Iron", { -0.7 + (k - 13) * 0.25, 4, 0 }, H.I, { 0.1, 0.1, 0.1 }))
		end
		for k = 19, 22 do
			table.insert(floating, H.part(k, "Pommel", "Block", "Iron", { -0.7 + (k - 19) * 0.25, 4.5, 0 }, H.I, { 0.1, 0.1, 0.1 }))
		end
		A.truthy(callers(H.core("floating", floating)).connectivity, "no checkpoint from connectivity")
		-- the counter resets: F2 reaches a few dozen checkpoints, not one per spend
		local _, small = callers(Blueprints.get("F2").core)
		A.truthy(small < 150, "checkpoints on F2: " .. small)
	end)

	t.it("§4.9 a checkpoint may raise to cancel; the module keeps nothing and the next run is whole", function()
		local core = H.p1()
		local expected = Dump.canonical(run(core))
		for _, stopAt in ipairs({ 1, 2, 3, 10, 100, 300 }) do
			local n = 0
			local text = A.throws(function()
				run(core, { checkpoint = function()
					n += 1
					if n == stopAt then
						error("CANCELLED")
					end
				end })
			end, "CANCELLED")
			A.contains(text, "CANCELLED")
			A.eq(Dump.canonical(run(core)), expected, "after a cancel at checkpoint " .. stopAt)
		end
	end)

	t.it("§4.9 a checkpoint may yield: run in a coroutine, interleaved with another run, gives the same bits", function()
		local function resumable(core: any): thread
			return coroutine.create(function(): any
				return run(core, { checkpoint = function()
					coroutine.yield()
				end })
			end)
		end
		local coreA, coreB = H.p1(), Blueprints.core("F3")
		local expectedA, expectedB = Dump.canonical(run(coreA)), Dump.canonical(run(coreB))
		local a, b = resumable(coreA), resumable(coreB)
		local doneA, doneB: any = nil, nil
		local yields = 0
		while doneA == nil or doneB == nil do
			if doneA == nil then
				local ok, value = coroutine.resume(a)
				A.truthy(ok, tostring(value))
				if coroutine.status(a) == "dead" then
					doneA = value
				end
			end
			if doneB == nil then
				local ok, value = coroutine.resume(b)
				A.truthy(ok, tostring(value))
				if coroutine.status(b) == "dead" then
					doneB = value
				end
			end
			yields += 1
		end
		A.truthy(yields > 10, "the runs did interleave")
		A.eq(Dump.canonical(doneA), expectedA)
		A.eq(Dump.canonical(doneB), expectedB)
	end)

	t.it("P-DET, P-NOMUT, P-FINITE: frozen fixtures and variants, twice, bit for bit", function()
		local cores: { any } = {}
		for _, id in ipairs(Blueprints.order) do
			table.insert(cores, Blueprints.get(id).core)
		end
		for _, key in ipairs({ "A14", "A16", "A17", "A23", "A24" }) do
			table.insert(cores, canonicalOf(Adversarial.variant(key)))
		end
		for _, core in ipairs(cores) do
			Build.freeze(core)
			local a, b = run(core), run(core)
			A.eq(Dump.canonical(a), Dump.canonical(b), core.name)
			H.finite(a, core.name)
		end
	end)

	t.it("P-ORDER: Definitions rows rebuilt in shuffled order leave the result bit-identical", function()
		local function shuffled(catalog: any, order: { number }): any
			return Catalog.build(Drafts.rows(catalog.ordered, order))
		end
		local materials = shuffled(Materials, { 7, 3, 1, 5, 2, 6, 4 })
		local massProps = Drafts.planted("src/shared/Physics/MassProps.luau", {
			["../Definitions/Balance"] = Balance,
			["../Definitions/Types"] = Types,
			["../Definitions/Materials"] = materials,
			["../Blueprint/Schema"] = Schema,
			["./Gjk"] = Gjk,
			["./Sampling"] = Sampling,
			["./Shapes"] = Shapes,
		})
		local planted = Drafts.planted("src/shared/Physics/Analyze.luau", {
			["../Definitions/Types"] = Types,
			["../Definitions/EquipmentTypes"] = EquipmentTypes,
			["../Definitions/Limits"] = Limits,
			["../Definitions/Versions"] = Versions,
			["../Blueprint/Schema"] = Schema,
			["./Gjk"] = Gjk,
			["./MassProps"] = massProps,
			["./Sampling"] = Sampling,
			["./Shapes"] = Shapes,
		})
		for _, id in ipairs(Blueprints.order) do
			local core: any = Blueprints.get(id).core
			A.eq(Dump.canonical(planted.run(core)), Dump.canonical(Analyze.run(core)), id)
		end
	end)

	t.it("a caller bug raises, naming it: an unknown type, a foreign slot, an unknown shape or material", function()
		local core = Blueprints.core("F2")
		core.type = "Axe"
		A.throws(function()
			run(core)
		end, "unknown equipment type")
		A.throws(function()
			quick(core)
		end, "unknown equipment type")
		local slot = Blueprints.core("F2")
		slot.parts[1].slot = "Hilt"
		A.throws(function()
			run(slot)
		end, "Hilt")
		local shape = Blueprints.core("F2")
		shape.parts[1].shape = "Sphere"
		A.throws(function()
			run(shape)
		end, "unknown shape")
		local material = Blueprints.core("F2")
		material.parts[1].material = "Adamant"
		A.throws(function()
			run(material)
		end, "unknown material")
	end)

	-- T-PERF-01 and S-PERF-01 run these (§14.11); S-PERF-01 goes through Pipeline.analyze, which asserts a canonical core: the
	-- slowest valid designs under VERDICT_WORK_MAX, valid, and the designs past it, TooComplex.
	t.slow("§4.9 worst_designs.luau: every design canonical; the valid ones valid under the cap, the others TooComplex", function()
		local Worst: any = (require :: any)("../../docs/spec/prototypes/S2/cover/worst_designs")
		A.truthy(#Worst.valid >= 6 and #Worst.tooComplex >= 6, "designs: " .. #Worst.valid .. ", " .. #Worst.tooComplex)
		for _, d in ipairs(Worst.valid) do
			local core: any = { schema = Versions.BLUEPRINT_SCHEMA, name = "worst", type = "Sword", parts = d.parts }
			A.truthy(Canonical.isCanonical(core), d.name .. " is canonical")
			A.truthy(Analyze.run(core).validation.ok, d.name .. " is valid")
			A.truthy(d.units <= Geo.VERDICT_WORK_MAX, d.name .. " is under the cap")
		end
		for _, d in ipairs(Worst.tooComplex) do
			local core: any = { schema = Versions.BLUEPRINT_SCHEMA, name = "worst", type = "Sword", parts = d.parts }
			A.truthy(Canonical.isCanonical(core), d.name .. " is canonical")
			local errors = Analyze.run(core).validation.errors
			A.eq(errors[#errors].code, "TooComplex", d.name)
		end
	end)
end)
