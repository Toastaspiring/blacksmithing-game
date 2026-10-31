--!strict
-- Profile.Data safety + size budget (prototype data shapes; S1 owns the real template).
local serde = require("@lune/serde")
local Test = require("../lib/Test")
local A = require("../lib/Assert")
local ProfileSafe = require("../lib/ProfileSafe")
local TestRng = require("../lib/TestRng")

local function part(rng: TestRng.TestRng, decimals: number?): { [string]: any }
	local function num(x: number): number
		if decimals then
			local m = 10 ^ (decimals :: number)
			return math.floor(x * m + 0.5) / m
		end
		return x
	end
	return {
		slot = "Blade", shape = "Block", material = "Steel",
		pos = { num(rng:range(-0.5, 0.5)), num(rng:range(-1, 4)), num(rng:range(-0.1, 0.1)) },
		rot = { num(rng:range(-1, 1)), num(rng:range(-1, 1)), num(rng:range(-1, 1)), num(rng:range(-1, 1)) },
		size = { num(rng:range(0.05, 1)), num(rng:range(0.05, 3)), num(rng:range(0.05, 0.3)) },
	}
end

local function maxProfile(blueprints: number, items: number, partsPer: number, decimals: number?): { [string]: any }
	local rng = TestRng.new(99)
	local function bp(i: number)
		local parts = {}
		for _ = 1, partsPer do table.insert(parts, part(rng, decimals)) end
		return { id = "bp" .. i, name = "Blueprint " .. i, equipmentType = "Sword", parts = parts }
	end
	local data = { version = 1, blueprints = {}, items = {}, displays = { "", "", "", "" } }
	for i = 1, blueprints do table.insert(data.blueprints, bp(i)) end
	for i = 1, items do
		table.insert(data.items, {
			id = "it" .. i, balanceVersion = 1, blueprint = bp(1000 + i), rarity = "Rare", quality = 0.61803398874989,
			steps = {
				{ step = "Smelting", tier = "Normal", seed = 4000000000, score = 0.7234 },
				{ step = "Hammering", tier = "Hard", seed = 123456789, score = 0.6612 },
				{ step = "Sharpening", tier = "Hard", seed = 987654321, score = 0.5891 },
			},
			stats = { damage = 12.345678901234, reach = 3.3099, sharpness = 0.73, durability = 0.81 },
		})
	end
	return data
end

return Test.suite("Persistence/ProfileSafe (prototype)", function(t)
	t.it("rejects what ProfileStore cannot store", function()
		A.truthy(ProfileSafe.check({ 1, 2, nil :: any, 4 }) ~= nil, "gap")
		A.truthy(ProfileSafe.check({ 1, x = 2 }) ~= nil, "mixed")
		A.truthy(ProfileSafe.check({ a = 0 / 0 }) ~= nil, "nan")
		A.truthy(ProfileSafe.check({ a = function() end }) ~= nil, "function")
		A.truthy(ProfileSafe.check(setmetatable({}, {})) ~= nil, "metatable")
		A.truthy(ProfileSafe.check({ [true :: any] = 1 }) ~= nil, "bool key")
		A.eq(ProfileSafe.check({ a = { 1, 2, 3 }, b = "ok", c = true }), nil)
	end)

	t.it("size budget probe: JSON bytes of a large profile", function()
		for _, cfg in { { 50, 200, 32, nil }, { 50, 200, 32, 4 }, { 20, 100, 16, 4 } } do
			local data = maxProfile(cfg[1] :: number, cfg[2] :: number, cfg[3] :: number, cfg[4] :: number?)
			A.eq(ProfileSafe.check(data), nil)
			local bytes = #serde.encode("json", data)
			print(string.format("      blueprints=%d items=%d parts=%d decimals=%s -> %.0f KB JSON",
				cfg[1] :: number, cfg[2] :: number, cfg[3] :: number, tostring(cfg[4]), bytes / 1024))
			A.truthy(bytes < 4 * 1024 * 1024, "over the 4 MB DataStore key limit")
		end
	end)
end)
