--!strict
-- T-DIF-04, 07, 09, 10 Physics/Analyze's difficulty (SPEC §5, §5.6, §4.7; §14.6 names them, E-S8.5 lists them, the M3
-- plan defines them: .build-notes/m3-plan/plan-r2.md [8.2], with the lead's L3, L12): what may not move D, through
-- Analyze.run, the analysis as the game makes it.
--   T-DIF-04  hidden filler, duplicates and dust: steps and edge bit-identical to the design without them ([7.6]'s
--             cases, the A variants' BitIdentical relations, Gen.withFiller), stronger than §14.6's |ΔG| ≤ TOL_DUST_G
--             for dust. A copy in a slot whose name comes first is a real change (§4.4); Gen.withFiller keeps a copy in
--             its host's slot. A laminate gap the verdict hides (≤ HIDE_OFFSET + EPS_GEOM across) reads as one solid to
--             Thinness and the edge too (fix round 1), up to the window's edge (V1's FA2), and however slantwise the
--             chords cross it from one part to the next: a laminate turned 30° about its length, a blade cut along its
--             X-Z diagonal (fix round 2), three and four plates (fix round 3). Not where a chord leaves through a
--             slanted slit's mouth at the rims (§17.1 O10), nor where the far plate is cut flush beside the crossings,
--             its probe in the piece beside: §17.1 O11's residual, pinned (fix round 4)
--   T-DIF-07  (a) Y/Z translation: on every F and C fixture × E-S2.10's offsets (slow; fast, C10, C11 and F1 at
--             + 0.3317, F1 at + 0.125) every |Δx_f| ≤ TOL_FACTOR_ABS, |ΔG| ≤ TOL_G_INVARIANT and cutIndex kept; a Y
--             shift that keeps the raster's cells (its samples lie on no face) keeps the outline (Douglas–Peucker on
--             the integer lattice: L3's option (a), fix round 1), so every step's EdgeLength to the bit, Thinness
--             within 1e-12 (its last bits follow the rounding of L and of the chords) and G to the bit: a Thinness
--             probe on another part's face, which the shift's rounding moved (F1's and F5's tip at + 0.125, ΔG 0.0007),
--             reads that part as met (§17.1 O11's face tie, fix round 2). On Gen designs the same for their Y draw
--             alone, G within TOL_G_INVARIANT (M2's owned volumes where a round part's overlap is sampled still move
--             it: V2's 0.0001), and |Δx_f| for Y and Z together.
--             (b) flush re-segmentation (D2 (i)): E-S2.10's F5 cuts and C12 against C02 at those tolerances; V1's fins
--             and the Prop stream's case 152 (θ on every local axis and the canonical walk's lattice pick, fix round 1:
--             |ΔG| ≤ TOL_G_INVARIANT, where the stride and θ moved 0.12–0.38 and a tier); on Gen.segmented designs
--             Volume and EdgeLength only: the pieces' grids, walks and counts are their own, and Asymmetry's grid
--             follows the parts as built (§17.1 O11): on this corpus G moves up to 0.0379 (Asymmetry on the Blade),
--             a tier only at a boundary (M3-notes, fixer A).
--             (c) ids and order: shuffled ids, the parts reordered by Canonical, give steps and edge bit-identical,
--             physics within 1e-12 (M2 sums it in blueprint order), on C09, P5, P1 and 6 random grip stacks of 3–6
--             Blocks, where a difficulty frame summed in blueprint order would move (fix round 1). X shifts and
--             whole-sword turns are real changes.
--             (d) another writing of one solid (fix round 1): a rib and a rod on F5's blade turned about their own
--             length, Gen #244's blade written its 24 ways (0.0475 thick; as generated: slow), Gen designs' Blocks
--             written (b, a, c) a quarter turn about Z (slow): d, g, tiers the same, factors and edge within 1e-12 (a
--             probe on the face of a Block written another way read that Block by rounding: fix round 2)
--   T-DIF-09  step scoping: CraftPlans' enabled steps in order on their work sets (WorkSet.select, kept parts only),
--             Smelting and Hammering on All's factors, the weights' terms; a planted plan followed; A27; O8's label
--             rule
--   T-DIF-10  the client's path (a yielding checkpoint) = the server's = measureInvalid's, by Dump.canonical
-- The fixtures run in --quick; the Gen corpora (FUZZ_N_VALID designs) are t.slow, so that --quick stays well under
-- §14.1's 30 s (the M3 plan's [9.4]). The measured values the plan has "printed" are in docs/build/M3-notes.md: the
-- specs print nothing.

local Test = require("../lib/Test")
local A = require("../lib/Assert")
local Dump = require("../lib/Dump")
local Gen = require("../lib/Gen")
local Prop = require("../lib/Prop")
local TestRng = require("../lib/TestRng")
local Tol = require("../lib/Tol")
local Adversarial = require("../fixtures/Adversarial")
local Blueprints = require("../fixtures/Blueprints")
local Build = require("../fixtures/Build")
local Calibration = require("../fixtures/Calibration")
local Cost = require("../fixtures/Cost")
local Regression = require("../fixtures/Regression")
local D = require("./DifficultyHelpers")
local Balance = require("../../src/shared/Definitions/Balance")
local CraftPlans = require("../../src/shared/Definitions/CraftPlans")
local EquipmentTypes = require("../../src/shared/Definitions/EquipmentTypes")
local Limits = require("../../src/shared/Definitions/Limits")
local Materials = require("../../src/shared/Definitions/Materials")
local Steps = require("../../src/shared/Definitions/Steps")
local Versions = require("../../src/shared/Definitions/Versions")
local Quantize = require("../../src/shared/Util/Quantize")
local Canonical = require("../../src/shared/Blueprint/Canonical")
local WorkSet = require("../../src/shared/Blueprint/WorkSet")
local Analyze = require("../../src/shared/Physics/Analyze")
local Difficulty = require("../../src/shared/Physics/Difficulty")

type Rng = TestRng.TestRng
type Part = Build.Part
type StepAnalysis = Analyze.StepAnalysis

local Geo = Balance.Geometry
local Dif = Balance.Difficulty
local SWORD: any = EquipmentTypes.get("Sword")
local CTX = Gen.context(Limits, SWORD, Materials.enabled, Versions.BLUEPRINT_SCHEMA, Geo)
local I = Build.I
local P = Build.part

-- E-S2.10's six offsets (v2/run.luau): three along Y, two along Z, one along both.
local OFFSETS: { { number } } = { { 0, 0.013, 0 }, { 0, 0.125, 0 }, { 0, 0.3317, 0 }, { 0, 0, 0.01 }, { 0, 0, -0.037 },
	{ 0, 0.2, 0.05 } }

local function run(core: any, opts: any?): any
	return Analyze.run(core, opts)
end

-- A design built here, through Canonical (its parts sorted by id).
local function canonical(name: string, parts: { Part }): any
	local result = Canonical.draft(Build.core(name, parts)) :: any
	A.truthy(result.ok, name .. ": Canonical must accept it, got " .. Dump.short(result))
	return result.value
end

local function canonicalOf(key: string): any
	local result = Canonical.draft(Adversarial.variant(key).draft()) :: any
	A.truthy(result.ok, key .. ": Canonical must accept it, got " .. Dump.short(result))
	return result.value
end

