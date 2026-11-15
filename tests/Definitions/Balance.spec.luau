--!strict
-- tests/Definitions/Balance.spec.luau — Definitions/Balance (SPEC §2.8, §4, §5, §8, §16.10; T-DEF-06).

local A = require("../lib/Assert")
local Dump = require("../lib/Dump")
local Test = require("../lib/Test")
local H = require("./DefsHelpers")
local Balance = require("../../src/shared/Definitions/Balance")
local EquipmentTypes = require("../../src/shared/Definitions/EquipmentTypes")
local Limits = require("../../src/shared/Definitions/Limits")
local Tiers = require("../../src/shared/Definitions/Tiers")

local GEOMETRY: { [string]: any } = {
	EPS_GEOM = 1e-7,
	HIDE_OFFSET = 0.012,
	MIN_PART_VOLUME = 0.0002,
	ENCLOSED_EXPOSED_MAX = 0.02,
	H_VOL = 0.05,
	N_MIN_AXIS = 2,
	N_MAX_AXIS = 48,
	N_MAX_PART = 3000,
	N_VOL_TOTAL = 12000,
	H_SURF = 0.04,
	NS_MAX = 64,
	N_SURF_WORK = 40000,
	N_SUB_WORK = 24000,
	COVER_BALL_GRID = 4,
	VERDICT_WORK_MAX = 700000,
	H_LADDER = { 1, 1.25, 1.5, 2, 2.5, 3, 4, 5, 6, 8, 10, 12, 16 },
	MAX_EXACT = 3,
	H_OVERLAP = 0.0125,
	OVERLAP_N_MIN = 4,
	OVERLAP_N_MAX = 24,
	N_OVERLAP_WORK = 40000,
	GJK_MAX_ITER = 48,
	AXIS_ELONGATION = 1.5,
	AXIS_MAX_TILT_COS = 0.7071,
	EDGE_CELL = 0.02,
	RASTER_TOL = 0.005,
	EDGE_MAX_CELLS = 12000,
	EDGE_MAX_WORK = 30000,
	EDGE_MAX_THICK = 0.25,
	EDGE_DOWN_COS = 0.5,
	EDGE_SIMPLIFY = 1,
	EDGE_GAP_BRIDGE = 3,
	EDGE_MIN_CHAIN = 3,
	EDGE_MAX_POINTS = 256,
	CUT_LO = 10,
	CUT_HI = 60,
}

local DIFFICULTY: { [string]: any } = {
	V_PART_FULL = 0.004,
	JOINT_BOOST = 1.0,
	A_JOINT_REF = 0.05,
	THICK_BUDGET = 400,
	SIGMA_LO = 45,
	SIGMA_HI = 130,
	THIN_SHARE_MIN = 0.25,
	ASYM_TOL = 0.02,
	ASYM_RAMP = 0.03,
	ASYM_N_MIN = 10,
	ASYM_AXIS_X = 0.6,
	ASYM_WORK = 30000,
}

local STATS_SWORD: { [string]: any } = {
	MATERIAL_SCALE = 100,
	PURITY_FLOOR = 0.70,
	SHARP_FLOOR = 0.30,
	DURA_FLOOR = 0.50,
	FORGE_FLOOR = 0.60,
	EDGE_REF = 6.0,
	EDGE_GAIN = 1.0,
	MASS_REF = 0.80,
	MASS_BIAS = 0.4,
	MASS_FACTOR_MIN = 0.6,
	MASS_FACTOR_MAX = 1.3,
	DAMAGE_BASE = 28,
	BALANCE_IDEAL = 0.08,
	BALANCE_TOLERANCE = 0.04,
	BALANCE_FALLOFF = 0.30,
	BALANCE_REACH_MIN = 1.0,
}

local QUALITY: { [string]: any } = {
	WEIGHT_SUM_TOL = 1e-9,
	FAILED_STEP_CAP_TIER = "Normal",
	DESIGN_GAMMA = 0.15,
}

