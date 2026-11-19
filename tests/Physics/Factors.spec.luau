--!strict
-- T-DIF-01, 06, 08 and T-DIF-13's oracle, Physics/Factors (SPEC §5.2, §5.3; §14.6 names them, the M3 plan defines them:
-- .build-notes/m3-plan/plan-r2.md [8.2] with the lead's L2, L11, L12, L13 and L16). The factors' inputs are built as
-- Analyze's phases hold them (DifficultyHelpers), the steps played through Difficulty.
--   T-DIF-01  every factor in range and g, m, d on the 1e-4 grid on Gen designs (on every fixture: Difficulty.spec);
--             the caps
--   T-DIF-06  real edits move them one way: F5's blade thinned, C02's lengthened, C01 → C10's parts
--   T-DIF-08  C13, and Gen swords built half and mirrored with Blueprint/Mirror, measure Asymmetry ≤ TOL_ASYM_ZERO
--   T-DIF-13  X06's Asymmetry against the 120-probe oracle (E-S2.5)
--   [8.2]     the prototype's factors in the measure's rank order (the verdict's where it cleans a part:
--             DifficultyHelpers.inRankOrder) on every fixture whose verdict the build shares:
--             PartCount, Asymmetry, MaterialMix to the bit, Volume within 1e-12, SurfaceComplexity and Joints within
--             1e-12 where the measure's grid is the prototype's, else on the build's own measure (L2), as where the
--             whole-design shift fix's contact and flush rules apply (OWN_CONTACT, OWN_OVERLAP); Smelting's g
--             and d equal. Thinness and EdgeLength are the build's own (fix round 1: θ on every local axis, the
--             canonical walk and its lattice pick, gaps merged as the verdict hides them, §5.2; the raster sampled
--             off its cell centres, §4.6), EdgeLength the edge's to the bit
--   the parts ORDER, cbrt, norm, unionChord (its gaps, its face ties: fix round 2; three plates' hidden gaps joined
--             in turn: fix round 3; each probe asked of the part across alone, so a seam beside a slanted crossing, a V
--             whose faces a third plate hides and an open slot crossed at a grazing slant stay open: fix round 4; a
--             join past one end where the other shows, and at a tie the first in the list: M3's review round 5), θ
--             (thinDirections), the canonical walk (an axis along ±Z too), Thinness' share term (L13); the budgets and
--             the checkpoints; P-DET, P-NOMUT and the set's order (L16)

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
local Calibration = require("../fixtures/Calibration")
local Cost = require("../fixtures/Cost")
local Regression = require("../fixtures/Regression")
local D = require("./DifficultyHelpers")
local H = require("./PhysicsHelpers")
local Balance = require("../../src/shared/Definitions/Balance")
local EquipmentTypes = require("../../src/shared/Definitions/EquipmentTypes")
local Limits = require("../../src/shared/Definitions/Limits")
local Materials = require("../../src/shared/Definitions/Materials")
local Types = require("../../src/shared/Definitions/Types")
local Validate = require("../../src/shared/Definitions/Validate")
local Versions = require("../../src/shared/Definitions/Versions")
local Canonical = require("../../src/shared/Blueprint/Canonical")
local Mirror = require("../../src/shared/Blueprint/Mirror")
local Analyze = require("../../src/shared/Physics/Analyze")
local Difficulty = require("../../src/shared/Physics/Difficulty")
local Edge = require("../../src/shared/Physics/Edge")
local Factors = require("../../src/shared/Physics/Factors")
local MassProps = require("../../src/shared/Physics/MassProps")
local Sampling = require("../../src/shared/Physics/Sampling")
local Shapes = require("../../src/shared/Physics/Shapes")

-- Through a cast, so luau-lsp stays out of the prototype's loose types: it is reference data, not game code.
local Fixtures: any = (require :: any)("../../docs/spec/prototypes/S2/v2/fixtures")
local Num: any = (require :: any)("../../docs/spec/prototypes/S2/v2/num")

type Rng = TestRng.TestRng
type Measured = D.Measured
type Prepared = Shapes.Prepared
type StepAnalysis = Difficulty.StepAnalysis

local Geo = Balance.Geometry
local Dif = Balance.Difficulty
local SWORD: any = EquipmentTypes.get("Sword")
local CTX = Gen.context(Limits, SWORD, Materials.enabled, Versions.BLUEPRINT_SCHEMA, Geo)
local ABS = 1e-12

-- Every step's work set on the Sword: Smelting's and Hammering's, Sharpening's.
local BOTH: { any } = { "All", { "Blade" } }

-- [8.2]: the factors the prototype computes as the build does, from the same inputs (Thinness and EdgeLength no longer:
-- the build's own chords, walk, pick and raster samples).
local TO_THE_BIT: { [string]: boolean } = { PartCount = true, Asymmetry = true, MaterialMix = true }

-- [8.2] Two rules of the build's own (the whole-design shift fix, §17.1 O11 (j)), which the prototype leaves to the
-- rounding of where the design stands. A gap of exactly CONTACT_TOL is contact (§4.2, Sampling.CONTACT_REACH): the
-- contact rows of these fixtures take the samples that lie at CONTACT_TOL, so their Joints is the build's own
-- measure's.
-- A part that only touches another face to face is not above it (§4.3): C04's Cylinder guard owns 1e-6 more than in
-- the prototype, whose box test let a flush part in (closer to the exact overlap, M3-notes), so its Volume and
-- SurfaceComplexity are the build's own ownership's.
local OWN_CONTACT: { [string]: boolean } = { C04 = true, C05 = true, C07 = true, C08 = true, C11 = true, C13 = true,
	X03 = true, X04b = true, ["X04g0.010"] = true, ["X06-0.01"] = true }
local OWN_OVERLAP: { [string]: boolean } = { C04 = true }

local function canonicalOf(key: string): any
	local result = Canonical.draft(Adversarial.variant(key).draft()) :: any
	A.truthy(result.ok, key .. ": Canonical must accept it, got " .. Dump.short(result))
	return result.value
end

local function stepsOf(core: any): { StepAnalysis }
	local steps = D.steps(D.measured(core))
	if steps == nil then
		return A.fail(core.name .. ": a work set is empty")
	end
	return steps
end

-- [8.2] The build's own measure where its grid is not the prototype's (L2), or a rule of its own applies:
-- SurfaceComplexity = Σ exposedKept / (6·cbrt(Σ owned volume)²), Joints from the contact rows and the contact graph,
-- and Volume = Σ owned volume, over WorkSet.select's parts.
local function ownMeasure(m: Measured, selector: any): (number, number, number)
	local set = D.set(m, selector)
	local exposure, owned, touching = m.ctx.exposure, m.ctx.owned, m.ctx.touching
	local area, volume, joints = 0, 0, 0
	for _, i in ipairs(set) do
		area += exposure.exposedKept[i]
		volume += owned.ownedVolume[i]
	end
	for a = 1, #set - 1 do
		for b = a + 1, #set do
			local i, j = set[a], set[b]
			if touching[i][j] then
				local mean = (exposure.contact[i][j] + exposure.contact[j][i]) / 2
				local s = math.min(1, m.parts[i].volume / Dif.V_PART_FULL, m.parts[j].volume / Dif.V_PART_FULL)
				joints += s * (1 + Dif.JOINT_BOOST * math.clamp(1 - mean / Dif.A_JOINT_REF, 0, 1))
			end
		end
	end
	local c = Num.cbrt(volume)
	return area / (6 * c * c), joints, volume
end

local function agreeWithPrototype(b: any)
	local what = b.name
	local core: any = { schema = 1, name = what, type = "Sword", parts = b.parts }
	local m = D.measured(core)
	local mine = D.steps(m) :: { StepAnalysis }
	local theirs = D.proto(b)
	A.truthy(mine ~= nil, what .. ": every work set has parts")
	local sameGrid = m.ctx.exposure.hSurf == theirs.hSurf
	local tag = string.match(what, "^%S+") :: string
	local ownContact, ownOverlap = OWN_CONTACT[tag] == true, OWN_OVERLAP[tag] == true
	A.eq(#mine, #theirs.steps, what .. " steps")
	for i, s in ipairs(mine) do
		local t = theirs.steps[i]
		local label = what .. " " .. s.step
		A.eq(s.step, t.step, label)
		if s.step == "Smelting" then -- Volume alone: the prototype's step
			A.eq(s.g, t.g, label .. " g")
			A.eq(s.d, t.d, label .. " d")
			A.eq(s.tierRaw, t.tierRaw, label .. " tierRaw")
		end
		A.eq(s.material, t.material, label .. " material")
		local area, joints, volume = ownMeasure(m, if s.step == "Sharpening" then { "Blade" } else "All")
		for k, v in ipairs(s.factors) do
			local tv = t.factors[k]
			local f = v.factor
			A.eq(f, tv.factor, label)
			if TO_THE_BIT[f] then
				A.eq(v.raw, tv.raw, label .. " " .. f)
				A.eq(v.x, tv.x, label .. " " .. f .. " x")
			elseif f == "EdgeLength" then
				A.eq(v.raw, m.edge.length, label .. " EdgeLength, the edge's")
			elseif f == "Thinness" then
				A.truthy(v.raw >= 0 and v.raw <= 1, label .. " Thinness in [0, 1]")
			elseif f == "Volume" then
				A.near(v.raw, if ownOverlap then volume else tv.raw, ABS, label .. " Volume")
			elseif f == "SurfaceComplexity" then
				A.near(v.raw, if sameGrid and not ownOverlap then tv.raw else area, ABS, label .. " SurfaceComplexity")
			else
				A.near(v.raw, if sameGrid and not ownContact then tv.raw else joints, ABS, label .. " " .. f)
			end
		end
	end
end

-- A sword built half and mirrored (L11): validSword's parts with centre x ≥ 0, then the mirror image (Blueprint/Mirror,
-- fresh ids) of those with x > 0 and of those on the plane that are not their own image, as the editor's mirror copy
-- makes them (§11.10); a sword with no Blade part at x ≥ 0 is reflected first. Canonical.
local function halfAndMirrored(rng: Rng): any
	local core = Gen.validSword(rng, CTX)
	local blade = false
	for _, p in core.parts do
		blade = blade or (p.slot == "Blade" and p.pos[1] >= 0)
	end
	local parts: { any } = {}
	local top = 0
	for _, p: any in core.parts do
		top = math.max(top, p.id)
		local q: any = if blade then p else Mirror.reflect(p, "X")
		if q.pos[1] >= 0 then
			table.insert(parts, q)
		end
	end
	for i = 1, #parts do
		local p = parts[i]
		if p.pos[1] > 0 or not Mirror.isSelfSymmetric(p, "X") then
			top += 1
			local image: any = Mirror.reflect(p, "X")
			image.id = top
			table.insert(parts, image)
		end
	end
	local result = Canonical.draft({ schema = core.schema, name = core.name, type = core.type, parts = parts }) :: any
	A.truthy(result.ok, "the mirrored sword is canonical: " .. Dump.short(result))
	return result.value
end

-- The factor, normalized, within TOL_ASYM_ZERO (§16.32); measured 0 on 500 designs, both sets.
local function mirroredCorpus(n: number)
	Prop.check(n, halfAndMirrored, function(core: any)
		local m = D.measured(core)
		for _, selector in BOTH do
			A.truthy(#D.set(m, selector) > 0, "a work set with parts")
			local v = D.valueOf(D.factors(m, selector), "Asymmetry")
			A.truthy(v.x <= Tol.TOL_ASYM_ZERO, string.format("Asymmetry %.6f (raw %.6f)", v.x, v.raw))
		end
	end)
end

return Test.suite("Physics/Factors", function(t)
	t.it("§5.2 ORDER is FactorId order: Definitions/Validate's and the Sword's refs'", function()
		A.deepEq(Factors.ORDER, Validate.FACTOR_ORDER, "Validate")
		A.eq(#SWORD.geometry.refs, #Factors.ORDER, "refs")
		for k, row in ipairs(SWORD.geometry.refs) do
			A.eq(row.factor, Factors.ORDER[k], "refs row " .. k)
		end
		A.truthy(table.isfrozen(Factors.ORDER), "frozen")
	end)

	t.it("§4.1 cbrt is the prototype's, bit for bit, and a cube root to a few ulps", function()
		local rng = TestRng.new(Tol.PROP_BASE_SEED)
		for _ = 1, 2000 do
			local v = rng:range(1, 10) * 10 ^ rng:int(-12, 6)
			local c = Factors.cbrt(v)
			A.eq(c, Num.cbrt(v), "the prototype's at " .. v)
			A.truthy(math.abs(c * c * c - v) <= 1e-15 * v, string.format("cbrt(%.17g)³ = %.17g", v, c * c * c))
		end
		A.eq(Factors.cbrt(0), 0, "0")
		A.eq(Factors.cbrt(-1), 0, "a negative volume measures 0")
		A.eq(Factors.cbrt(8), 2, "8")
		A.eq(Factors.cbrt(0.125), 0.5, "1/8")
	end)

	t.it("§5.2 norm; the union chord, grown from the probe, gaps the verdict hides across merged (§4.4)", function()
		A.eq(Factors.norm(5, 0, 10), 0.5, "inside")
		A.eq(Factors.norm(-1, 0, 1), 0, "below")
		A.eq(Factors.norm(2, 0, 1), 1, "above")
		-- along Z through (0, 1, 0), its owner part 1: [−0.03, 0.03], a 0.011 gap (hidden: ≤ HIDE_OFFSET + EPS_GEOM, past
		-- CONTACT_TOL), [0.041, 0.1], then a 0.0121 gap (it shows) and [0.1121, 0.2]; the parts but the owner grown by
		-- 1e-10 (face ties)
		local parts = H.prepared(Build.core("chords", {
			Build.part(1, "Blade", "Block", "Iron", { 0, 1, 0 }, Build.I, { 0.1, 0.1, 0.06 }),
			Build.part(2, "Blade", "Block", "Iron", { 0, 1, 0.0705 }, Build.I, { 0.1, 0.1, 0.059 }),
			Build.part(3, "Blade", "Block", "Iron", { 0, 1, 0.15605 }, Build.I, { 0.1, 0.1, 0.0879 }),
		}))
		A.truthy(0.011 > Limits.CONTACT_TOL and 0.011 <= Geo.HIDE_OFFSET and 0.0121 > Geo.HIDE_OFFSET + Geo.EPS_GEOM,
			"the gaps straddle the verdict's window")
		local length = Factors.unionChord(parts, parts[1], 0, 1, 0, 0, 0, 1)
		A.near(length, 0.13 + 1e-10, 1e-15, "the hidden gap merged, the shown one not")
		A.eq(Factors.unionChord({ parts[3], parts[2], parts[1] }, parts[1], 0, 1, 0, 0, 0, 1), length, "any order")
		A.eq(Factors.unionChord({ parts[3] }, parts[1], 0, 1, 0, 0, 0, 1), 0, "a chord away from the probe is not grown into")
		-- a gap crossed at a slant (Edge.hiddenGap): two plates turned 30° about Y, 0.0105 apart along their normal, which
		-- the Z line crosses 0.0121 apart; 0.0121 apart, it shows
		local turned = H.axisAngle(0, 1, 0, 30)
		local function laminate(g: number): number
			local t = (0.06 - g) / 2
			local off = g / 2 + t / 2
			local plates = H.prepared(Build.core("laminate", {
				Build.part(1, "Blade", "Block", "Iron", { 0.5 * off, 2, 0.8660254037844386 * off }, turned, { 0.16, 2.6, t }),
				Build.part(2, "Blade", "Block", "Iron", { -0.5 * off, 2, -0.8660254037844386 * off }, turned, { 0.16, 2.6, t }),
			}))
			local _, _, z = Shapes.toWorld(plates[1], 0, 0, 0)
			return (Factors.unionChord(plates, plates[1], 0.5 * off, 2, z, 0, 0, 1))
		end
		A.near(laminate(0.0105), 0.06 / 0.8660254037844386, 1e-9, "0.0105 apart: the plates' whole width along Z")
		A.near(laminate(0.0121), (0.06 - 0.0121) / 2 / 0.8660254037844386, 1e-9, "0.0121 apart: one plate's")
	end)

	-- M3's review round 3: the nearest chord past each end is the one asked, and the closure runs again after a join
	-- (asking the farthest, or one round of hidden joins, passed the suite). Each face's probe is asked of the part
	-- across alone: a probe that lands in a part beside it, past a flush seam or in a third plate beside a V, merges
	-- nothing (fix round 3 asked the list's other parts too, and so merged visible air: an open slot, below; withdrawn
	-- in fix round 4). Review round 5: a join past lo whatever lies past hi, and at a tie the first in the list.
	t.it("§5.2 the union chord's hidden gaps: three plates turned 30° about Y grown from any of them to the stack's "
		.. "width, past one end where the other shows; at a tie the first in the list asks; a probe in the piece beside "
		.. "a flush seam, or in a third plate beside a V, merges nothing", function()
		local turned = H.axisAngle(0, 1, 0, 30)
		local cos30 = 0.8660254037844386
		local plates: { Prepared } = {}
		for k = 1, 3 do
			local s = (k - 2) * (0.02 + 0.0105) -- along the normal (0.5, 0, cos 30°), each gap 0.0121 along Z
			plates[k] = H.prepare(Build.part(k, "Blade", "Block", "Iron", { 0.5 * s, 2.68, cos30 * s }, turned,
				{ 0.16, 2.6, 0.02 }), k)
		end
		for k = 1, 3 do
			local x, _, z = Shapes.toWorld(plates[k], 0, 0, 0)
			A.near(Factors.unionChord(plates, plates[k], x, 2.68, z, 0, 0, 1), (3 * 0.02 + 2 * 0.0105) / cos30, 1e-9,
				"from plate " .. k .. ": the stack's width along Z")
		end
		-- the upper plate 0.03 over the middle one, which the verdict shows: from the middle plate the chord grows down
		-- through the lower one past lo, though nothing past hi joins (a mutant that skipped a join past lo wherever a
		-- chord lay past hi passed the suite; M3's review round 5)
		local s3 = 0.02 + 0.03
		local apart = H.prepare(Build.part(3, "Blade", "Block", "Iron", { 0.5 * s3, 2.68, cos30 * s3 }, turned,
			{ 0.16, 2.6, 0.02 }), 3)
		A.near(Factors.unionChord({ plates[1], plates[2], apart }, plates[2], 0, 2.68, 0, 0, 0, 1),
			(2 * 0.02 + 0.0105) / cos30, 1e-9, "the upper plate apart: the lower two's width along Z")
		-- two chords that end, or start, at one t to the bit: flat plates pa and qa 0.0105 apart along the world axes, and
		-- strips pb and qb 0.006 wide with their z extents round where a line 30° off Z leaves pa (e) and meets qa (f,
		-- 0.00606 on along x), so e's probe lands in qa, not qb, and f's in pa, not pb. hiddenGap asks the first in the
		-- list, as W's rank order puts the plates first, from the plate under pa and from the one over qa alike (mutants
		-- that asked the last of a tie, of the chords that end the grown chord or of those past it, passed the suite;
		-- M3's review round 5)
		local fx = 0.0105 * 0.5 / cos30
		local function flat(id: number, x: number, z: number, sx: number): Prepared
			return H.prepare(Build.part(id, "Blade", "Block", "Iron", { x, 2.68, z }, Build.I, { sx, 0.5, 0.02 }), id)
		end
		local under, pa, pb = flat(1, 0, -0.03, 0.2), flat(2, 0, -0.01, 0.2), flat(3, 0, -0.01, 0.006)
		local qa, qb, over = flat(4, 0, 0.0205, 0.2), flat(5, fx, 0.0205, 0.006), flat(6, 0, 0.0405, 0.2)
		local across = (3 * 0.02 + 0.0105) / cos30 -- the plate under's bottom to qa's top, pa's bottom to over's top
		A.near(Factors.unionChord({ under, pa, pb, qa, qb }, under, -0.03 * 0.5 / cos30, 2.68, -0.03, 0.5, 0, cos30),
			across, 1e-9, "a tie at each end, the plates first: merged up from the plate under")
		A.near(Factors.unionChord({ over, qa, qb, pa, pb }, over, 0.0405 * 0.5 / cos30, 2.68, 0.0405, 0.5, 0, cos30),
			across, 1e-9, "the same, down from the plate over")
		A.near(Factors.unionChord({ under, pb, pa, qb, qa }, under, -0.03 * 0.5 / cos30, 2.68, -0.03, 0.5, 0, cos30),
			0.04 / cos30, 1e-9, "the strips first: the plate under and pa alone")
		-- plates 0.024 thick turned 45° about Y, 0.0105 apart, the upper one cut flush at local x −0.020: the Z line
		-- through the lower one's centre meets the piece on the −x side, and the lower face's probe lands in the other.
		-- The seam beside a slanted crossing stays open, §17.1 O11's residual (fix round 3's set merged it: m1 − l0)
		local r = 0.70710678118654757
		local d = 0.024 + 0.0105
		local turned45 = H.axisAngle(0, 1, 0, 45)
		local lower = H.prepare(Build.part(1, "Blade", "Block", "Iron", { 0, 2.68, 0 }, turned45, { 0.16, 2.6, 0.024 }), 1)
		local function piece(id: number, a: number, b: number): Prepared
			local c = (a + b) / 2
			return H.prepare(Build.part(id, "Blade", "Block", "Iron", { d * r + c * r, 2.68, d * r - c * r }, turned45,
				{ b - a, 2.6, 0.024 }), id)
		end
		local met, beside = piece(2, -0.08, -0.020), piece(3, -0.020, 0.08)
		A.near(Factors.unionChord({ lower, met, beside }, lower, 0, 2.68, 0, 0, 0, 1), 0.024 / r, 1e-9,
			"the piece beside in the list: the lower plate's chord")
		A.near(Factors.unionChord({ lower, met }, lower, 0, 2.68, 0, 0, 0, 1), 0.024 / r, 1e-9,
			"without it: the lower plate's chord")
		-- Edge.spec's V, 10° and 10° over 0.06: p's and q's faces, turned 10° off the Z line x = 0.1, a third plate s on
		-- its open side 0.0102 off the line holding both probes. The verdict shows the V's middle (0.0123 across between q
		-- and s, 0.0154 at the apex): from inside p the chord along Z stays p's (fix round 3's set merged it to q)
		local s10, c10 = math.sin(math.rad(10)), math.cos(math.rad(10))
		local p = H.prepare(Build.part(1, "Blade", "Block", "Iron", { 0.1 + 0.02 * c10, 2.68, -0.02 * s10 },
			H.axisAngle(0, 1, 0, 10), { 0.04, 0.5, 0.06 }), 1)
		local q = H.prepare(Build.part(2, "Blade", "Block", "Iron", { 0.1 + 0.02 * c10, 2.68, 0.06 + 0.02 * s10 },
			H.axisAngle(0, 1, 0, -10), { 0.04, 0.5, 0.06 }), 2)
		local third = H.prepare(Build.part(3, "Blade", "Block", "Iron", { 0.1 - 0.0102 - 0.015, 2.68, 0.03 }, Build.I,
			{ 0.03, 0.5, 0.18 }), 3)
		local _, p0, p1 = Shapes.chord(p, 0.1, 2.68, 0, 0, 0, 1)
		A.near(p1, 0, 1e-12, "the line leaves p at z = 0")
		A.near(Factors.unionChord({ p, q, third }, p, 0.1, 2.68, (p0 + p1) / 2, 0, 0, 1), p1 - p0, 1e-9,
			"the V: p's chord alone")
	end)

	-- M3's review round 4: four slabs 3° off the Z line, p and r 0.012 over it, r' and q 0.0119 over p's top plane past an
	-- open slot c long (Edge.spec's slot), p's lower end on a plate B: from inside B the Z line grows through B and p,
	-- leaves p's top face under r and meets q's bottom face over r' 0.227 further, each probe in the slab beside. Asked of
	-- the list's other parts too (fix round 3), the union chord merged across the slot: 0.2905 against 0.0421. With
	-- c = 0 the two slits are one channel whose faces the slabs beside hide: open all the same, the seam beside a slanted
	-- crossing (§17.1 O11).
	t.it("§5.2 the union chord's hidden gaps: an open slot crossed at a grazing slant between two hidden gaps is not "
		.. "merged", function()
		local sb, cb = math.sin(math.rad(3)), math.cos(math.rad(3))
		local s, t2, ue = 0.0119, 0.021, 0.03
		local uf = ue - s * cb / sb
		local x0 = 0.02
		local dx = x0 - ue * sb
		local dz = 0.02 + (ue + t2) * cb + t2 * sb -- p's lowest corner on B's top face, z = 0.02
		local turned = H.axisAngle(0, 1, 0, 87)
		local function slab(id: number, u0: number, u1: number, h0: number, h1: number): Prepared
			local u, h = (u0 + u1) / 2, (h0 + h1) / 2
			return H.prepare(Build.part(id, "Blade", "Block", "Iron", { dx + u * sb + h * cb, 2.68, dz - u * cb + h * sb },
				turned, { u1 - u0, 0.5, h1 - h0 }), id)
		end
		local function parts(c: number): { Prepared }
			return {
				H.prepare(Build.part(1, "Blade", "Block", "Iron", { 0, 2.68, 0.01 }, Build.I, { 0.16, 0.5, 0.02 }), 1), -- B
				slab(2, 0, ue + t2, -t2, 0), -- p
				slab(3, 0, ue + t2, 0.012, 0.012 + t2), -- r
				slab(4, uf - t2, -c, s - 0.012 - t2, s - 0.012), -- r'
				slab(5, uf - t2, -c, s, s + t2), -- q
			}
		end
		for _, c in { 0, 0.15 } do
			local list = parts(c)
			local _, _, p1 = Shapes.chord(list[2], x0, 2.68, 0, 0, 0, 1)
			A.near(Factors.unionChord(list, list[1], x0, 2.68, 0.01, 0, 0, 1), p1, 1e-8,
				"c " .. c .. ": B and p alone (TIE/cos 87° past p)")
		end
	end)

	-- §17.1 O11's face tie (M3's review round 2): a probe on another part's face, its line along that face. Rounding
	-- decided whether the line met that part, so a Y shift could move it; every part but the owner is read grown by
	-- 1e-10, so it does, wherever the design stands.
	t.it("§5.2 a probe on another part's face: the line along the face meets that part, whatever the shift", function()
		for _, dy in { 0, 0.013, 0.125, 0.3317, 1.509295, -0.7151 } do
			-- the owner spans y 0.9–1.1; the other part's lower face is y = 1.05, through the probe
			local parts = H.prepared(Build.core("tie", {
				Build.part(1, "Blade", "Block", "Iron", { 0, 1 + dy, 0 }, Build.I, { 0.1, 0.2, 0.06 }),
				Build.part(2, "Blade", "Block", "Iron", { 0.0 + 0.0137, 1.1 + dy, 0 }, Build.I, { 0.1, 0.1, 0.1 }),
			}))
			local length = Factors.unionChord(parts, parts[1], 0, 1.05 + dy, 0, 0, 0, 1)
			A.near(length, 0.1 + 2e-10, 1e-12, string.format("y + %g: the line along the face meets the part", dy))
			A.near(Factors.unionChord(parts, parts[1], 0, 1.05 + dy, 0, 1, 0, 0), 0.1 + 0.0137 + 1e-10, 1e-12,
				string.format("y + %g: along X too", dy))
		end
	end)

	t.it("§5.2 θ: a polyhedron's three local axes, a Cylinder's axis and two radial directions fixed by Z, a Ball's "
		.. "world axes; ±Z left out; the same lines for every writing", function()
		local Z = { 0, 0, 1 }
		local function dirsOf(shape: string, rot: { number }, size: { number }): { number }
			return Factors.thinDirections(H.prepare(Build.part(1, "Blade", shape, "Iron", { 0, 2, 0 }, rot, size)), Z[1],
				Z[2], Z[3])
		end
		-- the lines of a direction list, each as its unit vector with its first non-zero component positive, sorted
		local function lines(d: { number }): { { number } }
			local out: { { number } } = {}
			for a = 1, #d, 3 do
				local v = { d[a], d[a + 1], d[a + 2] }
				local s = 1
				for k = 1, 3 do
					if math.abs(v[k]) > 1e-9 then
						s = if v[k] < 0 then -1 else 1
						break
					end
				end
				table.insert(out, { s * v[1], s * v[2], s * v[3] })
			end
			table.sort(out, function(p: { number }, q: { number }): boolean
				for k = 1, 3 do
					if math.abs(p[k] - q[k]) > 1e-9 then
						return p[k] < q[k]
					end
				end
				return false
			end)
			return out
		end
		local function sameLines(a: { number }, b: { number }, what: string)
			local la, lb = lines(a), lines(b)
			A.eq(#la, #lb, what .. " lines")
			for k, v in la do
				for c = 1, 3 do
					A.near(v[c], lb[k][c], 1e-12, what .. " line " .. k)
				end
			end
		end
		local turned = H.axisAngle(1, 2, 3, 40)
		local block = H.prepare(Build.part(1, "Blade", "Block", "Iron", { 0, 2, 0 }, turned, { 0.3, 0.1, 0.2 }))
		A.deepEq(dirsOf("Block", turned, { 0.3, 0.1, 0.2 }),
			{ block.ux, block.uy, block.uz, block.vx, block.vy, block.vz, block.wx, block.wy, block.wz }, "a turned Block")
		A.deepEq(dirsOf("Block", Build.I, { 0.16, 2.6, 0.06 }), { 1, 0, 0, 0, 1, 0 }, "F5's blade: local Z is Z")
		A.deepEq(dirsOf("Ball", turned, { 0.3, 0.3, 0.3 }), { 1, 0, 0, 0, 1, 0 }, "a Ball, turned: world X and Y")
		local rod = dirsOf("Cylinder", Build.Z90, { 0.9, 0.16, 0.16 }) -- axis along +Y
		sameLines(rod, { 0, 1, 0, 1, 0, 0 }, "a rod along Y: its axis and X (Z left out)")
		sameLines(dirsOf("Cylinder", Build.Y90, { 0.2, 0.3, 0.3 }), { 0, 1, 0, 1, 0, 0 },
			"a disc whose axis is Z (left out): Y and X square to it")
		-- every writing of one solid: a Block's 24, a rod spun about its axis, a Ball turned
		local plain = Build.part(1, "Blade", "Block", "Iron", { 0, 2, 0 }, turned, { 0.3, 0.1, 0.2 })
		for k, w in D.writings() do
			local p = D.written(plain, w)
			sameLines(dirsOf("Block", p.rot, p.size), dirsOf("Block", turned, plain.size), "the Block's writing " .. k)
		end
		local rodTurn = Build.mul(turned, Build.Z90)
		for _, deg in { 30, 90, 137 } do
			sameLines(dirsOf("Cylinder", Build.mul(rodTurn, H.axisAngle(1, 0, 0, deg)), { 0.9, 0.16, 0.16 }),
				dirsOf("Cylinder", rodTurn, { 0.9, 0.16, 0.16 }), "a rod spun " .. deg .. "°")
		end
		sameLines(dirsOf("Ball", H.axisAngle(0.36, 0.48, 0.8, 70), { 0.3, 0.3, 0.3 }), dirsOf("Ball", Build.I,
			{ 0.3, 0.3, 0.3 }), "a Ball turned")
	end)

	t.it("§5.2 the canonical walk: a Block's writings walk one sequence of points, its axes from the thinnest out (one "
		.. "along ±Z too); the pick's step is coprime to the walk", function()
		local h = Geo.H_VOL
		local turned = H.axisAngle(1, 2, 3, 40)
		local size = { 0.3, 0.06, 0.16 }
		local function pointsOf(p: any): { number }
			local S = Sampling.volumeSamples(p, h)
			local walk = Factors.canonicalWalk(p, S, function() end)
			A.truthy(walk ~= nil, "a polyhedron has a canonical walk")
			local out: { number } = {}
			local seen: { [number]: boolean } = {}
			for c = 0, S.n - 1 do
				local s = (walk :: any)(c)
				A.truthy(s >= 1 and s <= S.n and not seen[s], "a permutation of the samples")
				seen[s] = true
				table.insert(out, S.x[s])
				table.insert(out, S.y[s])
				table.insert(out, S.z[s])
			end
			return out
		end
		local plain = Build.part(1, "Blade", "Block", "Iron", { 0, 2, 0 }, turned, size)
		local base = pointsOf(H.prepare(plain))
		A.eq(#base, 3 * 6 * 2 * 4, "6 × 2 × 4 samples")
		for k, w in D.writings() do
			local q = pointsOf(H.prepare(D.written(plain, w)))
			for i, v in base do
				A.near(q[i], v, 1e-12, "writing " .. k .. ": coordinate " .. i)
			end
		end
		-- the thinnest axis outermost: the first half of the walk is one of its two layers
		local p = H.prepare(Build.part(1, "Blade", "Block", "Iron", { 0, 2, 0 }, Build.I, size))
		local S = Sampling.volumeSamples(p, h)
		local walk = Factors.canonicalWalk(p, S, function() end) :: any
		for c = 0, S.n - 1 do
			A.eq(S.y[walk(c)] < 2, c < S.n / 2, "layer of position " .. c)
		end
		A.eq(Factors.canonicalWalk(H.prepare(Build.part(1, "Blade", "Ball", "Iron", { 0, 2, 0 }, Build.I,
			{ 0.3, 0.3, 0.3 })), S, function() end), nil, "a round part keeps its own order")
		-- a Block turned about Z alone, one local axis along ±Z (V1's FA8: the sign rule's last case, +Z, pinned)
		local flat = Build.part(1, "Blade", "Block", "Iron", { 0, 2, 0 }, H.axisAngle(0, 0, 1, 40), { 0.3, 0.06, 0.16 })
		local first = pointsOf(H.prepare(flat))
		for k, w in D.writings() do
			local q = pointsOf(H.prepare(D.written(flat, w)))
			for i, v in first do
				A.near(q[i], v, 1e-12, "turned about Z, writing " .. k .. ": coordinate " .. i)
			end
		end
		for _, n in { 1, 2, 3, 4, 12, 48, 96, 432, 2304, 3000 } do
			local a = Factors.latticeStep(n)
			local x, y = n, a
			while y > 0 do
				x, y = y, x % y
			end
			A.truthy(x == 1 and a >= 1 and (n == 1 or a < n), n .. ": step " .. a .. " coprime")
		end
	end)

	t.it("§5.2 Thinness' share term counts the probes taken: the striking slot's weight, or all where none is (L13)",
		function()
			-- F5 with its guard 0.03 thick (thin metal outside the striking slot) and no probe on its blade parts: none
			-- of the probes taken is in the striking slot, so the share is of all of them, as with no striking slot
			local core = Blueprints.core("F5")
			core.parts[3].size[3] = 0.03
			local m = D.measured(core)
			local all = D.set(m, "All")
			local probes = table.clone(m.ctx.probes.byPart)
			for _, i in ipairs(all) do
				if m.parts[i].slot == "Blade" then
					probes[i] = { n = 0, x = {}, y = {}, z = {}, w = 0 }
				end
			end
			local ctx = table.clone(m.ctx)
			ctx.probes = { h = m.ctx.probes.h, total = m.ctx.probes.total, byPart = probes }
			local thin = Factors.thinness(ctx, all)
			local geometry: any = table.clone(D.GEOMETRY)
			geometry.strikingSlot = "Head" -- no part's slot
			local noSlot = table.clone(ctx)
			noSlot.geometry = geometry
			A.eq(thin, Factors.thinness(noSlot, all), "as with no striking slot")
			-- over the striking slot's weight, 0, the share would be 0
			A.truthy(thin > 0, "the thin guard counts: " .. thin)
		end)

	-- Fast until M3's fix round 1 (§14.1's 27 s); its designs are the first of the PROP_N case's.
	t.slow("T-DIF-01 Gen designs: every factor in range, g, m, d on the 1e-4 grid", function()
		Prop.check(20, function(rng: Rng): any
			return Gen.validSword(rng, CTX)
		end, function(core: any)
			D.inRange(stepsOf(core), "Gen")
		end)
	end)

	t.slow("T-DIF-01 Gen designs, PROP_N: every factor in range, g, m, d on the 1e-4 grid", function()
		Prop.check(Tol.PROP_N, function(rng: Rng): any
			return Gen.validSword(rng, CTX)
		end, function(core: any)
			D.inRange(stepsOf(core), "Gen")
		end)
	end)

	t.it("T-DIF-01 the caps: A24's Thinness, P1's, P2's and P4's Volume, F3's Blade's SurfaceComplexity", function()
		local a24 = stepsOf(canonicalOf("A24"))
		A.eq(D.valueOf(D.stepOf(a24, "Hammering").factors, "Thinness").raw, 1, "A24 Thinness on All")
		A.eq(D.valueOf(D.stepOf(a24, "Sharpening").factors, "Thinness").raw, 1, "A24 Thinness on the Blade")
		local hammering = D.stepOf(a24, "Hammering")
		A.eq(hammering.d, 0.4, "A24 Hammering")
		A.eq(hammering.tier, "Hard", "A24 Hammering plays Hard")
		local VOLUMES = { { id = "P1", volume = 2.2682 }, { id = "P2", volume = 0.9968 },
			{ id = "P4", volume = 1.2608 } }
		for _, row in VOLUMES do
			local v = D.valueOf(D.stepOf(stepsOf(Cost.get(row.id).core), "Smelting").factors, "Volume")
			A.near(v.raw, row.volume, 5e-5, row.id .. " Volume")
			A.eq(v.x, 1, row.id .. " Volume x")
		end
		local sc = D.valueOf(D.stepOf(stepsOf(Blueprints.get("F3").core), "Sharpening").factors, "SurfaceComplexity")
		A.near(sc.raw, 2.9804, 5e-5, "F3's Blade SurfaceComplexity")
		A.eq(sc.x, 1, "F3's Blade SurfaceComplexity x")
	end)

	t.it("T-DIF-01 the EdgeLength cap: F2's hilt with a 1.4 × 3.43 blade is valid and measures 8.2001, x 1", function()
		local cap: any = Blueprints.core("F2")
		cap.parts[4] = Build.part(4, "Blade", "Block", "Iron", { 0, 1.55 + 3.43 / 2, 0 }, Build.I, { 1.4, 3.43, 0.06 })
		A.truthy(Analyze.run(cap).validation.ok, "valid")
		local e = D.valueOf(D.stepOf(stepsOf(cap), "Sharpening").factors, "EdgeLength")
		A.near(e.raw, 8.2001, 5e-5, "EdgeLength")
		A.truthy(e.raw >= 8, "past the range's top")
		A.eq(e.x, 1, "x")
	end)

	t.it("T-DIF-06 F5's blade thinned 0.060 → 0.043: Thinness on All and Hammering rise, Hard from 0.045 (0.2070)",
		function()
			local THICK = { 0.060, 0.055, 0.050, 0.047, 0.045, 0.043 }
			local HAMMERING = { 0.1037, 0.1322, 0.1658, 0.1895, 0.2070, 0.2263 }
			local THINNESS = { 0.2594, 0.3305, 0.4144, 0.4737, 0.5176, 0.5657 }
			local lastD, lastThin = -1, -1
			for k, th in THICK do
				local core = Blueprints.core("F5")
				core.parts[4].size[3] = th
				local hammering = D.stepOf(stepsOf(core), "Hammering")
				local thin = D.valueOf(hammering.factors, "Thinness").raw
				A.near(hammering.d, HAMMERING[k], 5e-5, th .. " Hammering")
				A.near(thin, THINNESS[k], 5e-5, th .. " Thinness")
				A.eq(hammering.tier, if th <= 0.045 then "Hard" else "Normal", th .. " tier")
				A.truthy(hammering.d >= lastD and thin >= lastThin, th .. " non-decreasing")
				lastD, lastThin = hammering.d, thin
			end
		end)

	t.it("T-DIF-06 C02's blade lengthened +0.15 → +0.25: EdgeLength and Sharpening rise, Hard from +0.20 (0.2056)",
		function()
			local LONGER = { 0, 0.15, 0.20, 0.25 }
			local SHARPENING = { 0.1318, 0.1889, 0.2056, 0.2314 }
			local EDGE = { 5.6435, 5.9635, 6.0435, 6.1635 }
			local lastD, lastEdge = -1, -1
			for k, dl in LONGER do
				local core = Calibration.core("C02")
				core.parts[4].size[2] += dl
				core.parts[4].pos[2] += dl / 2
				core.parts[5].pos[2] += dl
				core.parts[6].pos[2] += dl
				local sharpening = D.stepOf(stepsOf(core), "Sharpening")
				local edge = D.valueOf(sharpening.factors, "EdgeLength").raw
				A.near(sharpening.d, SHARPENING[k], 5e-5, "+" .. dl .. " Sharpening")
				A.near(edge, EDGE[k], 5e-5, "+" .. dl .. " EdgeLength")
				A.eq(sharpening.tier, if dl >= 0.20 then "Hard" else "Normal", "+" .. dl .. " tier")
				A.truthy(sharpening.d >= lastD and edge >= lastEdge, "+" .. dl .. " non-decreasing")
				lastD, lastEdge = sharpening.d, edge
			end
		end)

	t.it("T-DIF-06 PartCount rises with the parts: C01's 4 to C10's 6.916, its 20 filler parts", function()
		local function partCount(id: string): number
			return D.valueOf(D.factors(D.measured(Calibration.get(id).core), "All"), "PartCount").raw
		end
		A.eq(partCount("C01"), 4, "C01: four parts, each at least V_PART_FULL")
		A.near(partCount("C10"), 6.916, 5e-4, "C10")
	end)

	t.it("T-DIF-08 C13, its guard built half and mirrored: Asymmetry 0 on All and on its Blade", function()
		local m = D.measured(Calibration.get("C13").core)
		for _, selector in BOTH do
			local v = D.valueOf(D.factors(m, selector), "Asymmetry")
			A.eq(v.raw, 0, "raw")
			A.eq(v.x, 0, "x")
		end
	end)

	-- Fast until M3's fix round 1 (§14.1's 27 s); its designs are the first of the FUZZ_N_VALID case's.
	t.slow("T-DIF-08 Gen swords built half and mirrored (Blueprint/Mirror): Asymmetry ≤ TOL_ASYM_ZERO on both sets",
		function()
			mirroredCorpus(20)
		end)

	t.slow("T-DIF-08 Gen swords built half and mirrored, FUZZ_N_VALID: Asymmetry ≤ TOL_ASYM_ZERO on both sets (L11)",
		function()
			mirroredCorpus(Tol.FUZZ_N_VALID)
		end)

	-- E-S2.5's oracle (v2/run.luau's asymOracle): ASYM_N_MIN 120, ASYM_WORK 1e9 and N_MAX_AXIS 400, planted into
	-- Sampling, whose volumeSamples reads N_MAX_AXIS itself, and into Factors with that Sampling.
	-- The whole-design shift fix (§17.1 O11 (j)): Asymmetry's work estimate counts the mirror candidates, and a box test
	-- at exactly reach left a part that far away to the rounding of where the design stands.
	t.it("§5.2 Asymmetry's mirror candidates take a part exactly reach from a mirrored box, however a move rounds the "
		.. "gap: its work estimate the same at every move", function()
			-- a block 0.05 (ASYM_TOL + ASYM_RAMP) under the other's mirror image: tested at reach alone, 0.111 and 0.148
			-- up Y rounded the gap past it and dropped each from the other's candidates (the estimate 800 → 640)
			local reach = Dif.ASYM_TOL + Dif.ASYM_RAMP
			local function estimate(dy: number, gap: number): number
				local m = D.measured({ parts = {
					H.solid(1, "Block", { 0.2, 2.1 + dy, 0 }, H.I, { 0.2, 0.2, 0.06 }),
					H.solid(2, "Block", { -0.2, 2.1 - 0.2 - gap + dy, 0 }, H.I, { 0.2, 0.2, 0.06 }),
					H.solid(3, "Block", { 0, 1 + dy, 0 }, H.I, { 0.1, 0.6, 0.1 }, "Grip"),
				} })
				local _, _, est = Factors.asymmetry(m.ctx, D.set(m, "All"))
				return est
			end
			local atReach = estimate(0, reach)
			A.truthy(atReach > estimate(0, reach + 0.001), "at reach a candidate, past it none")
			for k = 1, 4 do
				A.eq(estimate(0.037 * k, reach), atReach, string.format("moved %g along Y", 0.037 * k))
			end
		end)

	t.it("§5.2 Asymmetry's candidates take a part exactly reach from a mirrored box along Z (at every move along Z) "
		.. "and along X (wherever it stands): its estimate as at a gap 0.001 inside reach", function()
			local reach = Dif.ASYM_TOL + Dif.ASYM_RAMP
			local function estimate(a: number, dz: number, gapX: number?, gapZ: number?): number
				local behind = if gapZ then { -a, 2.1, 0.06 + gapZ + dz } else { -a - 0.2 - (gapX :: number), 2.1, dz }
				local m = D.measured({ parts = {
					H.solid(1, "Block", { a, 2.1, dz }, H.I, { 0.2, 0.2, 0.06 }),
					H.solid(2, "Block", behind, H.I, { 0.2, 0.2, 0.06 }),
					H.solid(3, "Block", { 0, 1, dz }, H.I, { 0.1, 0.6, 0.1 }, "Grip"),
				} })
				local _, _, est = Factors.asymmetry(m.ctx, D.set(m, "All"))
				return est
			end
			local atReach = estimate(0.2, 0, nil, reach)
			A.truthy(atReach > estimate(0.2, 0, nil, reach + 0.001), "along Z: at reach a candidate, past it none")
			A.eq(estimate(0.2, 0, nil, reach + 1e-6), estimate(0.2, 0, nil, reach + 0.001), "1e-6 past reach: no candidate")
			A.eq(estimate(0.2, 0, nil, reach + 5e-9), estimate(0.2, 0, nil, reach + 0.001), "5e-9 past reach: no candidate")
			-- MIRROR_GUARD (1e-9) pinned from both sides, within 1.5 times it: 1.5e-9 past reach no candidate, 5e-10 past one
			A.eq(estimate(0.2, 0, nil, reach + 1.5e-9), estimate(0.2, 0, nil, reach + 0.001), "1.5e-9 past reach: no candidate")
			A.eq(estimate(0.2, 0, nil, reach + 5e-10), atReach, "5e-10 past reach, inside MIRROR_GUARD: a candidate")
			for k = 1, 8 do
				A.eq(estimate(0.2, 0.0137 * k, nil, reach), atReach, string.format("moved %g along Z", 0.0137 * k))
			end
			for k = 0, 15 do
				local a = 0.2 + 0.0071 * k
				A.eq(estimate(a, 0, reach), estimate(a, 0, reach - 0.001), string.format("along X, the part at %g", a))
			end
		end)

	t.it("T-DIF-13 X06's Asymmetry on its Blade against the 120-probe oracle: within 0.02, 0.0030 measured", function()
		local geometry: any, difficulty: any = table.clone(Geo), table.clone(Dif)
		geometry.N_MAX_AXIS = 400
		difficulty.ASYM_N_MIN, difficulty.ASYM_WORK = 120, 1e9
		local oracle = Drafts.planted("src/shared/Physics/Factors.luau", {
			["../Definitions/Balance"] = { Geometry = geometry, Difficulty = difficulty },
			["../Definitions/Types"] = Types,
			["../Definitions/Materials"] = Materials,
			["./Edge"] = Edge,
			["./MassProps"] = MassProps,
			["./Sampling"] = H.plantedSampling({ N_MAX_AXIS = 400 }),
			["./Shapes"] = Shapes,
		})
		local MEASURED = { 0, 0, 0.0396, 0.1529, 0.2804, 0.4078 }
		local ORACLE = { 0, 0, 0.0413, 0.1559, 0.2817, 0.4075 }
		local worst = 0
		for k, offset in { "0.00", "0.01", "0.02", "0.03", "0.04", "0.05" } do
			local m = D.measured(Regression.get("X06-" .. offset).core)
			local blade = D.set(m, { "Blade" })
			local raw = Factors.asymmetry(m.ctx, blade)
			local truth = oracle.asymmetry(m.ctx, blade)
			A.near(raw, MEASURED[k], 5e-5, offset .. " measured")
			A.near(truth, ORACLE[k], 5e-5, offset .. " the oracle")
			worst = math.max(worst, math.abs(raw - truth))
		end
		A.truthy(worst <= 0.02, "E-S2.5's bound: " .. worst)
		A.near(worst, 0.0030, 5e-5, "the largest error")
	end)

	t.it("[8.2] the prototype's factors in the measure's rank order: S2's calibration swords and F1–F5", function()
		for _, b in ipairs(Fixtures.calibration()) do
			agreeWithPrototype(b)
		end
		for _, b in ipairs(Fixtures.golden()) do
			agreeWithPrototype(b)
		end
		-- C09's Thinness on All: 0.3858 in part order (E-S2.9), 0.3898 in rank order ([7.3]), 0.3935 with fix round 1's
		-- θ, walk and pick
		local c09 = D.valueOf(D.factors(D.measured(Calibration.get("C09").core), "All"), "Thinness")
		A.near(c09.raw, 0.3935, 5e-5, "C09's Thinness on All")
	end)

	t.it("[8.2] the prototype's factors in the measure's rank order: A25–A27, X01–X07 and their bases", function()
		local seen: { [any]: boolean } = {}
		for _, group in { Fixtures.adversarial(), Fixtures.regression() } do
			for _, r in ipairs(group) do
				for _, b in { r.base, r.fixture } do
					if not seen[b] then
						seen[b] = true
						agreeWithPrototype(b)
					end
				end
			end
		end
	end)

	t.it("[8.2] the prototype's factors on P2–P5; P1 on its own verdict, SurfaceComplexity and Joints on its measure",
		function()
			for i, b in ipairs(Fixtures.perf()) do
				if i > 1 then
					agreeWithPrototype(b)
				end
			end
			-- P1 keeps two blocks the prototype cleans (Reference.spec's OWN_VERDICT): its d is the build's own ([7.2])
			local m = D.measured(Cost.get("P1").core)
			local steps = D.steps(m) :: { StepAnalysis }
			for k, d in { 1, 0, 0.0086 } do
				A.eq(steps[k].d, d, "P1 " .. steps[k].step)
			end
			for _, s in steps do
				local area, joints = ownMeasure(m, if s.step == "Sharpening" then { "Blade" } else "All")
				local label = "P1 " .. s.step
				A.near(D.valueOf(s.factors, "SurfaceComplexity").raw, area, ABS, label .. " SurfaceComplexity")
				A.near(D.valueOf(s.factors, "Joints").raw, joints, ABS, label .. " Joints")
			end
		end)

	t.it("§4.9 budgets on P1–P5: Thinness' probes ≤ THICK_BUDGET, Asymmetry's work ≤ ASYM_WORK or the last rung",
		function()
			local last = Geo.H_VOL * Geo.H_LADDER[#Geo.H_LADDER]
			for _, f in Cost.list do
				local m = D.measured(f.core)
				for _, selector in BOTH do
					local set = D.set(m, selector)
					local _, budget = Factors.measure(m.ctx, set)
					local n = 0
					for _, i in set do
						n += m.ctx.probes.byPart[i].n
					end
					A.eq(budget.thinStride, math.max(1, math.ceil(n / Dif.THICK_BUDGET)), f.id .. " stride")
					A.truthy(budget.thinProbes <= Dif.THICK_BUDGET, f.id .. " probes " .. budget.thinProbes)
					local fits = budget.asymWork <= Dif.ASYM_WORK or budget.asymSpacing == last
					A.truthy(fits, f.id .. " Asymmetry's work " .. budget.asymWork)
				end
			end
		end)

	-- One unit ≈ one shape query: Thinness' probes, Asymmetry's samples and their volume samples each reach a
	-- checkpoint at Analyze's cadence, so none is a long uncharged stretch.
	t.it("§4.9 Thinness' and Asymmetry's loops reach a checkpoint at CHECK_UNITS", function()
		local seen: { [string]: boolean } = {}
		local units, total = 0, 0
		local function spend(n: number)
			units += n
			total += n
			if units >= Analyze.CHECK_UNITS then
				units = 0
				for level = 2, 6 do
					local name = debug.info(level, "n")
					if name and name ~= "" then
						seen[name] = true
					end
				end
			end
		end
		local m = D.measured(Calibration.get("C09").core)
		local all = D.set(m, "All")
		local _, budget = Factors.measure(m.ctx, all, spend)
		A.truthy(total > budget.thinProbes, "C09: " .. total .. " units for " .. budget.thinProbes .. " probes")
		for _, name in { "thinness", "asymmetry", "volumeSamples" } do
			A.truthy(seen[name], "no checkpoint from " .. name)
		end
	end)

	-- What each loop reports, by the function that charges it (the spend's direct caller), on fixed designs and both work
	-- sets: a charge lost, changed or moved fails here at once, where only the timed T-PERF-01, run alone, felt it (M3's
	-- review: buried probes, Asymmetry's per-sample and per-part charges uncharged all passed the fast suite). F4's and
	-- P5's Wedges walk canonicalWalk's rows. Thinness' union chords charge Edge.hiddenGap's queries (fix round 2: F5 on
	-- All 4801 → 4911, P5 14656 → 14794 and on the Blade 8217 → 8273; fix round 3, a normal first and every box test
	-- charged: F5 on All → 4921, F4 5600 → 5644, P5 → 14848 and on the Blade → 8351). A part that only touches another
	-- face to face is above it no more (§4.3, the whole-design shift fix), so the probes and samples that charged one
	-- unit for it charge none: F5 on All thinness 4921 → 4715, asymmetry 11069 → 9746; F4 5644 → 5564, 19264 → 17849,
	-- on the Blade 2208 → 2178, 10069 → 9796; P5 14848 → 14642, 21409 → 20086.
	t.it("§4.9 each loop charges its own units: Thinness', Asymmetry's, the walk's and the samples' by caller", function()
		local function byCaller(core: any, selector: any): { [string]: number }
			local m = D.measured(core)
			local by: { [string]: number } = {}
			Factors.measure(m.ctx, D.set(m, selector), function(n: number)
				local name = debug.info(2, "n")
				local key = if name and name ~= "" then name else "?"
				by[key] = (by[key] or 0) + n
			end)
			return by
		end
		local f5, f4, p5 = Blueprints.get("F5").core, Blueprints.get("F4").core, Cost.get("P5").core
		A.deepEq(byCaller(f5, "All"), { thinness = 4715, asymmetry = 9746, volumeSamples = 2640 }, "F5 All")
		A.deepEq(byCaller(f5, { "Blade" }), { thinness = 1197, asymmetry = 3685, volumeSamples = 1160 }, "F5 Blade")
		A.deepEq(byCaller(f4, "All"), { thinness = 5564, canonicalWalk = 272, asymmetry = 17849, volumeSamples = 4856 },
			"F4 All")
		A.deepEq(byCaller(f4, { "Blade" }), { thinness = 2178, canonicalWalk = 272, asymmetry = 9796, volumeSamples = 3536 },
			"F4 Blade")
		A.deepEq(byCaller(p5, "All"), { thinness = 14642, canonicalWalk = 60, asymmetry = 20086, volumeSamples = 3040 },
			"P5 All")
		A.deepEq(byCaller(p5, { "Blade" }), { thinness = 8351, canonicalWalk = 60, asymmetry = 13965, volumeSamples = 1560 },
			"P5 Blade")
	end)

	t.it("§5.2 a factor without a reference range is a caller's bug: Factors.measure raises, naming it", function()
		local m = D.measured(Blueprints.get("F5").core)
		local ctx = table.clone(m.ctx)
		local geometry = table.clone(m.ctx.geometry) :: any
		geometry.refs = { m.ctx.geometry.refs[1] }
		ctx.geometry = geometry
		local set = D.set(m, "All")
		local ok, message = pcall(function()
			Factors.measure(ctx, set)
		end)
		A.falsy(ok, "raised")
		-- PartCount's row kept; Thinness has none to look up (its range is σ's, inside φ): Asymmetry's is the first missing
		A.truthy(string.find(tostring(message), "no reference range for Asymmetry", 1, true) ~= nil, tostring(message))
	end)

	t.it("P-DET and P-NOMUT: Factors.measure on frozen inputs, twice, the same values; any order of the set", function()
		for _, core in { Blueprints.get("F1").core, Calibration.get("C09").core, Cost.get("P5").core } do
			local m = D.measured(core)
			Build.freeze(m.ctx)
			for _, selector in BOTH do
				local set = Build.freeze(D.set(m, selector))
				local a, ab = Factors.measure(m.ctx, set)
				local b, bb = Factors.measure(m.ctx, set)
				A.eq(Dump.canonical({ a, ab }), Dump.canonical({ b, bb }), core.name .. " P-DET")
				local reversed: { number } = {}
				for k = #set, 1, -1 do
					table.insert(reversed, set[k])
				end
				A.eq(Dump.canonical((Factors.measure(m.ctx, reversed))), Dump.canonical(a), core.name .. " any order")
			end
		end
	end)
end)
