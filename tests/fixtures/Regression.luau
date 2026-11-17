--!strict
-- tests/fixtures/Regression.luau — S2's regression fixtures X01–X07 (SPEC §14.7; E-S2.5): every variant and every base
-- design the prototype measures them against (docs/spec/prototypes/S2/v2/fixtures.luau, regression()), keyed by the
-- prototype's ids, in its order. Canonical BlueprintCores in blueprint space, every part at least 0.02 stud inside the
-- Sword hitbox; the rows are the prototype's, pasted with the bits Lune computed for them, and
-- tests/FixtureSet/Regression.spec checks them against it bit for bit. Deep-frozen; Regression.core(id) hands out a
-- mutable copy. Most are F5 with its blade re-cut or nudged.
--
-- expect (Build.Expected): canon, validation and save as Calibration's. tiers and tierRaw as measured for the M3 plan
-- (the build's verdict, the prototype's edge and factors, the measure's rank order: .build-notes/m3-plan/plan-r2.md,
-- [7.2]), which T-DIF-12's goldens bless from Analyze.run. relation: E-S2.5's check against a base fixture (a
-- Regression id, or F4 or F5), with the prototype's kind and bound (T-DIF-13):
--   D       |ΔD| ≤ bound on every step                Thinness  |ΔThinness| ≤ bound on each work set
--   Edge    |ΔEdgeLength| ≤ bound · EdgeLength        G         |ΔG| ≤ bound on every step
--   Asym    |Asymmetry − the 120-probe oracle| ≤ bound (the base is only where the design comes from)
--   G+mass  |ΔG| ≤ bound, and the mass within TOL_MASS_REL (0.5 %)

local Build = require("./Build")

type Part = Build.Part
type Measured = Build.Measured

local P = Build.part
local I, Z45, Y90 = Build.I, Build.Z45, Build.Y90

local N, H, Ex = "Normal", "Hard", "Expert"

local function tiers(smelting: string, hammering: string, sharpening: string): { [string]: string }
	return { Smelting = smelting, Hammering = hammering, Sharpening = sharpening }
end

-- X02: five of the six copies are Enclosed; the one at z 0.012 shows its +Z face.
local COPIES: { Build.Cleaned } = {
	{ partId = 6, reason = "Enclosed" },
	{ partId = 7, reason = "Enclosed" },
	{ partId = 8, reason = "Enclosed" },
	{ partId = 9, reason = "Enclosed" },
	{ partId = 10, reason = "Enclosed" },
}

local function fixture(id: string, label: string, what: string, name: string, parts: { Part },
	played: { [string]: string }, raw: { [string]: string }?, relation: { to: string, kind: string, bound: number }?,
	cleaned: { Build.Cleaned }?): Measured
	return {
		id = id,
		label = label,
		what = what,
		core = Build.core(name, parts),
		expect = {
			canon = { ok = true, equals = "draft" },
			validation = { valid = true, errors = {} },
			tiers = played,
			tierRaw = raw or Build.copy(played),
			cleaned = Build.copy(cleaned or {}),
			relation = relation,
			save = "Valid",
		},
	}
end