return Test.suite("Definitions/Balance", function(t)
	t.it("groups are exactly Geometry, Difficulty, Stats, Quality and Display (§2.8)", function()
		A.deepEq(Dump.sortedKeys(Balance :: any), { "Difficulty", "Display", "Geometry", "Quality", "Stats" })
	end)

	t.it("Geometry = §16.10", function()
		A.deepEq(Balance.Geometry, GEOMETRY)
	end)

	t.it("Difficulty = §16.10", function()
		A.deepEq(Balance.Difficulty, DIFFICULTY)
	end)

	t.it("Stats.Sword = §8.2 / §16.10, one row per enabled equipment type", function()
		A.deepEq(Balance.Stats.Sword, STATS_SWORD)
		for _, et in EquipmentTypes.enabled do
			A.truthy((Balance.Stats :: any)[et.id] ~= nil, et.id .. " has stat constants")
		end
		A.deepEq(Dump.sortedKeys(Balance.Stats :: any), { "Sword" })
	end)

	t.it("Quality = §8.5 / §16.10; FAILED_STEP_CAP_TIER is the first enabled tier", function()
		A.deepEq(Balance.Quality, QUALITY)
		A.eq(Balance.Quality.FAILED_STEP_CAP_TIER, Tiers.enabled[1].id)
	end)

	t.it("Display = {MASS_UNIT_LABEL = \"kg\"} (Q13)", function()
		A.deepEq(Balance.Display, { MASS_UNIT_LABEL = "kg" })
	end)

	t.it("coupled constants agree: HIDE_OFFSET = CONTACT_TOL + 0.002, RASTER_TOL = CONTACT_TOL / 2", function()
		A.near(Balance.Geometry.HIDE_OFFSET, Limits.CONTACT_TOL + 0.002, 1e-15)
		A.near(Balance.Geometry.RASTER_TOL, Limits.CONTACT_TOL / 2, 1e-15)
		A.truthy(Balance.Geometry.EPS_GEOM < Limits.EPS_CONTAIN, "EPS_GEOM below the containment epsilon")
		A.near(Balance.Geometry.AXIS_MAX_TILT_COS, math.sqrt(0.5), 1e-4, "45°")
	end)

	t.it("ladders and budgets are well formed", function()
		local ladder = Balance.Geometry.H_LADDER
		A.eq(ladder[1], 1, "the ladder starts at the base spacing")
		for k = 2, #ladder do
			A.truthy(ladder[k] > ladder[k - 1], "H_LADDER increases at " .. k)
		end
		local g = Balance.Geometry
		A.truthy(g.N_MIN_AXIS <= g.N_MAX_AXIS and g.OVERLAP_N_MIN <= g.OVERLAP_N_MAX, "per-axis bounds")
		A.truthy(g.N_MAX_PART <= g.N_VOL_TOTAL, "a part fits in the total budget")
		A.truthy(g.CUT_LO < g.CUT_HI, "cutIndex ramp")
		A.eq(g.CUT_HI - g.CUT_LO, 50, "cutIndex = clamp((L/t − 10)/50, 0, 1) (§4.6)")
		local d = Balance.Difficulty
		A.truthy(d.SIGMA_LO < d.SIGMA_HI, "Thinness ramp")
		A.near(d.ASYM_TOL + d.ASYM_RAMP, 0.05, 1e-15, "Asymmetry ramps to 0.05")
	end)

	t.it("the stat constants keep the §8.2 ranges sane", function()
		local s = Balance.Stats.Sword
		for _, k in { "PURITY_FLOOR", "SHARP_FLOOR", "DURA_FLOOR", "FORGE_FLOOR", "MASS_BIAS" } do
			local v = (s :: any)[k]
			A.truthy(v > 0 and v < 1, k .. " is a fraction")
		end
		A.truthy(s.MASS_FACTOR_MIN < 1 and 1 < s.MASS_FACTOR_MAX, "F_mass = 1 at the reference mass")
		A.truthy(s.BALANCE_TOLERANCE < s.BALANCE_IDEAL, "the plateau stays in front of the guard")
		A.near(s.BALANCE_IDEAL - s.BALANCE_TOLERANCE, 0.04, 1e-15, "full marks from 4 % of reach")
		A.near(s.BALANCE_IDEAL + s.BALANCE_TOLERANCE, 0.12, 1e-15, "to 12 %")
		A.truthy(s.DAMAGE_BASE * s.MASS_FACTOR_MAX * (1 + s.EDGE_GAIN) <= 100, "Damage tops out ≤ 100 before the clamp")
	end)

	t.it("T-DEF-06 deep-frozen, finite and JSON-safe", function()
		local frozen, at = H.isDeepFrozen(Balance)
		A.truthy(frozen, "not frozen at " .. tostring(at))
		local ok, bad = H.jsonSafe(Balance)
		A.truthy(ok, "not JSON-safe at " .. tostring(bad))
	end)
end)
