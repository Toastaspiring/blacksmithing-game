--!strict
-- tests/fixtures/Calibration.luau — S2's calibration swords C01, C02 in Iron and in Steel, C04–C15 (SPEC §5.5,
-- §14.7; E-S2.9): canonical BlueprintCores in blueprint space, every part at least 0.02 stud inside the Sword hitbox,
-- in the prototype's order (docs/spec/prototypes/S2/v2/fixtures.luau, calibration()), with the outcomes §5.5 states.
-- The rows are the prototype's, pasted with the bits Lune computed for them: C06, C09, C13 and C15 hold rotations and
-- positions it built with trigonometry, which a fixture never recomputes (Build.luau's header).
-- tests/FixtureSet/Calibration.spec checks every row against the prototype, bit for bit. Deep-frozen;
-- Calibration.core(id) hands out a mutable copy.
--
-- expect (Build.Expected): canon, a fixed point of Canonical.draft (M1); validation, valid (M2); tiers and tierRaw,
-- §5.5's table (T-DIF-11, M3); cleaned, Physics' verdict (M2); save. The d values and E-S2.9's physics and factor
-- tables are blessed into goldens from Analyze.run (M3, §14.7); S8 keeps no copy.

local Build = require("./Build")

type Part = Build.Part
type Measured = Build.Measured

local P = Build.part
local I, Z90, Y90, YM90 = Build.I, Build.Z90, Build.Y90, Build.YM90

local N, H, Ex = "Normal", "Hard", "Expert"

local function tiers(smelting: string, hammering: string, sharpening: string): { [string]: string }
	return { Smelting = smelting, Hammering = hammering, Sharpening = sharpening }
end

-- C10 and C11: the two blocks inside the pommel are Enclosed, the two 0.05 specks on the grip Dust.
local FILLER: { Build.Cleaned } = {
	{ partId = 21, reason = "Enclosed" },
	{ partId = 22, reason = "Enclosed" },
	{ partId = 23, reason = "Dust" },
	{ partId = 24, reason = "Dust" },
}

local function fixture(id: string, label: string, what: string, name: string, parts: { Part },
	played: { [string]: string }, raw: { [string]: string }?, cleaned: { Build.Cleaned }?): Measured
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
			save = "Valid",
		},
	}
end

