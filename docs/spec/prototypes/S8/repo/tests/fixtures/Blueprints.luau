--!strict
-- tests/fixtures/Blueprints.luau — golden reference blueprints (PROTOTYPE encoding).
-- Fixture frame: origin O = centre of the grip's top face (= guard's bottom face),
-- +Y toward the tip, +X across the guard, +Z through the blade. The real loader maps
-- this frame into S2's blueprint frame with one translation (FIXTURE_ORIGIN in S2 space).
-- Shapes follow ProtoShapes conventions (Cylinder axis = local X, etc.).

local S = math.sqrt(0.5) -- sin/cos 45°
local Z45 = { 0, 0, math.sin(math.pi / 8), math.cos(math.pi / 8) } -- 45° about Z (fixture data, not an authoritative path)
local Z90 = { 0, 0, S, S } -- 90° about Z: cylinder axis X -> Y
local Y90 = { 0, S, 0, S } -- 90° about Y: wedge slope from Y-Z plane into Y-X plane
local I = { 0, 0, 0, 1 }

local F = {}

-- F1 Arming sword — the Combat System's procedural sword (Sword.luau), Steel blade.
F.ArmingSword = {
	{ slot = "Pommel", shape = "Ball", material = "Iron", pos = { 0, -1.03, 0 }, rot = I, size = { 0.26, 0.26, 0.26 } },
	{ slot = "Grip", shape = "Block", material = "Iron", pos = { 0, -0.45, 0 }, rot = I, size = { 0.16, 0.90, 0.16 } },
	{ slot = "Guard", shape = "Block", material = "Iron", pos = { 0, 0.09, 0 }, rot = I, size = { 1.00, 0.18, 0.24 } },
	{ slot = "Blade", shape = "Block", material = "Steel", pos = { 0, 1.48, 0 }, rot = I, size = { 0.16, 2.60, 0.06 } },
	{ slot = "Blade", shape = "Block", material = "Steel", pos = { 0, 2.78, 0 }, rot = Z45, size = { 0.113, 0.113, 0.055 } },
}

-- F2 Minimal valid sword — one axis-aligned Block per slot, all Iron.
F.MinimalSword = {
	{ slot = "Pommel", shape = "Block", material = "Iron", pos = { 0, -1.15, 0 }, rot = I, size = { 0.30, 0.30, 0.30 } },
	{ slot = "Grip", shape = "Block", material = "Iron", pos = { 0, -0.50, 0 }, rot = I, size = { 0.20, 1.00, 0.20 } },
	{ slot = "Guard", shape = "Block", material = "Iron", pos = { 0, 0.10, 0 }, rot = I, size = { 0.80, 0.20, 0.20 } },
	{ slot = "Blade", shape = "Block", material = "Iron", pos = { 0, 1.40, 0 }, rot = I, size = { 0.20, 2.40, 0.08 } },
}

-- F3 Rapier — long, very thin Steel blade, cylinder grip, ball quillons, wedge point.
F.Rapier = {
	{ slot = "Pommel", shape = "Ball", material = "Steel", pos = { 0, -1.04, 0 }, rot = I, size = { 0.28, 0.28, 0.28 } },
	{ slot = "Grip", shape = "Cylinder", material = "Steel", pos = { 0, -0.45, 0 }, rot = Z90, size = { 0.90, 0.13, 0.13 } },
	{ slot = "Guard", shape = "Block", material = "Steel", pos = { 0, 0.04, 0 }, rot = I, size = { 0.90, 0.08, 0.08 } },
	{ slot = "Guard", shape = "Ball", material = "Steel", pos = { -0.45, 0.04, 0 }, rot = I, size = { 0.12, 0.12, 0.12 } },
	{ slot = "Guard", shape = "Ball", material = "Steel", pos = { 0.45, 0.04, 0 }, rot = I, size = { 0.12, 0.12, 0.12 } },
	{ slot = "Blade", shape = "Block", material = "Steel", pos = { 0, 1.78, 0 }, rot = I, size = { 0.07, 3.40, 0.035 } },
	{ slot = "Blade", shape = "Wedge", material = "Steel", pos = { 0, 3.63, 0 }, rot = Y90, size = { 0.035, 0.30, 0.07 } },
}

-- F4 Cleaver — wide, heavy, single-edged (asymmetric) Iron blade with a clipped top.
F.Cleaver = {
	{ slot = "Pommel", shape = "Block", material = "Iron", pos = { 0, -1.00, 0 }, rot = I, size = { 0.30, 0.20, 0.30 } },
	{ slot = "Grip", shape = "Block", material = "Iron", pos = { 0, -0.45, 0 }, rot = I, size = { 0.22, 0.90, 0.22 } },
	{ slot = "Guard", shape = "Block", material = "Iron", pos = { 0, 0.075, 0 }, rot = I, size = { 0.50, 0.15, 0.30 } },
	{ slot = "Blade", shape = "Block", material = "Iron", pos = { 0.175, 1.25, 0 }, rot = I, size = { 0.85, 2.20, 0.16 } },
	{ slot = "Blade", shape = "Wedge", material = "Iron", pos = { 0.175, 2.55, 0 }, rot = Y90, size = { 0.16, 0.40, 0.85 } },
}

F.order = { "ArmingSword", "MinimalSword", "Rapier", "Cleaver" }

return F
