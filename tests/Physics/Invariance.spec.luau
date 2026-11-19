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
--             + 0.3317, F1 at + 0.125, C09 0.0013 either way along Z) every step's g, m, d and tiers to the bit, every
--             factor within 1e-12 (its last bits follow the rounding of the moved coordinates) and cutIndex kept: the
--             whole-design shift fix (§17.1 O11 (j)) counts both ranks' heights in RANK_Q and places each kept part in the
--             measure's across from the kept parts it ties with, in RANK_Q (no point of the design's own; the verdict's
--             rank reads the world's planes, so near copies that straddle z = 0 swap under a Z move, G the same, round 3),
--             leaves a part that only touches another out of its higher parts, keeps an overlap box's cells off a whole
--             number's rounding, counts Asymmetry's candidates and contact a hair past their reach, sums G's x on a 1e-9
--             grid, each pinned below on the design it moved; a Y shift that keeps the raster's cells (its samples lie on no
--             face) keeps the outline (Douglas–Peucker on the integer lattice: L3's option (a), fix round 1), so every
--             step's EdgeLength to the bit: a Thinness probe on another part's face, which the shift's rounding moved
--             (F1's and F5's tip at + 0.125, ΔG 0.0007), reads that part as met (§17.1 O11's face tie, fix round 2).
--             On Gen designs the same for their Y draw alone, and steps to the bit for Y and Z together. X shifts move
--             only Asymmetry and the edge, which stand on x = 0 (§5.2, §4.6): P5 0.0013 along −X keeps every other
--             factor.
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
-- The fixtures run in --quick but for the heaviest cases the shift fix added, which §14.6 names; the Gen corpora
-- (FUZZ_N_VALID designs) are t.slow, so that --quick stays under §14.1's 30 s (the M3 plan's [9.4]). The measured
-- values the plan has "printed" are in docs/build/M3-notes.md: the specs print nothing.

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
local Mirror = require("../../src/shared/Blueprint/Mirror")
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

-- A copy of core moved dx along X (Gen.translate moves Y and Z only: an X move is a real change to Asymmetry and the
-- edge, which stand on x = 0).
local function movedX(core: any, dx: number): any
	local out = Gen.copy(core)
	for _, p in out.parts do
		p.pos = { p.pos[1] + dx + 0, p.pos[2], p.pos[3] }
	end
	return out
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

-- T-DIF-07 (a): a whole design moved along Y or Z: the same parts kept, every step's g, m, d, tierRaw and tier to the
-- bit, every factor's raw within 1e-12 but those in skip (an X move's Asymmetry and EdgeLength), cutIndex within 1e-12.
local function sameSteps(report: any, base: any, what: string, skip: { [string]: boolean }?)
	A.truthy(report.validation.ok == base.validation.ok, what .. ": validity")
	A.deepEq(report.physics.kept, base.physics.kept, what .. ": the parts kept")
	for i, s in report.steps do
		local b = base.steps[i]
		for _, field in { "g", "m", "d", "tierRaw", "tier" } do
			A.eq(s[field], b[field], what .. " " .. s.step .. " " .. field)
		end
		for k, f in s.factors do
			if not (skip and skip[f.factor]) then
				A.near(f.raw, b.factors[k].raw, 1e-12, what .. " " .. s.step .. " " .. f.factor)
			end
		end
	end
	if not skip then
		A.near(report.physics.cutIndex, base.physics.cutIndex, 1e-12, what .. " cutIndex")
	end
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

-- T-DIF-07 (a), a Y shift: where the raster's cells are kept, every step's EdgeLength (raw) to the bit; whether the
-- raster was kept (T-EDG-01 6 holds it).
local function yKept(report: any, base: any, what: string): boolean
	if report.edge.cell ~= base.edge.cell or report.edge.bladeArea ~= base.edge.bladeArea then
		return false
	end
	for i, s in report.steps do
		local b = base.steps[i]
		A.eq(factorOf(s, "EdgeLength").raw, factorOf(b, "EdgeLength").raw, what .. " " .. s.step .. " EdgeLength")
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
				sameSteps(report, base, what)
				if o[3] == 0 then
					A.truthy(yKept(report, base, what), what .. ": the raster kept")
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

