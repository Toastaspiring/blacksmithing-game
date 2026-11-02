--!strict
-- tests/fixtures/Blueprints.luau — the golden fixtures F1–F5 (SPEC §14.7, coordinates E-S8.3): canonical
-- BlueprintCores in blueprint space, every part at least 0.02 stud inside the Sword hitbox, with the outcomes §14
-- expects of them. Deep-frozen, so a module under test that mutates its input fails loudly; Blueprints.core(id) hands
-- out a fresh mutable copy for building variants.
--
--   F1 ArmingSword   Iron hilt, two-part Steel blade with a 45° tip overlapping the blade
--   F2 MinimalSword  one Iron Block per slot, faces flush
--   F3 Rapier        Steel; X-axis cylinder grip, ball quillons overlapping the guard, a 0.035-stud blade and a
--                    single-edged wedge tip (needs MIN_DIM ≤ 0.035, else F3 takes the new MIN_DIM)
--   F4 Cleaver       wide Iron blade offset to +X, wedge top
--   F5 StarterSword  F1 with parts 4 and 5 in Iron: the granted starter (Q21). SPEC §9.3 makes Persistence/Template's
--                    STARTER the one copy tests import; until M7 builds it, this is the copy, and Template.STARTER's
--                    parts must equal these.
--
-- expect (what §14 states; tests/FixtureSet checks what M1 can, the rest waits for its milestone):
--   canon       Canonical.draft(core) is ok and returns core bit for bit (core is a fixed point), M1
--   validation  valid, no errors (Physics/Analyze, M2)
--   tiers       played tier per step and tierRaw where it differs: SPEC §5.5's table (T-DIF-11, M3). The d values
--               and E-S2.9's physics and factor tables are blessed into goldens from Analyze.run (M3); S8 keeps no
--               copy of them (§14.7)
--   starter     F5 only: D ≤ Hard.dMin − Tol.STARTER_MARGIN on every step (T-DIF-11, Q7, Q21)
--   oracle      E-S8.3's independent analytic oracle (densities Iron 7.87, Steel 7.85; overlaps counted once):
--               minSide, margin (to the hitbox), volume (union), mass, comX/comY, gripY (volume-weighted centroid of
--               the Grip parts), reach (grip point to the farthest exact Blade vertex), balanceFromHand
--               (COM_y − grip_y); printed to 3–5 decimals. S2's E-S2.9 physics must agree (T-PHY-03, M2)
--   save        what Blueprint.Save does with it: "Valid" = stored with valid = true (S-E2E-03, M7)

local Build = require("./Build")

type Part = Build.Part
type Core = Build.Core

export type Oracle = {
	minSide: number,
	margin: number,
	volume: number,
	mass: number,
	comX: number,
	comY: number,
	gripY: number,
	reach: number,
	balanceFromHand: number,
}
export type Expect = {
	canon: { ok: boolean, equals: string },
	validation: { valid: boolean },
	tiers: { [string]: string },
	tierRaw: { [string]: string },
	starter: boolean,
	oracle: Oracle,
	save: string,
}
export type Fixture = { id: string, label: string, what: string, core: Core, expect: Expect }

local P = Build.part
local I, Z45, Z90, Y90 = Build.I, Build.Z45, Build.Z90, Build.Y90

local function f1Parts(bladeMaterial: string): { Part }
	return {
		P(1, "Pommel", "Ball", "Iron", { 0, 0.17, 0 }, I, { 0.26, 0.26, 0.26 }),
		P(2, "Grip", "Block", "Iron", { 0, 0.75, 0 }, I, { 0.16, 0.90, 0.16 }),
		P(3, "Guard", "Block", "Iron", { 0, 1.29, 0 }, I, { 1.00, 0.18, 0.24 }),
		P(4, "Blade", "Block", bladeMaterial, { 0, 2.68, 0 }, I, { 0.16, 2.60, 0.06 }),
		P(5, "Blade", "Block", bladeMaterial, { 0, 3.98, 0 }, Z45, { 0.113, 0.113, 0.055 }),
	}
end

local NORMAL3 = { Smelting = "Normal", Hammering = "Normal", Sharpening = "Normal" }

local function fixture(id: string, label: string, what: string, name: string, parts: { Part }, tiers: { [string]: string },
	tierRaw: { [string]: string }, oracle: Oracle, starter: boolean?): Fixture
	return {
		id = id,
		label = label,
		what = what,
		core = Build.core(name, parts),
		expect = {
			canon = { ok = true, equals = "draft" },
			validation = { valid = true },
			tiers = Build.copy(tiers),
			tierRaw = Build.copy(tierRaw),
			starter = starter == true,
			oracle = oracle,
			save = "Valid",
		},
	}
end

