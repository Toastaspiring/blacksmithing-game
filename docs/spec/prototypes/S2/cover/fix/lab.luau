--!nocheck
-- the modules of a tree: LAB_ROOT (default the repo)
local process = require("@lune/process")
local ROOT = process.env.LAB_ROOT or "C:/Users/louis/Documents/RANDOM/ROBLOX/Blacksmithing Game"
local function req(p) return (require :: any)(ROOT .. "/" .. p) end
local L = {
	ROOT = ROOT,
	Balance = req("src/shared/Definitions/Balance"),
	Cover = req("src/shared/Physics/Cover"),
	Sampling = req("src/shared/Physics/Sampling"),
	Shapes = req("src/shared/Physics/Shapes"),
	Analyze = req("src/shared/Physics/Analyze"),
	Quat = req("src/shared/Blueprint/Quat"),
	Mirror = req("src/shared/Blueprint/Mirror"),
	Canonical = req("src/shared/Blueprint/Canonical"),
	H = req("tests/Physics/PhysicsHelpers"),
	Brute = req("tests/Physics/CoverBrute"),
	Oracle = req("tests/Physics/VisibleOracle"),
	TestRng = req("tests/lib/TestRng"),
	Blueprints = req("tests/fixtures/Blueprints"),
	Fx = req("docs/spec/prototypes/S2/v2/fixtures"),
	Worst = req("docs/spec/prototypes/S2/cover/worst_designs"),
	Attacks = req("tests/Physics/CoverAttacks"),
}
L.Geo = L.Balance.Geometry
function L.prepared(parts)
	local out = {}
	for i, p in ipairs(parts) do out[i] = L.Shapes.prepare(p, i) end
	return out
end
function L.units(parts)
	local e = L.Sampling.exposure(L.prepared(parts))
	return e.verdictWork, e.capped, e
end
return L
