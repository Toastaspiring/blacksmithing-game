--!strict
-- tests/Definitions/Types.spec.luau — Definitions/Types (SPEC §2.2, §2.4; T-DEF-01): the id unions declared in
-- Types.luau are read from its source and compared with the catalogs, so a catalog id that is not a declared id (or
-- a declared id with no row) fails here rather than at a cast.

local fs = require("@lune/fs")
local A = require("../lib/Assert")
local Test = require("../lib/Test")
local H = require("./DefsHelpers")
local EquipmentTypes = require("../../src/shared/Definitions/EquipmentTypes")
local Materials = require("../../src/shared/Definitions/Materials")
local MinigameFamilies = require("../../src/shared/Definitions/MinigameFamilies")
local Rarities = require("../../src/shared/Definitions/Rarities")
local Stats = require("../../src/shared/Definitions/Stats")
local Steps = require("../../src/shared/Definitions/Steps")
local Tiers = require("../../src/shared/Definitions/Tiers")
local Types = require("../../src/shared/Definitions/Types")
local Validate = require("../../src/shared/Definitions/Validate")

local SOURCE = "src/shared/Definitions/Types.luau"

-- The string literals of each `export type <Name>Id = "A" | "B" ...` union, in source order (comments dropped).
local function unions(): { [string]: { string } }
	local text = string.gsub(fs.readFile(SOURCE), "\r\n", "\n")
	local out: { [string]: { string } } = {}
	local current: string? = nil
	for _, line in string.split(text, "\n") do
		local code = string.gsub(line, "%-%-.*$", "")
		local name = string.match(code, "^export type (%w+Id) =")
		if name then
			current = name
			out[name] = {}
		elseif string.match(code, "^export type") or string.match(code, "^%S") then
			current = nil
		end
		if current then
			for id in string.gmatch(code, '"(%w+)"') do
				table.insert(out[current], id)
			end
		end
	end
	return out
end

return Test.suite("Definitions/Types", function(t)
	t.it("types only: the module returns an empty frozen table", function()
		A.eq(next(Types), nil)
		A.truthy(table.isfrozen(Types))
	end)

	t.it("T-DEF-01 every declared id is a PascalCase, unique string", function()
		local u = unions()
		for _, name in { "EquipmentTypeId", "SlotId", "ShapeId", "MaterialId", "StepId", "FamilyId", "TierId", "RarityId",
			"StatId", "FactorId", "StationId" } do
			local ids = u[name]
			A.truthy(ids ~= nil and #ids > 0, name .. " is declared")
			local seen: { [string]: boolean } = {}
			for _, id in ids do
				A.truthy(string.match(id, "^%u%w*$") ~= nil, name .. ": " .. id .. " is PascalCase")
				A.falsy(seen[id], name .. ": " .. id .. " is unique")
				seen[id] = true
			end
		end
	end)

	t.it("T-DEF-01 catalog ids are exactly the declared unions, in catalogue order", function()
		local u = unions()
		A.deepEq(H.ids(Materials.ordered), u.MaterialId, "MaterialId")
		A.deepEq(H.ids(Steps.ordered), u.StepId, "StepId")
		A.deepEq(H.ids(Tiers.ordered), u.TierId, "TierId")
		A.deepEq(H.ids(Rarities.ordered), u.RarityId, "RarityId")
		A.deepEq(H.ids(Stats.ordered), u.StatId, "StatId")
		A.deepEq(H.ids(MinigameFamilies.ordered), u.FamilyId, "FamilyId")
		A.deepEq(Validate.FACTOR_ORDER, u.FactorId, "FactorId order")
	end)

	t.it("T-DEF-01 equipment types and slots use declared ids; the Sword's slots come first", function()
		local u = unions()
		for _, et in EquipmentTypes.ordered do
			A.truthy(table.find(u.EquipmentTypeId, et.id) ~= nil, et.id)
			for _, s in et.slots do
				A.truthy(table.find(u.SlotId, s.id) ~= nil, et.id .. "." .. s.id)
			end
		end
		A.deepEq(table.move(u.SlotId, 1, 4, 1, {}), { "Blade", "Guard", "Grip", "Pommel" })
		A.deepEq(u.EquipmentTypeId, { "Sword", "Axe", "Spear", "Hammer", "Armor" })
		A.deepEq(u.ShapeId, { "Block", "Wedge", "CornerWedge", "Cylinder", "Ball" })
		A.deepEq(u.StationId, { "DraftingTable", "Furnace", "Anvil", "Grindstone" })
	end)
end)
