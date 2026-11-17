--!strict
-- T-EDG-01 Physics/Edge (SPEC §4.6; §14.6 names it, the M3 plan defines it: .build-notes/m3-plan/plan-r2.md [8.1] with
-- the lead's L1, L3, L6 and L16). Edge's inputs are built here as Analyze's phase 6 hands them over: the parts in the
-- measure's rank order (Sampling.measureRanked), kept indexed like them (Sampling.exposure), the difficulty frame on
-- them (MassProps.difficultyFrame); cutIndex on MassProps' bladeLength.
--   1 F5 and F1: one chain of 5.4330 from the +X base over the tip to the −X base, cell 0.02, cutIndex 0.724180
--   2 E-S2.9's edge and cutIndex columns (cutIndex to 6 decimals, L1; fix round 1's values); the prototype's edge in the
--     measure's rank order on every fixture whose verdict the build shares but those the off-centre samples and the
--     merged hidden gaps move (OFF_PROTOTYPE, whose edges T-DIF-12's goldens hold; P1's verdict is the build's own)
--   3 X04's 12 cases one chain of F5's length (TOL_EDGE_REL)   4 P5's comb: 11 chains
--   5 the rules: a thick blade has no edge, the EdgeLength cap case, hilt-buried cells, pommel-facing segments and the
--     gaps bridged, chains' points, lengths and total order, Douglas–Peucker on lattice points (exact: a point at tol
--     dropped, ties to the first), the merged chords (a gap the verdict hides is no gap where the line crosses it from
--     one part to the next, however slantwise, and a corner beside a face, which the verdict shows, merges nothing:
--     hiddenGap, fix round 2; every shape's face normal; the window's edge crossed at a slant; the raster's run asks
--     the part that ends it: fix round 3; the window's edge against a face along the world axes; a chord inside the run
--     does not ask; each face's probe asked of the part across alone, so an open slot crossed at a grazing slant
--     between two hidden gaps stays open and a sword's edge over it one chain, and so do a V whose faces a third plate
--     hides and a seam beside a slanted crossing, §17.1 O11's residual: fix round 4, fix round 3's set withdrawn; a
--     probe past a turned block's box beside its edge, and both probes HIDE_OFFSET out either way along a line: M3's
--     review round 5), a cell RASTER_TOL from a face sampled inside it, cutIndex
--   6 invariance: a Y or Z shift keeps the raster (so cutIndex: T-DIF-07 (a)) and the outline, its chains, points' x
--     and lengths to the bit, the points' y moved by Δy (no sample lies on a face, and Douglas–Peucker runs on the
--     outline's integer lattice: L3's option (a), fix round 1): every shifted copy of F1–F5 and C01–C15, the critic's
--     Gen designs (TestRng 0x5EED0007 #89, 0x5EED0001 #131 at +0.2, which Douglas–Peucker in blueprint XY moved) and,
--     slow, FUZZ_N_VALID Gen designs; the X mirror keeps the raster, EdgeLength within TOL_EDGE_REL
--   5 also §4.6's boundaries built exactly: EDGE_MAX_THICK, EDGE_MAX_CELLS, a loop all eligible opened at its lowest
--     vertex (fix round 1)
--   7 budgets on P1; the ladder and the loops reach checkpoints (L6) and charge their own units, pinned by caller on
--     F5, F4 and P5 (fix round 1), the raster its hidden-gap tests too (three plates turned 30°: fix round 3); P-DET,
--     P-NOMUT, the list's order (L16)

local Test = require("../lib/Test")
local A = require("../lib/Assert")
local Dump = require("../lib/Dump")
local Gen = require("../lib/Gen")
local Prop = require("../lib/Prop")
local TestRng = require("../lib/TestRng")
local Tol = require("../lib/Tol")
local H = require("./PhysicsHelpers")
local Blueprints = require("../fixtures/Blueprints")
local Build = require("../fixtures/Build")
local Calibration = require("../fixtures/Calibration")
local Cost = require("../fixtures/Cost")
local Regression = require("../fixtures/Regression")
local Balance = require("../../src/shared/Definitions/Balance")
local EquipmentTypes = require("../../src/shared/Definitions/EquipmentTypes")
local Limits = require("../../src/shared/Definitions/Limits")
local Materials = require("../../src/shared/Definitions/Materials")
local Versions = require("../../src/shared/Definitions/Versions")
local Mirror = require("../../src/shared/Blueprint/Mirror")
local Edge = require("../../src/shared/Physics/Edge")
local MassProps = require("../../src/shared/Physics/MassProps")
local Sampling = require("../../src/shared/Physics/Sampling")
local Shapes = require("../../src/shared/Physics/Shapes")

-- Through a cast, so luau-lsp stays out of the prototype's loose types: it is reference data, not game code.
local Proto: any = (require :: any)("../../docs/spec/prototypes/S2/v2/analyze")
local Fixtures: any = (require :: any)("../../docs/spec/prototypes/S2/v2/fixtures")

type Prepared = Shapes.Prepared
type Rng = TestRng.TestRng
type EdgeProfile = Edge.EdgeProfile

local Geo = Balance.Geometry
local SWORD = EquipmentTypes.get("Sword") :: any
local GEOMETRY = SWORD.geometry
local CTX = Gen.context(Limits, SWORD, Materials.enabled, Versions.BLUEPRINT_SCHEMA, Geo)
local ABS = 1e-12

-- E-S2.10's six offsets (v2/run.luau): three along Y, two along Z, one along both.
local OFFSETS: { { number } } = { { 0, 0.013, 0 }, { 0, 0.125, 0 }, { 0, 0.3317, 0 }, { 0, 0, 0.01 }, { 0, 0, -0.037 },
	{ 0, 0.2, 0.05 } }

-- The prototype's fixtures whose edge is not the prototype's since fix round 1 (docs/build/M3-notes.md): each cell is
-- sampled off its centre (§4.6), so the cells the prototype's centres decided by rounding (a face, or a face RASTER_TOL
-- off, through the centre) read as the geometry has them, and chords merge across the gaps the verdict hides (P3).
-- Douglas–Peucker on the integer lattice moves none of the others beyond 1e-12 (their lengths' last bits only).
-- T-DIF-12's goldens hold these edges; every other fixture's is the prototype's to the bit.
local OFF_PROTOTYPE: { [string]: string } = {
	["C04 Rapier (Steel blade)"] = "outline: the cells RASTER_TOL off the blade's faces at ±0.045, which rounding left "
		.. "out, are in: EdgeLength +0.0420",
	["C05 Cleaver"] = "raster: 3 cells fewer, mean thickness 0.1490 → 0.1477",
	["C06 Sabre (Steel)"] = "raster: 5 cells more; outline: EdgeLength −0.0002",
	["C09 Ornate (18 parts)"] = "raster: no plain chord on its bevels' sharp edges, mean thickness 0.0433 → 0.0440",
	["C15 Arming rotated 4 deg about Z at the grip"] = "raster: 5 cells more; outline: EdgeLength −0.0001",
	["F4 Cleaver"] = "raster: 4 cells fewer",
	["X03 F4 + 0.0003 st3 fin"] = "raster: 1 cell more",
	["X07c 4 segments overlapping 0.07"] = "raster: the mean thickness",
	["P2 24 rotated cylinders"] = "raster: 14 cells more; 15 chains as the prototype, EdgeLength 1.3153 → 1.2325",
	["P3 24 rotated wedges"] = "raster: 14 cells more; the merged hidden gaps",
	["P4 24 overlapping balls"] = "raster: 10 cells more; 6 chains as the prototype, EdgeLength 2.2176 → 2.2742",
	["P5 comb blade (sawtooth, 24 parts)"] = "raster: 12 cells more",
}

-- [7.1]'s EdgeLength (4 decimals) and L1's cutIndex (6 decimals), F1–F5 and C01–C15 (E-S2.9), as fix round 1 moved them:
-- C04 7.1067 → 7.1487, C05's cutIndex 0.158369 → 0.161483, C06 6.4797 → 6.4795, C15 5.6261 → 5.6260.
local COLUMNS: { { id: string, edge: number, cut: number } } = {
	{ id = "F1", edge = 5.4330, cut = 0.724180 }, { id = "F2", edge = 4.9803, cut = 0.425000 },
	{ id = "F3", edge = 7.4089, cut = 1 }, { id = "F4", edge = 5.7237, cut = 0.134375 },
	{ id = "F5", edge = 5.4330, cut = 0.724180 }, { id = "C01", edge = 5.0602, cut = 0.300000 },
	{ id = "C02", edge = 5.6435, cut = 0.766667 }, { id = "C02s", edge = 5.6435, cut = 0.766667 },
	{ id = "C04", edge = 7.1487, cut = 1 }, { id = "C05", edge = 5.9721, cut = 0.161483 },
	{ id = "C06", edge = 6.4795, cut = 0.890676 }, { id = "C07", edge = 2.9683, cut = 0.313333 },
	{ id = "C08", edge = 6.3917, cut = 0.617500 }, { id = "C09", edge = 5.4113, cut = 1 },
	{ id = "C10", edge = 4.9802, cut = 0.271528 }, { id = "C11", edge = 5.0202, cut = 0.271528 },
	{ id = "C12", edge = 5.6435, cut = 0.766667 }, { id = "C13", edge = 5.6435, cut = 0.765380 },
	{ id = "C14", edge = 5.6435, cut = 0.766667 }, { id = "C15", edge = 5.6260, cut = 0.766667 },
}

local function coreOf(id: string): any
	if string.sub(id, 1, 1) == "F" then
		return Blueprints.get(id).core
	end
	return Calibration.get(id).core
end

-- Edge's inputs: the parts in the measure's rank order, kept indexed like them, the difficulty frame on them.
local function inputs(core: any): ({ Prepared }, { boolean }, { number }, { number })
	local parts = H.prepared(core)
	local kept = Sampling.exposure(parts).kept
	local _, byRank = Sampling.measureRanked(parts)
	local keptByRank: { boolean } = table.create(#byRank, false)
	for r, p in ipairs(byRank) do
		keptByRank[r] = kept[p.index]
	end
	local point, axis = MassProps.difficultyFrame(byRank, keptByRank, GEOMETRY.gripSlot)
	return byRank, keptByRank, point, axis
end

local function edgeOf(core: any, spend: Sampling.Spend?): (EdgeProfile, Edge.RasterStats)
	local list, kept, point, axis = inputs(core)
	return Edge.profile(list, kept, GEOMETRY, point, axis, spend)
end

-- Every part kept, in the order given: a raster of any parts, no verdict.
local function edgeOfAll(parts: { any }): EdgeProfile
	local list = H.prepared(Build.core("parts", parts))
	return (Edge.profile(list, table.create(#list, true), GEOMETRY, { 0, 0, 0 }, { 0, 1 }))
end

local function cutIndexOf(core: any, e: EdgeProfile): number
	return Edge.cutIndex(H.measure(core).bladeLength, e.bladeMeanThickness)
end

-- A prototype blueprint with its parts in the measure's rank order, ids kept (Reference.spec's inRankOrder).
local function inRankOrder(b: any): any
	local list: { Prepared } = {}
	for i, part in ipairs(b.parts) do
		list[i] = Shapes.prepare(part, i)
	end
	local _, order = Sampling.measureRanked(list)
	local parts: { any } = {}
	for r, p in ipairs(order) do
		parts[r] = b.parts[p.index]
	end
	return { name = b.name, parts = parts }
end

-- Two edges differ: a chain, a point, a length or the raster (cell, bladeArea, mean thickness) beyond tol.
local function edgesDiffer(a: EdgeProfile, b: any, tol: number): boolean
	if #a.chains ~= #b.chains or math.abs(a.length - b.length) > tol or a.cell ~= b.cell
		or math.abs(a.bladeArea - b.bladeArea) > tol or math.abs(a.bladeMeanThickness - b.bladeMeanThickness) > tol
	then
		return true
	end
	for k, c in ipairs(a.chains) do
		local d = b.chains[k]
		if #c.points ~= #d.points or math.abs(c.length - d.length) > tol then
			return true
		end
		for q, p in ipairs(c.points) do
			if math.abs(p[1] - d.points[q][1]) > tol or math.abs(p[2] - d.points[q][2]) > tol then
				return true
			end
		end
	end
	return false
end

-- Two edges agree: chains, points and lengths within tol, the raster (cell, bladeArea, mean thickness) within ABS.
local function sameEdge(a: EdgeProfile, b: any, tol: number, what: string)
	A.eq(#a.chains, #b.chains, what .. " chains")
	A.near(a.length, b.length, tol, what .. " length")
	A.eq(a.cell, b.cell, what .. " cell")
	A.near(a.bladeArea, b.bladeArea, ABS, what .. " bladeArea")
	A.near(a.bladeMeanThickness, b.bladeMeanThickness, ABS, what .. " bladeMeanThickness")
	for k, c in ipairs(a.chains) do
		local d = b.chains[k]
		A.near(c.length, d.length, tol, what .. " chain " .. k .. " length")
		A.eq(#c.points, #d.points, what .. " chain " .. k .. " points")
		for q, p in ipairs(c.points) do
			A.near(p[1], d.points[q][1], tol, what .. " chain " .. k .. " x" .. q)
			A.near(p[2], d.points[q][2], tol, what .. " chain " .. k .. " y" .. q)
		end
	end
end

-- The build's edge against the prototype's in the measure's rank order: the same, or, for OFF_PROTOTYPE, not.
local function againstPrototype(b: any)
	local core: any = { schema = 1, name = b.name, type = "Sword", parts = b.parts }
	local theirs = Proto.run(inRankOrder(b), { measureInvalid = true })
	if OFF_PROTOTYPE[b.name] then
		A.truthy(edgesDiffer(edgeOf(core), theirs.edge, ABS), b.name .. ": listed off the prototype, but its edge is the "
			.. "prototype's (" .. OFF_PROTOTYPE[b.name] .. ")")
	else
		sameEdge(edgeOf(core), theirs.edge, ABS, b.name)
	end
end

-- §4.6's output: at most EDGE_MAX_POINTS points, at least EDGE_MIN_CHAIN cells long, the length its segments' sum,
-- longest first, then by the first point's x and y; length = the main chain's.
local function wellFormed(e: EdgeProfile, what: string)
	A.eq(e.length, if #e.chains > 0 then e.chains[1].length else 0, what .. " length = the main chain's")
	for k, c in ipairs(e.chains) do
		A.truthy(#c.points >= 2 and #c.points <= Geo.EDGE_MAX_POINTS, what .. " chain " .. k .. " points")
		A.truthy(c.length >= Geo.EDGE_MIN_CHAIN * e.cell - ABS, what .. " chain " .. k .. " long enough")
		local sum = 0
		for q = 2, #c.points do
			local dx, dy = c.points[q][1] - c.points[q - 1][1], c.points[q][2] - c.points[q - 1][2]
			sum += math.sqrt(dx * dx + dy * dy)
		end
		A.near(sum, c.length, 1e-9, what .. " chain " .. k .. " length = its segments")
		if k > 1 then
			local a, b = e.chains[k - 1], c
			local ordered = a.length > b.length or (a.length == b.length and (a.points[1][1] < b.points[1][1]
				or (a.points[1][1] == b.points[1][1] and a.points[1][2] <= b.points[1][2])))
			A.truthy(ordered, what .. " chains " .. (k - 1) .. ", " .. k .. " in order")
		end
	end
end

local function moved(core: any, d: { number }): any
	local out = Build.copy(core)
	for _, p in out.parts do
		p.pos = { p.pos[1] + d[1], p.pos[2] + d[2], p.pos[3] + d[3] }
	end
	return out
end

-- Every part reflected in the plane x = 0 (Blueprint/Mirror), ids kept.
local function mirrored(core: any): any
	local out = Build.copy(core)
	for i, p in core.parts do
		out.parts[i] = Mirror.reflect(p, "X")
	end
	return out
end

-- The raster under a translation: its cells kept (the cell size and bladeArea to the bit), the mean thickness within
-- 1e-12 (a turned part's chords carry the shifted rounding).
local function rasterAlike(a: EdgeProfile, b: EdgeProfile, what: string)
	A.eq(b.cell, a.cell, what .. " cell")
	A.eq(b.bladeArea, a.bladeArea, what .. " bladeArea")
	A.near(b.bladeMeanThickness, a.bladeMeanThickness, ABS, what .. " bladeMeanThickness")
end

-- The outline under a translation: the lattice is kept, so the chains, their points' x and their lengths to the bit
-- (Douglas–Peucker compares integers); Y moves the points' y by Δy (within 1e-9), a pure Z shift keeps them to the bit.
local function outlineAlike(a: EdgeProfile, b: EdgeProfile, d: { number }, what: string)
	A.eq(#b.chains, #a.chains, what .. " chains")
	A.eq(b.length, a.length, what .. " length")
	for k, c in ipairs(a.chains) do
		local e = b.chains[k]
		A.eq(e.length, c.length, what .. " chain " .. k)
		A.eq(#e.points, #c.points, what .. " chain " .. k .. " points")
		for q, p in ipairs(c.points) do
			A.eq(e.points[q][1], p[1], what .. " chain " .. k .. " x" .. q)
			if d[2] == 0 then
				A.eq(e.points[q][2], p[2], what .. " chain " .. k .. " y" .. q)
			else
				A.near(e.points[q][2], p[2] + d[2], 1e-9, what .. " chain " .. k .. " y" .. q)
			end
		end
	end
end

local function translatedAlike(a: EdgeProfile, b: EdgeProfile, d: { number }, what: string)
	rasterAlike(a, b, what)
	outlineAlike(a, b, d, what)
end

local function relative(a: number, b: number): number
	return if a > 0 then math.abs(b - a) / a else math.abs(b - a)
end

-- On a Gen design: Y alone and Z alone keep the raster and the outline (translatedAlike), the X mirror image the raster
-- and EdgeLength within TOL_EDGE_REL. Returns the mirror's relative EdgeLength change.
local function genInvariance(core: any, delta: { number }, what: string): number
	local base = edgeOf(core)
	wellFormed(base, what)
	translatedAlike(base, edgeOf(Gen.translate(core, delta[2], 0)), { 0, delta[2], 0 }, what .. " Y")
	translatedAlike(base, edgeOf(Gen.translate(core, 0, delta[3])), { 0, 0, delta[3] }, what .. " Z")
	local m = edgeOf(mirrored(core))
	A.near(m.bladeArea, base.bladeArea, ABS, what .. " mirror: bladeArea")
	A.near(m.bladeMeanThickness, base.bladeMeanThickness, ABS, what .. " mirror: bladeMeanThickness")
	local relM = relative(base.length, m.length)
	A.truthy(relM <= Tol.TOL_EDGE_REL, string.format("%s mirror: EdgeLength %.6f → %.6f", what, base.length, m.length))
	return relM
end

local function genCorpus(n: number)
	local worstM = 0
	Prop.check(n, function(rng: Rng): any
		local core = Gen.validSword(rng, CTX)
		local _, delta = Gen.translated(rng, CTX, core)
		return { core = core, delta = delta }
	end, function(c: any)
		worstM = math.max(worstM, genInvariance(c.core, c.delta, "Gen"))
	end)
	A.truthy(worstM <= Tol.TOL_EDGE_REL, string.format("worst mirror %.4g", worstM))
end

-- The designs the critic found (plan_r2_critique_result.json, major 3): TestRng 0x5EED0007's #89, moved by its own
-- translated draw, and 0x5EED0001's #131 by E-S2.10's (0, 0.2, 0.05), each axis alone; along Y Douglas–Peucker in
-- blueprint XY tipped their outlines (6.696057 → 6.691727, and 6.413334 over 10 points → 6.389542 over 8).
local function criticDesign(seed: number, n: number, drawDelta: boolean): (any, { number })
	local rng = TestRng.new(seed)
	local core: any, delta: { number } = nil, { 0, 0, 0 }
	for _ = 1, n do
		core = Gen.validSword(rng, CTX)
		if drawDelta then
			local _, d = Gen.translated(rng, CTX, core)
			delta = d
		end
	end
	return core, delta
end

-- Two plates 0.16 × 2.6 × 0.024 turned 30° about Y, g apart along their normal (sin 30°, 0, cos 30°), and where the Z
-- line through x = 0, y = 2.68 leaves the lower one (e) and meets the upper one (f), g/cos 30° further.
local function turnedPair(g: number): (Prepared, Prepared, number, number)
	local turned = H.axisAngle(0, 1, 0, 30)
	local t = 0.024
	local d = g + t -- centre to centre along the normal
	local P = H.prepare(Build.part(1, "Blade", "Block", "Iron", { 0, 2.68, 0 }, turned, { 0.16, 2.6, t }), 1)
	local Q = H.prepare(Build.part(2, "Blade", "Block", "Iron", { 0.5 * d, 2.68, 0.8660254037844386 * d }, turned,
		{ 0.16, 2.6, t }), 2)
	local _, _, e = Shapes.chord(P, 0, 2.68, 0, 0, 0, 1)
	local _, f = Shapes.chord(Q, 0, 2.68, 0, 0, 0, 1)
	return P, Q, e, f
end

-- A plate's top face at z = 0 and a square rod turned 45° about its length, its lower edge 0.002 over the face at
-- x = 0.03; and a point (x, z) on the rod's flank 0.0119 up.
local function rodOverPlate(): (Prepared, Prepared, number, number)
	local plate = H.prepare(Build.part(1, "Blade", "Block", "Iron", { 0, 2.68, -0.03 }, Build.I, { 0.16, 2.6, 0.06 }), 1)
	local half = 0.03 * math.sqrt(2)
	local rod = H.prepare(Build.part(2, "Blade", "Block", "Iron", { 0.03, 2.68, 0.002 + half }, H.axisAngle(0, 1, 0, 45),
		{ 0.06, 2.6, 0.06 }), 2)
	return plate, rod, 0.03 + 0.0099, 0.0119
end

-- Plates p and q whose faces, turned ap and aq off the Z line x = 0.1, y = 2.68, make a shallow V that the line
-- crosses along its length, leaving p at z = 0 and meeting q at z = len, and a plate r on the V's open side, its face
-- 0.0102 off the line, holding both faces' probes: a channel beside a third part, len·sin a across at each point, which
-- the verdict shows in its middle (between q and r 0.0123 across, 0.0154 at the apex, for 10°, 10° and 0.06).
local function vee(ap: number, aq: number, len: number): (Prepared, Prepared, Prepared)
	local sp, cp = math.sin(math.rad(ap)), math.cos(math.rad(ap))
	local sq, cq = math.sin(math.rad(aq)), math.cos(math.rad(aq))
	local p = H.prepare(Build.part(1, "Blade", "Block", "Iron", { 0.1 + 0.02 * cp, 2.68, -0.02 * sp },
		H.axisAngle(0, 1, 0, ap), { 0.04, 0.5, 0.06 }), 1)
	local q = H.prepare(Build.part(2, "Blade", "Block", "Iron", { 0.1 + 0.02 * cq, 2.68, len + 0.02 * sq },
		H.axisAngle(0, 1, 0, -aq), { 0.04, 0.5, 0.06 }), 2)
	local r = H.prepare(Build.part(3, "Blade", "Block", "Iron", { 0.1 - 0.0102 - 0.015, 2.68, len / 2 }, Build.I,
		{ 0.03, 0.5, len + 0.12 }), 3)
	return p, q, r
end

-- Four slabs 0.021 thick, 0.5 long in Y, their faces 3° off the Z line x = 0.0016, y = 2.68 (local z (cos 3°, 0, sin
-- 3°), local x u (sin 3°, 0, −cos 3°)): p (h −0.021 … 0) and r 0.012 over it, u 0 … 0.051; r' and q, 0.0119 over p's
-- top plane, from u = −c down to where the line meets q's face and 0.021 past it. The line leaves p's top face at u =
-- 0.03 under r, rises 0.0119 over 0.227 along Z and meets q's bottom face over r': each face's probe lands in the slab
-- beside, each point 0.0119 across from the other's face. With c = 0 the two slits are one channel; with c = 0.15 an
-- open slot 0.15 long lies between them, which the verdict shows (its end faces' probes land in air). V1's (M3's review
-- round 4).
local function slot(c: number): ({ Prepared }, number, number)
	local sb, cb = math.sin(math.rad(3)), math.cos(math.rad(3))
	local s, t = 0.0119, 0.021
	local ue = 0.03
	local uf = ue - s * cb / sb
	local turned = H.axisAngle(0, 1, 0, 87)
	local function slab(id: number, u0: number, u1: number, h0: number, h1: number): Prepared
		local u, h = (u0 + u1) / 2, (h0 + h1) / 2
		return H.prepare(Build.part(id, "Blade", "Block", "Iron", { u * sb + h * cb, 2.68, -u * cb + h * sb }, turned,
			{ u1 - u0, 0.5, h1 - h0 }), id)
	end
	local list = {
		slab(1, 0, ue + t, -t, 0), -- p
		slab(2, 0, ue + t, 0.012, 0.012 + t), -- r
		slab(3, uf - t, -c, s - 0.012 - t, s - 0.012), -- r'
		slab(4, uf - t, -c, s, s + t), -- q
	}
	local _, _, e = Shapes.chord(list[1], ue * sb, 2.68, 0, 0, 0, 1)
	local _, f = Shapes.chord(list[4], ue * sb, 2.68, 0, 0, 0, 1)
	return list, e, f
end

-- F5 without its tip, the open slot of slot() 0.4 long (y 3.98 … 4.38) over its blade, crossed by the raster's column
-- x = 0.0087, and two Blade bridges 0.025 × 0.04 × 0.24 tying r' and q to the blade (V1's slot sword, M3's review
-- round 4). Valid, nothing cleaned.
local function slotSword(): any
	local sb, cb = math.sin(math.rad(3)), math.cos(math.rad(3))
	local s, t, ue, c = 0.0119, 0.021, 0.03, 0.15
	local uf = ue - s * cb / sb
	local xoff = 0.0087 - ue * sb
	local turned = H.axisAngle(0, 1, 0, 87)
	local parts = Build.copy(Blueprints.get("F5").core).parts
	table.remove(parts, 5)
	local function slab(id: number, u0: number, u1: number, h0: number, h1: number)
		local u, h = (u0 + u1) / 2, (h0 + h1) / 2
		table.insert(parts, Build.part(id, "Blade", "Block", "Iron", { xoff + u * sb + h * cb, 4.18, 0.03 - u * cb + h * sb },
			turned, { u1 - u0, 0.4, h1 - h0 }))
	end
	slab(11, 0, ue + t, -t, 0)
	slab(12, 0, ue + t, 0.012, 0.012 + t)
	slab(13, uf - t, -c, s - 0.012 - t, s - 0.012)
	slab(14, uf - t, -c, s, s + t)
	table.insert(parts, Build.part(15, "Blade", "Block", "Iron", { 0.0087 + 0.036, 4, 0.13 }, Build.I,
		{ 0.025, 0.04, 0.24 }))
	table.insert(parts, Build.part(16, "Blade", "Block", "Iron", { 0.0087 - 0.047, 4, 0.13 }, Build.I,
		{ 0.025, 0.04, 0.24 }))
	return Build.core("slot sword", parts)
end

return Test.suite("Physics/Edge", function(t)
	t.it("T-EDG-01 1 F5 and F1: one chain of 5.4330 from the +X base over the tip to the −X base, cell 0.02", function()
		for _, id in { "F5", "F1" } do
			local core = Blueprints.get(id).core
			local e = edgeOf(core)
			A.eq(#e.chains, 1, id .. " one chain")
			local c = e.chains[1]
			A.near(c.length, 5.4330, 5e-5, id .. " EdgeLength")
			A.eq(#c.points, 5, id .. " points")
			A.near(c.points[1][1], 0.080, ABS, id .. " first x")
			A.near(c.points[1][2], 1.380, ABS, id .. " first y")
			A.near(c.points[5][1], -0.080, ABS, id .. " last x")
			A.near(c.points[5][2], 1.380, ABS, id .. " last y")
			A.truthy(c.points[3][2] > 4 and math.abs(c.points[3][1]) < Geo.EDGE_CELL, id .. " over the tip")
			A.eq(e.cell, Geo.EDGE_CELL, id .. " cell")
			A.near(cutIndexOf(core, e), 0.724180, 1e-6, id .. " cutIndex")
			local list, kept, point = inputs(core)
			A.deepEq(e.gripPoint, point, id .. " the difficulty frame's point")
			A.deepEq(e.gripAxis, { 0, 1 }, id .. " axis fixed at +Y")
			A.truthy(#list == 5 and kept[1], id)
		end
	end)

	t.it("T-EDG-01 2 E-S2.9's edge and cutIndex columns: EdgeLength within 5e-5, cutIndex within 1e-6 (L1)", function()
		for _, row in COLUMNS do
			local core = coreOf(row.id)
			local e = edgeOf(core)
			A.near(e.length, row.edge, 5e-5, row.id .. " EdgeLength")
			A.near(cutIndexOf(core, e), row.cut, 1e-6, row.id .. " cutIndex")
			wellFormed(e, row.id)
		end
	end)

	t.it("T-EDG-01 2 the prototype's edge in the measure's rank order: S2's calibration and golden fixtures, but "
		.. "OFF_PROTOTYPE", function()
		for _, b in ipairs(Fixtures.calibration()) do
			againstPrototype(b)
		end
		for _, b in ipairs(Fixtures.golden()) do
			againstPrototype(b)
		end
	end)

	t.it("T-EDG-01 2 the prototype's edge in the measure's rank order: A25–A27, X01–X07 and their bases, P2–P5, but "
		.. "OFF_PROTOTYPE", function()
		local list: { any } = {}
		local listed: { [any]: boolean } = {}
		local function add(b: any)
			if not listed[b] then
				listed[b] = true
				table.insert(list, b)
			end
		end
		for _, a in ipairs(Fixtures.adversarial()) do
			add(a.base)
			add(a.fixture)
		end
		for _, r in ipairs(Fixtures.regression()) do
			add(r.base)
			add(r.fixture)
		end
		for i, b in ipairs(Fixtures.perf()) do
			if i > 1 then
				table.insert(list, b)
			end
		end
		for _, b in ipairs(list) do
			againstPrototype(b)
		end
		-- every OFF_PROTOTYPE row names a prototype fixture, so none outlives its fixture
		local names: { [string]: boolean } = {}
		for _, group in { Fixtures.calibration(), Fixtures.golden(), list } do
			for _, b in ipairs(group) do
				names[b.name] = true
			end
		end
		for _, row in { "C04 Rapier (Steel blade)", "C05 Cleaver", "C06 Sabre (Steel)", "C09 Ornate (18 parts)",
			"C15 Arming rotated 4 deg about Z at the grip", "F4 Cleaver", "X03 F4 + 0.0003 st3 fin",
			"X07c 4 segments overlapping 0.07", "P2 24 rotated cylinders", "P3 24 rotated wedges", "P4 24 overlapping balls",
			"P5 comb blade (sawtooth, 24 parts)" } do
			A.truthy(names[row] and OFF_PROTOTYPE[row] ~= nil, row .. ": a prototype fixture, listed")
		end
		-- P1 keeps two blocks the prototype cleans (Reference.spec's OWN_VERDICT): its edge is the build's own. The centred
		-- raster's one chain of 0.1897 became two with fix round 1's samples (a three-point chain of 0.2286 the main), and
		-- four with the lattice: that chain's middle point lies exactly a cell from its segment (dropped: 0.18), and
		-- three chains of exactly EDGE_MIN_CHAIN cells, 0.18, are kept (blueprint XY measured them 0.17999999999999972)
		local p1 = edgeOf(Cost.get("P1").core)
		A.eq(#p1.chains, 4, "P1 chains")
		A.near(p1.length, 0.1897, 5e-5, "P1 EdgeLength")
		for k = 2, 4 do
			A.eq(p1.chains[k].length, Geo.EDGE_MIN_CHAIN * p1.cell, "P1 chain " .. k .. ": exactly EDGE_MIN_CHAIN cells")
		end
		wellFormed(p1, "P1")
		-- P2's physics frame is the build's (§4.5: a grip part past 45° has no vote): axis −45°, bladeLength 2.1073, so its
		-- cutIndex is 0 where the prototype's frame gives 0.0225 (L7)
		local p2 = Cost.get("P2").core
		local physics = H.measure(p2)
		A.near(physics.gripAxis[1], -0.707107, 1e-6, "P2's grip axis")
		A.near(physics.bladeLength, 2.1073, 5e-5, "P2's blade length")
		A.eq(cutIndexOf(p2, (edgeOf(p2))), 0, "P2's cutIndex")
	end)

	t.it("T-EDG-01 3 X04's 12 cases: one chain each, F5's EdgeLength within TOL_EDGE_REL", function()
		local f5 = edgeOf(Blueprints.get("F5").core).length
		local n = 0
		for _, f in Regression.list do
			if string.sub(f.id, 1, 3) == "X04" then
				n += 1
				local e = edgeOf(f.core)
				A.eq(#e.chains, 1, f.id .. " one chain")
				A.truthy(relative(f5, e.length) <= Tol.TOL_EDGE_REL, string.format("%s EdgeLength %.6f", f.id, e.length))
				A.near(e.length, 5.4330, 5e-5, f.id .. " EdgeLength (measured 0.00 %)")
			end
		end
		A.eq(n, 12, "X04's cases")
	end)

	t.it("T-EDG-01 4 P5's comb: 11 chains, the main one 1.6777", function()
		local e = edgeOf(Cost.get("P5").core)
		local want = { 1.678, 0.552, 0.552, 0.541, 0.541, 0.532, 0.532, 0.521, 0.521, 0.170, 0.170 }
		A.eq(#e.chains, #want, "chains")
		for k, length in want do
			A.near(e.chains[k].length, length, 5e-4, "chain " .. k)
		end
		A.near(e.length, 1.6777, 5e-5, "EdgeLength")
		wellFormed(e, "P5")
	end)

	t.it("T-EDG-01 5 a blade thicker than EDGE_MAX_THICK has no edge; the cap case measures 8.2001", function()
		local thick = Blueprints.core("F2")
		thick.parts[4].size = { 0.20, 2.40, 0.30 }
		local e = edgeOf(thick)
		A.eq(#e.chains, 0, "a 0.30 blade: no chain")
		A.eq(e.length, 0, "EdgeLength")
		A.near(e.bladeMeanThickness, 0.30, 1e-9, "the raster still measures it")
		-- F2's hilt with a 1.4 × 3.43 × 0.06 blade standing on the guard, top 4.98: valid, past EdgeLength's range
		local cap = Blueprints.core("F2")
		cap.parts[4] = Build.part(4, "Blade", "Block", "Iron", { 0, 1.55 + 3.43 / 2, 0 }, Build.I, { 1.4, 3.43, 0.06 })
		A.truthy(Gen.margin(CTX, cap.parts) >= 0, "inside the hitbox")
		local c = edgeOf(cap)
		A.eq(#c.chains, 1, "one chain")
		A.near(c.length, 8.2001, 5e-5, "EdgeLength")
		A.truthy(c.length > 8.0, "past the reference range's top (T-DIF-01's cap)")
	end)

	-- §4.6's boundaries, each built exactly (M3's review: `<` for `≤` at either, or a loop opened at its lowest-rightmost
	-- vertex, passed the fast suite)
	t.it("T-EDG-01 5 the boundaries: a blade EDGE_MAX_THICK thick keeps its edge, one of EDGE_MAX_CELLS cells the first "
		.. "rung; a loop all eligible opens at its lowest vertex", function()
		local atMax = Blueprints.core("F2")
		atMax.parts[4].size = { 0.20, 2.40, Geo.EDGE_MAX_THICK }
		local e = edgeOf(atMax)
		A.eq(e.bladeMeanThickness, Geo.EDGE_MAX_THICK, "the blade's chords")
		A.eq(#e.chains, 1, "inner thickness ≤ EDGE_MAX_THICK: eligible, one chain")
		local function lone(pos: { number }, size: { number }): (EdgeProfile, Edge.RasterStats)
			local list = H.prepared(Build.core("lone", { Build.part(1, "Blade", "Block", "Iron", pos, Build.I, size) }))
			return Edge.profile(list, { true }, GEOMETRY, { 0, 0, 0 }, { 0, 1 })
		end
		local full, stats = lone({ 0, 1.0 + 3.92 / 2, 0 }, { 1.12, 3.92, 0.06 })
		A.eq(stats.cells, Geo.EDGE_MAX_CELLS, "a 1.12 × 3.92 blade: exactly EDGE_MAX_CELLS cells at EDGE_CELL")
		A.eq(full.cell, Geo.EDGE_CELL, "cells ≤ EDGE_MAX_CELLS: the first rung")
		A.eq((lone({ 0, 1.0 + 3.94 / 2, 0 }, { 1.12, 3.94, 0.06 })).cell, Geo.EDGE_CELL * Geo.H_LADDER[2],
			"a row more: the next rung")
		-- a lone blade 0.30 wide, off the plane x = 0: every edge of its loop is eligible, so the loop opens at its lowest
		-- vertex (lowest y, then lowest x), and Douglas–Peucker measures the run from there
		local off = lone({ 0.05, 2.68, 0 }, { 0.30, 2.60, 0.06 })
		A.eq(Dump.canonical(off.chains), "{[1]={length=5.4701916675182973,points={[1]={[1]=0.20000000000000001,[2]="
			.. "1.3900000000000001},[2]={[1]=0.19,[2]=3.9800000000000004},[3]={[1]=-0.10000000000000001,[2]=3.9699999999999998},"
			.. "[4]={[1]=-0.10000000000000001,[2]=1.3800000000000001}}}}", "its one chain")
	end)

	t.it("T-EDG-01 5 cells against a hilt cell are no edge; pommel-facing segments dropped, short such gaps bridged", function()
		local blade = Build.part(1, "Blade", "Block", "Iron", { 0, 2.68, 0 }, Build.I, { 0.16, 2.60, 0.06 })
		-- a lone blade: one chain up the +X side, over the top and down the −X side; its underside faces the pommel
		local lone = edgeOfAll({ blade })
		A.eq(#lone.chains, 1, "lone blade")
		local c = lone.chains[1]
		A.near(c.points[1][1], 0.08, ABS, "starts on the +X side")
		A.near(c.points[#c.points][1], -0.08, ABS, "ends on the −X side")
		for q = 2, #c.points do
			local dx, dy = c.points[q][1] - c.points[q - 1][1], c.points[q][2] - c.points[q - 1][2]
			A.truthy(-dx / math.sqrt(dx * dx + dy * dy) >= -Geo.EDGE_DOWN_COS, "segment " .. (q - 1) .. " faces away")
		end
		-- a Guard block flush against its +X side from y 2.0 to 2.4: those cells are buried and split the side
		local guarded = edgeOfAll({ blade, Build.part(2, "Guard", "Block", "Iron", { 0.13, 2.2, 0 }, Build.I,
			{ 0.10, 0.40, 0.06 }) })
		A.eq(#guarded.chains, 2, "the side splits at the hilt")
		A.near(guarded.chains[1].points[1][1], 0.08, ABS, "the main chain starts on the +X side")
		A.near(guarded.chains[1].points[1][2], 2.40, ABS, "above the hilt")
		local low = guarded.chains[2].points
		A.near(low[#low][2], 2.00, ABS, "the other ends below it")
		for _, ch in guarded.chains do
			for _, p in ch.points do
				A.falsy(p[1] > 0.075 and p[2] > 2.0 + ABS and p[2] < 2.4 - ABS, "no edge against the hilt")
			end
		end
		A.near(lone.length - guarded.chains[1].length - guarded.chains[2].length, 0.40, 1e-4, "the hilt's 0.40 is lost")
		-- an overhang: a blade 0.12 wide under one 0.12 + 2s wide; the overhang's underside faces the pommel
		local function overhang(s: number): EdgeProfile
			return edgeOfAll({
				Build.part(1, "Blade", "Block", "Iron", { 0, 2.03, 0 }, Build.I, { 0.12, 1.30, 0.06 }),
				Build.part(2, "Blade", "Block", "Iron", { 0, 3.33, 0 }, Build.I, { 0.12 + 2 * s, 1.30, 0.06 }),
			})
		end
		A.eq(#overhang(0.04).chains, 1, "a 0.04 underside, under EDGE_GAP_BRIDGE cells: bridged")
		A.eq(#overhang(0.06).chains, 3, "a 0.06 underside: the sides break off below it")
	end)

	t.it("T-EDG-01 5 a gap the verdict hides is no gap; a cell RASTER_TOL off a face is sampled inside the dilation",
		function()
			-- F5's blade as two plates through its thickness, outer faces kept: a gap of 0.011 is hidden (§4.4: ≤
			-- HIDE_OFFSET + EPS_GEOM), so the chords merge into the 0.06 the blade has; at 0.0121 the faces show
			local function laminate(g: number): EdgeProfile
				local t, z = (0.06 - g) / 2, g / 2 + (0.06 - g) / 4
				return edgeOfAll({
					Build.part(1, "Blade", "Block", "Iron", { 0, 2.68, z }, Build.I, { 0.16, 2.60, t }),
					Build.part(2, "Blade", "Block", "Iron", { 0, 2.68, -z }, Build.I, { 0.16, 2.60, t }),
				})
			end
			A.near(laminate(0.011).bladeMeanThickness, 0.06, 1e-12, "a hidden gap: the chords merged")
			A.near(laminate(0.0121).bladeMeanThickness, 0.06 - 0.0121, 1e-12, "a gap that shows: the plates' metal")
			-- a blade 0.09 wide: its faces at ±0.045 lie RASTER_TOL from the cell centres ±0.05, which 0.045 + 0.005 left
			-- out by rounding; the samples, 0.0013 in, are within the dilation, so the outline runs at ±0.06 (C04's)
			local e = edgeOfAll({ Build.part(1, "Blade", "Block", "Iron", { 0, 2.68, 0 }, Build.I, { 0.09, 2.60, 0.06 }) })
			local c = e.chains[1]
			A.near(c.points[1][1], 0.06, ABS, "the +X side's outline")
			A.near(c.points[#c.points][1], -0.06, ABS, "the −X side's, its mirror")
			A.near(e.bladeArea, 4 * 0.02 * 0.02 * 130, 1e-12, "the plain cells: 4 a row")
		end)

	t.it("T-EDG-01 5 hidden gaps: a facing gap the line crosses at a slant merges as far as the verdict hides it; a "
		.. "corner beside a face, which the verdict shows, does not (V1's two-sided rule merged it)", function()
		local MG = Geo.HIDE_OFFSET + Geo.EPS_GEOM
		-- two plates turned 30° about Y, g apart along their normal: the Z line from the lower one's centre leaves its face
		-- at e and meets the upper one's at f, g/cos 30° apart along the line
		local P, Q, e, f = turnedPair(0.0105)
		local hidden, units = Edge.hiddenGap(P, 0, 2.68, e, Q, 0, 2.68, f)
		A.truthy(f - e > MG, "0.0105 across is " .. (f - e) .. " along Z, past MERGE_GAP")
		A.truthy(hidden, "0.0105 across: hidden")
		A.eq(units, 6, "both faces looked at: a normal, then the probe's box test and sd each")
		local P2, Q2, e2, f2 = turnedPair(0.0121)
		A.truthy(not (Edge.hiddenGap(P2, 0, 2.68, e2, Q2, 0, 2.68, f2)), "0.0121 across: the faces show")
		-- a plate's top face at z = 0 and a square rod turned 45° about its length, its lower edge 0.002 over the face at
		-- x = 0.03; e on the plate under the edge, f on the rod's flank 0.0119 up: each part lies within MERGE_GAP of the
		-- other's point, but the flank's probe, HIDE_OFFSET along its normal, lands 0.0034 over the plate: it shows
		local plate, rod, fx, fz = rodOverPlate()
		A.near(Shapes.sd(rod, fx, 2.68, fz), 0, 1e-12, "f lies on the rod's flank")
		A.truthy(Shapes.sd(rod, 0.03, 2.68, 0) <= MG and Shapes.sd(plate, fx, 2.68, fz) <= MG, "V1's two-sided test holds")
		A.truthy(not (Edge.hiddenGap(plate, 0.03, 2.68, 0, rod, fx, 2.68, fz)), "a corner beside a face: not hidden")
		A.eq(select(2, Edge.hiddenGap(plate, 0.03, 2.68, 0, rod, 0.03, 2.68, 0.05)), 1,
			"a point 0.05 across: the normal alone, no box test or sd")
	end)

	t.it("T-EDG-01 5 hidden gaps at the window's edge crossed at a slant, and the corner beside a face crossed from the "
		.. "rod's flank", function()
		-- 0.01200005 across: each face's probe lands 5e-8 short of the other plate, within EPS_GEOM, as the verdict reads
		-- it (REACH, HIDE_OFFSET + 2·EPS_GEOM, holds it); 0.0120002 across, they show (M3's review round 3: REACH =
		-- HIDE_OFFSET, or a probe's tolerance of 0, passed the suite)
		local P, Q, e, f = turnedPair(0.01200005)
		A.truthy(Edge.hiddenGap(P, 0, 2.68, e, Q, 0, 2.68, f), "0.01200005 across: hidden")
		P, Q, e, f = turnedPair(0.0120002)
		A.truthy(not (Edge.hiddenGap(P, 0, 2.68, e, Q, 0, 2.68, f)), "0.0120002 across: the faces show")
		-- from the rod's flank to the plate: the plate's probe lands in the rod, the flank's over the plate (a test that
		-- dropped the first face's probe passed the suite)
		local plate, rod, fx, fz = rodOverPlate()
		A.truthy(not (Edge.hiddenGap(rod, fx, 2.68, fz, plate, 0.03, 2.68, 0)), "the rod's flank to the plate: not hidden")
	end)

	t.it("T-EDG-01 5 hidden gaps on every shape's face: Block (−X, +Y), Wedge, CornerWedge (both slopes), Cylinder side "
		.. "and cap, Ball", function()
		-- a plate 0.0105 off the face along its outward normal hides the gap, 0.0125 off it shows: a normal of the wrong
		-- sign or of the wrong face sends a probe into the part itself (M3's review round 3: only a Block's +Z face and a
		-- Wedge's slope were exercised)
		local turn = H.axisAngle(1, 2, 3, 40)
		-- shape, size, a point of its surface and its outward normal, local
		local cases: { { any } } = {
			{ "Block", { 0.2, 0.1, 0.06 }, { -0.1, 0.01, 0.005 }, { -1, 0, 0 } },
			{ "Block", { 0.2, 0.1, 0.06 }, { 0.02, 0.05, 0.01 }, { 0, 1, 0 } },
			{ "Wedge", { 0.2, 0.1, 0.1 }, { 0.03, 0, 0 }, { 0, 0.05, -0.05 } },
			{ "CornerWedge", { 0.2, 0.1, 0.12 }, { 0, 0, -0.02 }, { -0.05, 0.1, 0 } },
			{ "CornerWedge", { 0.2, 0.1, 0.12 }, { 0.03, 0, 0 }, { 0, 0.06, 0.05 } },
			{ "Cylinder", { 0.4, 0.1, 0.1 }, { 0.05, 0.05 * 0.766044443118978, 0.05 * 0.6427876096865394 },
				{ 0, 0.766044443118978, 0.6427876096865394 } },
			{ "Cylinder", { 0.4, 0.1, 0.1 }, { 0.2, 0.01, -0.02 }, { 1, 0, 0 } },
			{ "Ball", { 0.1, 0.1, 0.1 }, { 0.05 * 0.48, 0.05 * 0.6, 0.05 * 0.64 }, { 0.48, 0.6, 0.64 } },
		}
		for k, c in cases do
			local p = H.prepare(Build.part(1, "Blade", c[1], "Iron", { 0, 2, 0 }, turn, c[2]), 1)
			local l = c[4]
			local m = math.sqrt(l[1] * l[1] + l[2] * l[2] + l[3] * l[3])
			local nx = (l[1] * p.ux + l[2] * p.vx + l[3] * p.wx) / m
			local ny = (l[1] * p.uy + l[2] * p.vy + l[3] * p.wy) / m
			local nz = (l[1] * p.uz + l[2] * p.vz + l[3] * p.wz) / m
			local ex, ey, ez = Shapes.toWorld(p, c[3][1], c[3][2], c[3][3])
			A.near(Shapes.sd(p, ex, ey, ez), 0, 1e-12, k .. ": e lies on the " .. c[1] .. "'s surface")
			-- a plate whose local Z is n: turned about Z × n by the angle between them
			local ax, ay = -ny, nx
			local s = math.sqrt(ax * ax + ay * ay)
			local rot = if s < 1e-12 then Build.I else H.axisAngle(ax / s, ay / s, 0, math.deg(math.acos(nz)))
			local function gap(g: number): boolean
				local c0 = g + 0.015
				local q = H.prepare(Build.part(2, "Blade", "Block", "Iron", { ex + c0 * nx, ey + c0 * ny, ez + c0 * nz }, rot,
					{ 0.2, 0.2, 0.03 }), 2)
				local fx, fy, fz = ex + g * nx, ey + g * ny, ez + g * nz
				A.near(Shapes.sd(q, fx, fy, fz), 0, 1e-12, k .. ": f lies on the plate's face")
				return (Edge.hiddenGap(p, ex, ey, ez, q, fx, fy, fz))
			end
			A.truthy(gap(0.0105), k .. " " .. c[1] .. ": a plate 0.0105 off along its normal hides the gap")
			A.truthy(not gap(0.0125), k .. " " .. c[1] .. ": 0.0125 off, the faces show")
		end
	end)

	t.it("T-EDG-01 5 hidden gaps where the faces are not parallel: f's probe goes along the normal of f's own face, and "
		.. "each probe HIDE_OFFSET out, as the verdict's", function()
		-- p a plate turned −20° about Y, its top face through e = (0.004, 2.68, 0); q a block whose lower face lies 0.003
		-- over z = 0 and whose +X face lies at x = 0, so that e lies nearer that face than the lower one. The line from e
		-- meets q's lower face at f: e's probe lands in q and f's, along −Z, in p: hidden. Along q's normal at e, +X, f's
		-- probe lands over p (M3's fix round 4: a mutant that took q's normal at e passed the suite)
		local s20, c20 = math.sin(math.rad(20)), math.cos(math.rad(20))
		local p = H.prepare(Build.part(1, "Blade", "Block", "Iron", { 0.004 + 0.015 * s20, 2.68, -0.015 * c20 },
			H.axisAngle(0, 1, 0, -20), { 0.1, 0.5, 0.03 }), 1)
		local q = H.prepare(Build.part(2, "Blade", "Block", "Iron", { -0.05, 2.68, 0.018 }, Build.I, { 0.1, 0.5, 0.03 }), 2)
		A.truthy(Shapes.sd(p, 0.002, 2.68, 0.003) > Geo.EPS_GEOM, "over p, 0.012 along +X from f")
		A.truthy((Edge.hiddenGap(p, 0.004, 2.68, 0, q, -0.010, 2.68, 0.003)), "q's lower face at f: hidden")
		-- p's top face at z = 0; q a plate turned −10° about Y, its lower face HIDE_OFFSET + 1.5·EPS_GEOM over e = (0, 2.68,
		-- 0) along Z and falling towards −X, where the line from e meets it at f: f's probe lands 0.0016 deep in p, e's
		-- 1.48e-7 short of q across, past EPS_GEOM: e's face shows, not hidden (a mutant whose probe went REACH out held it
		-- and passed the suite)
		local s10, c10 = math.sin(math.rad(10)), math.cos(math.rad(10))
		local g = Geo.HIDE_OFFSET + 1.5 * Geo.EPS_GEOM
		local plate = H.prepare(Build.part(1, "Blade", "Block", "Iron", { 0, 2.68, -0.015 }, Build.I, { 0.2, 0.5, 0.03 }), 1)
		local tilted = H.prepare(Build.part(2, "Blade", "Block", "Iron", { -0.01 * s10, 2.68, g + 0.01 * c10 },
			H.axisAngle(0, 1, 0, -10), { 0.1, 0.5, 0.02 }), 2)
		local l = math.sqrt(0.01 * 0.01 + 0.01024 * 0.01024)
		local ux, uz = -0.01 / l, 0.01024 / l
		local _, t0 = Shapes.chord(tilted, 0, 2.68, 0, ux, 0, uz)
		A.truthy(Shapes.sd(tilted, 0, 2.68, Geo.HIDE_OFFSET) > Geo.EPS_GEOM, "e's probe lies past EPS_GEOM of q")
		A.truthy(Shapes.sd(plate, t0 * ux + Geo.HIDE_OFFSET * s10, 2.68, t0 * uz - Geo.HIDE_OFFSET * c10) < -0.001,
			"f's probe lies in p")
		A.truthy(not (Edge.hiddenGap(plate, 0, 2.68, 0, tilted, t0 * ux, 2.68, t0 * uz)), "e's face shows: not hidden")
		-- the same line the other way, leaving q at f for p at e: f's probe, asked first now, lands in p, and e's, the
		-- second, goes HIDE_OFFSET out as the first does, 1.48e-7 short of q: not hidden (a mutant whose second probe went
		-- REACH out held it and passed the suite; M3's review round 5)
		A.truthy(not (Edge.hiddenGap(tilted, t0 * ux, 2.68, t0 * uz, plate, 0, 2.68, 0)), "from q to p: e's face shows, "
			.. "not hidden")
	end)

	t.it("T-EDG-01 5 hidden gaps asked of the part across alone: a seam beside a slanted crossing stays open (§17.1 "
		.. "O11), and so does a V whose faces a third plate hides, which the verdict shows in its middle", function()
		-- plates 0.024 thick turned 45° about Y, g apart along their normal: the Z line through the lower one's centre
		-- leaves it at local x −0.012 and meets the upper one at −0.0225, and the lower face's probe lands at −0.012. The
		-- upper plate cut flush at local x −0.020: the piece met lies past REACH of e and cannot hold the probe, which
		-- lands in the piece beside. The gap stays open: the seam beside a slanted crossing that §17.1 O11 names (F5's
		-- laminate turned 30° and 0.0105 apart, its far plate in 4 flush pieces, plays Hammering 0.3095 Hard against
		-- 0.1734 merged: Invariance.spec). Fix round 3 asked the piece beside too, as any part of the set, and so merged
		-- visible air (the open slot, below): withdrawn in fix round 4
		local turned = H.axisAngle(0, 1, 0, 45)
		local r = 0.70710678118654757
		local t0 = 0.024
		for _, g in { 0.0105, 0.01200005 } do
			local d = t0 + g -- centre to centre along the normal (r, 0, r)
			local function piece(id: number, a: number, b: number): Prepared
				local c = (a + b) / 2 -- along local x (r, 0, −r)
				return H.prepare(Build.part(id, "Blade", "Block", "Iron", { d * r + c * r, 2.68, d * r - c * r }, turned,
					{ b - a, 2.6, t0 }), id)
			end
			local lower = H.prepare(Build.part(1, "Blade", "Block", "Iron", { 0, 2.68, 0 }, turned, { 0.16, 2.6, t0 }), 1)
			local met, beside = piece(2, -0.08, -0.020), piece(3, -0.020, 0.08)
			local _, _, e = Shapes.chord(lower, 0, 2.68, 0, 0, 0, 1)
			local hit, f = Shapes.chord(met, 0, 2.68, 0, 0, 0, 1)
			A.truthy(hit and not Shapes.aabbContains(met, 0, 2.68, e, Geo.HIDE_OFFSET + 2 * Geo.EPS_GEOM),
				g .. " apart: the piece met lies past REACH of e (its box)")
			local px, pz = Geo.HIDE_OFFSET * r, e + Geo.HIDE_OFFSET * r -- the lower face's probe, along (r, 0, r)
			A.truthy(Shapes.sd(beside, px, 2.68, pz) <= Geo.EPS_GEOM, g .. " apart: the probe lies in the piece beside")
			local hidden, units = Edge.hiddenGap(lower, 0, 2.68, e, met, 0, 2.68, f)
			A.truthy(not hidden, g .. " apart: not hidden")
			A.eq(units, 2, g .. " apart: a normal and the piece met's box test")
		end
		-- a V of two plates whose faces, turned off the Z line, it crosses along their length, and a third plate on the
		-- V's open side holding both faces' probes: each probe lies in the third plate, not in the part across, so the V
		-- stays open, as the verdict shows its middle (fix round 3's set merged it at 0.0104 across at both points)
		for _, c in { { 15, 15, 0.04 }, { 10, 10, 0.06 }, { 15, 10, 0.06 }, { 10, 15, 0.06 } } do
			local p, q = vee(c[1], c[2], c[3])
			A.truthy(not (Edge.hiddenGap(p, 0.1, 2.68, 0, q, 0.1, 2.68, c[3])),
				string.format("%g° and %g° over %g: not hidden", c[1], c[2], c[3]))
		end
	end)

	t.it("T-EDG-01 5 hidden gaps: an open slot that the line crosses at a grazing slant between two hidden gaps, each "
		.. "face's probe in the slab beside it, stays open, and a sword's edge over it one chain", function()
		-- each probe lies in the slab beside the line and each point 0.0119 across from the other's face; asked of any part
		-- of the set (fix round 3), the slot merged, its column read ≈ 0.27 thick, past EDGE_MAX_THICK, and cut the
		-- sword's edge in two (Sharpening 0.2728 Hard → 0.0720 Normal; M3's review round 4). With c = 0 the two slits are
		-- one channel whose faces the slabs beside hide: open all the same, the seam beside a slanted crossing (§17.1 O11)
		local x = 0.03 * math.sin(math.rad(3))
		for _, c in { 0, 0.15 } do
			local list, e, f = slot(c)
			A.truthy(f - e > 0.2, "the crossing is " .. (f - e) .. " along Z")
			A.truthy(not (Edge.hiddenGap(list[1], x, 2.68, e, list[4], x, 2.68, f)), "c " .. c .. ": not hidden")
		end
		local e = edgeOf(slotSword())
		A.eq(#e.chains, 1, "the slot sword: one chain")
		A.near(e.length, 6.0851, 1e-4, "the slot sword's EdgeLength")
	end)

	t.it("T-EDG-01 5 hidden gaps at the window's edge against a part's face along a world axis: a probe 5e-8 short of "
		.. "it, outside its box, is held, and so is one past a turned block's box beside its edge", function()
		-- flat plates, the upper one's lower face 0.01200005 over the lower one's top, a line from e on the top face to f
		-- on the lower face 0.01 along X: each probe lands 5e-8 short of the other face, outside that part's box, within
		-- EPS_GEOM of it, as the verdict reads it; the box test's 2·EPS_GEOM holds it (M3's review round 4: a box test
		-- without it passed the suite)
		local g = 0.01200005
		local lower = H.prepare(Build.part(1, "Blade", "Block", "Iron", { 0, 2.68, -0.01 }, Build.I, { 0.16, 0.5, 0.02 }), 1)
		local upper = H.prepare(Build.part(2, "Blade", "Block", "Iron", { 0, 2.68, g + 0.01 }, Build.I, { 0.16, 0.5, 0.02 }),
			2)
		A.truthy(not Shapes.aabbContains(upper, 0, 2.68, Geo.HIDE_OFFSET, 0), "the probe lies outside the upper box")
		A.truthy((Edge.hiddenGap(lower, 0, 2.68, 0, upper, 0.01, 2.68, g)), "the part across holds the probe")
		-- the upper plate cut flush at x = 0.005: the line meets the piece on +x, the probe lands under the other: the
		-- seam beside the crossing, open (§17.1 O11)
		local met = H.prepare(Build.part(2, "Blade", "Block", "Iron", { 0.0425, 2.68, g + 0.01 }, Build.I,
			{ 0.075, 0.5, 0.02 }), 2)
		A.truthy(not (Edge.hiddenGap(lower, 0, 2.68, 0, met, 0.01, 2.68, g)), "the piece met: not hidden")
		-- a block turned 45° about Z, its lower face g over the lower plate's top: a Block's sd is the largest of its faces'
		-- terms, so beside its vertical edge it holds within EPS_GEOM points up to √2·EPS_GEOM past its box. e's probe
		-- lands 1.4·EPS_GEOM past the box's +X bound there, within EPS_GEOM by the sd, and the box test's 2·EPS_GEOM holds
		-- it, as the verdict's own test does (M3's review round 5: a box test with EPS_GEOM alone passed the suite)
		local turned = H.prepare(Build.part(2, "Blade", "Block", "Iron", { 0, 2.68, g + 0.01 }, H.axisAngle(0, 0, 1, 45),
			{ 0.04, 0.04, 0.02 }), 2)
		local ex = turned.maxx + 1.4 * Geo.EPS_GEOM
		A.truthy(not Shapes.aabbContains(turned, ex, 2.68, Geo.HIDE_OFFSET, Geo.EPS_GEOM)
			and Shapes.sd(turned, ex, 2.68, Geo.HIDE_OFFSET) <= Geo.EPS_GEOM, "the probe lies past the box, within EPS_GEOM")
		A.truthy((Edge.hiddenGap(lower, ex, 2.68, 0, turned, 0.005, 2.68, g)), "the turned block holds the probe")
	end)

	t.it("T-EDG-01 5 hidden gaps in the raster: the run's last part asks, through flush layers, after a gap that shows and "
		.. "in any order of the list", function()
		-- plates turned 30° about Y, 2.6 × 0.16 wide, at s along their normal: hidden 0.0105 apart (0.0121 along Z) the
		-- raster reads them as merged along Z at 0.0100; a run that kept its first part as the one asked, its last at a
		-- new run, or the parts out of step with their chords in the sort, read them apart (M3's review round 3)
		local nx, nz = 0.5, 0.8660254037844386 -- the plates' local z
		local turned = H.axisAngle(0, 1, 0, 30)
		local function profile(plates: { { number } }): number
			local list: { Prepared } = {}
			for k, p in plates do
				list[k] = H.prepare(Build.part(k, "Blade", "Block", "Iron", { p[1] * nx, 2.68, p[1] * nz }, turned,
					{ 0.16, p[3], p[2] }), k)
			end
			return (Edge.profile(list, table.create(#list, true), GEOMETRY, { 0, 0, 0 }, { 0, 1 })).bladeMeanThickness
		end
		-- { s, thickness, length } per plate
		local function cases(g: number): { { { number } } }
			local t2 = (0.06 - g) / 2
			local hi, lo = g / 2 + t2 / 2, -(g / 2 + t2 / 2)
			return {
				{ { lo, t2, 2.6 }, { hi, t2, 2.6 } }, -- the laminate
				{ { lo - t2 / 4, t2 / 2, 2.6 }, { lo + t2 / 4, t2 / 2, 2.6 }, { hi, t2, 2.6 } }, -- its lower plate in 2 layers
				{ { lo - t2 / 2 - 0.05 - 0.01, 0.02, 2.6 }, { lo, t2, 2.6 }, { hi, t2, 2.6 } }, -- a plate 0.05 below: shows
				{ { hi, t2, 2.62 }, { lo, t2, 2.6 } }, -- the upper plate first in the list
			}
		end
		local hidden, merged = cases(0.0105), cases(0.0100)
		for k = 1, #hidden do
			A.near(profile(hidden[k]), profile(merged[k]), 0.001,
				"case " .. k .. ": 0.0105 across (0.0121 along Z, hidden) reads as 0.0100 (merged along Z)")
		end
		-- a run of parts that are not parallel too (under fix round 3's set, parallel plates answered alike whichever of
		-- them was asked): a flat block (its top at z = 0), a Wedge on it whose slope rises 30° along −x, a plate 0.02
		-- thick g off the slope; and a flat plate 0.05 under the turned laminate, a run that shows, then a hidden gap
		local hy = 0.08 * 0.57735026918962573 -- the Wedge's half height, tan 30° × its half width
		local function sloped(g: number, order: { number }): number
			local s = g + 0.01 -- the plate's centre off the slope, along its normal (−sin 30°, 0, cos 30°)
			local parts = {
				Build.part(1, "Blade", "Block", "Iron", { 0, 2.68, -0.015 }, Build.I, { 0.16, 2.6, 0.03 }),
				Build.part(2, "Blade", "Wedge", "Iron", { 0, 2.68, hy }, { 0.5, 0.5, 0.5, 0.5 }, { 2.6, 2 * hy, 0.16 }),
				Build.part(3, "Blade", "Block", "Iron", { -0.5 * s, 2.68, hy + 0.8660254037844386 * s },
					H.axisAngle(0, 1, 0, -30), { 0.16, 2.6, 0.02 }),
			}
			local list: { Prepared } = {}
			for k, i in order do
				list[k] = H.prepare(parts[i], k)
			end
			return (Edge.profile(list, table.create(#list, true), GEOMETRY, { 0, 0, 0 }, { 0, 1 })).bladeMeanThickness
		end
		A.near(sloped(0.0105, { 1, 2, 3 }), sloped(0.0100, { 1, 2, 3 }), 0.001, "a Wedge's slope after a flush join")
		A.near(sloped(0.0105, { 2, 1, 3 }), sloped(0.0100, { 2, 1, 3 }), 0.001, "the Wedge first in the list")
		local function under(g: number): number
			local t2 = (0.06 - g) / 2
			local s = g / 2 + t2 / 2
			local list = {
				H.prepare(Build.part(1, "Blade", "Block", "Iron", { 0, 2.68, -0.08 }, Build.I, { 0.16, 2.6, 0.02 }), 1),
				H.prepare(Build.part(2, "Blade", "Block", "Iron", { -s * nx, 2.68, -s * nz }, turned, { 0.16, 2.6, t2 }), 2),
				H.prepare(Build.part(3, "Blade", "Block", "Iron", { s * nx, 2.68, s * nz }, turned, { 0.16, 2.6, t2 }), 3),
			}
			return (Edge.profile(list, { true, true, true }, GEOMETRY, { 0, 0, 0 }, { 0, 1 })).bladeMeanThickness
		end
		A.near(under(0.0105), under(0.0100), 0.001, "a flat plate under the laminate: a new run, then the hidden gap")
	end)

	t.it("T-EDG-01 5 hidden gaps in the raster: a chord inside the run, after its last part, does not ask", function()
		-- the turned laminate of the case above, 0.0105 apart, and a block 0.03 × 2.6 × 0.005 along the world axes at
		-- the lower plate's centre, inside it on every line through it: the run's last part is still the lower plate,
		-- whose face the line leaves (a run that handed the asking to every chord that joins, even one inside it, asked
		-- the block's +Z face: 0.0121 across, open; M3's review round 4)
		local nx, nz = 0.5, 0.8660254037844386
		local turned = H.axisAngle(0, 1, 0, 30)
		local function thickness(g: number, rivet: boolean): number
			local t2 = (0.06 - g) / 2
			local s = g / 2 + t2 / 2
			local list = {
				H.prepare(Build.part(1, "Blade", "Block", "Iron", { -s * nx, 2.68, -s * nz }, turned, { 0.16, 2.6, t2 }), 1),
				H.prepare(Build.part(2, "Blade", "Block", "Iron", { s * nx, 2.68, s * nz }, turned, { 0.16, 2.6, t2 }), 2),
			}
			if rivet then
				list[3] = H.prepare(Build.part(3, "Blade", "Block", "Iron", { -s * nx, 2.68, -s * nz }, Build.I,
					{ 0.03, 2.6, 0.005 }), 3)
			end
			return (Edge.profile(list, table.create(#list, true), GEOMETRY, { 0, 0, 0 }, { 0, 1 })).bladeMeanThickness
		end
		A.near(thickness(0.0105, true), thickness(0.0105, false), 1e-12, "the block inside changes nothing")
		A.near(thickness(0.0105, true), thickness(0.0100, true), 0.001, "0.0105 across reads as 0.0100")
	end)

	t.it("T-EDG-01 5 Douglas–Peucker, the merged chords and cutIndex", function()
		-- on lattice points, exactly: a straight run keeps its ends; a bump past tol is kept, one at tol is not; ties keep
		-- the first point; past either end of its segment a point measures from that end
		A.deepEq(Edge.simplify({ 0, 2, 4, 6 }, { 0, 0, 0, 0 }, 1), { 1, 4 }, "straight")
		A.deepEq(Edge.simplify({ 0, 2, 4, 6, 8 }, { 0, 0, 2, 0, 0 }, 1), { 1, 3, 5 }, "a bump of 2 > 1")
		A.deepEq(Edge.simplify({ 0, 2, 4 }, { 0, 1, 0 }, 1), { 1, 3 }, "a bump of exactly tol is dropped")
		A.deepEq(Edge.simplify({ 0, 1, 2, 3 }, { 0, 1, 1, 0 }, 0.5), { 1, 2, 4 }, "a tie keeps the first, which covers it")
		A.deepEq(Edge.simplify({ 0, 6, 4 }, { 0, 0, 0 }, 1), { 1, 2, 3 }, "past the end: 2 from it, kept")
		A.deepEq(Edge.simplify({ 0, -3, 4 }, { 0, 0, 0 }, 1), { 1, 2, 3 }, "past the start: 3 from it, kept")
		-- exact where blueprint XY rounds: (4002, 2999) lies exactly 2 from the segment to (8000, 6000) (cross 20,000 =
		-- 2 × its length 10,000); in studs at h 0.02 the float rule measured 0.020000000000003126 and kept it (so P1's
		-- outline and worst valid 3's, 9's and 10's kept points exactly a cell off: M3's fix round 1)
		A.deepEq(Edge.simplify({ 0, 4002, 8000 }, { 0, 2999, 6000 }, 2), { 1, 3 }, "exactly tol off a long diagonal")
		A.deepEq(Edge.simplify({ 0, 4003, 8000 }, { 0, 2998, 6000 }, 2), { 1, 2, 3 }, "a lattice step farther: kept")
		-- a closed run measures from its first point: the farthest is kept
		A.deepEq(Edge.simplify({ 0, 1, 2, 1, 0 }, { 0, 0, 1, 1, 0 }, 0.5), { 1, 3, 5 }, "closed: the farthest")
		local frozen = Build.freeze({ 0, 2, 4, 6, 8 })
		A.deepEq(Edge.simplify(frozen, Build.freeze({ 0, 0, 2, 0, 0 }), 1), { 1, 3, 5 }, "frozen input (P-NOMUT)")
		local units = 0
		Edge.simplify({ 0, 2, 4, 6, 8 }, { 0, 0, 2, 0, 0 }, 1, function(n: number)
			units += n
		end)
		A.eq(units, 4 + 2 + 2, "one unit per point a span holds")
		-- chords: union length, gaps up to tol merged, in any order, the input left as it was
		local ivs = Build.freeze({ 0.5, 0.7, 0, 0.2, 0.205, 0.3 })
		A.near(Edge.mergedLength(ivs, 3, 0.01), 0.5, 1e-15, "0..0.3 (a 0.005 gap merged) + 0.5..0.7")
		A.near(Edge.mergedLength(ivs, 3, 0.001), 0.495, 1e-15, "the gap kept")
		A.near(Edge.mergedLength({ 0, 1, 0.2, 0.4 }, 2, 0.01), 1, 1e-15, "nested")
		-- cutIndex = clamp((max(bladeLength, 1e-6)/t − CUT_LO)/(CUT_HI − CUT_LO), 0, 1), 0 with no thickness
		local lo, hi = Geo.CUT_LO, Geo.CUT_HI
		A.eq(Edge.cutIndex(2.77, 0), 0, "no thickness")
		A.near(Edge.cutIndex(3, 0.1), (30 - lo) / (hi - lo), 1e-15, "inside the range")
		A.eq(Edge.cutIndex(3, 1), 0, "wide and short: 0")
		A.eq(Edge.cutIndex(30, 0.1), 1, "thin and long: 1")
		A.eq(Edge.cutIndex(-1, 1e-6), 0, "a blade that ends below the guard counts 1e-6: ratio 1, under CUT_LO")
		A.near(Edge.cutIndex(-1, 2e-8), (1e-6 / 2e-8 - lo) / (hi - lo), 1e-12, "the floor is 1e-6")
	end)

	t.it("T-EDG-01 5 no kept part of the striking slot: no chain, all zero, the frame", function()
		local list = H.prepared(Blueprints.get("F5").core)
		local kept = { true, true, true, false, false }
		local e, stats = Edge.profile(list, kept, GEOMETRY, { 0, 0.75, 0 }, { 0, 1 })
		A.deepEq(e, { chains = {}, length = 0, cell = 0, bladeArea = 0, bladeMeanThickness = 0, gripPoint = { 0, 0.75, 0 },
			gripAxis = { 0, 1 } }, "the empty profile")
		A.deepEq(stats, { cells = 0, work = 0 }, "no raster")
	end)

	t.it("T-EDG-01 5 every fixture's chains: points, lengths and order (Calibration, Regression, Cost)", function()
		for _, set in { Calibration.list, Regression.list, Cost.list } do
			for _, f in set do
				wellFormed(edgeOf(f.core), f.id)
			end
		end
	end)

	t.it("T-EDG-01 6 Y and Z shifts of F1–F5 and C01–C15: the raster and the outline kept, the points moved by Δy, "
		.. "every shifted copy", function()
		-- the centred raster moved four (C05 + 0.125: one cell; C09 − 0.037 in Z: 240 cells, cutIndex 1 → 0.8842;
		-- C10 and C11 + 0.3317: EdgeLength −0.04 and −0.02): a cell centre on a face or RASTER_TOL from one; and
		-- Douglas–Peucker in blueprint XY changed the lengths' last bits on 16 of these copies
		local shifted = 0
		for _, row in COLUMNS do
			local core = coreOf(row.id)
			local base = edgeOf(core)
			for _, d in OFFSETS do
				local copy = moved(core, d)
				if Gen.margin(CTX, copy.parts) >= -Limits.EPS_CONTAIN then -- an offset out of the hitbox is skipped
					shifted += 1
					local what = string.format("%s + (0, %g, %g)", row.id, d[2], d[3])
					local e = edgeOf(copy)
					translatedAlike(base, e, d, what)
				end
			end
		end
		A.eq(shifted, 111, "the shifted copies inside the hitbox")
	end)

	t.it("T-EDG-01 6 X mirror images of F1–F5 and C01–C15: the raster kept, EdgeLength within TOL_EDGE_REL", function()
		for _, row in COLUMNS do
			local core = coreOf(row.id)
			local a, b = (edgeOf(core)), (edgeOf(mirrored(core)))
			A.near(b.bladeArea, a.bladeArea, ABS, row.id .. " bladeArea")
			A.near(b.bladeMeanThickness, a.bladeMeanThickness, ABS, row.id .. " bladeMeanThickness")
			A.truthy(relative(a.length, b.length) <= Tol.TOL_EDGE_REL, string.format("%s EdgeLength %.6f → %.6f", row.id,
				a.length, b.length))
		end
	end)

	t.it("T-EDG-01 6 the critic's Gen designs, 0x5EED0007 #89 and 0x5EED0001 #131 at +0.2: Y keeps the outline to the "
		.. "bit, Z too, the mirror the raster", function()
		-- Douglas–Peucker in blueprint XY broke a tie the other way once these were moved (L3: the lattice, fix round 1)
		local c89, d89 = criticDesign(0x5EED0007, 89, true)
		genInvariance(c89, d89, "0x5EED0007 #89")
		local c131 = criticDesign(0x5EED0001, 131, false)
		genInvariance(c131, { 0, 0.2, 0.05 }, "0x5EED0001 #131")
	end)

	t.slow("T-EDG-01 6 Gen designs, FUZZ_N_VALID: Y and Z keep the raster and the outline to the bit, the mirror the "
		.. "raster", function()
		genCorpus(Tol.FUZZ_N_VALID)
	end)

	t.it("T-EDG-01 7 budgets on P1: the chosen rung's cells and work fit EDGE_MAX_CELLS and EDGE_MAX_WORK", function()
		local e, stats = edgeOf(Cost.get("P1").core)
		local last = Geo.EDGE_CELL * Geo.H_LADDER[#Geo.H_LADDER]
		A.truthy(e.cell > Geo.EDGE_CELL, "P1 coarsens the raster: " .. e.cell)
		A.truthy((stats.cells <= Geo.EDGE_MAX_CELLS and stats.work <= Geo.EDGE_MAX_WORK) or e.cell == last,
			string.format("cell %g: %d cells, %d tests", e.cell, stats.cells, stats.work))
		for _, f in Cost.list do
			local g, s = edgeOf(f.core)
			A.truthy((s.cells <= Geo.EDGE_MAX_CELLS and s.work <= Geo.EDGE_MAX_WORK) or g.cell == last, f.id)
		end
	end)

	-- One unit ≈ one shape query (L6): the ladder's rows, the raster's cells, the crack rows, the edges and
	-- Douglas–Peucker's spans each reach a checkpoint at Analyze's cadence, so none is a long uncharged stretch.
	t.it("T-EDG-01 7 the ladder and every loop reach a checkpoint at CHECK_UNITS", function()
		local seen: { [string]: boolean } = {}
		local units, total = 0, 0
		local function spend(n: number)
			units += n
			total += n
			if units >= 500 then
				units = 0
				for level = 2, 6 do
					local name = debug.info(level, "n")
					if name and name ~= "" then
						seen[name] = true
					end
				end
			end
		end
		local _, stats = edgeOf(Blueprints.get("F5").core, spend)
		-- the raster charges at least a unit a cell, the crack rows a unit a cell, the ladder its rows
		A.truthy(total > 2 * stats.cells, "F5: " .. total .. " units for " .. stats.cells .. " cells")
		edgeOf(Cost.get("P5").core, spend)
		for _, name in { "rungFits", "raster", "crackEdges", "traceLoops", "emitRun", "simplify" } do
			A.truthy(seen[name], "no checkpoint from " .. name)
		end
	end)

	-- What each loop reports, by the function that charges it (the spend's direct caller), on fixed designs: a charge
	-- lost, changed or moved fails here at once, where only the timed T-PERF-01, run alone, felt it (M3's review: the
	-- raster at a unit a cell, traceLoops' charge dropped and one more empty row all passed the fast suite). F4 has a
	-- Wedge, P5 is the comb.
	t.it("T-EDG-01 7 each loop charges its own units: by caller on F5, F4 and P5", function()
		local function byCaller(core: any): { [string]: number }
			local by: { [string]: number } = {}
			edgeOf(core, function(n: number)
				local name = debug.info(2, "n")
				local key = if name and name ~= "" then name else "?"
				by[key] = (by[key] or 0) + n
			end)
			return by
		end
		A.deepEq(byCaller(Blueprints.get("F5").core), { rungFits = 690, raster = 4992, crackEdges = 1656, traceLoops = 284,
			simplify = 831 }, "F5")
		A.deepEq(byCaller(Blueprints.get("F4").core), { rungFits = 670, raster = 18216, crackEdges = 6164, traceLoops = 346,
			simplify = 963 }, "F4")
		A.deepEq(byCaller(Cost.get("P5").core), { rungFits = 2070, raster = 12096, crackEdges = 3312, traceLoops = 404,
			simplify = 3333 }, "P5")
	end)

	-- F5, F4 and P5 cross no gap past MERGE_GAP along Z, so the raster's hidden-gap tests went uncharged and passed
	-- (M3's review round 3): three plates turned 30° about Y, each gap 0.0105 across, 0.0121 along Z.
	t.it("T-EDG-01 7 the raster charges its hidden-gap tests: three plates turned 30° about Y", function()
		local turned = H.axisAngle(0, 1, 0, 30)
		local function plates(g: number): { Prepared }
			local list: { Prepared } = {}
			for k = 1, 3 do
				local s = (k - 2) * (0.02 + g) -- along the normal (0.5, 0, cos 30°)
				list[k] = H.prepare(Build.part(k, "Blade", "Block", "Iron", { 0.5 * s, 2.68, 0.8660254037844386 * s }, turned,
					{ 0.16, 2.6, 0.02 }), k)
			end
			return list
		end
		local function raster(g: number): (EdgeProfile, number)
			local units = 0
			local e = Edge.profile(plates(g), { true, true, true }, GEOMETRY, { 0, 0, 0 }, { 0, 1 }, function(n: number)
				if debug.info(2, "n") == "raster" then
					units += n
				end
			end)
			return e, units
		end
		local hidden, units = raster(0.0105)
		local merged, plain = raster(0.0100)
		A.near(hidden.bladeMeanThickness, merged.bladeMeanThickness, 0.002, "the mean thickness: as merged along Z (0.0100)")
		-- 0.0100 apart (0.01155 along Z) the gaps merge with no hidden-gap test; 0.0105 apart each covered cell that crosses
		-- a gap adds that test's 6 queries
		A.truthy(units - plain >= 6 * (hidden.bladeArea / (hidden.cell * hidden.cell)) / 2,
			"the raster's units hold the hidden-gap tests: " .. units .. " against " .. plain)
	end)

	t.it("T-EDG-01 7 P-DET and P-NOMUT: frozen inputs, two runs, the same profile; any order of the list", function()
		for _, id in { "F1", "C09", "P5" } do
			local core = if id == "F1" then Blueprints.get(id).core elseif id == "C09" then Calibration.get(id).core
				else Cost.get(id).core
			local list, kept, point, axis = inputs(core)
			Build.freeze(list)
			Build.freeze(kept)
			Build.freeze(point)
			Build.freeze(axis)
			local a = Edge.profile(list, kept, GEOMETRY, point, axis)
			local b = Edge.profile(list, kept, GEOMETRY, point, axis)
			A.eq(Dump.canonical(a), Dump.canonical(b), id .. " P-DET")
			A.truthy(a.gripPoint ~= point and a.gripAxis ~= axis, id .. " the frame copied, not shared")
			-- the list in reverse: the same edge, bit for bit
			local rlist: { Prepared }, rkept: { boolean } = {}, {}
			for r = #list, 1, -1 do
				table.insert(rlist, list[r])
				table.insert(rkept, kept[r])
			end
			A.eq(Dump.canonical((Edge.profile(rlist, rkept, GEOMETRY, point, axis))), Dump.canonical(a), id .. " any order")
		end
	end)
end)