-- (a) translated, the steps to the bit and every factor within 1e-12 (sameSteps), and its Y draw alone the same and
-- EdgeLength to the bit (yKept); (b) re-cut flush, Volume and EdgeLength within TOL_FACTOR_ABS.
local function genCorpus(n: number)
	Prop.check(n, function(rng: Rng): any
		local core = Gen.validSword(rng, CTX)
		local moved, delta = Gen.translated(rng, CTX, core)
		local cut, ids = Gen.segmented(rng, CTX, core)
		return { core = core, moved = moved, delta = delta, cut = cut, cutIds = ids }
	end, function(input: any)
		local base = run(input.core)
		sameSteps(run(input.moved), base, string.format("moved (0, %.4f, %.4f)", input.delta[2], input.delta[3]))
		local what = string.format("moved (0, %.4f, 0)", input.delta[2])
		local alongY = run(Gen.translate(input.core, input.delta[2], 0))
		sameSteps(alongY, base, what)
		A.truthy(yKept(alongY, base, what), what .. ": the raster kept")
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

	t.slow("T-DIF-04 a hidden Grip part steers no rank: C09 with a Grip block enclosed in its grip, off its axis, reads "
		.. "C09's steps and edge", function()
			-- the verdict's rank reads the world's planes and the measure's places a kept part across from the kept parts it
			-- ties with on volume and height (§4.4): the block moves neither, so it cannot reorder C09's bevels, twins at ±z
			-- (placed from every Grip part's point, the shift fix's first round: Hammering 0.3201 → 0.3196)
			local parts = copyParts(fixtureCore("C09"))
			table.insert(parts, P(19, "Grip", "Block", "Iron", { 0, 0.88, 0.03 }, I, { 0.04, 0.5, 0.02 }))
			checkPair({ name = "C09 + a Grip block off its axis", base = fixtureCore("C09"),
				filled = canonical("C09 + a grip block", parts), cleaned = { 19 } })
		end)

	-- The shift fix's round 2 (§4.4, §17.1 O11 (j)): each case below moved a tier on the first round's tree, whose ranks
	-- placed a part from the grip's point, and fails again with it (M3-notes, fixer U).
	t.it("T-DIF-04 a hidden Grip part chooses no Grip copy: P5 with its grip again 4e-8 or 4e-9 along +X, and a Grip "
		.. "speck against the grip's +X face or inside it, keeps the copy kept and reads P5's steps", function()
			-- a near copy's faces lie within EPS_GEOM of the grip's, so the verdict's rank keeps one of the two. Placed from
			-- every Grip part's point, the speck moved it past the copies' midpoint, the verdict kept the copy, the kept
			-- grip's point moved 4e-8 or 4e-9, and P5's teeth, twins at ±0.14 about it, swapped in the measure: Hammering
			-- 0.2167 Hard → 0.1902 Normal (f7ac37d 0.2167). The verdict's rank reads the world's planes, which no speck moves
			local base = run(fixtureCore("P5"))
			for _, case in { { 4e-8, 0.105, 0.05 }, { 4e-9, 0.03, 0.02 } } do
				local parts = copyParts(fixtureCore("P5"))
				table.insert(parts, P(16, "Grip", "Block", "Iron", { case[1], 0.75, 0 }, I, { 0.16, 0.9, 0.16 }))
				table.insert(parts, P(17, "Grip", "Block", "Iron", { case[2], 0.75, 0 }, I, { case[3], case[3], case[3] }))
				local what = string.format("P5 + a grip copy %g along +X + a Grip speck at x %g", case[1], case[2])
				local report = run(canonical("P5 + a grip copy + a speck", parts))
				A.truthy(report.validation.ok, what .. ": valid")
				A.truthy(report.physics.kept[2] and not report.physics.kept[16], what .. ": the grip kept, its copy cleaned")
				A.falsy(report.physics.kept[17], what .. ": the speck cleaned")
				for i, s in report.steps do
					for _, field in { "g", "m", "d", "tierRaw", "tier" } do
						A.eq(s[field], base.steps[i][field], what .. " " .. s.step .. " " .. field)
					end
				end
			end
		end)

	t.it("T-DIF-04 a hidden part steers no ownership: F5 with two Blade twins overlapping at its face, Iron at −x and "
		.. "Steel at +x, and a third twin hidden in its blade off the axis: every owned volume, the mass and the steps",
		function()
			-- ownership, the measure and the walks take the measure's rank, whose ties are the kept parts alone (§4.3,
			-- §4.4): the hidden twin, tied with them on volume and height, would move their centre to x 0.01 and hand
			-- their overlap to the Steel one (the Iron twin's owned volume 0.0018 → 0.00072). In the first round a Grip
			-- block hidden in the pommel did the same through the grip's point
			local parts = copyParts(fixtureCore("F5"))
			table.insert(parts, P(6, "Blade", "Block", "Iron", { -0.02, 2.0, 0.045 }, I, { 0.1, 0.6, 0.03 }))
			table.insert(parts, P(7, "Blade", "Block", "Steel", { 0.02, 2.0, 0.045 }, I, { 0.1, 0.6, 0.03 }))
			local base = run(canonical("F5 + twins", parts))
			table.insert(parts, P(8, "Blade", "Block", "Iron", { 0.03, 2.0, 0 }, I, { 0.1, 0.6, 0.03 }))
			local report = run(canonical("F5 + twins + a hidden twin", parts))
			A.eq(report.physics.kept[8], false, "the third twin is cleaned")
			for k = 1, 7 do
				A.eq(report.physics.ownedVolume[k], base.physics.ownedVolume[k], "owned volume " .. k)
			end
			A.eq(report.physics.mass, base.physics.mass, "mass")
			sameDifficulty(report, base, "F5 + twins + a hidden twin")
		end)

	-- F2 with a sealed Iron box on its blade's top (walls 0.02, 0.3 across), its cavity filled by two hidden fillers of one
	-- size and height that overlap 0.1 along Z, Iron at −z and the other at +z (V2's review round 3, laid along Z).
	local function boxedF2(other: string): { Part }
		local parts = copyParts(fixtureCore("F2"))
		for _, q in {
			P(11, "Blade", "Block", "Iron", { 0, 3.96, 0 }, I, { 0.3, 0.02, 0.3 }),
			P(12, "Blade", "Block", "Iron", { 0, 4.24, 0 }, I, { 0.3, 0.02, 0.3 }),
			P(13, "Blade", "Block", "Iron", { -0.14, 4.1, 0 }, I, { 0.02, 0.26, 0.3 }),
			P(14, "Blade", "Block", "Iron", { 0.14, 4.1, 0 }, I, { 0.02, 0.26, 0.3 }),
			P(15, "Blade", "Block", "Iron", { 0, 4.1, -0.14 }, I, { 0.26, 0.26, 0.02 }),
			P(16, "Blade", "Block", "Iron", { 0, 4.1, 0.14 }, I, { 0.26, 0.26, 0.02 }),
			P(17, "Blade", "Block", "Iron", { 0, 4.1, -0.04 }, I, { 0.26, 0.26, 0.18 }),
			P(18, "Blade", "Block", other, { 0, 4.1, 0.04 }, I, { 0.26, 0.26, 0.18 }),
		} do
			table.insert(parts, q)
		end
		return parts
	end

	t.slow("T-DIF-04 a hidden part steers no ownership among hidden parts: F2 with a sealed box on its blade's top filled by "
		.. "two hidden fillers, Iron at −z and Steel at +z with the Steel one again in place (Ctrl+D), or both Iron with the "
		.. "+z one again in place or the whole moved 0.05 along ±Z: every owned volume, the mass, the balance and the steps",
		function()
			-- the fillers fill the cavity, so both are Enclosed and own what no kept part does, their overlap going to the one
			-- ranked first. Placed from the centre of the cleaned parts it tied with (the shift fix's rounds 2 and 3), the copy
			-- pulled that centre to z 0.0133 and handed the overlap to the Steel one: mass 1.29371984 → 1.29358464, balance
			-- 0.387402 → 0.387166, G the same (f7ac37d the same with the copy). Placed from the centre of the kept parts, after
			-- the material, no hidden part moves it, and the move keeps it; from the world's planes, as on f7ac37d, the move
			-- carried the Iron twins' midpoint past z = 0 and handed the overlap to the other (§4.3)
			local cases: { { what: string, r: any, b: any } } = {}
			local base = run(canonical("F2 + a filled box", boxedF2("Steel")))
			local copied = boxedF2("Steel")
			table.insert(copied, P(19, "Blade", "Block", "Steel", { 0, 4.1, 0.04 }, I, { 0.26, 0.26, 0.18 }))
			local report = run(canonical("F2 + a filled box + a copy", copied))
			A.deepEq(cleanedIds(report), { 17, 18, 19 }, "the fillers and the copy cleaned")
			sameDifficulty(report, base, "F2 + a filled box + a copy")
			table.insert(cases, { what = "F2 + a filled box + a copy", r = report, b = base })
			local twins = run(canonical("F2 + a box filled with Iron", boxedF2("Iron")))
			-- of one material the place decides, so a copy that joined their ties' centre (z 0.0133), or a hidden part that
			-- joined the kept parts', would hand the overlap to the +z one, and a centre a move shifts (the world's planes, or
			-- the kept parts' centres summed, not averaged) would hand it over one way or the other
			local ironCopied = boxedF2("Iron")
			table.insert(ironCopied, P(19, "Blade", "Block", "Iron", { 0, 4.1, 0.04 }, I, { 0.26, 0.26, 0.18 }))
			local ironReport = run(canonical("F2 + an Iron box + a copy", ironCopied))
			A.deepEq(cleanedIds(ironReport), { 17, 18, 19 }, "the Iron fillers and the copy cleaned")
			sameDifficulty(ironReport, twins, "F2 + a box filled with Iron + a copy")
			table.insert(cases, { what = "F2 + a box filled with Iron + a copy", r = ironReport, b = twins })
			for _, dz in { -0.05, 0.05 } do
				local what = "F2 + a box filled with Iron moved 0.05 " .. (if dz < 0 then "down" else "up") .. " Z"
				local moved = run(Gen.translate(canonical("F2 + a box filled with Iron", boxedF2("Iron")), 0, dz))
				sameSteps(moved, twins, what)
				table.insert(cases, { what = what, r = moved, b = twins })
			end
			for _, case in cases do
				local what, r, b = case.what, case.r, case.b
				for k = 1, #b.physics.ownedVolume do
					A.near(r.physics.ownedVolume[k], b.physics.ownedVolume[k], 1e-15, what .. ": owned volume " .. k)
				end
				A.near(r.physics.mass, b.physics.mass, 1e-12, what .. ": mass")
				A.near(r.physics.balance, b.physics.balance, 1e-12, what .. ": balance")
			end
		end)

	t.it("T-DIF-04 a Ctrl+D copy left in place joins no higher set: F2 with a sealed box on its blade's top, two Guard "
		.. "fillers that overlap and a Pommel filler under them and a wall, one of the Guard ones again in place, relabelled "
		.. "Pommel or in Steel, or the wall again; a Pommel filler in the cavity's corner under two walls, the first again; "
		.. "two Guard fillers at one centre: every owned volume, the mass and the balance", function()
			-- the Pommel filler has three higher parts, so its overlap is clipped exactly and it owns the 0.001 of it that lies
			-- in the cavity's gap; counted among them, the copy made four (MAX_EXACT), sampled in cells 0.0114 across that
			-- read the gap as covered: it owned 6e-17, mass −3.148e-4 kg, balance −5.53e-4 (f7ac37d the same) (§4.3). An
			-- exact copy is one whatever its slot or material and whether its original is kept, and it is compared with every
			-- part already counted: a kept wall's copy comes after every kept part, so in the corner it does not follow its
			-- original (walls 13 and 15, then the copy: counted, −2.188e-4 kg)
			local function box(fillers: { Part }): { Part }
				local parts = copyParts(fixtureCore("F2"))
				for _, q in {
					P(11, "Blade", "Block", "Iron", { 0, 3.96, 0 }, I, { 0.3, 0.02, 0.3 }),
					P(12, "Blade", "Block", "Iron", { 0, 4.24, 0 }, I, { 0.3, 0.02, 0.3 }),
					P(13, "Blade", "Block", "Iron", { -0.14, 4.1, 0 }, I, { 0.02, 0.26, 0.3 }),
					P(14, "Blade", "Block", "Iron", { 0.14, 4.1, 0 }, I, { 0.02, 0.26, 0.3 }),
					P(15, "Blade", "Block", "Iron", { 0, 4.1, -0.14 }, I, { 0.26, 0.26, 0.02 }),
					P(16, "Blade", "Block", "Iron", { 0, 4.1, 0.14 }, I, { 0.26, 0.26, 0.02 }),
				} do
					table.insert(parts, q)
				end
				for _, q in fillers do
					table.insert(parts, q)
				end
				return parts
			end
			local function filled(): { Part }
				return box({
					P(17, "Guard", "Block", "Iron", { 0, 4.1, -0.034 }, I, { 0.258, 0.258, 0.19 }),
					P(18, "Guard", "Block", "Iron", { 0, 4.1, 0.045 }, I, { 0.258, 0.258, 0.19 }),
					P(21, "Pommel", "Block", "Iron", { -0.1, 4.1, 0 }, I, { 0.08, 0.2, 0.2 }),
				})
			end
			local function sameAs(b: any, parts: { Part }, what: string): any
				local report = run(canonical("F2 + a box + a copy", parts))
				for k = 1, #b.physics.ownedVolume do
					A.near(report.physics.ownedVolume[k], b.physics.ownedVolume[k], 1e-15, what .. ": owned volume " .. k)
				end
				A.near(report.physics.mass, b.physics.mass, 1e-12, what .. ": mass")
				A.near(report.physics.balance, b.physics.balance, 1e-12, what .. ": balance")
				return report
			end
			local base = run(canonical("F2 + a filled box", filled()))
			A.near(base.physics.ownedVolume[13], 4e-5, 1e-15, "the Pommel filler owns the gap's slice")
			for _, case in {
				{ what = "a Guard filler again",
					copy = P(22, "Guard", "Block", "Iron", { 0, 4.1, -0.034 }, I, { 0.258, 0.258, 0.19 }) },
				{ what = "it relabelled Pommel",
					copy = P(22, "Pommel", "Block", "Iron", { 0, 4.1, -0.034 }, I, { 0.258, 0.258, 0.19 }) },
				{ what = "it in Steel",
					copy = P(22, "Guard", "Block", "Steel", { 0, 4.1, -0.034 }, I, { 0.258, 0.258, 0.19 }) },
				{ what = "wall 13 again",
					copy = P(22, "Blade", "Block", "Iron", { -0.14, 4.1, 0 }, I, { 0.02, 0.26, 0.3 }) },
			} do
				local copied = filled()
				table.insert(copied, case.copy)
				local report = sameAs(base, copied, "F2 + a filled box + " .. case.what)
				A.deepEq(cleanedIds(report), { 17, 18, 21, 22 }, case.what .. ": the fillers and the copy cleaned")
			end
			local corner = box({
				P(17, "Guard", "Block", "Iron", { 0, 4.1, 0 }, I, { 0.258, 0.258, 0.258 }),
				P(21, "Pommel", "Block", "Iron", { -0.1, 4.1, -0.1 }, I, { 0.08, 0.2, 0.08 }),
			})
			local cornerBase = run(canonical("F2 + a box", corner))
			A.near(cornerBase.physics.ownedVolume[#corner], 2.78e-5, 1e-15, "the corner filler owns the gaps' slivers")
			table.insert(corner, P(22, "Blade", "Block", "Iron", { -0.14, 4.1, 0 }, I, { 0.02, 0.26, 0.3 }))
			sameAs(cornerBase, corner, "F2 + a box, a corner filler + wall 13 again")
			-- a part at another's centre is no copy of it: the second Guard filler 0.258 × 0.19 × 0.2 at the first's centre
			-- (the cavity no longer full, all three show and are kept) still covers the Pommel filler from z 0.061 to 0.066
			-- between y 4.005 and 4.195, so it owns the gap's slice and 0.069 × (0.2 × 0.034 + 0.01 × 0.005), exactly
			local crossed = box({
				P(17, "Guard", "Block", "Iron", { 0, 4.1, -0.034 }, I, { 0.258, 0.258, 0.19 }),
				P(18, "Guard", "Block", "Iron", { 0, 4.1, -0.034 }, I, { 0.258, 0.19, 0.2 }),
				P(21, "Pommel", "Block", "Iron", { -0.1, 4.1, 0 }, I, { 0.08, 0.2, 0.2 }),
			})
			local report = run(canonical("F2 + a box", crossed))
			A.near(report.physics.ownedVolume[#crossed], 4e-5 + 0.069 * (0.2 * 0.034 + 0.01 * 0.005), 1e-15,
				"the Pommel filler under two fillers at one centre")
		end)

	t.it("T-DIF-07 (c) ids decide nothing between hidden twins: F2 with two Iron Dust Balls 0.07 across, one 0.005 into "
		.. "its guard's front face and one 0.03 further out along +Z, owns the same volumes, mass, centre of mass and "
		.. "balance whichever has the lower id, and in the design's Z image", function()
			-- the twins tie on volume, height and material, so where each stands from the kept parts' centre decides which
			-- owns their overlap, the nearer, whatever their ids. Left to the index, the order also chose which of them
			-- samples the guard's overlap and theirs in one box, in its own frame (§4.3): mass 1.08372 or 1.08351 kg,
			-- balance −0.056862 or −0.056872, by the ids alone; f7ac37d and the shift fix's rounds 1–3 the same either way
			local function twins(idNear: number, idFar: number): any
				local parts = copyParts(fixtureCore("F2"))
				table.insert(parts, P(idNear, "Guard", "Ball", "Iron", { 0.2, 1.45, 0.13 }, I, { 0.07, 0.07, 0.07 }))
				table.insert(parts, P(idFar, "Guard", "Ball", "Iron", { 0.2, 1.45, 0.16 }, I, { 0.07, 0.07, 0.07 }))
				return run(canonical("F2 + two Dust Balls", parts))
			end
			local a, b = twins(5, 6), twins(6, 5)
			A.deepEq(cleanedIds(a), { 5, 6 }, "F2 + two Dust Balls: both Dust")
			A.eq(a.physics.ownedVolume[5], b.physics.ownedVolume[6], "the nearer Ball owns the same, either id")
			A.eq(a.physics.ownedVolume[6], b.physics.ownedVolume[5], "the farther Ball owns the same, either id")
			A.eq(a.physics.mass, b.physics.mass, "mass")
			A.eq(a.physics.balance, b.physics.balance, "balance")
			for k = 1, 3 do
				A.eq(a.physics.com[k], b.physics.com[k], "com " .. k)
			end
			-- the image keeps which stands nearer the kept parts' centre, |z| before z (by the signed place the farther, at
			-- z −0.16, would come first and own the overlap)
			local parts = copyParts(fixtureCore("F2"))
			table.insert(parts, P(5, "Guard", "Ball", "Iron", { 0.2, 1.45, 0.13 }, I, { 0.07, 0.07, 0.07 }))
			table.insert(parts, P(6, "Guard", "Ball", "Iron", { 0.2, 1.45, 0.16 }, I, { 0.07, 0.07, 0.07 }))
			local images = copyParts(canonical("F2 + two Dust Balls", parts))
			for i, p in images do
				images[i] = Mirror.reflect(p :: any, "Z") :: any
			end
			local image = run(canonical("F2 + two Dust Balls, Z image", images))
			for k = 1, #a.physics.ownedVolume do
				A.near(image.physics.ownedVolume[k], a.physics.ownedVolume[k], 1e-15, "its Z image: owned volume " .. k)
			end
			A.near(image.physics.mass, a.physics.mass, 1e-15, "its Z image: mass")
			A.near(image.physics.balance, a.physics.balance, 1e-15, "its Z image: balance")
		end)

	t.slow("T-DIF-07 (c) a mirror image keeps who owns a hidden overlap: F2 with two Dust Wedges 0.07 turned 30° about Z, "
		.. "the editor's mirror copies across x = 0 overlapping on its guard's front face, of one material or Iron and "
		.. "Steel: its Z image's owned volumes part by part, mass and balance, and its X image's mass and balance (with "
		.. "Iron and Steel its owned volumes too)", function()
			-- a cleaned part's turn as given, which a mirror image rewrites, comes after the material and where it stands from
			-- the kept parts' centre (§4.3). Before them, as in the reviewers' repair, the Z image reordered the copies and
			-- gave their overlap to the other, the mass 1.4e-6 kg off with Iron and Steel (f7ac37d the same either way)
			local h = math.sqrt(0.5 - 0.5 * math.sqrt(0.75)) -- sin 15°, cos 15°: 30° about Z
			local turn = { 0, 0, h, math.sqrt(1 - h * h) }
			for _, other in { "Iron", "Steel" } do
				local parts = copyParts(fixtureCore("F2"))
				local wedge = P(5, "Guard", "Wedge", "Iron", { 0.012, 1.45, 0.125 }, turn, { 0.07, 0.07, 0.07 })
				local copy = Mirror.reflect(wedge :: any, "X") :: any
				copy.id, copy.material = 6, other
				table.insert(parts, wedge)
				table.insert(parts, copy)
				local design = canonical("F2 + two Dust Wedges", parts)
				local before = run(design)
				A.deepEq(cleanedIds(before), { 5, 6 }, "F2 + two Dust Wedges, Iron and " .. other .. ": both Dust")
				-- across x = 0 the copies trade places, so with Iron and Steel only the material keeps their overlap with the
				-- Iron one (by the place alone the −x one, the other material here and Iron there, owns it); of one material
				-- they are twins about the kept parts' centre, which swap their owned volumes there, the residual §4.3 names
				for _, plane in { "Z", "X" } do
					local images = copyParts(design)
					for i, p in images do
						images[i] = Mirror.reflect(p :: any, plane :: Mirror.Plane) :: any
					end
					local what = "F2 + two Dust Wedges, Iron and " .. other .. ", its " .. plane .. " image"
					local report = run(canonical("F2 + two Dust Wedges, its image", images))
					if plane == "Z" or other == "Steel" then
						for k = 1, #before.physics.ownedVolume do
							A.near(report.physics.ownedVolume[k], before.physics.ownedVolume[k], 1e-15,
								what .. ": owned volume " .. k)
						end
					end
					A.near(report.physics.mass, before.physics.mass, 1e-15, what .. ": mass")
					A.near(report.physics.balance, before.physics.balance, 1e-15, what .. ": balance")
				end
			end
		end)

	t.it("T-DIF-04 a hidden part tied with kept ones reorders none of them: P5 with a Wedge of its teeth's size hidden in "
		.. "its blade at x 0.02, height 1.6, in the Guard slot, reads P5's steps and edge", function()
			-- the walks (Thinness, the edge) go in the measure's rank order, whose ties are kept parts (§4.4, §17.2):
			-- counted among P5's first teeth, twins at ±0.14, the hidden Wedge would move their centre to x 0.0067 and walk
			-- the +x tooth first (Hammering 0.2167 → 0.2117). The verdict's rank reads the world's planes, so it changes none
			local parts = copyParts(fixtureCore("P5"))
			table.insert(parts, P(16, "Guard", "Wedge", "Iron", { 0.02, 1.6, 0 }, parts[7].rot, { 0.08, 0.12, 0.06 }))
			checkPair({ name = "P5 + a hidden tooth", base = fixtureCore("P5"), filled = canonical("P5 + a hidden tooth", parts),
				cleaned = { 16 } })
		end)

	-- The shift fix's round 3 (§4.4, §17.1 O11 (j)): the verdict's rank reads the world's planes again, as on f7ac37d. Each
	-- case below moved a tier, or which near copy is kept, on the second round's tree, which placed the verdict's ties from
	-- their centre, hidden parts counted, and fails again with it (M3-notes, fixer W).
	t.slow("T-DIF-04 a hidden part chooses no near copy: C09 with its blade core 2.3 long and the core again 0.001 along "
		.. "+X, cleaned, reads the same steps with that copy again exactly, or the core again 0.0005 along +X", function()
			-- the copy shows a strip 0.001 wide and the core keeps the faces they share: the verdict's rank, from the world's
			-- planes, puts the core first whatever a player hides beside them. Ranked by |x| from the ties' centre, an exact
			-- copy of the copy (Ctrl+D) pulled the centre to it, or a third copy halfway sat on it, and that copy kept the
			-- faces: the core and it both kept, PartCount + 1, Joints 19.13 → 23.41, Sharpening 0.2110 Hard → 0.1967 Normal
			-- (f7ac37d 0.2110 either way, V1's review round 2)
			local parts = copyParts(fixtureCore("C09"))
			local core = Build.find(parts, 12) :: Part
			core.size[2] = 2.3
			table.insert(parts, P(19, "Blade", "Block", "Iron", { 0.001, core.pos[2], 0 }, I, table.clone(core.size)))
			local base = canonical("C09 + a near copy of its core", parts)
			for _, x in { 0.001, 0.0005 } do
				local filled = copyParts(base)
				table.insert(filled, P(20, "Blade", "Block", "Iron", { x, core.pos[2], 0 }, I, table.clone(core.size)))
				checkPair({ name = "C09 + a near copy of its core + a copy at x " .. x, base = base,
					filled = canonical("C09 + two copies of its core", filled), cleaned = { 19, 20 } })
			end
		end)

	-- Plausible #1940, a laminate on C02 (a Steel core 0.03 between two cheeks 0.02), with its core again 0.002 along +Z.
	local function laminate1940(): { Part }
		local parts = copyParts(fixtureCore("C02"))
		table.insert(parts, P(7, "Blade", "Block", "Iron", { 0, 2.65, 0.025 }, I, { 0.4, 2.5, 0.02 }))
		table.insert(parts, P(8, "Blade", "Block", "Iron", { 0, 2.65, -0.025 }, I, { 0.4, 2.5, 0.02 }))
		table.insert(parts, P(9, "Blade", "Block", "Steel", { 0, 2.65, 0 }, I, { 0.41, 2.5, 0.03 }))
		table.insert(parts, P(10, "Blade", "Block", "Steel", { 0, 2.65, 0.002 }, I, { 0.41, 2.5, 0.03 }))
		return parts
	end

	t.slow("T-DIF-04 a hidden part chooses no near copy: a laminate on C02 (plausible #1940) with its Steel core again 0.002 "
		.. "along +Z, cleaned, reads the same steps with that copy again exactly", function()
			-- the copy shows a strip 0.002 wide, the core keeps the faces they share. Ranked from the ties' centre, the copy's
			-- exact copy (Ctrl+D) pulled the centre past the copy, which then kept the faces and the core was cleaned:
			-- Sharpening 0.1950 Normal → 0.2099 Hard (V2's review round 2). From the world's planes the core, at z 0, comes
			-- first whatever is hidden beside it (f7ac37d the same)
			local base = canonical("#1940 + a near copy of its core", laminate1940())
			local filled = copyParts(base)
			table.insert(filled, P(11, "Blade", "Block", "Steel", { 0, 2.65, 0.002 }, I, { 0.41, 2.5, 0.03 }))
			checkPair({ name = "#1940 + a near copy of its core + its copy", base = base,
				filled = canonical("#1940 + two copies of its core", filled), cleaned = { 4, 10, 11 } })
		end)

	t.slow("T-DIF-07 (c) a mirror image keeps the near copy kept: the laminate on C02 (plausible #1940) with its core again "
		.. "0.002 along +Z, across z = 0, cleans the copy and reads its steps", function()
			-- ranked from their centre, the core and its copy were twins about it, so the image kept the copy and cleaned the
			-- core: Sharpening 0.1950 Normal → 0.2099 Hard (V2's review round 2). From the world's planes the core, at z 0,
			-- comes first in the image too, as on f7ac37d: only twins about z = 0 swap (§17.1 O11 (l))
			local base = canonical("#1940 + a near copy of its core", laminate1940())
			local images = copyParts(base)
			for i, p in images do
				images[i] = Mirror.reflect(p :: any, "Z") :: any
			end
			local report, before = run(canonical("#1940 + a near copy, its image", images)), run(base)
			A.deepEq(cleanedIds(before), { 4, 10 }, "the core kept, its copy cleaned")
			A.deepEq(cleanedIds(report), { 4, 10 }, "and so in the image")
			for i, s in report.steps do
				for _, field in { "g", "m", "d", "tierRaw", "tier" } do
					A.eq(s[field], before.steps[i][field], "#1940 + a near copy of its core, its image " .. s.step .. " " .. field)
				end
			end
		end)

	t.it("T-DIF-07 (c) ids decide no tier between near copies: P5's grip and a copy of it 3e-10 along +X, its teeth typed "
		.. "at ±0.1400000004, read the same steps whichever copy has the lower id", function()
			-- the verdict keeps the copy at x 0, from the world's planes, whichever has the lower id (in the second round
			-- their places, from their centre, rounded to one RANK_Q step and the index decided, as of exact copies). Placed
			-- from the kept grip's point, the teeth, half a step out, swapped with it: Hammering 0.2167 Hard or 0.1902 Normal
			-- by the ids alone (f7ac37d 0.2167 either way). In the measure the teeth rank from their own centre
			local function build(gripX: number, copyX: number): any
				local parts = copyParts(fixtureCore("P5"))
				parts[2].pos = { gripX, 0.75, 0 }
				for _, p in parts do
					if p.shape == "Wedge" then
						p.pos = { if p.pos[1] > 0 then 0.1400000004 else -0.1400000004, p.pos[2], p.pos[3] }
					end
				end
				table.insert(parts, P(16, "Grip", "Block", "Iron", { copyX, 0.75, 0 }, I, { 0.16, 0.9, 0.16 }))
				return canonical("P5 + a grip copy", parts)
			end
			local a, b = run(build(0, 3e-10)), run(build(3e-10, 0))
			for i, s in a.steps do
				for _, field in { "g", "m", "d", "tierRaw", "tier" } do
					A.eq(s[field], b.steps[i][field], "P5's grip copies 3e-10 apart, ids either way: " .. s.step .. " " .. field)
				end
			end
		end)

	t.slow("T-DIF-04 Gen.withFiller, FUZZ_N_VALID designs × Enclosed, Duplicate, Dust: every filler cleaned, steps "
		.. "and edge bit-identical", function()
		fillerCorpus(Tol.FUZZ_N_VALID)
	end)

	t.it("T-DIF-07 (a) C10, C11 and F1 at + 0.3317 in Y, where centred cells moved C10's and C11's G 0.0063 and 0.0031 "
		.. "and blueprint XY F1's EdgeLength, and F1 at + 0.125, where its tip's probes on the blade's face moved G 0.0007: "
		.. "the steps and EdgeLength to the bit, every factor within 1e-12, cutIndex kept", function()
			-- fix round 1 reads each cell off its centre and runs Douglas–Peucker on the integer lattice; every F and C
			-- fixture × E-S2.10's offsets is the slow case (moved there to keep --quick under 27 s), and T-EDG-01 6 holds
			-- their 111 copies' edges fast
			for _, dy in { 0.3317, 0.125 } do
				local ids: { string } = if dy == 0.125 then { "F1" } else { "C10", "C11", "F1" }
				for _, id in ids do
					local core = fixtureCore(id)
					local base, report = run(core), run(Gen.translate(core :: any, dy, 0))
					local what = string.format("%s + (0, %g, 0)", id, dy)
					sameSteps(report, base, what)
					A.truthy(yKept(report, base, what), what .. ": the raster kept")
				end
			end
		end)

	-- The whole-design shift fix (§17.1 O11 (j)): each case below moved G, Joints or a verdict on f7ac37d under a move
	-- that keeps every part in the hitbox, and fails again with its guard reverted alone (M3-notes, fixer S).
	t.slow("T-DIF-07 (a) a whole design moved keeps the measure's rank (§4.4, its kept parts placed from their ties' centre "
		.. "in RANK_Q): C09 0.0013 along ±Z its steps, P5 0.0013 along −X its Thinness; X01's near copies 0.037 along Z its "
		.. "steps, the verdict's rank from the world's planes", function()
			-- ranked from the world's planes, |z| before z, the measure reordered C09's bevels, twins at ±z (Hammering 0.3201
			-- → 0.3196 at −0.0013; at +0.0013 the same but for RANK_Q, whose places tie exactly whatever the rounding), and
			-- |x| moved P5's Thinness 0.0662 at −0.0013 along X (Hammering Hard → Normal). An X move still moves Asymmetry
			-- and the edge, which stand on x = 0 (here only the raster's mean thickness: cutIndex 4.3e-5). The verdict's rank
			-- reads the world's planes, which no hidden part moves (§4.4): X01's blade at z 0 keeps the faces it shares with
			-- its copies at ±0.003, but moved 0.037 either way along Z all three stand on one side of z = 0, the copy
			-- nearest it keeps them and the blade, between the copies, is cleaned (PartCount 6.18 → 5.18, Joints 12.27 →
			-- 8.28), G the same, as on f7ac37d: §17.1 O11 (j)'s near copies, pinned
			local x01 = fixtureCore("X01")
			local base = run(x01)
			A.deepEq(cleanedIds(base), {}, "X01 as built: every copy kept")
			for _, dz in { 0.037, -0.037 } do
				local what = string.format("X01 + (0, 0, %g)", dz)
				local moved = run(Gen.translate(x01 :: any, 0, dz))
				A.deepEq(cleanedIds(moved), { 4 }, what .. ": the blade between its copies cleaned")
				for i, s in moved.steps do
					for _, field in { "g", "m", "d", "tierRaw", "tier" } do
						A.eq(s[field], base.steps[i][field], what .. " " .. s.step .. " " .. field)
					end
				end
			end
			local c09 = fixtureCore("C09")
			local c09Base = run(c09)
			for _, dz in { 0.0013, -0.0013 } do
				sameSteps(run(Gen.translate(c09 :: any, 0, dz)), c09Base, string.format("C09 + (0, 0, %g)", dz))
			end
			local p5 = fixtureCore("P5")
			local p5Moved = run(movedX(p5, -0.0013))
			sameSteps(p5Moved, run(p5), "P5 + (-0.0013, 0, 0)", { Asymmetry = true, EdgeLength = true })
			A.eq(p5Moved.steps[2].tier, "Hard", "P5 + (-0.0013, 0, 0): Hammering's tier")
		end)

	t.slow("T-DIF-07 (a) twins whose heights differ in the last bit tie on height, so a whole design moved keeps their "
		.. "order (§4.4, the height in RANK_Q): P5 with tooth 7 at 1.4 + 0.2 reads P5's steps, moved 0.13 along Y too, "
		.. "and with tooth 6 an ulp up moved 0.411; F2 with its blade again an ulp lower keeps the blade", function()
			-- a tooth dragged from 1.4 by 0.2 stands at 1.5999999999999999, its twin typed at 1.6 at 1.6000000000000001.
			-- Ranked by the raw height the lower came first (Hammering 0.2117), and a move that rounds both to one height
			-- (0.13: 1.73 both) left the order to the place: the twins swapped (Thinness 0.41266 → 0.42522, Hammering
			-- 0.2117 → 0.2167; f7ac37d the same)
			local p5 = run(fixtureCore("P5"))
			local low = copyParts(fixtureCore("P5"))
			low[7].pos = { low[7].pos[1], 1.4 + 0.2, low[7].pos[3] }
			A.truthy(low[7].pos[2] < low[6].pos[2], "the tooth an ulp under its twin")
			local high = copyParts(fixtureCore("P5"))
			high[6].pos = { high[6].pos[1], 1.6000000000000003, high[6].pos[3] }
			local cases: { { parts: { Part }, dy: number } } = { { parts = low, dy = 0.13 }, { parts = high, dy = 0.411 } }
			for _, case in cases do
				local core = canonical("P5, a tooth an ulp off its twin", case.parts)
				local base = run(core)
				sameSteps(base, p5, "P5, a tooth an ulp off its twin")
				local what = string.format("P5, a tooth an ulp off + (0, %g, 0)", case.dy)
				sameSteps(run(Gen.translate(core, case.dy, 0)), base, what)
			end
			-- the verdict's rank alike: F2's blade again an ulp lower ties with it, so the lower id keeps their faces as of
			-- an exact copy (A17), as built and moved (ranked by the raw height, the copy was kept as built and the blade
			-- wherever a move rounded the two to one height)
			local parts = copyParts(fixtureCore("F2"))
			table.insert(parts, P(5, "Blade", "Block", "Iron", { 0, 2.75 - 4.440892098500626e-16, 0 }, I, { 0.2, 2.4, 0.08 }))
			local copied = canonical("F2, its blade an ulp lower", parts)
			local base = run(copied)
			A.truthy(base.physics.kept[4] and not base.physics.kept[5], "the blade kept, the copy cleaned")
			sameSteps(run(Gen.translate(copied, 0.4, 0)), base, "F2, its blade an ulp lower + (0, 0.4, 0)")
		end)

	t.it("T-DIF-07 a sub-visible move of the grip alone reorders no twins (§4.4): P5 with its grip 1e-9 along +X or +Z "
		.. "plays P5's steps", function()
			-- placed from the grip's point, 1e-9 along +X swapped P5's teeth, twins at ±0.14 about it: Hammering 0.2167
			-- Hard → 0.1902 Normal; of every 3rd plausible design 13.4 % moved G so (M3-notes, Reviewer V1)
			local base = run(fixtureCore("P5"))
			for _, move in { { 1, 1e-9 }, { 3, 1e-9 } } do
				local parts = copyParts(fixtureCore("P5"))
				local pos = table.clone(parts[2].pos)
				pos[move[1]] += move[2]
				parts[2].pos = pos
				local what = string.format("P5, its grip %g along %s", move[2], if move[1] == 1 then "X" else "Z")
				local report = run(canonical(what, parts))
				for i, s in report.steps do
					for _, field in { "g", "m", "d", "tierRaw", "tier" } do
						A.eq(s[field], base.steps[i][field], what .. " " .. s.step .. " " .. field)
					end
				end
			end
		end)

	t.slow("T-DIF-07 (a) a part that only touches another face to face is above it at no shift (§4.3): C09's pommel "
		.. "housed in a block (E-S2.11's pommelInBlock family), moved along Y, keeps every owned volume and its steps",
		function()
			-- the ownership's box test took a flush part in or left it out by the rounding of the faces, and with it the
			-- jobs' boxes and the ladder of every sampled overlap: 0.0013 down Y moved 10 owned volumes, M2's volume
			-- 1.9e-5, on f7ac37d
			local parts = copyParts(fixtureCore("C09"))
			table.insert(parts, P(19, "Pommel", "Block", "Iron", { 0, 0.3395, 0 }, I, { 0.3, 0.3, 0.3 }))
			local core = canonical("C09 housed", parts)
			local base = run(core)
			for _, dy in { 0.0013, -0.0013, 0.037, 0.3317 } do
				local what = string.format("C09 housed + (0, %g, 0)", dy)
				local report = run(Gen.translate(core, dy, 0))
				sameSteps(report, base, what)
				for i, v in report.physics.ownedVolume do
					A.near(v, base.physics.ownedVolume[i], 1e-12, what .. " owned volume " .. i)
				end
			end
		end)

	t.slow("T-DIF-07 (a) a sampled overlap's cells keep their count however a move rounds its box (§4.3): C09 moved to "
		.. "the hitbox's Z edges keeps every owned volume and its steps", function()
			-- 0.169 along ±Z, its room less 0.001, made a sampled box's extent 11.999999999999998 cells as built and
			-- 12.000000000000002 moved: 12 → 13 cells on f7ac37d, 3 owned volumes 1.5e-5 apart, SurfaceComplexity 0.001
			local c09 = fixtureCore("C09")
			local base = run(c09)
			local lo, hi = Gen.bounds(c09.parts)
			for _, dz in { SWORD.geometry.hitboxMax[3] - hi[3] - 0.001, SWORD.geometry.hitboxMin[3] - lo[3] + 0.001 } do
				local what = string.format("C09 + (0, 0, %.17g)", dz)
				local report = run(Gen.translate(c09 :: any, 0, dz))
				sameSteps(report, base, what)
				for i, v in report.physics.ownedVolume do
					A.near(v, base.physics.ownedVolume[i], 1e-12, what .. " owned volume " .. i)
				end
			end
		end)

	t.slow("T-DIF-07 (a) G sums each factor's x on a 1e-9 grid, so no move's last bits tip its 1e-4 rounding (§5.1): F4 "
		.. "with a plate on its guard (E-S2.11's plateEdge family), moved along Y, keeps Smelting's G 0.4593", function()
			-- Volume's last bits, which follow the rounding of a moved design, sat on a half step: 0.4593 → 0.4592 at
			-- + 0.3317 and at the hitbox's Y edges on f7ac37d
			local parts = copyParts(fixtureCore("F4"))
			table.insert(parts, P(6, "Guard", "Block", "Iron", { 0, 1.3099999999999998, 0 }, I, { 0.5, 0.12, 0.18 }))
			local core = canonical("F4 plated", parts)
			local base = run(core)
			A.eq(base.steps[1].g, 0.4593, "Smelting's G as built")
			local lo, hi = Gen.bounds(core.parts)
			local moves = { 0.3317, SWORD.geometry.hitboxMax[2] - hi[2] - 0.001, SWORD.geometry.hitboxMin[2] - lo[2] + 0.001 }
			for _, dy in moves do
				sameSteps(run(Gen.translate(core, dy, 0)), base, string.format("F4 plated + (0, %.17g, 0)", dy))
			end
		end)

	t.slow("T-DIF-07 (a) a gap of exactly CONTACT_TOL is contact however a move rounds it (§4.2, V3 and the contact rows): "
		.. "C07, and C02 with a plate on its guard, moved along Y, keep their Joints", function()
			-- on f7ac37d the gap rounded either side of CONTACT_TOL: C07's contact rows lost or took a face's samples
			-- (Joints 0.176 at ±0.0013), and the plate left or joined V3's contact graph (Joints 1.58 at + 0.0013)
			local c07 = fixtureCore("C07")
			local c07Base = run(c07)
			for _, dy in { 0.0013, -0.0013 } do
				sameSteps(run(Gen.translate(c07 :: any, dy, 0)), c07Base, string.format("C07 + (0, %g, 0)", dy))
			end
			local parts = copyParts(fixtureCore("C02"))
			table.insert(parts, P(7, "Guard", "Block", "Iron", { 0, 1.42, 0 }, I, { 0.66, 0.16, 0.144 }))
			local plated = canonical("C02 plated", parts)
			local base = run(plated)
			for _, dy in { 0.0013, -0.037, 0.3317 } do
				sameSteps(run(Gen.translate(plated, dy, 0)), base, string.format("C02 plated + (0, %g, 0)", dy))
			end
		end)

	t.it("T-DIF-07 (a) a part exactly CONTACT_TOL from the rest is connected however a move rounds the gap, in V3's broad "
		.. "phase too: F2 with its pommel 0.01 under its grip, moved along Y, valid at every move", function()
			-- of the moves 0.0137k, k = 1…24, V3's GJK at CONTACT_TOL loses the pommel at 15 (k = 1, 3, …), its box test
			-- at CONTACT_TOL alone at k = 20 only
			local parts = copyParts(fixtureCore("F2"))
			parts[1].pos = { parts[1].pos[1], parts[1].pos[2] - 0.01, parts[1].pos[3] }
			local core = canonical("F2, its pommel 0.01 down", parts)
			A.truthy(run(core).validation.ok, "valid as built")
			for _, k in { 1, 3, 20 } do
				A.truthy(run(Gen.translate(core, 0.0137 * k, 0)).validation.ok, string.format("valid moved %g along Y", 0.0137 * k))
			end
		end)

	t.it("T-DIF-07 (a) a Ball exactly CONTACT_TOL from a part is in its contact rows however a move rounds the gap, its "
		.. "samples' box margin the reach itself: F2 with a Ball pommel 0.24 across 0.01 under its grip, moved along Y",
		function()
			-- a Ball's samples have no patch (2·lim is 2·EPS_GEOM), so the rows' box test before sd runs at CONTACT_REACH;
			-- at CONTACT_TOL the grip's rows lost the Ball's pole at these moves (Joints 4.6332 → 4.656)
			local parts = {}
			for _, p in copyParts(fixtureCore("F2")) do
				if p.slot ~= "Pommel" then
					table.insert(parts, p)
				end
			end
			table.insert(parts, P(5, "Pommel", "Ball", "Iron", { 0, 0.35 - 0.01 - 0.12, 0 }, I, { 0.24, 0.24, 0.24 }))
			local core = canonical("F2 with a Ball pommel", parts)
			local base = run(core)
			A.truthy(base.validation.ok, "valid as built")
			for _, k in { 12, 17, 22 } do
				local dy = 0.0137 * k - 0.2
				sameSteps(run(Gen.translate(core, dy, 0)), base, string.format("F2 with a Ball pommel + (0, %g, 0)", dy))
			end
		end)

	t.it("§4.2 contact is asked at CONTACT_TOL + 1e-9, no further: F2 with its pommel 0.0100005, 0.010000003 or "
		.. "0.0100000015 under its grip floats, and 0.0100000005 under it holds", function()
			-- CONTACT_REACH's 1e-9 pinned from both sides, within 1.5 times it
			for _, gap in { 0.0100005, 0.010000003, 0.0100000015 } do
				local parts = copyParts(fixtureCore("F2"))
				parts[1].pos = { parts[1].pos[1], parts[1].pos[2] - gap, parts[1].pos[3] }
				A.truthy(not run(canonical("F2, its pommel down", parts)).validation.ok,
					string.format("%g past CONTACT_TOL: no contact", gap - 0.01))
			end
			local parts = copyParts(fixtureCore("F2"))
			parts[1].pos = { parts[1].pos[1], parts[1].pos[2] - 0.0100000005, parts[1].pos[3] }
			A.truthy(run(canonical("F2, its pommel down", parts)).validation.ok, "5e-10 past CONTACT_TOL: contact")
		end)

	t.slow("T-DIF-07 (a) F1–F5 and C01–C15 moved by E-S2.10's offsets: the steps to the bit, every factor within 1e-12, "
		.. "cutIndex kept; along Y, EdgeLength to the bit", function()
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

	t.slow("T-DIF-07 (a), (b) Gen designs, FUZZ_N_VALID: translated in Y and Z, and along Y alone, the steps to the bit, "
		.. "every factor within 1e-12, cutIndex kept, along Y EdgeLength to the bit; re-cut, Volume and EdgeLength within "
		.. "TOL_FACTOR_ABS", function()
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
