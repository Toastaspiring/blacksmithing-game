--!strict
-- tests/Definitions/Limits.spec.luau — Definitions/Limits (SPEC §3.6, §9.8, §16.2; T-DEF-06 "Limits consistent").

local A = require("../lib/Assert")
local Test = require("../lib/Test")
local H = require("./DefsHelpers")
local EquipmentTypes = require("../../src/shared/Definitions/EquipmentTypes")
local Limits = require("../../src/shared/Definitions/Limits")

local EXPECTED: { [string]: any } = {
	POS_ABS_MAX = 16,
	MIN_DIM = 0.02,
	MAX_DIM = 6.0,
	EPS_CONTAIN = 1e-4,
	CONTACT_TOL = 0.01,
	MAX_PARTS = 24,
	MAX_PART_ID = 65535,
	QUAT_NORM_TOL = 1e-9,
	QUAT_INPUT_TOL = 1e-2,
	NAME_MIN_CP = 1,
	NAME_MAX_CP = 32,
	NAME_MAX_INPUT_BYTES = 256,
	MAX_ISSUES_STORED = 8,
	MAX_STEP_FLAGS = 10,
	MAX_BLUEPRINTS = 40,
	MAX_ITEMS = 150,
	MAX_UI_FLAGS = 64,
	UI_FLAG_KEY_MAX_BYTES = 32,
	DATASTORE_VALUE_LIMIT = 4194304,
	KEY_WRITE_BYTES_PER_MIN = 4000000,
	PROFILE_SIZE_WARN_BYTES = 1000000,
	PROFILE_SIZE_BLOCK_BYTES = 2000000,
	PROFILE_STORE_NAME = "PlayerData",
	PROFILE_KEY_PREFIX = "User_",
}

-- §9.8: W(B, I, P) = 3,606 + B·(775 + 336·P) + I·(1,708 + 336·P) bytes for P ≥ 1 (E-S1.4)
local function worstProfileBytes(b: number, i: number, p: number): number
	return 3606 + b * (775 + 336 * p) + i * (1708 + 336 * p)
end

return Test.suite("Definitions/Limits", function(t)
	t.it("values = §16.2, and nothing else", function()
		A.deepEq(Limits, EXPECTED)
	end)

	t.it("T-DEF-06 geometry bounds are consistent with the Sword hitbox", function()
		local g = (EquipmentTypes.get("Sword") :: any).geometry
		A.truthy(Limits.MIN_DIM <= 0.05, "MIN_DIM is at most 0.05 (Q4)")
		A.truthy(Limits.MIN_DIM < Limits.MAX_DIM, "MIN_DIM < MAX_DIM")
		local dx, dy, dz = g.hitboxMax[1] - g.hitboxMin[1], g.hitboxMax[2] - g.hitboxMin[2], g.hitboxMax[3] - g.hitboxMin[3]
		local diagonal = math.sqrt(dx * dx + dy * dy + dz * dz)
		A.near(diagonal, 5.284, 0.001, "hitbox diagonal")
		A.truthy(Limits.MAX_DIM > diagonal, "MAX_DIM exceeds the hitbox diagonal")
		for k = 1, 3 do
			A.truthy(math.abs(g.hitboxMin[k]) <= Limits.POS_ABS_MAX and math.abs(g.hitboxMax[k]) <= Limits.POS_ABS_MAX,
				"hitbox inside ±POS_ABS_MAX")
		end
		A.truthy(Limits.EPS_CONTAIN < Limits.CONTACT_TOL and Limits.CONTACT_TOL < Limits.MIN_DIM, "tolerances below MIN_DIM")
		A.truthy(Limits.QUAT_NORM_TOL < Limits.QUAT_INPUT_TOL, "renormalize inside the input tolerance")
		A.eq(Limits.MAX_PARTS, g.partsMax, "MAX_PARTS = the Sword part limit")
		for _, s in (EquipmentTypes.get("Sword") :: any).slots do
			A.truthy(s.max <= Limits.MAX_PARTS, s.id .. " max within MAX_PARTS")
		end
		A.truthy(Limits.MAX_PART_ID >= Limits.MAX_PARTS and Limits.MAX_PART_ID < 65536, "part ids fit 16 bits")
	end)

	t.it("T-DEF-06 name and record limits are consistent", function()
		A.truthy(Limits.NAME_MIN_CP >= 1 and Limits.NAME_MIN_CP <= Limits.NAME_MAX_CP, "1 ≤ min ≤ max code points")
		A.truthy(Limits.NAME_MAX_CP * 2 <= Limits.NAME_MAX_INPUT_BYTES, "a Latin name (≤ 2 bytes per code point) fits")
		A.truthy(Limits.MAX_STEP_FLAGS >= 9, "≥ the 9 flag kinds, so no flag is dropped")
		A.truthy(Limits.MAX_ISSUES_STORED >= 5, "room for the 5 ValidationCodes")
	end)

	t.it("T-DEF-06 persistence budgets: the worst profile at the caps fits (§9.8, E-S1.4, E-S1.9)", function()
		local worst = worstProfileBytes(Limits.MAX_BLUEPRINTS, Limits.MAX_ITEMS, Limits.MAX_PARTS)
		A.eq(worst, 1822966, "W(40, 150, 24)")
		A.truthy(worst <= Limits.DATASTORE_VALUE_LIMIT / 2, "≤ 50 % of the key")
		A.truthy(worst < Limits.PROFILE_SIZE_BLOCK_BYTES, "the size block is unreachable under the MVP caps")
		A.truthy(Limits.PROFILE_SIZE_WARN_BYTES < Limits.PROFILE_SIZE_BLOCK_BYTES, "warn below block")
		A.truthy(2 * Limits.PROFILE_SIZE_BLOCK_BYTES <= Limits.KEY_WRITE_BYTES_PER_MIN, "2 writes/min fit the key's limit")
		A.truthy(Limits.PROFILE_SIZE_BLOCK_BYTES < Limits.DATASTORE_VALUE_LIMIT, "block below the value limit")
		A.truthy(Limits.MAX_UI_FLAGS * Limits.UI_FLAG_KEY_MAX_BYTES < 4096, "uiFlags stay small")
		A.eq(Limits.PROFILE_KEY_PREFIX .. "123", "User_123", "Roblox's right-to-be-forgotten key pattern")
	end)

	t.it("frozen and JSON-safe", function()
		A.truthy(table.isfrozen(Limits))
		local ok, bad = H.jsonSafe(Limits)
		A.truthy(ok, "not JSON-safe at " .. tostring(bad))
	end)
end)