local function fixtureCore(id: string): any
	local first = string.sub(id, 1, 1)
	if first == "F" then
		return Blueprints.get(id).core
	elseif first == "C" then
		return Calibration.get(id).core
	elseif first == "X" then
		return Regression.get(id).core
	elseif first == "P" then
		return Cost.get(id).core
	end
	return canonicalOf(id)
end

local function copyParts(core: any): { Part }
	return Build.copy(core.parts)
end

local function dLine(report: any): string
	local out: { string } = {}
	for _, s in report.steps do
		table.insert(out, string.format("%.4f %s", s.d, s.tier))
	end
	return table.concat(out, " / ")
end

-- T-DIF-04: steps (every g, m, d, tier and factor) and the edge (chains, points, raster, frame), to the bit.
local function sameDifficulty(report: any, base: any, what: string)
	A.truthy(report.steps ~= nil and base.steps ~= nil, what .. ": both have steps")
	A.eq(Dump.canonical(report.steps), Dump.canonical(base.steps), what .. " steps")
	A.eq(Dump.canonical(report.edge), Dump.canonical(base.edge), what .. " edge")
end

local function cleanedIds(report: any): { number }
	local ids: { number } = {}
	for _, c in report.cleaned do
		table.insert(ids, c.partId)
	end
	return ids
end

-- T-DIF-07: the x of every factor a step weighs (its terms: E-S2.10's "MVP factors"; PartCount and Joints count the
-- pieces of a re-cut, as they should) within TOL_FACTOR_ABS, and G within gTol (nil: G not asserted); the worst Δx.
local function within(report: any, base: any, gTol: number?, what: string): number
	local worst = 0
	for i, s in report.steps do
		local b = base.steps[i]
		if gTol then
			A.truthy(math.abs(s.g - b.g) <= gTol, string.format("%s %s |ΔG| %.6f", what, s.step, math.abs(s.g - b.g)))
		end
		for k, term in s.terms do
			local dx = math.abs(term.x - b.terms[k].x)
			worst = math.max(worst, dx)
			A.truthy(dx <= Tol.TOL_FACTOR_ABS, string.format("%s %s %s |Δx| %.6f", what, s.step, term.factor, dx))
		end
	end
	return worst
end

local function factorOf(s: StepAnalysis, id: string): any
	for _, f in s.factors do
		if f.factor == id then
			return f
		end
	end
	return A.fail("no factor " .. id)
end

-- ── T-DIF-04's designs ([7.6], the plan's contracts.luau dif04) ───────────────────────────────────────────────────

type Pair = { name: string, base: any, filled: any, cleaned: { number }, d: { number }? }