local LIST: { Fixture } = {
	fixture("F1", "F1 ArmingSword", "Iron hilt, two-part Steel blade, 45° tip overlapping the blade", "Arming Sword",
		f1Parts("Steel"), NORMAL3, NORMAL3, {
			minSide = 0.055, margin = 0.040, volume = 0.10076, mass = 0.7925, comX = 0, comY = 1.4174, gripY = 0.75,
			reach = 3.3100, balanceFromHand = 0.6674,
		}),
	fixture("F2", "F2 MinimalSword", "one Iron Block per slot", "Minimal Sword", {
		P(1, "Pommel", "Block", "Iron", { 0, 0.20, 0 }, I, { 0.30, 0.30, 0.30 }),
		P(2, "Grip", "Block", "Iron", { 0, 0.85, 0 }, I, { 0.20, 1.00, 0.20 }),
		P(3, "Guard", "Block", "Iron", { 0, 1.45, 0 }, I, { 0.80, 0.20, 0.20 }),
		P(4, "Blade", "Block", "Iron", { 0, 2.75, 0 }, I, { 0.20, 2.40, 0.08 }),
	}, NORMAL3, NORMAL3, {
		minSide = 0.080, margin = 0.050, volume = 0.13740, mass = 1.0813, comX = 0, comY = 1.3930, gripY = 0.85,
		reach = 3.1019, balanceFromHand = 0.5430,
	}),
	fixture("F3", "F3 Rapier", "Steel, X-axis cylinder grip, ball quillons, 0.035-stud blade, single-edged wedge tip",
		"Rapier", {
			P(1, "Pommel", "Ball", "Steel", { 0, 0.16, 0 }, I, { 0.28, 0.28, 0.28 }),
			P(2, "Grip", "Cylinder", "Steel", { 0, 0.75, 0 }, Z90, { 0.90, 0.13, 0.13 }),
			P(3, "Guard", "Block", "Steel", { 0, 1.24, 0 }, I, { 0.90, 0.08, 0.08 }),
			P(4, "Guard", "Ball", "Steel", { -0.45, 1.24, 0 }, I, { 0.12, 0.12, 0.12 }),
			P(5, "Guard", "Ball", "Steel", { 0.45, 1.24, 0 }, I, { 0.12, 0.12, 0.12 }),
			P(6, "Blade", "Block", "Steel", { 0, 2.98, 0 }, I, { 0.07, 3.40, 0.035 }),
			P(7, "Blade", "Wedge", "Steel", { 0, 4.83, 0 }, Y90, { 0.035, 0.30, 0.07 }),
		}, { Smelting = "Normal", Hammering = "Hard", Sharpening = "Hard" },
		{ Smelting = "Normal", Hammering = "Expert", Sharpening = "Master" }, {
			minSide = 0.035, margin = 0.020, volume = 0.03907, mass = 0.3067, comX = 0.0001, comY = 1.1767, gripY = 0.75,
			reach = 4.2302, balanceFromHand = 0.4267,
		}),
	fixture("F4", "F4 Cleaver", "wide Iron blade offset to +X, wedge top", "Cleaver", {
		P(1, "Pommel", "Block", "Iron", { 0, 0.20, 0 }, I, { 0.30, 0.20, 0.30 }),
		P(2, "Grip", "Block", "Iron", { 0, 0.75, 0 }, I, { 0.22, 0.90, 0.22 }),
		P(3, "Guard", "Block", "Iron", { 0, 1.275, 0 }, I, { 0.50, 0.15, 0.30 }),
		P(4, "Blade", "Block", "Iron", { 0.175, 2.45, 0 }, I, { 0.85, 2.20, 0.16 }),
		P(5, "Blade", "Wedge", "Iron", { 0.175, 3.75, 0 }, Y90, { 0.16, 0.40, 0.85 }),
	}, { Smelting = "Hard", Hammering = "Normal", Sharpening = "Hard" },
		{ Smelting = "Expert", Hammering = "Normal", Sharpening = "Hard" }, {
			minSide = 0.150, margin = 0.100, volume = 0.41046, mass = 3.2303, comX = 0.1485, comY = 2.1882, gripY = 0.75,
			reach = 3.2567, balanceFromHand = 1.4382,
		}),
	fixture("F5", "F5 StarterSword", "F1 with parts 4 and 5 in Iron, the granted starter (Q21)", "Starter Sword",
		f1Parts("Iron"), NORMAL3, NORMAL3, {
			minSide = 0.055, margin = 0.040, volume = 0.10076, mass = 0.7930, comX = 0, comY = 1.4182, gripY = 0.75,
			reach = 3.3100, balanceFromHand = 0.6682,
		}, true),
}

local BY_ID: { [string]: Fixture } = {}
local ORDER: { string } = {}
for _, f in LIST do
	BY_ID[f.id] = f
	table.insert(ORDER, f.id)
end

local Blueprints = {
	order = ORDER, -- {"F1", …, "F5"}
	list = LIST, -- the fixtures, in that order
}

-- The fixture with this id; errors on an unknown id (a test bug).
function Blueprints.get(id: string): Fixture
	local f = BY_ID[id]
	if f == nil then
		error("Blueprints.get: no fixture " .. tostring(id), 2)
	end
	return f
end

-- A fresh, mutable deep copy of the fixture's core.
function Blueprints.core(id: string): Core
	return Build.copy(Blueprints.get(id).core)
end

Build.freeze(LIST)
table.freeze(ORDER)
return table.freeze(Blueprints)