local LIST: { Measured } = {
	fixture("X01base", "X01 base: the union blade 0.066",
		"F5 with its blade as the union of X01's copies, 0.16 × 2.60 × 0.066", "Union blade 0.066", {
			P(1, "Pommel", "Ball", "Iron", { 0, 0.17, 0 }, I, { 0.26, 0.26, 0.26 }), -- Pommel
			P(2, "Grip", "Block", "Iron", { 0, 0.75, 0 }, I, { 0.16, 0.9, 0.16 }), -- Grip
			P(3, "Guard", "Block", "Iron", { 0, 1.29, 0 }, I, { 1, 0.18, 0.24 }), -- Guard
			P(4, "Blade", "Block", "Iron", { 0, 3.98, 0 }, Z45, { 0.113, 0.113, 0.055 }), -- Tip
			P(5, "Blade", "Block", "Iron", { 0, 2.68, 0 }, I, { 0.16, 2.6, 0.066 }), -- Blade
		}, tiers(N, N, N)),
	fixture("X01", "X01 2 blade copies at z ±0.003 (vs the union blade 0.066)",
		"F5 + 2 copies of its blade at z ±0.003", "Blade copies at z +-0.003", {
			P(1, "Pommel", "Ball", "Iron", { 0, 0.17, 0 }, I, { 0.26, 0.26, 0.26 }), -- Pommel
			P(2, "Grip", "Block", "Iron", { 0, 0.75, 0 }, I, { 0.16, 0.9, 0.16 }), -- Grip
			P(3, "Guard", "Block", "Iron", { 0, 1.29, 0 }, I, { 1, 0.18, 0.24 }), -- Guard
			P(4, "Blade", "Block", "Iron", { 0, 2.68, 0 }, I, { 0.16, 2.6, 0.06 }), -- Blade
			P(5, "Blade", "Block", "Iron", { 0, 3.98, 0 }, Z45, { 0.113, 0.113, 0.055 }), -- Tip
			P(6, "Blade", "Block", "Iron", { 0, 2.68, 0.003 }, I, { 0.16, 2.6, 0.06 }), -- CopyA
			P(7, "Blade", "Block", "Iron", { 0, 2.68, -0.003 }, I, { 0.16, 2.6, 0.06 }), -- CopyB
		}, tiers(N, N, N), nil, { to = "X01base", kind = "D", bound = 0.01 }),
	fixture("X01raw", "X01raw 2 blade copies at z ±0.003 (vs F5)", "X01's design, against F5",
		"Blade copies at z +-0.003", {
			P(1, "Pommel", "Ball", "Iron", { 0, 0.17, 0 }, I, { 0.26, 0.26, 0.26 }), -- Pommel
			P(2, "Grip", "Block", "Iron", { 0, 0.75, 0 }, I, { 0.16, 0.9, 0.16 }), -- Grip
			P(3, "Guard", "Block", "Iron", { 0, 1.29, 0 }, I, { 1, 0.18, 0.24 }), -- Guard
			P(4, "Blade", "Block", "Iron", { 0, 2.68, 0 }, I, { 0.16, 2.6, 0.06 }), -- Blade
			P(5, "Blade", "Block", "Iron", { 0, 3.98, 0 }, Z45, { 0.113, 0.113, 0.055 }), -- Tip
			P(6, "Blade", "Block", "Iron", { 0, 2.68, 0.003 }, I, { 0.16, 2.6, 0.06 }), -- CopyA
			P(7, "Blade", "Block", "Iron", { 0, 2.68, -0.003 }, I, { 0.16, 2.6, 0.06 }), -- CopyB
		}, tiers(N, N, N), nil, { to = "F5", kind = "D", bound = 0.05 }),
	fixture("X02base", "X02 base: the union blade 0.072",
		"F5 with its blade as the union of X02's copies, 0.16 × 2.60 × 0.072 at z 0.006", "Union blade 0.072", {
			P(1, "Pommel", "Ball", "Iron", { 0, 0.17, 0 }, I, { 0.26, 0.26, 0.26 }), -- Pommel
			P(2, "Grip", "Block", "Iron", { 0, 0.75, 0 }, I, { 0.16, 0.9, 0.16 }), -- Grip
			P(3, "Guard", "Block", "Iron", { 0, 1.29, 0 }, I, { 1, 0.18, 0.24 }), -- Guard
			P(4, "Blade", "Block", "Iron", { 0, 3.98, 0 }, Z45, { 0.113, 0.113, 0.055 }), -- Tip
			P(5, "Blade", "Block", "Iron", { 0, 2.68, 0.006 }, I, { 0.16, 2.6, 0.072 }), -- Blade
		}, tiers(N, N, N)),
	fixture("X02", "X02 6 blade copies at z = k·0.002 (vs the union blade 0.072)",
		"F5 + 6 copies of its blade at z = k·0.002, k = 1…6", "6 blade copies", {
			P(1, "Pommel", "Ball", "Iron", { 0, 0.17, 0 }, I, { 0.26, 0.26, 0.26 }), -- Pommel
			P(2, "Grip", "Block", "Iron", { 0, 0.75, 0 }, I, { 0.16, 0.9, 0.16 }), -- Grip
			P(3, "Guard", "Block", "Iron", { 0, 1.29, 0 }, I, { 1, 0.18, 0.24 }), -- Guard
			P(4, "Blade", "Block", "Iron", { 0, 2.68, 0 }, I, { 0.16, 2.6, 0.06 }), -- Blade
			P(5, "Blade", "Block", "Iron", { 0, 3.98, 0 }, Z45, { 0.113, 0.113, 0.055 }), -- Tip
			P(6, "Blade", "Block", "Iron", { 0, 2.68, 0.002 }, I, { 0.16, 2.6, 0.06 }), -- Copy1
			P(7, "Blade", "Block", "Iron", { 0, 2.68, 0.004 }, I, { 0.16, 2.6, 0.06 }), -- Copy2
			P(8, "Blade", "Block", "Iron", { 0, 2.68, 0.006 }, I, { 0.16, 2.6, 0.06 }), -- Copy3
			P(9, "Blade", "Block", "Iron", { 0, 2.68, 0.008 }, I, { 0.16, 2.6, 0.06 }), -- Copy4
			P(10, "Blade", "Block", "Iron", { 0, 2.68, 0.01 }, I, { 0.16, 2.6, 0.06 }), -- Copy5
			P(11, "Blade", "Block", "Iron", { 0, 2.68, 0.012 }, I, { 0.16, 2.6, 0.06 }), -- Copy6
		}, tiers(N, N, N), nil, { to = "X02base", kind = "D", bound = 0.01 }, COPIES),
	fixture("X03", "X03 F4 + a 0.0003 stud³ fin", "F4 + a 0.10 × 0.06 × 0.05 fin 0.001 into the blade's +X face",
		"Cleaver + a fin", {
			P(1, "Pommel", "Block", "Iron", { 0, 0.2, 0 }, I, { 0.3, 0.2, 0.3 }), -- Pommel
			P(2, "Grip", "Block", "Iron", { 0, 0.75, 0 }, I, { 0.22, 0.9, 0.22 }), -- Grip
			P(3, "Guard", "Block", "Iron", { 0, 1.275, 0 }, I, { 0.5, 0.15, 0.3 }), -- Guard
			P(4, "Blade", "Block", "Iron", { 0.175, 2.45, 0 }, I, { 0.85, 2.2, 0.16 }), -- Blade
			P(5, "Blade", "Wedge", "Iron", { 0.175, 3.75, 0 }, Y90, { 0.16, 0.4, 0.85 }), -- Tip
			P(6, "Blade", "Block", "Iron", { 0.649, 2.45, 0 }, I, { 0.1, 0.06, 0.05 }), -- Fin
		}, tiers(H, N, N), tiers(Ex, N, N), { to = "F4", kind = "Thinness", bound = 0.02 }),
	fixture("X04a", "X04a blade from 4 strips", "F5 with its blade as 4 strips 0.04 wide (seams at x = −0.04, 0, 0.04)",
		"Blade from 4 strips", {
			P(1, "Pommel", "Ball", "Iron", { 0, 0.17, 0 }, I, { 0.26, 0.26, 0.26 }), -- Pommel
			P(2, "Grip", "Block", "Iron", { 0, 0.75, 0 }, I, { 0.16, 0.9, 0.16 }), -- Grip
			P(3, "Guard", "Block", "Iron", { 0, 1.29, 0 }, I, { 1, 0.18, 0.24 }), -- Guard
			P(4, "Blade", "Block", "Iron", { 0, 3.98, 0 }, Z45, { 0.113, 0.113, 0.055 }), -- Tip
			P(5, "Blade", "Block", "Iron", { -0.06, 2.68, 0 }, I, { 0.04, 2.6, 0.06 }), -- Strip0
			P(6, "Blade", "Block", "Iron", { -0.019999999999999997, 2.68, 0 }, I, { 0.04, 2.6, 0.06 }), -- Strip1
			P(7, "Blade", "Block", "Iron", { 0.020000000000000004, 2.68, 0 }, I, { 0.04, 2.6, 0.06 }), -- Strip2
			P(8, "Blade", "Block", "Iron", { 0.06, 2.68, 0 }, I, { 0.04, 2.6, 0.06 }), -- Strip3
		}, tiers(N, N, N), nil, { to = "F5", kind = "Edge", bound = 0.02 }),
	fixture("X04b", "X04b blade from strips, seams at ±0.05 and 0",
		"F5's blade as strips 0.03, 0.05, 0.05, 0.03 wide, seams on cell centres", "Strips, seams at +-0.05 and 0", {
			P(1, "Pommel", "Ball", "Iron", { 0, 0.17, 0 }, I, { 0.26, 0.26, 0.26 }), -- Pommel
			P(2, "Grip", "Block", "Iron", { 0, 0.75, 0 }, I, { 0.16, 0.9, 0.16 }), -- Grip
			P(3, "Guard", "Block", "Iron", { 0, 1.29, 0 }, I, { 1, 0.18, 0.24 }), -- Guard
			P(4, "Blade", "Block", "Iron", { 0, 3.98, 0 }, Z45, { 0.113, 0.113, 0.055 }), -- Tip
			P(5, "Blade", "Block", "Iron", { -0.065, 2.68, 0 }, I, { 0.03, 2.6, 0.06 }), -- StripA
			P(6, "Blade", "Block", "Iron", { -0.025, 2.68, 0 }, I, { 0.05, 2.6, 0.06 }), -- StripB
			P(7, "Blade", "Block", "Iron", { 0.025, 2.68, 0 }, I, { 0.05, 2.6, 0.06 }), -- StripC
			P(8, "Blade", "Block", "Iron", { 0.065, 2.68, 0 }, I, { 0.03, 2.6, 0.06 }), -- StripD
		}, tiers(N, N, N), nil, { to = "F5", kind = "Edge", bound = 0.02 }),
	fixture("X04-5-0.004", "X04-5-0.004 5 segments, gaps 0.004", "F5 with its blade as 5 segments 0.004 apart",
		"5 segments, gaps 0.004", {
			P(1, "Pommel", "Ball", "Iron", { 0, 0.17, 0 }, I, { 0.26, 0.26, 0.26 }), -- Pommel
			P(2, "Grip", "Block", "Iron", { 0, 0.75, 0 }, I, { 0.16, 0.9, 0.16 }), -- Grip
			P(3, "Guard", "Block", "Iron", { 0, 1.29, 0 }, I, { 1, 0.18, 0.24 }), -- Guard
			P(4, "Blade", "Block", "Iron", { 0, 3.98, 0 }, Z45, { 0.113, 0.113, 0.055 }), -- Tip
			P(5, "Blade", "Block", "Iron", { 0, 1.6383999999999999, 0 }, I, { 0.16, 0.5168, 0.06 }), -- Seg0
			P(6, "Blade", "Block", "Iron", { 0, 2.1592, 0 }, I, { 0.16, 0.5168, 0.06 }), -- Seg1
			P(7, "Blade", "Block", "Iron", { 0, 2.6799999999999997, 0 }, I, { 0.16, 0.5168, 0.06 }), -- Seg2
			P(8, "Blade", "Block", "Iron", { 0, 3.2008, 0 }, I, { 0.16, 0.5168, 0.06 }), -- Seg3
			P(9, "Blade", "Block", "Iron", { 0, 3.7216, 0 }, I, { 0.16, 0.5168, 0.06 }), -- Seg4
		}, tiers(N, N, N), nil, { to = "F5", kind = "Edge", bound = 0.02 }),
	fixture("X04-5-0.006", "X04-5-0.006 5 segments, gaps 0.006", "F5 with its blade as 5 segments 0.006 apart",
		"5 segments, gaps 0.006", {
			P(1, "Pommel", "Ball", "Iron", { 0, 0.17, 0 }, I, { 0.26, 0.26, 0.26 }), -- Pommel
			P(2, "Grip", "Block", "Iron", { 0, 0.75, 0 }, I, { 0.16, 0.9, 0.16 }), -- Grip
			P(3, "Guard", "Block", "Iron", { 0, 1.29, 0 }, I, { 1, 0.18, 0.24 }), -- Guard
			P(4, "Blade", "Block", "Iron", { 0, 3.98, 0 }, Z45, { 0.113, 0.113, 0.055 }), -- Tip
			P(5, "Blade", "Block", "Iron", { 0, 1.6376, 0 }, I, { 0.16, 0.5152, 0.06 }), -- Seg0
			P(6, "Blade", "Block", "Iron", { 0, 2.1588, 0 }, I, { 0.16, 0.5152, 0.06 }), -- Seg1
			P(7, "Blade", "Block", "Iron", { 0, 2.6799999999999997, 0 }, I, { 0.16, 0.5152, 0.06 }), -- Seg2
			P(8, "Blade", "Block", "Iron", { 0, 3.2012, 0 }, I, { 0.16, 0.5152, 0.06 }), -- Seg3
			P(9, "Blade", "Block", "Iron", { 0, 3.7224, 0 }, I, { 0.16, 0.5152, 0.06 }), -- Seg4
		}, tiers(N, N, N), nil, { to = "F5", kind = "Edge", bound = 0.02 }),
	fixture("X04-5-0.009", "X04-5-0.009 5 segments, gaps 0.009", "F5 with its blade as 5 segments 0.009 apart",
		"5 segments, gaps 0.009", {
			P(1, "Pommel", "Ball", "Iron", { 0, 0.17, 0 }, I, { 0.26, 0.26, 0.26 }), -- Pommel
			P(2, "Grip", "Block", "Iron", { 0, 0.75, 0 }, I, { 0.16, 0.9, 0.16 }), -- Grip
			P(3, "Guard", "Block", "Iron", { 0, 1.29, 0 }, I, { 1, 0.18, 0.24 }), -- Guard
			P(4, "Blade", "Block", "Iron", { 0, 3.98, 0 }, Z45, { 0.113, 0.113, 0.055 }), -- Tip
			P(5, "Blade", "Block", "Iron", { 0, 1.6363999999999999, 0 }, I, { 0.16, 0.5128, 0.06 }), -- Seg0
			P(6, "Blade", "Block", "Iron", { 0, 2.1582, 0 }, I, { 0.16, 0.5128, 0.06 }), -- Seg1
			P(7, "Blade", "Block", "Iron", { 0, 2.68, 0 }, I, { 0.16, 0.5128, 0.06 }), -- Seg2
			P(8, "Blade", "Block", "Iron", { 0, 3.2018000000000004, 0 }, I, { 0.16, 0.5128, 0.06 }), -- Seg3
			P(9, "Blade", "Block", "Iron", { 0, 3.7236000000000002, 0 }, I, { 0.16, 0.5128, 0.06 }), -- Seg4
		}, tiers(N, N, N), nil, { to = "F5", kind = "Edge", bound = 0.02 }),
	fixture("X04-10-0.004", "X04-10-0.004 10 segments, gaps 0.004", "F5 with its blade as 10 segments 0.004 apart",
		"10 segments, gaps 0.004", {
			P(1, "Pommel", "Ball", "Iron", { 0, 0.17, 0 }, I, { 0.26, 0.26, 0.26 }), -- Pommel
			P(2, "Grip", "Block", "Iron", { 0, 0.75, 0 }, I, { 0.16, 0.9, 0.16 }), -- Grip
			P(3, "Guard", "Block", "Iron", { 0, 1.29, 0 }, I, { 1, 0.18, 0.24 }), -- Guard
			P(4, "Blade", "Block", "Iron", { 0, 3.98, 0 }, Z45, { 0.113, 0.113, 0.055 }), -- Tip
			P(5, "Blade", "Block", "Iron", { 0, 1.5082, 0 }, I, { 0.16, 0.2564, 0.06 }), -- Seg0
			P(6, "Blade", "Block", "Iron", { 0, 1.7686, 0 }, I, { 0.16, 0.2564, 0.06 }), -- Seg1
			P(7, "Blade", "Block", "Iron", { 0, 2.029, 0 }, I, { 0.16, 0.2564, 0.06 }), -- Seg2
			P(8, "Blade", "Block", "Iron", { 0, 2.2894, 0 }, I, { 0.16, 0.2564, 0.06 }), -- Seg3
			P(9, "Blade", "Block", "Iron", { 0, 2.5498, 0 }, I, { 0.16, 0.2564, 0.06 }), -- Seg4
			P(10, "Blade", "Block", "Iron", { 0, 2.8102, 0 }, I, { 0.16, 0.2564, 0.06 }), -- Seg5
			P(11, "Blade", "Block", "Iron", { 0, 3.0706, 0 }, I, { 0.16, 0.2564, 0.06 }), -- Seg6
			P(12, "Blade", "Block", "Iron", { 0, 3.331, 0 }, I, { 0.16, 0.2564, 0.06 }), -- Seg7
			P(13, "Blade", "Block", "Iron", { 0, 3.5914, 0 }, I, { 0.16, 0.2564, 0.06 }), -- Seg8
			P(14, "Blade", "Block", "Iron", { 0, 3.8518000000000003, 0 }, I, { 0.16, 0.2564, 0.06 }), -- Seg9
		}, tiers(N, N, N), nil, { to = "F5", kind = "Edge", bound = 0.02 }),
	fixture("X04-10-0.006", "X04-10-0.006 10 segments, gaps 0.006", "F5 with its blade as 10 segments 0.006 apart",
		"10 segments, gaps 0.006", {
			P(1, "Pommel", "Ball", "Iron", { 0, 0.17, 0 }, I, { 0.26, 0.26, 0.26 }), -- Pommel
			P(2, "Grip", "Block", "Iron", { 0, 0.75, 0 }, I, { 0.16, 0.9, 0.16 }), -- Grip
			P(3, "Guard", "Block", "Iron", { 0, 1.29, 0 }, I, { 1, 0.18, 0.24 }), -- Guard
			P(4, "Blade", "Block", "Iron", { 0, 3.98, 0 }, Z45, { 0.113, 0.113, 0.055 }), -- Tip
			P(5, "Blade", "Block", "Iron", { 0, 1.5072999999999999, 0 }, I, { 0.16, 0.25460000000000005, 0.06 }), -- Seg0
			P(6, "Blade", "Block", "Iron", { 0, 1.7679, 0 }, I, { 0.16, 0.25460000000000005, 0.06 }), -- Seg1
			P(7, "Blade", "Block", "Iron", { 0, 2.0285, 0 }, I, { 0.16, 0.25460000000000005, 0.06 }), -- Seg2
			P(8, "Blade", "Block", "Iron", { 0, 2.2891, 0 }, I, { 0.16, 0.25460000000000005, 0.06 }), -- Seg3
			P(9, "Blade", "Block", "Iron", { 0, 2.5497, 0 }, I, { 0.16, 0.25460000000000005, 0.06 }), -- Seg4
			P(10, "Blade", "Block", "Iron", { 0, 2.8103000000000002, 0 }, I, { 0.16, 0.25460000000000005, 0.06 }), -- Seg5
			P(11, "Blade", "Block", "Iron", { 0, 3.0709, 0 }, I, { 0.16, 0.25460000000000005, 0.06 }), -- Seg6
			P(12, "Blade", "Block", "Iron", { 0, 3.3315, 0 }, I, { 0.16, 0.25460000000000005, 0.06 }), -- Seg7
			P(13, "Blade", "Block", "Iron", { 0, 3.5921000000000003, 0 }, I, { 0.16, 0.25460000000000005, 0.06 }), -- Seg8
			P(14, "Blade", "Block", "Iron", { 0, 3.8527000000000005, 0 }, I, { 0.16, 0.25460000000000005, 0.06 }), -- Seg9
		}, tiers(N, N, N), nil, { to = "F5", kind = "Edge", bound = 0.02 }),
	fixture("X04-10-0.009", "X04-10-0.009 10 segments, gaps 0.009", "F5 with its blade as 10 segments 0.009 apart",
		"10 segments, gaps 0.009", {
			P(1, "Pommel", "Ball", "Iron", { 0, 0.17, 0 }, I, { 0.26, 0.26, 0.26 }), -- Pommel
			P(2, "Grip", "Block", "Iron", { 0, 0.75, 0 }, I, { 0.16, 0.9, 0.16 }), -- Grip
			P(3, "Guard", "Block", "Iron", { 0, 1.29, 0 }, I, { 1, 0.18, 0.24 }), -- Guard
			P(4, "Blade", "Block", "Iron", { 0, 3.98, 0 }, Z45, { 0.113, 0.113, 0.055 }), -- Tip
			P(5, "Blade", "Block", "Iron", { 0, 1.50595, 0 }, I, { 0.16, 0.2519, 0.06 }), -- Seg0
			P(6, "Blade", "Block", "Iron", { 0, 1.7668499999999998, 0 }, I, { 0.16, 0.2519, 0.06 }), -- Seg1
			P(7, "Blade", "Block", "Iron", { 0, 2.02775, 0 }, I, { 0.16, 0.2519, 0.06 }), -- Seg2
			P(8, "Blade", "Block", "Iron", { 0, 2.28865, 0 }, I, { 0.16, 0.2519, 0.06 }), -- Seg3
			P(9, "Blade", "Block", "Iron", { 0, 2.54955, 0 }, I, { 0.16, 0.2519, 0.06 }), -- Seg4
			P(10, "Blade", "Block", "Iron", { 0, 2.81045, 0 }, I, { 0.16, 0.2519, 0.06 }), -- Seg5
			P(11, "Blade", "Block", "Iron", { 0, 3.0713500000000002, 0 }, I, { 0.16, 0.2519, 0.06 }), -- Seg6
			P(12, "Blade", "Block", "Iron", { 0, 3.33225, 0 }, I, { 0.16, 0.2519, 0.06 }), -- Seg7
			P(13, "Blade", "Block", "Iron", { 0, 3.59315, 0 }, I, { 0.16, 0.2519, 0.06 }), -- Seg8
			P(14, "Blade", "Block", "Iron", { 0, 3.85405, 0 }, I, { 0.16, 0.2519, 0.06 }), -- Seg9
		}, tiers(N, N, N), nil, { to = "F5", kind = "Edge", bound = 0.02 }),
	fixture("X04g0.005", "X04g0.005 grip nudged 0.005 in X", "F5 with its grip moved 0.005 along +X",
		"Grip nudge 0.005 in X", {
			P(1, "Pommel", "Ball", "Iron", { 0, 0.17, 0 }, I, { 0.26, 0.26, 0.26 }), -- Pommel
			P(2, "Grip", "Block", "Iron", { 0.005, 0.75, 0 }, I, { 0.16, 0.9, 0.16 }), -- Grip
			P(3, "Guard", "Block", "Iron", { 0, 1.29, 0 }, I, { 1, 0.18, 0.24 }), -- Guard
			P(4, "Blade", "Block", "Iron", { 0, 2.68, 0 }, I, { 0.16, 2.6, 0.06 }), -- Blade
			P(5, "Blade", "Block", "Iron", { 0, 3.98, 0 }, Z45, { 0.113, 0.113, 0.055 }), -- Tip
		}, tiers(N, N, N), nil, { to = "F5", kind = "Edge", bound = 0.02 }),
	fixture("X04g0.010", "X04g0.010 grip nudged 0.010 in X", "F5 with its grip moved 0.010 along +X",
		"Grip nudge 0.010 in X", {
			P(1, "Pommel", "Ball", "Iron", { 0, 0.17, 0 }, I, { 0.26, 0.26, 0.26 }), -- Pommel
			P(2, "Grip", "Block", "Iron", { 0.01, 0.75, 0 }, I, { 0.16, 0.9, 0.16 }), -- Grip
			P(3, "Guard", "Block", "Iron", { 0, 1.29, 0 }, I, { 1, 0.18, 0.24 }), -- Guard
			P(4, "Blade", "Block", "Iron", { 0, 2.68, 0 }, I, { 0.16, 2.6, 0.06 }), -- Blade
			P(5, "Blade", "Block", "Iron", { 0, 3.98, 0 }, Z45, { 0.113, 0.113, 0.055 }), -- Tip
		}, tiers(N, N, N), nil, { to = "F5", kind = "Edge", bound = 0.02 }),
	fixture("X04g0.015", "X04g0.015 grip nudged 0.015 in X", "F5 with its grip moved 0.015 along +X",
		"Grip nudge 0.015 in X", {
			P(1, "Pommel", "Ball", "Iron", { 0, 0.17, 0 }, I, { 0.26, 0.26, 0.26 }), -- Pommel
			P(2, "Grip", "Block", "Iron", { 0.015, 0.75, 0 }, I, { 0.16, 0.9, 0.16 }), -- Grip
			P(3, "Guard", "Block", "Iron", { 0, 1.29, 0 }, I, { 1, 0.18, 0.24 }), -- Guard
			P(4, "Blade", "Block", "Iron", { 0, 2.68, 0 }, I, { 0.16, 2.6, 0.06 }), -- Blade
			P(5, "Blade", "Block", "Iron", { 0, 3.98, 0 }, Z45, { 0.113, 0.113, 0.055 }), -- Tip
		}, tiers(N, N, N), nil, { to = "F5", kind = "Edge", bound = 0.02 }),
	fixture("X04g0.020", "X04g0.020 grip nudged 0.020 in X", "F5 with its grip moved 0.020 along +X",
		"Grip nudge 0.020 in X", {
			P(1, "Pommel", "Ball", "Iron", { 0, 0.17, 0 }, I, { 0.26, 0.26, 0.26 }), -- Pommel
			P(2, "Grip", "Block", "Iron", { 0.02, 0.75, 0 }, I, { 0.16, 0.9, 0.16 }), -- Grip
			P(3, "Guard", "Block", "Iron", { 0, 1.29, 0 }, I, { 1, 0.18, 0.24 }), -- Guard
			P(4, "Blade", "Block", "Iron", { 0, 2.68, 0 }, I, { 0.16, 2.6, 0.06 }), -- Blade
			P(5, "Blade", "Block", "Iron", { 0, 3.98, 0 }, Z45, { 0.113, 0.113, 0.055 }), -- Tip
		}, tiers(N, N, N), nil, { to = "F5", kind = "Edge", bound = 0.02 }),
	fixture("X05+0.002", "X05+0.002 5 segments, gap 0.002", "F5 with its blade as 5 segments, a gap of 0.002",
		"5 segments, gap 0.002", {
			P(1, "Pommel", "Ball", "Iron", { 0, 0.17, 0 }, I, { 0.26, 0.26, 0.26 }), -- Pommel
			P(2, "Grip", "Block", "Iron", { 0, 0.75, 0 }, I, { 0.16, 0.9, 0.16 }), -- Grip
			P(3, "Guard", "Block", "Iron", { 0, 1.29, 0 }, I, { 1, 0.18, 0.24 }), -- Guard
			P(4, "Blade", "Block", "Iron", { 0, 3.98, 0 }, Z45, { 0.113, 0.113, 0.055 }), -- Tip
			P(5, "Blade", "Block", "Iron", { 0, 1.6391999999999998, 0 }, I, { 0.16, 0.5184, 0.06 }), -- Seg0
			P(6, "Blade", "Block", "Iron", { 0, 2.1595999999999997, 0 }, I, { 0.16, 0.5184, 0.06 }), -- Seg1
			P(7, "Blade", "Block", "Iron", { 0, 2.6799999999999997, 0 }, I, { 0.16, 0.5184, 0.06 }), -- Seg2
			P(8, "Blade", "Block", "Iron", { 0, 3.2003999999999997, 0 }, I, { 0.16, 0.5184, 0.06 }), -- Seg3
			P(9, "Blade", "Block", "Iron", { 0, 3.7207999999999997, 0 }, I, { 0.16, 0.5184, 0.06 }), -- Seg4
		}, tiers(N, N, N), nil, { to = "F5", kind = "G", bound = 0.01 }),
	fixture("X05+0.004", "X05+0.004 5 segments, gap 0.004", "F5 with its blade as 5 segments, a gap of 0.004",
		"5 segments, gap 0.004", {
			P(1, "Pommel", "Ball", "Iron", { 0, 0.17, 0 }, I, { 0.26, 0.26, 0.26 }), -- Pommel
			P(2, "Grip", "Block", "Iron", { 0, 0.75, 0 }, I, { 0.16, 0.9, 0.16 }), -- Grip
			P(3, "Guard", "Block", "Iron", { 0, 1.29, 0 }, I, { 1, 0.18, 0.24 }), -- Guard
			P(4, "Blade", "Block", "Iron", { 0, 3.98, 0 }, Z45, { 0.113, 0.113, 0.055 }), -- Tip
			P(5, "Blade", "Block", "Iron", { 0, 1.6383999999999999, 0 }, I, { 0.16, 0.5168, 0.06 }), -- Seg0
			P(6, "Blade", "Block", "Iron", { 0, 2.1592, 0 }, I, { 0.16, 0.5168, 0.06 }), -- Seg1
			P(7, "Blade", "Block", "Iron", { 0, 2.6799999999999997, 0 }, I, { 0.16, 0.5168, 0.06 }), -- Seg2
			P(8, "Blade", "Block", "Iron", { 0, 3.2008, 0 }, I, { 0.16, 0.5168, 0.06 }), -- Seg3
			P(9, "Blade", "Block", "Iron", { 0, 3.7216, 0 }, I, { 0.16, 0.5168, 0.06 }), -- Seg4
		}, tiers(N, N, N), nil, { to = "F5", kind = "G", bound = 0.01 }),
	fixture("X05+0.006", "X05+0.006 5 segments, gap 0.006", "F5 with its blade as 5 segments, a gap of 0.006",
		"5 segments, gap 0.006", {
			P(1, "Pommel", "Ball", "Iron", { 0, 0.17, 0 }, I, { 0.26, 0.26, 0.26 }), -- Pommel
			P(2, "Grip", "Block", "Iron", { 0, 0.75, 0 }, I, { 0.16, 0.9, 0.16 }), -- Grip
			P(3, "Guard", "Block", "Iron", { 0, 1.29, 0 }, I, { 1, 0.18, 0.24 }), -- Guard
			P(4, "Blade", "Block", "Iron", { 0, 3.98, 0 }, Z45, { 0.113, 0.113, 0.055 }), -- Tip
			P(5, "Blade", "Block", "Iron", { 0, 1.6376, 0 }, I, { 0.16, 0.5152, 0.06 }), -- Seg0
			P(6, "Blade", "Block", "Iron", { 0, 2.1588, 0 }, I, { 0.16, 0.5152, 0.06 }), -- Seg1
			P(7, "Blade", "Block", "Iron", { 0, 2.6799999999999997, 0 }, I, { 0.16, 0.5152, 0.06 }), -- Seg2
			P(8, "Blade", "Block", "Iron", { 0, 3.2012, 0 }, I, { 0.16, 0.5152, 0.06 }), -- Seg3
			P(9, "Blade", "Block", "Iron", { 0, 3.7224, 0 }, I, { 0.16, 0.5152, 0.06 }), -- Seg4
		}, tiers(N, N, N), nil, { to = "F5", kind = "G", bound = 0.01 }),
	fixture("X05+0.009", "X05+0.009 5 segments, gap 0.009", "F5 with its blade as 5 segments, a gap of 0.009",
		"5 segments, gap 0.009", {
			P(1, "Pommel", "Ball", "Iron", { 0, 0.17, 0 }, I, { 0.26, 0.26, 0.26 }), -- Pommel
			P(2, "Grip", "Block", "Iron", { 0, 0.75, 0 }, I, { 0.16, 0.9, 0.16 }), -- Grip
			P(3, "Guard", "Block", "Iron", { 0, 1.29, 0 }, I, { 1, 0.18, 0.24 }), -- Guard
			P(4, "Blade", "Block", "Iron", { 0, 3.98, 0 }, Z45, { 0.113, 0.113, 0.055 }), -- Tip
			P(5, "Blade", "Block", "Iron", { 0, 1.6363999999999999, 0 }, I, { 0.16, 0.5128, 0.06 }), -- Seg0
			P(6, "Blade", "Block", "Iron", { 0, 2.1582, 0 }, I, { 0.16, 0.5128, 0.06 }), -- Seg1
			P(7, "Blade", "Block", "Iron", { 0, 2.68, 0 }, I, { 0.16, 0.5128, 0.06 }), -- Seg2
			P(8, "Blade", "Block", "Iron", { 0, 3.2018000000000004, 0 }, I, { 0.16, 0.5128, 0.06 }), -- Seg3
			P(9, "Blade", "Block", "Iron", { 0, 3.7236000000000002, 0 }, I, { 0.16, 0.5128, 0.06 }), -- Seg4
		}, tiers(N, N, N), nil, { to = "F5", kind = "G", bound = 0.01 }),
	fixture("X05-0.005", "X05-0.005 5 segments, overlap 0.005", "F5 with its blade as 5 segments, overlapping 0.005",
		"5 segments, overlap 0.005", {
			P(1, "Pommel", "Ball", "Iron", { 0, 0.17, 0 }, I, { 0.26, 0.26, 0.26 }), -- Pommel
			P(2, "Grip", "Block", "Iron", { 0, 0.75, 0 }, I, { 0.16, 0.9, 0.16 }), -- Grip
			P(3, "Guard", "Block", "Iron", { 0, 1.29, 0 }, I, { 1, 0.18, 0.24 }), -- Guard
			P(4, "Blade", "Block", "Iron", { 0, 3.98, 0 }, Z45, { 0.113, 0.113, 0.055 }), -- Tip
			P(5, "Blade", "Block", "Iron", { 0, 1.642, 0 }, I, { 0.16, 0.524, 0.06 }), -- Seg0
			P(6, "Blade", "Block", "Iron", { 0, 2.161, 0 }, I, { 0.16, 0.524, 0.06 }), -- Seg1
			P(7, "Blade", "Block", "Iron", { 0, 2.68, 0 }, I, { 0.16, 0.524, 0.06 }), -- Seg2
			P(8, "Blade", "Block", "Iron", { 0, 3.199, 0 }, I, { 0.16, 0.524, 0.06 }), -- Seg3
			P(9, "Blade", "Block", "Iron", { 0, 3.718, 0 }, I, { 0.16, 0.524, 0.06 }), -- Seg4
		}, tiers(N, N, N), nil, { to = "F5", kind = "G", bound = 0.01 }),
	fixture("X05-0.020", "X05-0.020 5 segments, overlap 0.020", "F5 with its blade as 5 segments, overlapping 0.020",
		"5 segments, overlap 0.020", {
			P(1, "Pommel", "Ball", "Iron", { 0, 0.17, 0 }, I, { 0.26, 0.26, 0.26 }), -- Pommel
			P(2, "Grip", "Block", "Iron", { 0, 0.75, 0 }, I, { 0.16, 0.9, 0.16 }), -- Grip
			P(3, "Guard", "Block", "Iron", { 0, 1.29, 0 }, I, { 1, 0.18, 0.24 }), -- Guard
			P(4, "Blade", "Block", "Iron", { 0, 3.98, 0 }, Z45, { 0.113, 0.113, 0.055 }), -- Tip
			P(5, "Blade", "Block", "Iron", { 0, 1.648, 0 }, I, { 0.16, 0.536, 0.06 }), -- Seg0
			P(6, "Blade", "Block", "Iron", { 0, 2.1639999999999997, 0 }, I, { 0.16, 0.536, 0.06 }), -- Seg1
			P(7, "Blade", "Block", "Iron", { 0, 2.6799999999999997, 0 }, I, { 0.16, 0.536, 0.06 }), -- Seg2
			P(8, "Blade", "Block", "Iron", { 0, 3.1959999999999997, 0 }, I, { 0.16, 0.536, 0.06 }), -- Seg3
			P(9, "Blade", "Block", "Iron", { 0, 3.7119999999999997, 0 }, I, { 0.16, 0.536, 0.06 }), -- Seg4
		}, tiers(N, N, N), nil, { to = "F5", kind = "G", bound = 0.01 }),
	fixture("X05-0.050", "X05-0.050 5 segments, overlap 0.050", "F5 with its blade as 5 segments, overlapping 0.050",
		"5 segments, overlap 0.050", {
			P(1, "Pommel", "Ball", "Iron", { 0, 0.17, 0 }, I, { 0.26, 0.26, 0.26 }), -- Pommel
			P(2, "Grip", "Block", "Iron", { 0, 0.75, 0 }, I, { 0.16, 0.9, 0.16 }), -- Grip
			P(3, "Guard", "Block", "Iron", { 0, 1.29, 0 }, I, { 1, 0.18, 0.24 }), -- Guard
			P(4, "Blade", "Block", "Iron", { 0, 3.98, 0 }, Z45, { 0.113, 0.113, 0.055 }), -- Tip
			P(5, "Blade", "Block", "Iron", { 0, 1.66, 0 }, I, { 0.16, 0.56, 0.06 }), -- Seg0
			P(6, "Blade", "Block", "Iron", { 0, 2.17, 0 }, I, { 0.16, 0.56, 0.06 }), -- Seg1
			P(7, "Blade", "Block", "Iron", { 0, 2.6799999999999997, 0 }, I, { 0.16, 0.56, 0.06 }), -- Seg2
			P(8, "Blade", "Block", "Iron", { 0, 3.1900000000000004, 0 }, I, { 0.16, 0.56, 0.06 }), -- Seg3
			P(9, "Blade", "Block", "Iron", { 0, 3.7, 0 }, I, { 0.16, 0.56, 0.06 }), -- Seg4
		}, tiers(N, N, N), nil, { to = "F5", kind = "G", bound = 0.01 }),
	fixture("X06-0.00", "X06-0.00 blade offset 0.00 in X", "F5 with its blade parts moved 0.00 along +X",
		"Blade offset 0.00 in X", {
			P(1, "Pommel", "Ball", "Iron", { 0, 0.17, 0 }, I, { 0.26, 0.26, 0.26 }), -- Pommel
			P(2, "Grip", "Block", "Iron", { 0, 0.75, 0 }, I, { 0.16, 0.9, 0.16 }), -- Grip
			P(3, "Guard", "Block", "Iron", { 0, 1.29, 0 }, I, { 1, 0.18, 0.24 }), -- Guard
			P(4, "Blade", "Block", "Iron", { 0, 2.68, 0 }, I, { 0.16, 2.6, 0.06 }), -- Blade
			P(5, "Blade", "Block", "Iron", { 0, 3.98, 0 }, Z45, { 0.113, 0.113, 0.055 }), -- Tip
		}, tiers(N, N, N), nil, { to = "F5", kind = "Asym", bound = 0.02 }),
	fixture("X06-0.01", "X06-0.01 blade offset 0.01 in X", "F5 with its blade parts moved 0.01 along +X",
		"Blade offset 0.01 in X", {
			P(1, "Pommel", "Ball", "Iron", { 0, 0.17, 0 }, I, { 0.26, 0.26, 0.26 }), -- Pommel
			P(2, "Grip", "Block", "Iron", { 0, 0.75, 0 }, I, { 0.16, 0.9, 0.16 }), -- Grip
			P(3, "Guard", "Block", "Iron", { 0, 1.29, 0 }, I, { 1, 0.18, 0.24 }), -- Guard
			P(4, "Blade", "Block", "Iron", { 0.01, 2.68, 0 }, I, { 0.16, 2.6, 0.06 }), -- Blade
			P(5, "Blade", "Block", "Iron", { 0.01, 3.98, 0 }, Z45, { 0.113, 0.113, 0.055 }), -- Tip
		}, tiers(N, N, N), nil, { to = "F5", kind = "Asym", bound = 0.02 }),
	fixture("X06-0.02", "X06-0.02 blade offset 0.02 in X", "F5 with its blade parts moved 0.02 along +X",
		"Blade offset 0.02 in X", {
			P(1, "Pommel", "Ball", "Iron", { 0, 0.17, 0 }, I, { 0.26, 0.26, 0.26 }), -- Pommel
			P(2, "Grip", "Block", "Iron", { 0, 0.75, 0 }, I, { 0.16, 0.9, 0.16 }), -- Grip
			P(3, "Guard", "Block", "Iron", { 0, 1.29, 0 }, I, { 1, 0.18, 0.24 }), -- Guard
			P(4, "Blade", "Block", "Iron", { 0.02, 2.68, 0 }, I, { 0.16, 2.6, 0.06 }), -- Blade
			P(5, "Blade", "Block", "Iron", { 0.02, 3.98, 0 }, Z45, { 0.113, 0.113, 0.055 }), -- Tip
		}, tiers(N, N, N), nil, { to = "F5", kind = "Asym", bound = 0.02 }),
	fixture("X06-0.03", "X06-0.03 blade offset 0.03 in X", "F5 with its blade parts moved 0.03 along +X",
		"Blade offset 0.03 in X", {
			P(1, "Pommel", "Ball", "Iron", { 0, 0.17, 0 }, I, { 0.26, 0.26, 0.26 }), -- Pommel
			P(2, "Grip", "Block", "Iron", { 0, 0.75, 0 }, I, { 0.16, 0.9, 0.16 }), -- Grip
			P(3, "Guard", "Block", "Iron", { 0, 1.29, 0 }, I, { 1, 0.18, 0.24 }), -- Guard
			P(4, "Blade", "Block", "Iron", { 0.03, 2.68, 0 }, I, { 0.16, 2.6, 0.06 }), -- Blade
			P(5, "Blade", "Block", "Iron", { 0.03, 3.98, 0 }, Z45, { 0.113, 0.113, 0.055 }), -- Tip
		}, tiers(N, N, N), nil, { to = "F5", kind = "Asym", bound = 0.02 }),
	fixture("X06-0.04", "X06-0.04 blade offset 0.04 in X", "F5 with its blade parts moved 0.04 along +X",
		"Blade offset 0.04 in X", {
			P(1, "Pommel", "Ball", "Iron", { 0, 0.17, 0 }, I, { 0.26, 0.26, 0.26 }), -- Pommel
			P(2, "Grip", "Block", "Iron", { 0, 0.75, 0 }, I, { 0.16, 0.9, 0.16 }), -- Grip
			P(3, "Guard", "Block", "Iron", { 0, 1.29, 0 }, I, { 1, 0.18, 0.24 }), -- Guard
			P(4, "Blade", "Block", "Iron", { 0.04, 2.68, 0 }, I, { 0.16, 2.6, 0.06 }), -- Blade
			P(5, "Blade", "Block", "Iron", { 0.04, 3.98, 0 }, Z45, { 0.113, 0.113, 0.055 }), -- Tip
		}, tiers(N, N, H), nil, { to = "F5", kind = "Asym", bound = 0.02 }),
	fixture("X06-0.05", "X06-0.05 blade offset 0.05 in X", "F5 with its blade parts moved 0.05 along +X",
		"Blade offset 0.05 in X", {
			P(1, "Pommel", "Ball", "Iron", { 0, 0.17, 0 }, I, { 0.26, 0.26, 0.26 }), -- Pommel
			P(2, "Grip", "Block", "Iron", { 0, 0.75, 0 }, I, { 0.16, 0.9, 0.16 }), -- Grip
			P(3, "Guard", "Block", "Iron", { 0, 1.29, 0 }, I, { 1, 0.18, 0.24 }), -- Guard
			P(4, "Blade", "Block", "Iron", { 0.05, 2.68, 0 }, I, { 0.16, 2.6, 0.06 }), -- Blade
			P(5, "Blade", "Block", "Iron", { 0.05, 3.98, 0 }, Z45, { 0.113, 0.113, 0.055 }), -- Tip
		}, tiers(N, N, H), nil, { to = "F5", kind = "Asym", bound = 0.02 }),
	fixture("X07a", "X07a laminate of 2 plates 0.03", "F5 with its blade as 2 plates 0.03 thick, flush",
		"Laminate, 2 plates 0.03", {
			P(1, "Pommel", "Ball", "Iron", { 0, 0.17, 0 }, I, { 0.26, 0.26, 0.26 }), -- Pommel
			P(2, "Grip", "Block", "Iron", { 0, 0.75, 0 }, I, { 0.16, 0.9, 0.16 }), -- Grip
			P(3, "Guard", "Block", "Iron", { 0, 1.29, 0 }, I, { 1, 0.18, 0.24 }), -- Guard
			P(4, "Blade", "Block", "Iron", { 0, 3.98, 0 }, Z45, { 0.113, 0.113, 0.055 }), -- Tip
			P(5, "Blade", "Block", "Iron", { 0, 2.68, 0.015 }, I, { 0.16, 2.6, 0.03 }), -- PlateA
			P(6, "Blade", "Block", "Iron", { 0, 2.68, -0.015 }, I, { 0.16, 2.6, 0.03 }), -- PlateB
		}, tiers(N, N, N), nil, { to = "F5", kind = "G+mass", bound = 0.01 }),
	fixture("X07b", "X07b laminate of 2 plates 0.035 overlapping 0.01",
		"F5 with its blade as 2 plates 0.035 thick overlapping 0.01", "Laminate, 2 plates 0.035", {
			P(1, "Pommel", "Ball", "Iron", { 0, 0.17, 0 }, I, { 0.26, 0.26, 0.26 }), -- Pommel
			P(2, "Grip", "Block", "Iron", { 0, 0.75, 0 }, I, { 0.16, 0.9, 0.16 }), -- Grip
			P(3, "Guard", "Block", "Iron", { 0, 1.29, 0 }, I, { 1, 0.18, 0.24 }), -- Guard
			P(4, "Blade", "Block", "Iron", { 0, 3.98, 0 }, Z45, { 0.113, 0.113, 0.055 }), -- Tip
			P(5, "Blade", "Block", "Iron", { 0, 2.68, 0.0125 }, I, { 0.16, 2.6, 0.035 }), -- PlateA
			P(6, "Blade", "Block", "Iron", { 0, 2.68, -0.0125 }, I, { 0.16, 2.6, 0.035 }), -- PlateB
		}, tiers(N, N, N), nil, { to = "F5", kind = "G+mass", bound = 0.01 }),
	fixture("X07c", "X07c 4 segments overlapping 0.07", "F5 with its blade as 4 segments 0.70 long overlapping 0.07",
		"4 segments, overlap 0.07", {
			P(1, "Pommel", "Ball", "Iron", { 0, 0.17, 0 }, I, { 0.26, 0.26, 0.26 }), -- Pommel
			P(2, "Grip", "Block", "Iron", { 0, 0.75, 0 }, I, { 0.16, 0.9, 0.16 }), -- Grip
			P(3, "Guard", "Block", "Iron", { 0, 1.29, 0 }, I, { 1, 0.18, 0.24 }), -- Guard
			P(4, "Blade", "Block", "Iron", { 0, 3.98, 0 }, Z45, { 0.113, 0.113, 0.055 }), -- Tip
			P(5, "Blade", "Block", "Iron", { 0, 1.73, 0 }, I, { 0.16, 0.7, 0.06 }), -- Seg0
			P(6, "Blade", "Block", "Iron", { 0, 2.36, 0 }, I, { 0.16, 0.7, 0.06 }), -- Seg1
			P(7, "Blade", "Block", "Iron", { 0, 2.99, 0 }, I, { 0.16, 0.7, 0.06 }), -- Seg2
			P(8, "Blade", "Block", "Iron", { 0, 3.62, 0 }, I, { 0.16, 0.7, 0.06 }), -- Seg3
		}, tiers(N, N, N), nil, { to = "F5", kind = "G+mass", bound = 0.01 }),
}

local BY_ID: { [string]: Measured } = {}
local ORDER: { string } = {}
for _, f in LIST do
	BY_ID[f.id] = f
	table.insert(ORDER, f.id)
end

local Regression = {
	order = ORDER, -- {"X01base", "X01", "X01raw", …, "X07c"}
	list = LIST, -- the fixtures, in that order
}

-- The fixture with this id; errors on an unknown id (a test bug).
function Regression.get(id: string): Measured
	local f = BY_ID[id]
	if f == nil then
		error("Regression.get: no fixture " .. tostring(id), 2)
	end
	return f
end

-- A fresh, mutable deep copy of the fixture's core.
function Regression.core(id: string): Build.Core
	return Build.copy(Regression.get(id).core)
end

Build.freeze(LIST)
table.freeze(ORDER)
return table.freeze(Regression)