-- C04 with a 0.075 blade, + 9 nested blocks in it ×(0.96 − 0.02k) (Reference.spec's): the base plays Hard Sharpening.
local function c04Nested(): Pair
	local parts = copyParts(Calibration.get("C04").core)
	local blade = Build.find(parts, 5) :: Part
	blade.size[3] = 0.075
	local filled = Build.copy(parts)
	for k = 1, 9 do
		local f = 0.96 - 0.02 * k
		table.insert(filled, P(7 + k, "Blade", "Block", "Iron", blade.pos, blade.rot,
			{ blade.size[1] * f, blade.size[2] * f, blade.size[3] * f }))
	end
	return { name = "C04 with a 0.075 blade + 9 nested blocks", base = canonical("C04 0.075", parts),
		filled = canonical("C04 0.075 + 9", filled), cleaned = { 8, 9, 10, 11, 12, 13, 14, 15, 16 },
		-- [7.6]'s 0.1863 / 0.3835 until M3's fix round 1 moved them (fixer A's Thinness and raster; M3-notes)
		d = { 0.0000, 0.1888, 0.3901 } }
end

-- C09 with its core, bevels and tips 0.05 longer, + 6 blocks in the core ×(0.75 − 0.005k), 5 Blade and 1 Pommel.
local function c09Longer(): Pair
	local delta = 0.05
	local parts = copyParts(Calibration.get("C09").core)
	local core = parts[12]
	core.pos[2] += delta / 2
	core.size[2] += delta
	for id = 13, 16 do -- the bevels, length along their local X
		parts[id].pos[2] += delta / 2
		parts[id].size[1] += delta
	end
	for id = 17, 18 do -- the tips
		parts[id].pos[2] += delta
	end
	local filled = Build.copy(parts)
	for k = 1, 6 do
		local g = 0.75 - 0.005 * k
		table.insert(filled, P(18 + k, if k <= 5 then "Blade" else "Pommel", "Block", "Iron", core.pos, I,
			{ core.size[1] * g, core.size[2] * g, core.size[3] * g }))
	end
	return { name = "C09 with a blade 0.05 longer + 6 blocks", base = canonical("C09 longer", parts),
		filled = canonical("C09 longer + 6", filled), cleaned = { 19, 20, 21, 22, 23, 24 },
		-- [7.6]'s 0.3299 / 0.2153 until M3's fix round 1 moved them (fixer A's Thinness and raster; M3-notes)
		d = { 0.0008, 0.3313, 0.2155 } }
end

-- C09 + a plate 0.12 × 2 × 0.05 that shows 20 % (kept), + 5 hidden blocks ×(0.8 − 0.01j), slots G G G B B (§17.2).
local function c09Plate(): Pair
	local parts = copyParts(Calibration.get("C09").core)
	table.insert(parts, P(19, "Blade", "Block", "Iron", { -0.03, 2.6, 0 }, I, { 0.12, 2, 0.05 }))
	local filled = Build.copy(parts)
	local slots = { "Guard", "Guard", "Guard", "Blade", "Blade" }
	for j = 1, 5 do
		local g = 0.8 - 0.01 * j
		table.insert(filled, P(19 + j, slots[j], "Block", "Iron", { 0, 2.6, 0 }, I, { 0.12 * g, 2.4 * g, 0.06 * g }))
	end
	return { name = "C09 + a plate + 5 hidden blocks", base = canonical("C09 + plate", parts),
		filled = canonical("C09 + plate + 5", filled), cleaned = { 20, 21, 22, 23, 24 },
		-- [7.6]'s Hammering 0.3599 until M3's fix round 1 moved it (fixer A's Thinness; M3-notes)
		d = { 0.0009, 0.3595, 0.2542 } }
end

-- X07a (a laminate of 2 plates 0.03) + a Dust hairline 0.02 × 0.4 × 0.02 on the seam.
local function x07Hairline(): Pair
	local parts = copyParts(Regression.get("X07a").core)
	local filled = Build.copy(parts)
	table.insert(filled, P(7, "Blade", "Block", "Iron", { 0, 2.68, 0 }, I, { 0.02, 0.4, 0.02 }))
	return { name = "X07a + a Dust hairline", base = Regression.get("X07a").core,
		filled = canonical("X07a + hair", filled), cleaned = { 7 } }
end

-- The fixture + 4 flush plates in its main blade (the largest Blade Block), listed first: Guard on its Z faces, Pommel
-- on its X faces (Verdict.spec's skins).
local function flushPlates(id: string): Pair
	local base = fixtureCore(id)
	local main: Part? = nil
	for _, p in base.parts do
		if p.slot == "Blade" and p.shape == "Block"
			and (main == nil or p.size[1] * p.size[2] * p.size[3] > main.size[1] * main.size[2] * main.size[3])
		then
			main = p
		end
	end
	local h = main :: Part
	local tz, tx = math.min(0.02, h.size[3] / 3), math.min(0.02, h.size[1] / 3)
	local x, y, z = h.pos[1], h.pos[2], h.pos[3]
	local parts: { Part } = {
		P(1, "Guard", "Block", "Iron", { x, y, z + (h.size[3] - tz) / 2 }, h.rot, { h.size[1], h.size[2], tz }),
		P(2, "Guard", "Block", "Iron", { x, y, z - (h.size[3] - tz) / 2 }, h.rot, { h.size[1], h.size[2], tz }),
		P(3, "Pommel", "Block", "Iron", { x + (h.size[1] - tx) / 2, y, z }, h.rot, { tx, h.size[2], h.size[3] }),
		P(4, "Pommel", "Block", "Iron", { x - (h.size[1] - tx) / 2, y, z }, h.rot, { tx, h.size[2], h.size[3] }),
	}
	for _, p in copyParts(base) do
		p.id += 4
		table.insert(parts, p)
	end
	return { name = id .. " + 4 flush plates", base = base, filled = canonical(id .. " + 4 plates", parts),
		cleaned = { 1, 2, 3, 4 } }
end

local function checkPair(pair: Pair)
	local base, filled = run(pair.base), run(pair.filled)
	A.deepEq(cleanedIds(filled), pair.cleaned, pair.name .. " cleaned")
	sameDifficulty(filled, base, pair.name)
	if pair.d then
		for k, s in base.steps do
			A.near(s.d, pair.d[k], 5e-5, pair.name .. " base " .. s.step)
		end
	end
end

-- The fixture with its main blade (its largest Blade Block) split into two plates through its thickness, gap g apart,
-- the outer faces kept (V1's laminate).
local function laminate(id: string, g: number): any
	local parts = copyParts(fixtureCore(id))
	local main, top = 0, 0
	for i, p in parts do
		top = math.max(top, p.id)
		if p.slot == "Blade" and p.shape == "Block" and (main == 0
			or p.size[1] * p.size[2] * p.size[3] > parts[main].size[1] * parts[main].size[2] * parts[main].size[3])
		then
			main = i
		end
	end
	local h = table.remove(parts, main) :: Part
	local t = (h.size[3] - g) / 2
	local z = g / 2 + t / 2
	table.insert(parts, P(top + 1, "Blade", "Block", h.material, { h.pos[1], h.pos[2], h.pos[3] + z }, h.rot,
		{ h.size[1], h.size[2], t }))
	table.insert(parts, P(top + 2, "Blade", "Block", h.material, { h.pos[1], h.pos[2], h.pos[3] - z }, h.rot,
		{ h.size[1], h.size[2], t }))
	return canonical(id .. " laminated " .. g, parts)
end

-- F5 with its blade (0.16 × 2.6 × 0.06 at y 2.68) as two plates turned 30° about the blade's length, split through their
-- own thickness g apart (the outer thickness kept), or as two Wedges cut along its X-Z diagonal, g apart across it (V1's
-- review round 2: obliq.luau, wedgediag.luau).
local function slantLaminate(kind: string, g: number): any
	local parts = copyParts(fixtureCore("F5"))
	table.remove(parts, 4)
	if kind == "turned" then
		local q = { 0, 0.25881904510252074, 0, 0.96592582628906831 } -- 30° about Y: local z → (0.5, 0, 0.866…)
		local t = (0.06 - g) / 2
		local ox, oz = (g / 2 + t / 2) * 0.49999999999999994, (g / 2 + t / 2) * 0.86602540378443871
		table.insert(parts, P(6, "Blade", "Block", "Iron", { ox, 2.68, oz }, q, { 0.16, 2.6, t }))
		table.insert(parts, P(7, "Blade", "Block", "Iron", { -ox, 2.68, -oz }, q, { 0.16, 2.6, t }))
	else
		local a = { Build.R, Build.R, 0, 0 } -- local x → +Y, local y → +X, local z → −Z
		local b = Build.mul({ 0, 1, 0, 0 }, a) -- the other half, 180° about Y
		local l = math.sqrt(0.375 * 0.375 + 1)
		local nx, nz = 0.375 / l, 1 / l -- the diagonal's normal, towards the second Wedge
		table.insert(parts, P(6, "Blade", "Wedge", "Iron", { -g / 2 * nx, 2.68, -g / 2 * nz }, a, { 2.6, 0.16, 0.06 }))
		table.insert(parts, P(7, "Blade", "Wedge", "Iron", { g / 2 * nx, 2.68, g / 2 * nz }, b, { 2.6, 0.16, 0.06 }))
	end
	return canonical(string.format("F5 %s %g", kind, g), parts)
end

-- F5's blade as two plates turned 30° about Y, split through their thickness g apart (slantLaminate's "turned"), the
-- upper plate cut flush across its width at its local x = each of seams (V1's review round 3: seam.luau, seam2.luau).
local function seamedLaminate(g: number, seams: { number }): any
	local parts = copyParts(fixtureCore("F5"))
	table.remove(parts, 4)
	local q = { 0, 0.25881904510252074, 0, 0.96592582628906831 } -- 30° about Y: local z → (0.5, 0, 0.866…)
	local cx, cz = 0.86602540378443871, -0.49999999999999994 -- local x
	local t = (0.06 - g) / 2
	local ox, oz = (g / 2 + t / 2) * 0.49999999999999994, (g / 2 + t / 2) * 0.86602540378443871
	table.insert(parts, P(6, "Blade", "Block", "Iron", { -ox, 2.68, -oz }, q, { 0.16, 2.6, t }))
	local cuts = { -0.08 }
	for _, c in seams do
		table.insert(cuts, c)
	end
	table.insert(cuts, 0.08)
	for k = 1, #cuts - 1 do
		local a, b = cuts[k], cuts[k + 1]
		local c = (a + b) / 2
		table.insert(parts, P(6 + k, "Blade", "Block", "Iron", { ox + c * cx, 2.68, oz + c * cz }, q, { b - a, 2.6, t }))
	end
	return canonical(string.format("F5 seamed %g", g), parts)
end

-- F5 with its blade (0.16 × 2.6 at y 2.68) as k plates turned 30° about its length, each 0.03 thick but for the gaps,
-- g apart along their normal (V2's review round 3: a run of three or more parts across hidden gaps).
local function slantStack(k: number, g: number): any
	local parts = copyParts(fixtureCore("F5"))
	table.remove(parts, 4)
	local q = { 0, 0.25881904510252074, 0, 0.96592582628906831 } -- 30° about Y: local z → (0.5, 0, 0.866…)
	local outer = 0.03 * k
	local t = (outer - (k - 1) * g) / k
	for i = 0, k - 1 do
		local off = -outer / 2 + t / 2 + i * (t + g)
		table.insert(parts, P(6 + i, "Blade", "Block", "Iron", { off * 0.49999999999999994, 2.68, off * 0.86602540378443871 },
			q, { 0.16, 2.6, t }))
	end
	return canonical(string.format("F5 in %d plates %g", k, g), parts)
end

-- V1's finned sword: a 0.13 × 1.4 blade on a 3.0 grip, a fin 0.03 × 0.25 × 0.5 on its +X face, whole or cut flush into
-- k pieces along its length, each shorter than the fin is thin (V1's recut.luau, its fourth design).
local function finned(k: number): any
	local parts: { Part } = {
		P(1, "Pommel", "Block", "Iron", { 0, 0.08, 0 }, I, { 0.16, 0.12, 0.16 }),
		P(2, "Grip", "Block", "Iron", { 0, 1.64, 0 }, I, { 0.12, 3.0, 0.12 }),
		P(3, "Guard", "Block", "Iron", { 0, 3.19, 0 }, I, { 0.5, 0.1, 0.16 }),
		P(4, "Blade", "Block", "Iron", { 0, 3.24 + 0.7, 0 }, I, { 0.13, 1.4, 0.13 }),
	}
	local piece = 0.25 / k
	for i = 0, k - 1 do
		table.insert(parts, P(5 + i, "Blade", "Block", "Iron", { 0.065 + 0.015, 3.54 + (i + 0.5) * piece, 0 }, I,
			{ 0.03, piece, 0.5 }))
	end
	return canonical("finned in " .. k, parts)
end

-- The Prop stream's case 152 (PROP_BASE_SEED's 152nd case seed, B3 and V2): Invariance's genCorpus draws, whole and
-- re-cut flush. Two tip blocks cut into pieces shorter than they are thin; its main blade, turned, in three.
local function case152(): (any, any)
	local rng = TestRng.new(515583194)
	local core = Gen.validSword(rng, CTX)
	Gen.translated(rng, CTX, core)
	local cut = Gen.segmented(rng, CTX, core)
	return core, cut
end

-- Two analyses of one solid written two ways: d, g and tier the same on every step, every factor's raw, the edge's
-- chains and raster and cutIndex within 1e-12 (a turned part's samples and chords carry its writing's rounding).
local function sameSolid(report: any, base: any, what: string)
	for k, s in report.steps do
		local b = base.steps[k]
		A.eq(s.d, b.d, what .. " " .. s.step .. " d")
		A.eq(s.g, b.g, what .. " " .. s.step .. " g")
		A.eq(s.tier, b.tier, what .. " " .. s.step .. " tier")
		for j, f in s.factors do
			A.near(f.raw, b.factors[j].raw, 1e-12, what .. " " .. s.step .. " " .. f.factor)
		end
	end
	local e, f = report.edge, base.edge
	A.eq(#e.chains, #f.chains, what .. " chains")
	for k, c in e.chains do
		A.near(c.length, f.chains[k].length, 1e-12, what .. " chain " .. k)
		A.eq(#c.points, #f.chains[k].points, what .. " chain " .. k .. " points")
	end
	A.near(e.bladeArea, f.bladeArea, 1e-12, what .. " bladeArea")
	A.near(e.bladeMeanThickness, f.bladeMeanThickness, 1e-12, what .. " bladeMeanThickness")
	A.near(report.physics.cutIndex, base.physics.cutIndex, 1e-12, what .. " cutIndex")
end

-- T-DIF-07 (d): V1's Gen #244 (TestRng 0x5EED0042), its blade turned 54° about Y, written its 24 ways (thick > 0: that
-- thick), against itself as written first: the plain stride took other layers in other writings (Hammering 0.0734–
-- 0.1226, and 0.1893 Normal – 0.2051 Hard at 0.0475).
local function gen244(thick: number)
	local rng = TestRng.new(0x5EED0042)
	local core: any = nil
	for _ = 1, 244 do
		core = Gen.validSword(rng, CTX)
	end
	local parts = copyParts(core)
	local blade = 0
	for i, p in parts do
		if p.slot == "Blade" then
			blade = i
		end
	end
	if thick > 0 then
		parts[blade].size[3] = thick
	end
	local base = run(canonical("#244", parts))
	for k, w in D.writings() do
		local written = Build.copy(parts)
		written[blade] = D.written(parts[blade], w)
		sameSolid(run(canonical("#244 written", written)), base, string.format("#244 (%g) writing %d", thick, k))
	end
end

-- T-DIF-07 (a), a Y shift: where the raster's cells are kept, every step's EdgeLength (raw) to the bit, Thinness within
-- 1e-12 (its last bits follow the rounding of L and of the chords) and G within gTol (0: to the bit); whether the
-- raster was kept (T-EDG-01 6 holds it).
local function yKept(report: any, base: any, what: string, gTol: number): boolean
	if report.edge.cell ~= base.edge.cell or report.edge.bladeArea ~= base.edge.bladeArea then
		return false
	end
	for i, s in report.steps do
		local b = base.steps[i]
		A.eq(factorOf(s, "EdgeLength").raw, factorOf(b, "EdgeLength").raw, what .. " " .. s.step .. " EdgeLength")
		A.near(factorOf(s, "Thinness").raw, factorOf(b, "Thinness").raw, 1e-12, what .. " " .. s.step .. " Thinness")
		A.truthy(math.abs(s.g - b.g) <= gTol, string.format("%s %s |ΔG| %.6f", what, s.step, math.abs(s.g - b.g)))
	end
	return true
end

-- T-DIF-07 (a): each fixture moved by E-S2.10's offsets, inside the hitbox, against itself; the copies measured.
local function shiftedFixtures(ids: { string }): number
	local moved = 0
	for _, id in ids do
		local core = fixtureCore(id)
		local base = run(core)
		for _, o in OFFSETS do
			local shifted: any = Gen.translate(core :: any, o[2], o[3])
			if Analyze.quick(shifted).ok then -- an offset out of the hitbox is skipped, as v2/run.luau does
				moved += 1
				local what = string.format("%s + (0, %g, %g)", id, o[2], o[3])
				local report = run(shifted)
				within(report, base, Tol.TOL_G_INVARIANT, what)
				A.near(report.physics.cutIndex, base.physics.cutIndex, 1e-12, what .. " cutIndex")
				if o[3] == 0 then
					A.truthy(yKept(report, base, what, 0), what .. ": the raster kept")
				end
			end
		end
	end
	return moved
end

-- ── Gen corpora (FUZZ_N_VALID designs, t.slow) ────────────────────────────────────────────────────────────────────

local KINDS: { Gen.FillerKind } = { "Enclosed", "Duplicate", "Dust" }

local function fillerCorpus(n: number)
	Prop.check(n, function(rng: Rng): any
		local core = Gen.validSword(rng, CTX)
		local fills: { any } = {}
		for k = 1, #KINDS do
			local kind: Gen.FillerKind = KINDS[k]
			local filled, added = Gen.withFiller(rng, CTX, core, kind)
			table.insert(fills, { kind = kind, core = filled, added = added })
		end
		return { core = core, fills = fills }
	end, function(input: any)
		local base = run(input.core)
		for _, fill in input.fills do
			if #fill.added > 0 then
				local report = run(fill.core)
				A.truthy(report.validation.ok, fill.kind .. ": valid")
				A.deepEq(cleanedIds(report), fill.added, fill.kind .. ": every filler cleaned, nothing else")
				sameDifficulty(report, base, fill.kind)
			end
		end
	end)
end

-- (a) translated, every x within TOL_FACTOR_ABS, and its Y draw alone EdgeLength to the bit, Thinness within 1e-12 and
-- G within TOL_G_INVARIANT (yKept); (b) re-cut flush, Volume and EdgeLength within it.
local function genCorpus(n: number)
	Prop.check(n, function(rng: Rng): any
		local core = Gen.validSword(rng, CTX)
		local moved, delta = Gen.translated(rng, CTX, core)
		local cut, ids = Gen.segmented(rng, CTX, core)
		return { core = core, moved = moved, delta = delta, cut = cut, cutIds = ids }
	end, function(input: any)
		local base = run(input.core)
		within(run(input.moved), base, nil, string.format("moved (0, %.4f, %.4f)", input.delta[2], input.delta[3]))
		local what = string.format("moved (0, %.4f, 0)", input.delta[2])
		A.truthy(yKept(run(Gen.translate(input.core, input.delta[2], 0)), base, what, Tol.TOL_G_INVARIANT),
			what .. ": the raster kept")
		if #input.cutIds > 0 then
			local cut = run(input.cut)
			for i, s in cut.steps do
				for _, id in { "Volume", "EdgeLength" } do
					local dx = math.abs(factorOf(s, id).x - factorOf(base.steps[i], id).x)
					A.truthy(dx <= Tol.TOL_FACTOR_ABS, string.format("re-cut %s %s |Δx| %.6f", s.step, id, dx))
				end
			end
		end
	end)
end

-- A checkpoint that yields at every call (how the client's PreviewScheduler and the server's AnalysisQueue slice a run,
-- §1.6, §11.13), no checkpoint, or measureInvalid: one analysis.
local function yielded(core: any): any
	local thread = coroutine.create(function(): any
		return Analyze.run(core, { checkpoint = function()
			coroutine.yield()
		end })
	end)
	local yields = 0
	while true do
		local ok, value = coroutine.resume(thread)
		A.truthy(ok, tostring(value))
		if coroutine.status(thread) == "dead" then
			A.truthy(yields > 0, "it yielded")
			return value
		end
		yields += 1
	end
end

local function clientServer(core: any, what: string)
	local server = Dump.canonical(run(core))
	A.eq(Dump.canonical(yielded(core)), server, what .. ": client = server")
	A.eq(Dump.canonical(run(core, { measureInvalid = true })), server, what .. ": measureInvalid = server")
end

-- Ids permuted with a seeded shuffle, the parts then in the new ids' order (Canonical sorts them).
local function shuffledIds(core: any, rng: Rng): (any, { number })
	local ids: { number } = {}
	for i, p in core.parts do
		ids[i] = p.id
	end
	for i = #ids, 2, -1 do
		local j = rng:int(1, i)
		ids[i], ids[j] = ids[j], ids[i]
	end
	local parts = copyParts(core)
	for i, p in parts do
		p.id = ids[i]
	end
	return canonical(core.name .. " shuffled", parts), ids
end

-- V1's grip stacks (M3's review, its framesearch): a Ball pommel, k Grip Blocks of random sizes stacked flush, F5's
-- guard and blade above. Summed in blueprint order, the difficulty frame's point would move with the ids on about half
-- the shuffles of such a stack (the sum's last bits follow the order); the fixtures' grips seldom show it (C09's 4
-- Grip parts on 1 shuffle in 4, P5's 1 and P1's 2 never).
local function gripStack(rng: Rng, k: number): any
	local parts: { Part } = { P(1, "Pommel", "Ball", "Iron", { 0, 0.15, 0 }, I, { 0.26, 0.26, 0.26 }) }
	local y = 0.28
	for n = 1, k do
		local h = rng:range(0.1, 0.2)
		table.insert(parts, P(1 + n, "Grip", "Block", "Iron", { 0, y + h / 2, 0 }, I,
			{ rng:range(0.1, 0.2), h, rng:range(0.1, 0.2) }))
		y += h
	end
	table.insert(parts, P(k + 2, "Guard", "Block", "Iron", { 0, y + 0.09, 0 }, I, { 0.8, 0.18, 0.24 }))
	table.insert(parts, P(k + 3, "Blade", "Block", "Iron", { 0, y + 1.48, 0 }, I, { 0.16, 2.6, 0.06 }))
	return canonical("grip stack", parts)
end

local PHYSICS = { "mass", "volume", "guardPos", "balance", "balanceFromHand", "reach", "bladeLength", "totalLength",
	"comOffAxis", "edgeLength", "cutIndex" }

return Test.suite("Physics/Invariance", function(t)
	t.it("T-DIF-04 [7.6]'s designs: hidden blocks, a Dust hairline, flush plates; steps and edge bit-identical",
		function()
			for _, make in { c04Nested, c09Longer, c09Plate, x07Hairline } do
				checkPair(make())
			end
			for _, id in { "F5", "C02", "C05" } do
				checkPair(flushPlates(id))
			end
			-- the plate shows 20.12 % and is kept: Sharpening Hard, with or without the hidden blocks (§17.2)
			local plate = run(c09Plate().base)
			A.eq(plate.steps[3].tier, "Hard", "C09 + the plate")
			A.eq(run(Calibration.get("C09").core).steps[3].tier, "Normal", "C09")
		end)

	t.it("T-DIF-04 the A variants: A14 (19 Dust cubes), A16, A17 (enclosed, exact copies), A25 (a hidden grip core)",
		function()
			local checked = 0
			for _, variant: any in Adversarial.variants do
				local relation = variant.analysis and variant.analysis.relation
				if relation and relation.d == "BitIdentical" or variant.key == "A25" then
					local to = if relation then relation.to else "F1"
					local report = run(canonicalOf(variant.key))
					A.deepEq(report.cleaned, variant.analysis.cleaned, variant.key .. " cleaned")
					sameDifficulty(report, run(fixtureCore(to)), variant.key .. " against " .. to)
					checked += 1
				end
			end
			A.eq(checked, 4, "A14, A16, A17, A25")
		end)

	t.slow("T-DIF-04 Gen.withFiller, FUZZ_N_VALID designs × Enclosed, Duplicate, Dust: every filler cleaned, steps "
		.. "and edge bit-identical", function()
		fillerCorpus(Tol.FUZZ_N_VALID)
	end)

	t.it("T-DIF-07 (a) C10, C11 and F1 at + 0.3317 in Y, where centred cells moved C10's and C11's G 0.0063 and 0.0031 "
		.. "and blueprint XY F1's EdgeLength, and F1 at + 0.125, where its tip's probes on the blade's face moved G 0.0007: "
		.. "G and EdgeLength to the bit, Thinness within 1e-12, cutIndex kept", function()
			-- fix round 1 reads each cell off its centre and runs Douglas–Peucker on the integer lattice; every F and C
			-- fixture × E-S2.10's offsets is the slow case (moved there to keep --quick under 27 s), and T-EDG-01 6 holds
			-- their 111 copies' edges fast
			for _, id in { "C10", "C11", "F1" } do
				local core = fixtureCore(id)
				local base, report = run(core), run(Gen.translate(core :: any, 0.3317, 0))
				local what = id .. " + (0, 0.3317, 0)"
				within(report, base, Tol.TOL_G_INVARIANT, what)
				A.near(report.physics.cutIndex, base.physics.cutIndex, 1e-12, what .. " cutIndex")
				A.truthy(yKept(report, base, what, 0), what .. ": the raster kept")
			end
			local f1 = fixtureCore("F1")
			A.truthy(yKept(run(Gen.translate(f1 :: any, 0.125, 0)), run(f1), "F1 + (0, 0.125, 0)", 0),
				"F1 + 0.125: the raster kept")
		end)

	t.slow("T-DIF-07 (a) F1–F5 and C01–C15 moved by E-S2.10's offsets: |Δx_f| ≤ TOL_FACTOR_ABS, |ΔG| ≤ "
		.. "TOL_G_INVARIANT, cutIndex kept; along Y, G and EdgeLength to the bit, Thinness within 1e-12", function()
			local ids: { string } = table.clone(Blueprints.order)
			for _, f in Calibration.list do
				table.insert(ids, f.id)
			end
			A.eq(shiftedFixtures(ids), 111, "the shifted copies inside the hitbox")
		end)

	t.it("T-DIF-04 a laminate gap the verdict hides reads as one solid: Thinness and the edge the same across "
		.. "(CONTACT_TOL, HIDE_OFFSET]", function()
			-- the main blade of F5, C02, C05, C08 and F2 split through its thickness, 0.0099, 0.0101 and 0.0119 apart:
			-- every facing face hidden (§4.4); merged at CONTACT_TOL, Thinness and the mean thickness jumped past 0.010
			-- (F5's Hammering 0.1035 Normal → 0.3981 Hard). SurfaceComplexity still counts the gap out of V (§17.1 O10).
			-- Thinness within 1e-9: every part but a probe's own is read grown by 1e-10 (face ties, fix round 2), so a
			-- chord whose end lies on another part's slanted face moves with the plates' grids by that much
			for _, id in { "F5", "C02", "C05", "C08", "F2" } do
				local whole = run(fixtureCore(id))
				local first: any = nil
				for _, g in { 0.0099, 0.0101, 0.0119 } do
					local report = run(laminate(id, g))
					local what = string.format("%s laminated %g", id, g)
					first = first or report
					local thin = factorOf(report.steps[2], "Thinness").raw
					A.near(thin, factorOf(first.steps[2], "Thinness").raw, 1e-9, what .. " Thinness on All")
					A.eq(report.steps[2].tier, whole.steps[2].tier, what .. " Hammering's tier")
					A.eq(report.edge.bladeMeanThickness, whole.edge.bladeMeanThickness, what .. " mean thickness")
					A.eq(report.physics.cutIndex, whole.physics.cutIndex, what .. " cutIndex")
				end
			end
		end)

	t.it("T-DIF-04 the window's edge: a laminate gap within EPS_GEOM past HIDE_OFFSET, which the verdict hides, merges "
		.. "(V1's FA2)", function()
			-- 0.01200005: a face's probe, HIDE_OFFSET along its normal, lands 5e-8 short of the other plate, within EPS_GEOM
			-- (§4.4); merged only to HIDE_OFFSET, F5's Thinness read 0.9963 there
			local hidden, inside = run(laminate("F5", 0.01200005)), run(laminate("F5", 0.0119))
			A.near(factorOf(hidden.steps[2], "Thinness").raw, factorOf(inside.steps[2], "Thinness").raw, 1e-12,
				"Thinness on All")
			A.near(hidden.edge.bladeMeanThickness, inside.edge.bladeMeanThickness, 1e-12, "the edge's mean thickness")
		end)

	t.it("T-DIF-04 a laminate gap the verdict hides, crossed slantwise (F5's blade turned 30° about its length and split, "
		.. "or cut along its X-Z diagonal): Thinness, the mean thickness and Hammering's tier the same either side of "
		.. "MERGE_GAP·cos", function()
			-- along the chord alone the window is MERGE_GAP·cos of the crossing: the turned laminate's Z chords split from
			-- 0.0104 (Hammering 0.1318 Normal → 0.4095 Expert; the mean thickness 0.0593 → 0.0505), the diagonal's from
			-- 0.0113 (0.1762 Normal → 0.3028 Hard); a crossing now merges where both faces at it are hidden (Edge's hidden
			-- gaps), and past 0.0120001 they show. What still moves is the plates' own grids, which change with the gap
			-- (Thinness 0.0016; the diagonal's 0.0026 is its outline thickening as its Wedges part), and the edge's mouth
			-- columns at the rims (the mean thickness 0.0593 → 0.0591): at 30° no probe's line crosses a slit's mouth (a
			-- scratch closure of the mouths reads the same, M3's fix round 3); at 45° the mouths drift a tier, §17.1 O10
			local cases: { { kind: string, gaps: { number }, shows: number } } = {
				{ kind = "turned", gaps = { 0.0100, 0.0105, 0.0119 }, shows = 0.0121 },
				{ kind = "diagonal", gaps = { 0.0112, 0.0113, 0.0115 }, shows = 0.0121 },
			}
			for _, c in cases do
				local base = run(slantLaminate(c.kind, c.gaps[1]))
				for k = 2, 3 do
					local r = run(slantLaminate(c.kind, c.gaps[k]))
					local what = string.format("%s %g against %g", c.kind, c.gaps[k], c.gaps[1])
					A.truthy(r.validation.ok, what .. " valid")
					A.near(factorOf(r.steps[2], "Thinness").raw, factorOf(base.steps[2], "Thinness").raw, 0.005,
						what .. ": Thinness on All")
					A.near(r.edge.bladeMeanThickness, base.edge.bladeMeanThickness, 0.001, what .. ": the mean thickness")
					A.eq(r.steps[2].tier, base.steps[2].tier, what .. ": Hammering's tier")
				end
				local shown = run(slantLaminate(c.kind, c.shows))
				A.truthy(factorOf(shown.steps[2], "Thinness").raw > factorOf(base.steps[2], "Thinness").raw + 0.3,
					string.format("%s %g: the faces show, the plates read thin", c.kind, c.shows))
			end
		end)

	t.it("T-DIF-04 a slanted laminate's far plate cut flush, its seams beside the crossings, §17.1 O11's residual, "
		.. "pinned: hidden 0.0105 apart with 3 seams Hammering 0.3095 Hard, 0.0119 apart with one 0.2104 Hard, where the "
		.. "same pieces 0.0100 apart (merged along Z) play 0.1734 and 0.1337 Normal", function()
			-- a face's probe lands g·tan 30° beside where the line meets the far plate; past a seam it lands in the piece
			-- beside, which the verdict counts but the hidden-gap test, asking the part met alone, does not: the gap reopens
			-- at the seam (fix round 3 asked the piece beside too, as any part of the set, and so merged visible air, an
			-- open slot: Edge.spec; withdrawn in fix round 4). Pinned, so that a change that closes it updates §5's
			-- promise, §0.5 and O11
			local cases = {
				{ g = 0.0105, seams = { -0.035, 0.015, 0.045 }, d = 0.3095, thin = 0.74572, mt = 0.05779, d0 = 0.1734,
					thin0 = 0.40514 },
				{ g = 0.0119, seams = { -0.035 }, d = 0.2104, thin = 0.49866, mt = 0.05740, d0 = 0.1337, thin0 = 0.30620 },
			}
			for _, c in cases do
				local merged, hidden = run(seamedLaminate(0.0100, c.seams)), run(seamedLaminate(c.g, c.seams))
				local what = string.format("%g apart, %d seams: ", c.g, #c.seams)
				A.truthy(hidden.validation.ok and merged.validation.ok, what .. "both valid")
				A.near(hidden.steps[2].d, c.d, 5e-5, what .. "Hammering")
				A.eq(hidden.steps[2].tier, "Hard", what .. "Hammering's tier")
				A.near(factorOf(hidden.steps[2], "Thinness").raw, c.thin, 1e-4, what .. "Thinness on All")
				A.near(hidden.edge.bladeMeanThickness, c.mt, 1e-5, what .. "the mean thickness")
				A.near(merged.steps[2].d, c.d0, 5e-5, what .. "Hammering 0.0100 apart")
				A.eq(merged.steps[2].tier, "Normal", what .. "Hammering's tier 0.0100 apart")
				A.near(factorOf(merged.steps[2], "Thinness").raw, c.thin0, 1e-4, what .. "Thinness on All 0.0100 apart")
				A.near(merged.edge.bladeMeanThickness, 0.05933, 1e-5, what .. "the mean thickness 0.0100 apart")
			end
		end)

	t.it("T-DIF-04 three and four plates crossed slantwise: each hidden gap merges in turn, Thinness, the mean thickness "
		.. "and Hammering's tier the same either side of MERGE_GAP·cos", function()
			-- a chord or a raster line that crosses two hidden gaps joins the third plate only through the second: the union
			-- chord's closure runs again after each hidden join, and the raster's run passes on the part that ends it (one
			-- round of hidden joins: 3 plates at 0.0105, Thinness 0.3870 → 0.2740; the run's first part kept: the mean
			-- thickness 0.0734 → 0.0663; V2's review round 3). Thinness within 0.01: the plates' own grids, which thin with
			-- the gap, drift it (0.0073 and 0.0075 at 0.0119; a scratch closure of the slits' mouths reads the same, M3's
			-- fix round 3)
			for _, k in { 3, 4 } do
				local base = run(slantStack(k, 0.0100))
				for _, g in { 0.0105, 0.0119 } do
					local r = run(slantStack(k, g))
					local what = string.format("%d plates %g against 0.01", k, g)
					A.near(factorOf(r.steps[2], "Thinness").raw, factorOf(base.steps[2], "Thinness").raw, 0.01,
						what .. ": Thinness on All")
					A.near(r.edge.bladeMeanThickness, base.edge.bladeMeanThickness, 0.001, what .. ": the mean thickness")
					A.eq(r.steps[2].tier, base.steps[2].tier, what .. ": Hammering's tier")
				end
			end
		end)

	t.it("T-DIF-07 (b) F5's blade re-cut flush into 2, 3 and 7 pieces, C12 against C02: within the same tolerances",
		function()
			local f5 = Blueprints.get("F5").core
			local base = run(f5)
			for _, n in { 2, 3, 7 } do
				local parts: { Part } = {}
				for _, p in copyParts(f5) do
					if p.id ~= 4 then -- the blade, 0.16 × 2.60 × 0.06 from y 1.38
						table.insert(parts, p)
					end
				end
				local length = 2.60 / n
				for k = 0, n - 1 do
					table.insert(parts, P(6 + k, "Blade", "Block", "Iron", { 0, 1.38 + (k + 0.5) * length, 0 }, I,
						{ 0.16, length, 0.06 }))
				end
				within(run(canonical("F5 in " .. n, parts)), base, Tol.TOL_G_INVARIANT, "F5 in " .. n .. " pieces")
			end
			within(run(Calibration.get("C12").core), run(Calibration.get("C02").core), Tol.TOL_G_INVARIANT, "C12")
		end)

	t.it("T-DIF-07 (b) re-cuts that turned θ or the stride: V1's fin in 9 pieces and the Prop stream's case 152, |ΔG| ≤ "
		.. "TOL_G_INVARIANT", function()
			-- with θ the thinnest local axis and a plain stride, the fin's pieces turned θ to its length (Hammering
			-- 0.4856 Expert → 0.1033 Normal) and case 152's main blade lost its outer layers (0.2158 Hard → 0.0908)
			local whole, cut = run(finned(1)), run(finned(9))
			within(cut, whole, Tol.TOL_G_INVARIANT, "the fin in 9")
			A.eq(cut.steps[2].tier, whole.steps[2].tier, "the fin: Hammering's tier")
			local core, recut = case152()
			local a, b = run(core), run(recut)
			for k, s in b.steps do
				A.truthy(math.abs(s.g - a.steps[k].g) <= Tol.TOL_G_INVARIANT, string.format("case 152 %s |ΔG| %.4f", s.step,
					math.abs(s.g - a.steps[k].g)))
				A.eq(s.tier, a.steps[k].tier, "case 152 " .. s.step .. " tier")
			end
		end)

	t.slow("T-DIF-07 (a), (b) Gen designs, FUZZ_N_VALID: translated, every |Δx_f| ≤ TOL_FACTOR_ABS, and along Y alone "
		.. "EdgeLength to the bit, Thinness within 1e-12, G within TOL_G_INVARIANT; re-cut, Volume and EdgeLength", function()
		genCorpus(Tol.FUZZ_N_VALID)
	end)

	t.it("T-DIF-07 (c) C09, P5, P1 and 6 grip stacks of 3–6 Blocks with their ids shuffled: steps and edge (the frame's "
		.. "point) bit-identical, physics within 1e-12", function()
			local rng = TestRng.new(Tol.PROP_BASE_SEED)
			local designs: { { name: string, core: any, rounds: number } } = {
				{ name = "C09", core = fixtureCore("C09"), rounds = 4 },
				{ name = "P5", core = fixtureCore("P5"), rounds = 2 },
				{ name = "P1", core = fixtureCore("P1"), rounds = 2 },
			}
			local stacks = TestRng.new(0xF4A3E) -- V1's search's seed: fixed designs, shuffled by the run's seed
			for k = 1, 6 do
				table.insert(designs, { name = "grip stack " .. k, core = gripStack(stacks, stacks:int(3, 6)), rounds = 3 })
			end
			for _, design in designs do
				local id, core = design.name, design.core
				local base = run(core)
				for round = 1, design.rounds do
					local shuffled, ids = shuffledIds(core, rng)
					local what = string.format("%s, shuffle %d", id, round)
					local report = run(shuffled)
					sameDifficulty(report, base, what)
					local p, q = report.physics, base.physics
					for _, field in PHYSICS do
						A.near(p[field], q[field], 1e-12, what .. " " .. field)
					end
					for k = 1, 3 do
						A.near(p.com[k], q.com[k], 1e-12, what .. " COM")
					end
					-- per part, by its original index: the part now named ids[i] was part i
					local was: { [number]: number } = {}
					for i, newId in ids do
						was[newId] = i
					end
					local cleaned: { number } = {}
					for r, part in shuffled.parts do
						local i = was[part.id]
						A.eq(p.kept[r], q.kept[i], what .. " kept, part " .. i)
						A.near(p.ownedVolume[r], q.ownedVolume[i], 1e-12, what .. " owned volume, part " .. i)
						if not p.kept[r] then
							table.insert(cleaned, core.parts[i].id)
						end
					end
					table.sort(cleaned)
					A.deepEq(cleaned, cleanedIds(base), what .. " the same parts cleaned")
				end
			end
		end)

	t.it("T-DIF-07 (d) another writing of one solid: a rib and a rod on F5's blade turned about their length, Gen #244's "
		.. "blade written its 24 ways", function()
			-- θ the thinnest local axis took the writing's tie (Hammering 0.2117 Hard / 0.1637 Normal for the rib) and the
			-- plain stride each writing's own sample order (#244 at 0.0475 thick: 0.1893 Normal – 0.2051 Hard)
			local R = Build.R
			local function ribbed(shape: string, rot: { number }, size: { number }): any
				local parts = copyParts(fixtureCore("F5"))
				parts[4].size[3] = 0.05
				table.insert(parts, P(6, "Blade", shape, "Iron", { 0, 2.68, 0.04 }, rot, size))
				return run(canonical("F5 ribbed", parts))
			end
			sameSolid(ribbed("Block", { 0, R, 0, R }, { 0.03, 2.4, 0.03 }), ribbed("Block", I, { 0.03, 2.4, 0.03 }),
				"the rib turned a quarter about its length")
			sameSolid(ribbed("Cylinder", Build.mul(Build.Z90, { R, 0, 0, R }), { 2.4, 0.03, 0.03 }),
				ribbed("Cylinder", Build.Z90, { 2.4, 0.03, 0.03 }), "the rod spun a quarter")
			gen244(0.0475) -- thinned to sit at Hard's threshold; as generated: the slow case
		end)

	t.slow("T-DIF-07 (d) Gen #244's blade as generated, written its 24 ways: the same steps and edge", function()
		gen244(0)
	end)

	t.slow("T-DIF-07 (d) Gen designs, FUZZ_N_VALID, every Block written (b, a, c) a quarter turn about its Z: the same "
		.. "steps and edge", function()
		local turn = Build.Z90
		Prop.check(Tol.FUZZ_N_VALID, function(rng: Rng): any
			return Gen.validSword(rng, CTX)
		end, function(core: any)
			local parts = copyParts(core)
			for _, p in parts do
				if p.shape == "Block" then
					p.rot = Gen.hemisphere(Build.mul(p.rot, turn))
					p.size = { p.size[2], p.size[1], p.size[3] }
				end
			end
			sameSolid(run(canonical("written", parts)), run(core), core.name)
		end)
	end)

	t.it("T-DIF-09 steps on their work sets: CraftPlans' order, All shared, {Blade} for Sharpening, kept parts only",
		function()
			for _, id in { "F1", "C10" } do
				local core = fixtureCore(id)
				local report = run(core)
				local plan = Difficulty.planSteps("Sword")
				A.eq(#report.steps, #plan, id)
				for k, row in plan do
					local s = report.steps[k]
					A.eq(s.step, row.step, id .. " plan order")
					local set = WorkSet.select(core.parts, report.physics.kept, row.worksOn)
					-- PartCount sums the set's parts, kept ones: C10's 2 Enclosed blocks and 2 Dust specks are in none
					local n = 0
					for _, i in set do
						n += math.min(1, Gen.volume(core.parts[i]) / Dif.V_PART_FULL)
					end
					A.near(factorOf(s, "PartCount").raw, n, 1e-12, id .. " " .. s.step .. " PartCount on its set")
					local weights = (Steps.get(row.step) :: any).factorWeights
					local sum = 0
					for i, w in weights do
						local want = { factor = w.factor, w = w.w, x = factorOf(s, w.factor).x }
						A.deepEq(s.terms[i], want, id .. " term " .. i)
						sum += w.w
					end
					A.near(sum, 1, 1e-12, id .. " " .. s.step .. " Σw")
				end
				A.eq(Dump.canonical(report.steps[1].factors), Dump.canonical(report.steps[2].factors),
					id .. ": Smelting and Hammering on All's factors")
				A.truthy(Dump.canonical(report.steps[3].factors) ~= Dump.canonical(report.steps[2].factors),
					id .. ": Sharpening on the Blade's")
			end
			-- C10's 2 Enclosed blocks and 2 Dust specks would add to All's PartCount: they are in no set
			local c10 = fixtureCore("C10")
			local report = run(c10)
			A.deepEq(cleanedIds(report), { 21, 22, 23, 24 })
			local all = 0
			for _, p in c10.parts do
				all += math.min(1, Gen.volume(p) / Dif.V_PART_FULL)
			end
			A.truthy(factorOf(report.steps[1], "PartCount").raw < all - 0.5, "the cleaned parts left out")
			-- A27: its hilt 0.04 off x = 0 is in All's Asymmetry, not in the Blade's
			local a27, f1 = run(fixtureCore("A27")), run(fixtureCore("F1"))
			A.eq(a27.steps[3].d, f1.steps[3].d, "A27's Sharpening is F1's")
			A.deepEq({ f1.steps[2].d, a27.steps[2].d, a27.steps[3].d }, { 0.1037, 0.1537, 0.0989 }, "A27")
		end)

	t.it("T-DIF-09 a planted CraftPlans is followed: a disabled step left out, an extra step played on its set",
		function()
			local rows = Build.copy(CraftPlans.Sword.steps) :: any
			rows[2].enabled = false
			table.insert(rows, { step = "Finishing", weight = 0.40, worksOn = "All", feeds = {}, enabled = true })
			local plan = { type = "Sword", steps = rows }
			local plans = { Sword = plan, ordered = { plan }, get = function(id: string): any
				return if id == "Sword" then plan else nil
			end }
			local analyze = D.plantedPhysics({ craftPlans = plans }).analyze
			local f5 = fixtureCore("F5")
			local planted, real = analyze.run(f5), run(f5)
			local played: { string } = {}
			for _, s in planted.steps do
				table.insert(played, s.step)
			end
			A.deepEq(played, { "Smelting", "Sharpening", "Finishing" }, "Hammering disabled, Finishing appended")
			A.eq(Dump.canonical(planted.steps[1]), Dump.canonical(real.steps[1]), "Smelting")
			A.eq(Dump.canonical(planted.steps[2]), Dump.canonical(real.steps[3]), "Sharpening")
			-- Finishing weighs SurfaceComplexity alone, on All's factors
			local finishing = planted.steps[3]
			A.eq(Dump.canonical(finishing.factors), Dump.canonical(real.steps[1].factors), "All's factors")
			local x = factorOf(finishing, "SurfaceComplexity").x
			A.eq(finishing.g, Quantize.q(x, Quantize.SCALAR_SCALE), "Finishing g")
		end)

	-- §17.1 O8 **[Decision to confirm]**: the label of what shows counts, so a blade labelled Guard leaves the Blade.
	t.it("T-DIF-09 O8's label rule: F3's blade labelled Guard, Sharpening 0.6104 → 0.0645; C08's 0.2487 → 0", function()
		local cases = {
			{ id = "F3", part = 6, before = 0.6104, after = 0.0645 },
			{ id = "C08", part = 4, before = 0.2487, after = 0 },
		}
		for _, c in cases do
			local parts = copyParts(fixtureCore(c.id))
			parts[c.part].slot = "Guard"
			local before, after = run(fixtureCore(c.id)), run(canonical(c.id .. " relabelled", parts))
			A.truthy(after.validation.ok, c.id .. " relabelled is valid")
			A.eq(before.steps[3].d, c.before, c.id)
			A.eq(after.steps[3].d, c.after, c.id .. " relabelled: " .. dLine(after))
			A.eq(after.steps[1].d, before.steps[1].d, c.id .. " Smelting, on All")
			A.eq(after.steps[2].d, before.steps[2].d, c.id .. " Hammering, on All")
		end
	end)

	t.it("T-DIF-10 client path = server path = measureInvalid on F1–F5 and C09, by Dump.canonical", function()
		for _, id in { "F1", "F2", "F3", "F4", "F5", "C09" } do
			clientServer(fixtureCore(id), id)
		end
	end)

	t.slow("T-DIF-10 client path = server path = measureInvalid, FUZZ_N_VALID designs, by Dump.canonical", function()
		Prop.check(Tol.FUZZ_N_VALID, function(rng: Rng): any
			return Gen.validSword(rng, CTX)
		end, function(core: any)
			clientServer(core, core.name)
		end)
	end)
end)