local LIST: { Measured } = {
	fixture("C01", "C01 Minimal", "one Iron Block per slot, a 0.25 × 2.40 × 0.10 blade",
		"Minimal", {
			P(1, "Pommel", "Block", "Iron", { 0, 0.35, 0 }, I, { 0.3, 0.3, 0.3 }), -- Pommel
			P(2, "Grip", "Block", "Iron", { 0, 1, 0 }, I, { 0.2, 1, 0.2 }), -- Grip
			P(3, "Guard", "Block", "Iron", { 0, 1.6, 0 }, I, { 1, 0.2, 0.3 }), -- Guard
			P(4, "Blade", "Block", "Iron", { 0, 2.9, 0 }, I, { 0.25, 2.4, 0.1 }), -- Blade
		}, tiers(N, N, N)),
	fixture("C02", "C02 Arming (Iron)",
		"Iron: Ball pommel, Cylinder grip, a 0.20 × 2.50 × 0.06 blade, two mirrored Wedge tips", "Arming (Iron)", {
			P(1, "Pommel", "Ball", "Iron", { 0, 0.3, 0 }, I, { 0.3, 0.3, 0.3 }), -- Pommel
			P(2, "Grip", "Cylinder", "Iron", { 0, 0.88, 0 }, Z90, { 0.9, 0.16, 0.16 }), -- Grip
			P(3, "Guard", "Block", "Iron", { 0, 1.4, 0 }, I, { 1.1, 0.16, 0.24 }), -- Guard
			P(4, "Blade", "Block", "Iron", { 0, 2.65, 0 }, I, { 0.2, 2.5, 0.06 }), -- Blade
			P(5, "Blade", "Wedge", "Iron", { 0.05, 4.1, 0 }, YM90, { 0.06, 0.4, 0.1 }), -- TipR
			P(6, "Blade", "Wedge", "Iron", { -0.05, 4.1, 0 }, Y90, { 0.06, 0.4, 0.1 }), -- TipL
		}, tiers(N, N, N)),
	fixture("C02s", "C02 Arming (Steel)", "C02 all in Steel",
		"Arming (Steel)", {
			P(1, "Pommel", "Ball", "Steel", { 0, 0.3, 0 }, I, { 0.3, 0.3, 0.3 }), -- Pommel
			P(2, "Grip", "Cylinder", "Steel", { 0, 0.88, 0 }, Z90, { 0.9, 0.16, 0.16 }), -- Grip
			P(3, "Guard", "Block", "Steel", { 0, 1.4, 0 }, I, { 1.1, 0.16, 0.24 }), -- Guard
			P(4, "Blade", "Block", "Steel", { 0, 2.65, 0 }, I, { 0.2, 2.5, 0.06 }), -- Blade
			P(5, "Blade", "Wedge", "Steel", { 0.05, 4.1, 0 }, YM90, { 0.06, 0.4, 0.1 }), -- TipR
			P(6, "Blade", "Wedge", "Steel", { -0.05, 4.1, 0 }, Y90, { 0.06, 0.4, 0.1 }), -- TipL
		}, tiers(N, N, N)),
	fixture("C04", "C04 Rapier (Steel blade)", "Iron hilt with a Steel cross and cup, a 0.09 × 3.30 × 0.05 Steel blade",
		"Rapier (Steel blade)", {
			P(1, "Pommel", "Ball", "Iron", { 0, 0.25, 0 }, I, { 0.26, 0.26, 0.26 }), -- Pommel
			P(2, "Grip", "Cylinder", "Iron", { 0, 0.77, 0 }, Z90, { 0.8, 0.14, 0.14 }), -- Grip
			P(3, "Guard", "Block", "Steel", { 0, 1.21, 0 }, I, { 0.7, 0.1, 0.12 }), -- Cross
			P(4, "Guard", "Cylinder", "Steel", { 0, 1.285, 0 }, Z90, { 0.05, 0.44, 0.44 }), -- Cup
			P(5, "Blade", "Block", "Steel", { 0, 2.95, 0 }, I, { 0.09, 3.3, 0.05 }), -- Blade
			P(6, "Blade", "Wedge", "Steel", { 0.0225, 4.75, 0 }, YM90, { 0.05, 0.3, 0.045 }), -- TipR
			P(7, "Blade", "Wedge", "Steel", { -0.0225, 4.75, 0 }, Y90, { 0.05, 0.3, 0.045 }), -- TipL
		}, tiers(N, H, H), tiers(N, H, Ex)),
	fixture("C05", "C05 Cleaver", "a 1.00 × 2.20 × 0.14 blade offset to +X, a spine at −X, a Wedge top",
		"Cleaver", {
			P(1, "Pommel", "Block", "Iron", { 0, 0.32, 0 }, I, { 0.3, 0.24, 0.3 }), -- Pommel
			P(2, "Grip", "Cylinder", "Iron", { 0, 0.89, 0 }, Z90, { 0.92, 0.2, 0.2 }), -- Grip
			P(3, "Guard", "Block", "Iron", { 0, 1.41, 0 }, I, { 0.6, 0.14, 0.3 }), -- Guard
			P(4, "Blade", "Block", "Iron", { 0.25, 2.58, 0 }, I, { 1, 2.2, 0.14 }), -- Blade
			P(5, "Blade", "Block", "Iron", { -0.31, 2.58, 0 }, I, { 0.12, 2.2, 0.22 }), -- Spine
			P(6, "Blade", "Wedge", "Iron", { 0.19, 3.88, 0 }, Y90, { 0.14, 0.4, 1.12 }), -- Top
		}, tiers(H, N, H), tiers(Ex, N, H)),
	fixture("C06", "C06 Sabre (Steel)",
		"a blade of 5 Steel segments turned 2–14° about Z, curving to −X, tips turned with it", "Sabre (Steel)", {
			P(1, "Pommel", "Ball", "Iron", { 0, 0.3, 0 }, I, { 0.28, 0.28, 0.28 }), -- Pommel
			P(2, "Grip", "Cylinder", "Iron", { 0, 0.87, 0 }, Z90, { 0.88, 0.16, 0.16 }), -- Grip
			P(3, "Guard", "Block", "Steel", { 0, 1.38, 0 }, I, { 0.8, 0.14, 0.22 }), -- Guard
			P(4, "Blade", "Block", "Steel", { -0.0108188439777753, 1.7098111563759195, 0 }, { 0, 0, 0.01745240643728351, 0.9998476951563913 }, { 0.18, 0.62, 0.06 }), -- Seg1
			P(5, "Blade", "Block", "Steel", { -0.047259988339224596, 2.2884670360795165, 0 }, { 0, 0, 0.043619387365336, 0.9990482215818578 }, { 0.18, 0.62, 0.06 }), -- Seg2
			P(6, "Blade", "Block", "Steel", { -0.1139357001787126, 2.864422705874175, 0 }, { 0, 0, 0.0697564737441253, 0.9975640502598242 }, { 0.18, 0.62, 0.06 }), -- Seg3
			P(7, "Blade", "Block", "Steel", { -0.21066322600465912, 3.436099511303175, 0 }, { 0, 0, 0.09584575252022398, 0.9953961983671789 }, { 0.18, 0.62, 0.06 }), -- Seg4
			P(8, "Blade", "Block", "Steel", { -0.33717744239222325, 4.001930525979603, 0 }, { 0, 0, 0.12186934340514748, 0.992546151641322 }, { 0.18, 0.62, 0.06 }), -- Seg5
			P(9, "Blade", "Wedge", "Steel", { -0.49938247891848025, 4.4664889465528566, 0 }, { -0.08617463914053185, 0.7018361144661901, 0.08617463914053185, 0.7018361144661901 }, { 0.06, 0.36, 0.09 }), -- TipL
			P(10, "Blade", "Wedge", "Steel", { -0.4120558635536406, 4.4882619171568265, 0 }, { 0.08617463914053185, -0.7018361144661901, 0.08617463914053185, 0.7018361144661901 }, { 0.06, 0.36, 0.09 }), -- TipR
		}, tiers(N, H, H), tiers(N, H, Ex)),
	fixture("C07", "C07 Dagger", "a 0.18 × 1.20 × 0.06 blade with Wedge tips on a short hilt",
		"Dagger", {
			P(1, "Pommel", "Ball", "Iron", { 0, 0.21, 0 }, I, { 0.22, 0.22, 0.22 }), -- Pommel
			P(2, "Grip", "Cylinder", "Iron", { 0, 0.61, 0 }, Z90, { 0.6, 0.14, 0.14 }), -- Grip
			P(3, "Guard", "Block", "Iron", { 0, 0.96, 0 }, I, { 0.6, 0.12, 0.2 }), -- Guard
			P(4, "Blade", "Block", "Iron", { 0, 1.6, 0 }, I, { 0.18, 1.2, 0.06 }), -- Blade
			P(5, "Blade", "Wedge", "Iron", { 0.045, 2.35, 0 }, YM90, { 0.06, 0.3, 0.09 }), -- TipR
			P(6, "Blade", "Wedge", "Iron", { -0.045, 2.35, 0 }, Y90, { 0.06, 0.3, 0.09 }), -- TipL
		}, tiers(N, N, N)),
	fixture("C08", "C08 Greatsword", "a 0.30 × 2.80 × 0.08 blade, a 1.50-wide guard",
		"Greatsword", {
			P(1, "Pommel", "Ball", "Iron", { 0, 0.27, 0 }, I, { 0.34, 0.34, 0.34 }), -- Pommel
			P(2, "Grip", "Cylinder", "Iron", { 0, 1.03, 0 }, Z90, { 1.2, 0.18, 0.18 }), -- Grip
			P(3, "Guard", "Block", "Iron", { 0, 1.71, 0 }, I, { 1.5, 0.18, 0.26 }), -- Guard
			P(4, "Blade", "Block", "Iron", { 0, 3.18, 0 }, I, { 0.3, 2.8, 0.08 }), -- Blade
			P(5, "Blade", "Wedge", "Iron", { 0.075, 4.78, 0 }, YM90, { 0.08, 0.4, 0.15 }), -- TipR
			P(6, "Blade", "Wedge", "Iron", { -0.075, 4.78, 0 }, Y90, { 0.08, 0.4, 0.15 }), -- TipL
		}, tiers(N, N, H)),
	fixture("C09", "C09 Ornate (18 parts)",
		"grip rings, guard arms and finials, a blade core with 4 Wedge bevels, Wedge tips", "Ornate", {
			P(1, "Pommel", "Ball", "Iron", { 0, 0.3, 0 }, I, { 0.26, 0.26, 0.26 }), -- Pommel
			P(2, "Pommel", "Ball", "Iron", { 0, 0.14, 0 }, I, { 0.1, 0.1, 0.1 }), -- PommelCap
			P(3, "Grip", "Cylinder", "Iron", { 0, 0.88, 0 }, Z90, { 0.9, 0.15, 0.15 }), -- Grip
			P(4, "Grip", "Cylinder", "Iron", { 0, 0.6, 0 }, Z90, { 0.04, 0.19, 0.19 }), -- Ring1
			P(5, "Grip", "Cylinder", "Iron", { 0, 0.88, 0 }, Z90, { 0.04, 0.19, 0.19 }), -- Ring2
			P(6, "Grip", "Cylinder", "Iron", { 0, 1.16, 0 }, Z90, { 0.04, 0.19, 0.19 }), -- Ring3
			P(7, "Guard", "Block", "Iron", { 0, 1.41, 0 }, I, { 0.3, 0.18, 0.26 }), -- GuardCore
			P(8, "Guard", "Block", "Iron", { 0.33, 1.43, 0 }, { 0, 0, 0.08715574274765817, 0.9961946980917455 }, { 0.4, 0.1, 0.14 }), -- ArmR
			P(9, "Guard", "Block", "Iron", { -0.33, 1.43, 0 }, { 0, 0, -0.08715574274765817, 0.9961946980917455 }, { 0.4, 0.1, 0.14 }), -- ArmL
			P(10, "Guard", "Ball", "Iron", { 0.56, 1.47, 0 }, I, { 0.14, 0.14, 0.14 }), -- FinialR
			P(11, "Guard", "Ball", "Iron", { -0.56, 1.47, 0 }, I, { 0.14, 0.14, 0.14 }), -- FinialL
			P(12, "Blade", "Block", "Iron", { 0, 2.6, 0 }, I, { 0.12, 2.4, 0.06 }), -- Core
			P(13, "Blade", "Wedge", "Iron", { 0.085, 2.6, 0.015 }, { 0.5, -0.5, -0.5, 0.5 }, { 2.4, 0.03, 0.05 }), -- BevelUR
			P(14, "Blade", "Wedge", "Iron", { 0.085, 2.6, -0.015 }, { -0.5, -0.5, 0.5, 0.5 }, { 2.4, 0.03, 0.05 }), -- BevelLR
			P(15, "Blade", "Wedge", "Iron", { -0.085, 2.6, 0.015 }, { 0.5, 0.5, 0.5, 0.5 }, { 2.4, 0.03, 0.05 }), -- BevelUL
			P(16, "Blade", "Wedge", "Iron", { -0.085, 2.6, -0.015 }, { -0.5, 0.5, -0.5, 0.5 }, { 2.4, 0.03, 0.05 }), -- BevelLL
			P(17, "Blade", "Wedge", "Iron", { 0.055, 4, 0 }, YM90, { 0.06, 0.4, 0.11 }), -- TipR
			P(18, "Blade", "Wedge", "Iron", { -0.055, 4, 0 }, Y90, { 0.06, 0.4, 0.11 }), -- TipL
		}, tiers(N, H, N)),
	fixture("C10", "C10 Gamey filler, symmetric",
		"C01 + 16 studs in mirrored pairs, 2 blocks inside the pommel, 2 Dust specks", "Filler, symmetric", {
			P(1, "Pommel", "Block", "Iron", { 0, 0.35, 0 }, I, { 0.3, 0.3, 0.3 }), -- Pommel
			P(2, "Grip", "Block", "Iron", { 0, 1, 0 }, I, { 0.2, 1, 0.2 }), -- Grip
			P(3, "Guard", "Block", "Iron", { 0, 1.6, 0 }, I, { 1, 0.2, 0.3 }), -- Guard
			P(4, "Blade", "Block", "Iron", { 0, 2.9, 0 }, I, { 0.25, 2.4, 0.1 }), -- Blade
			P(5, "Blade", "Block", "Iron", { -0.06, 1.95, 0.05 }, I, { 0.09, 0.09, 0.09 }), -- Stud1
			P(6, "Blade", "Block", "Iron", { 0.06, 1.95, 0.05 }, I, { 0.09, 0.09, 0.09 }), -- Stud2
			P(7, "Blade", "Block", "Iron", { -0.06, 2.4, -0.05 }, I, { 0.09, 0.09, 0.09 }), -- Stud3
			P(8, "Blade", "Block", "Iron", { 0.06, 2.4, -0.05 }, I, { 0.09, 0.09, 0.09 }), -- Stud4
			P(9, "Blade", "Block", "Iron", { -0.06, 2.85, 0.05 }, I, { 0.09, 0.09, 0.09 }), -- Stud5
			P(10, "Blade", "Block", "Iron", { 0.06, 2.85, 0.05 }, I, { 0.09, 0.09, 0.09 }), -- Stud6
			P(11, "Blade", "Block", "Iron", { -0.06, 3.3, -0.05 }, I, { 0.09, 0.09, 0.09 }), -- Stud7
			P(12, "Blade", "Block", "Iron", { 0.06, 3.3, -0.05 }, I, { 0.09, 0.09, 0.09 }), -- Stud8
			P(13, "Blade", "Block", "Iron", { -0.06, 3.75, 0.05 }, I, { 0.09, 0.09, 0.09 }), -- Stud9
			P(14, "Blade", "Block", "Iron", { 0.06, 3.75, 0.05 }, I, { 0.09, 0.09, 0.09 }), -- Stud10
			P(15, "Guard", "Block", "Iron", { -0.15, 1.7, 0 }, I, { 0.09, 0.09, 0.09 }), -- Stud11
			P(16, "Guard", "Block", "Iron", { 0.15, 1.7, 0 }, I, { 0.09, 0.09, 0.09 }), -- Stud12
			P(17, "Guard", "Block", "Iron", { -0.3, 1.7, 0 }, I, { 0.09, 0.09, 0.09 }), -- Stud13
			P(18, "Guard", "Block", "Iron", { 0.3, 1.7, 0 }, I, { 0.09, 0.09, 0.09 }), -- Stud14
			P(19, "Guard", "Block", "Iron", { -0.44999999999999996, 1.7, 0 }, I, { 0.09, 0.09, 0.09 }), -- Stud15
			P(20, "Guard", "Block", "Iron", { 0.44999999999999996, 1.7, 0 }, I, { 0.09, 0.09, 0.09 }), -- Stud16
			P(21, "Pommel", "Block", "Iron", { 0.06, 0.35, 0 }, I, { 0.1, 0.1, 0.1 }), -- Hidden1
			P(22, "Pommel", "Block", "Iron", { -0.06, 0.35, 0 }, I, { 0.1, 0.1, 0.1 }), -- Hidden2
			P(23, "Grip", "Block", "Iron", { 0.125, 1, 0 }, I, { 0.05, 0.05, 0.05 }), -- Dust1
			P(24, "Grip", "Block", "Iron", { -0.125, 1, 0 }, I, { 0.05, 0.05, 0.05 }), -- Dust2
		}, tiers(N, N, N), nil, FILLER),
	fixture("C11", "C11 Gamey filler, lopsided",
		"C01 + 16 studs all to one side, 2 blocks inside the pommel, 2 Dust specks", "Filler, lopsided", {
			P(1, "Pommel", "Block", "Iron", { 0, 0.35, 0 }, I, { 0.3, 0.3, 0.3 }), -- Pommel
			P(2, "Grip", "Block", "Iron", { 0, 1, 0 }, I, { 0.2, 1, 0.2 }), -- Grip
			P(3, "Guard", "Block", "Iron", { 0, 1.6, 0 }, I, { 1, 0.2, 0.3 }), -- Guard
			P(4, "Blade", "Block", "Iron", { 0, 2.9, 0 }, I, { 0.25, 2.4, 0.1 }), -- Blade
			P(5, "Blade", "Block", "Iron", { 0.06, 1.95, 0.05 }, I, { 0.09, 0.09, 0.09 }), -- Stud1
			P(6, "Blade", "Block", "Iron", { 0.06, 2.17, 0.05 }, I, { 0.09, 0.09, 0.09 }), -- Stud2
			P(7, "Blade", "Block", "Iron", { 0.06, 2.4, -0.05 }, I, { 0.09, 0.09, 0.09 }), -- Stud3
			P(8, "Blade", "Block", "Iron", { 0.06, 2.62, -0.05 }, I, { 0.09, 0.09, 0.09 }), -- Stud4
			P(9, "Blade", "Block", "Iron", { 0.06, 2.85, 0.05 }, I, { 0.09, 0.09, 0.09 }), -- Stud5
			P(10, "Blade", "Block", "Iron", { 0.06, 3.0700000000000003, 0.05 }, I, { 0.09, 0.09, 0.09 }), -- Stud6
			P(11, "Blade", "Block", "Iron", { 0.06, 3.3, -0.05 }, I, { 0.09, 0.09, 0.09 }), -- Stud7
			P(12, "Blade", "Block", "Iron", { 0.06, 3.52, -0.05 }, I, { 0.09, 0.09, 0.09 }), -- Stud8
			P(13, "Blade", "Block", "Iron", { 0.06, 3.75, 0.05 }, I, { 0.09, 0.09, 0.09 }), -- Stud9
			P(14, "Blade", "Block", "Iron", { 0.06, 3.97, 0.05 }, I, { 0.09, 0.09, 0.09 }), -- Stud10
			P(15, "Guard", "Block", "Iron", { 0.12, 1.7, 0 }, I, { 0.09, 0.09, 0.09 }), -- Stud11
			P(16, "Guard", "Block", "Iron", { 0.19499999999999998, 1.7, 0 }, I, { 0.09, 0.09, 0.09 }), -- Stud12
			P(17, "Guard", "Block", "Iron", { 0.27, 1.7, 0 }, I, { 0.09, 0.09, 0.09 }), -- Stud13
			P(18, "Guard", "Block", "Iron", { 0.345, 1.7, 0 }, I, { 0.09, 0.09, 0.09 }), -- Stud14
			P(19, "Guard", "Block", "Iron", { 0.41999999999999993, 1.7, 0 }, I, { 0.09, 0.09, 0.09 }), -- Stud15
			P(20, "Guard", "Block", "Iron", { 0.495, 1.7, 0 }, I, { 0.09, 0.09, 0.09 }), -- Stud16
			P(21, "Pommel", "Block", "Iron", { 0.06, 0.35, 0 }, I, { 0.1, 0.1, 0.1 }), -- Hidden1
			P(22, "Pommel", "Block", "Iron", { -0.06, 0.35, 0 }, I, { 0.1, 0.1, 0.1 }), -- Hidden2
			P(23, "Grip", "Block", "Iron", { 0.125, 1, 0 }, I, { 0.05, 0.05, 0.05 }), -- Dust1
			P(24, "Grip", "Block", "Iron", { -0.125, 1, 0 }, I, { 0.05, 0.05, 0.05 }), -- Dust2
		}, tiers(N, N, N), nil, FILLER),
	fixture("C12", "C12 Arming, blade in 5 overlapping segments", "C02 with its blade as 5 overlapping segments",
		"Arming, 5 segments", {
			P(1, "Pommel", "Ball", "Iron", { 0, 0.3, 0 }, I, { 0.3, 0.3, 0.3 }), -- Pommel
			P(2, "Grip", "Cylinder", "Iron", { 0, 0.88, 0 }, Z90, { 0.9, 0.16, 0.16 }), -- Grip
			P(3, "Guard", "Block", "Iron", { 0, 1.4, 0 }, I, { 1.1, 0.16, 0.24 }), -- Guard
			P(4, "Blade", "Wedge", "Iron", { 0.05, 4.1, 0 }, YM90, { 0.06, 0.4, 0.1 }), -- TipR
			P(5, "Blade", "Wedge", "Iron", { -0.05, 4.1, 0 }, Y90, { 0.06, 0.4, 0.1 }), -- TipL
			P(6, "Blade", "Block", "Iron", { 0, 1.67, 0 }, I, { 0.2, 0.54, 0.06 }), -- Blade1
			P(7, "Blade", "Block", "Iron", { 0, 2.16, 0 }, I, { 0.2, 0.54, 0.06 }), -- Blade2
			P(8, "Blade", "Block", "Iron", { 0, 2.65, 0 }, I, { 0.2, 0.54, 0.06 }), -- Blade3
			P(9, "Blade", "Block", "Iron", { 0, 3.14, 0 }, I, { 0.2, 0.54, 0.06 }), -- Blade4
			P(10, "Blade", "Block", "Iron", { 0, 3.63, 0 }, I, { 0.2, 0.54, 0.06 }), -- Blade5
		}, tiers(N, N, N)),
	fixture("C13", "C13 Arming, guard = half + mirror",
		"C02 with its guard as a half and its X mirror image, + 2 CornerWedge finials", "Arming, mirrored guard", {
			P(1, "Pommel", "Ball", "Iron", { 0, 0.3, 0 }, I, { 0.3, 0.3, 0.3 }), -- Pommel
			P(2, "Grip", "Cylinder", "Iron", { 0, 0.88, 0 }, Z90, { 0.9, 0.16, 0.16 }), -- Grip
			P(3, "Blade", "Block", "Iron", { 0, 2.65, 0 }, I, { 0.2, 2.5, 0.06 }), -- Blade
			P(4, "Blade", "Wedge", "Iron", { 0.05, 4.1, 0 }, YM90, { 0.06, 0.4, 0.1 }), -- TipR
			P(5, "Blade", "Wedge", "Iron", { -0.05, 4.1, 0 }, Y90, { 0.06, 0.4, 0.1 }), -- TipL
			P(6, "Guard", "Block", "Iron", { 0.275, 1.4, 0 }, I, { 0.55, 0.16, 0.24 }), -- GuardR
			P(7, "Guard", "Block", "Iron", { -0.275, 1.4, 0 }, I, { 0.55, 0.16, 0.24 }), -- GuardL
			P(8, "Guard", "CornerWedge", "Iron", { 0.47, 1.54, 0 }, { 0, 0.25881904510252074, 0, 0.9659258262890683 }, { 0.12, 0.12, 0.16 }), -- FinialR
			P(9, "Guard", "CornerWedge", "Iron", { -0.47, 1.54, 0 }, { 0, 0.5000000000000001, 0, 0.8660254037844387 }, { 0.16, 0.12, 0.12 }), -- FinialL
		}, tiers(N, N, N)),
	fixture("C14", "C14 Arming moved (0, +0.27, +0.05)", "C02 translated by (0, +0.27, +0.05)",
		"Arming, moved", {
			P(1, "Pommel", "Ball", "Iron", { 0, 0.5700000000000001, 0.05 }, I, { 0.3, 0.3, 0.3 }), -- Pommel
			P(2, "Grip", "Cylinder", "Iron", { 0, 1.15, 0.05 }, Z90, { 0.9, 0.16, 0.16 }), -- Grip
			P(3, "Guard", "Block", "Iron", { 0, 1.67, 0.05 }, I, { 1.1, 0.16, 0.24 }), -- Guard
			P(4, "Blade", "Block", "Iron", { 0, 2.92, 0.05 }, I, { 0.2, 2.5, 0.06 }), -- Blade
			P(5, "Blade", "Wedge", "Iron", { 0.05, 4.369999999999999, 0.05 }, YM90, { 0.06, 0.4, 0.1 }), -- TipR
			P(6, "Blade", "Wedge", "Iron", { -0.05, 4.369999999999999, 0.05 }, Y90, { 0.06, 0.4, 0.1 }), -- TipL
		}, tiers(N, N, N)),
	fixture("C15", "C15 Arming rotated 4° about Z",
		"C02 turned 4° about Z at the grip (0, 0.88, 0): a real change in the fixed frame", "Arming, turned 4 deg", {
			P(1, "Pommel", "Ball", "Iron", { 0.04045875477159268, 0.3014128508493019, 0 }, { 0, 0, 0.03489949670250097, 0.9993908270190958 }, { 0.3, 0.3, 0.3 }), -- Pommel
			P(2, "Grip", "Cylinder", "Iron", { 0, 0.88, 0 }, { 0, 0, 0.7313537016191705, 0.6819983600624986 }, { 0.9, 0.16, 0.16 }), -- Grip
			P(3, "Guard", "Block", "Iron", { -0.03627336634694515, 1.3987333061351084, 0 }, { 0, 0, 0.03489949670250097, 0.9993908270190958 }, { 1.1, 0.16, 0.24 }), -- Guard
			P(4, "Blade", "Block", "Iron", { -0.12346895852710178, 2.6456883689598887, 0 }, { 0, 0, 0.03489949670250097, 0.9993908270190958 }, { 0.2, 2.5, 0.06 }), -- Blade
			P(5, "Blade", "Wedge", "Iron", { -0.17473764294309224, 4.09564406552384, 0 }, { 0.02467767077833599, -0.7066760308408345, 0.02467767077833599, 0.7066760308408345 }, { 0.06, 0.4, 0.1 }), -- TipR
			P(6, "Blade", "Wedge", "Iron", { -0.2744940479690747, 4.088668418149427, 0 }, { -0.02467767077833599, 0.7066760308408345, 0.02467767077833599, 0.7066760308408345 }, { 0.06, 0.4, 0.1 }), -- TipL
		}, tiers(N, H, H), tiers(N, H, Ex)),
}

local BY_ID: { [string]: Measured } = {}
local ORDER: { string } = {}
for _, f in LIST do
	BY_ID[f.id] = f
	table.insert(ORDER, f.id)
end

local Calibration = {
	order = ORDER, -- {"C01", "C02", "C02s", "C04", …, "C15"}
	list = LIST, -- the fixtures, in that order
}

-- The fixture with this id; errors on an unknown id (a test bug).
function Calibration.get(id: string): Measured
	local f = BY_ID[id]
	if f == nil then
		error("Calibration.get: no fixture " .. tostring(id), 2)
	end
	return f
end

-- A fresh, mutable deep copy of the fixture's core.
function Calibration.core(id: string): Build.Core
	return Build.copy(Calibration.get(id).core)
end

Build.freeze(LIST)
table.freeze(ORDER)
return table.freeze(Calibration)
