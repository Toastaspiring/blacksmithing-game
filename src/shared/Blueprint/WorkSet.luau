--!strict
-- Blueprint/WorkSet (SPEC §7.2, §8.5; owner S4): the one selector of a step's work set W_s. Physics and Crafting both
-- call it, so difficulty and rewards use the same parts and Physics never requires Crafting (§1.3 L4). Pure.
--   select(parts, kept, selector)  the ascending indices of the kept parts the selector matches, in a new array.
--                                  kept is PhysicsReport.kept: one boolean per part, in blueprint order (§4.7).
--                                  selector is a step's CraftPlans worksOn: "All", or a list of slots in any order.
-- Cleaned parts (Dust, Enclosed, §4.4) are in no work set, so hidden cores and specks buy nothing. A step with an empty
-- work set is not this module's call: validity implies a kept Blade part, and Plan.build asserts every set non-empty.
-- A kept that is not one boolean per part, or a selector that is neither form, is a caller's bug and errors.

local CraftPlans = require("../Definitions/CraftPlans")
local Schema = require("./Schema")

local WorkSet = {}

function WorkSet.select(parts: { Schema.PartData }, kept: { boolean }, selector: CraftPlans.WorkSelector): { number }
	if #kept ~= #parts then
		error(string.format("WorkSet.select: kept has %d entries for %d parts", #kept, #parts), 2)
	end
	local out: { number } = {}
	if selector == "All" then
		for i = 1, #parts do
			if kept[i] then
				table.insert(out, i)
			end
		end
	elseif type(selector) == "table" then
		for i = 1, #parts do
			if kept[i] and table.find(selector, parts[i].slot) ~= nil then
				table.insert(out, i)
			end
		end
	else
		error('WorkSet.select: selector must be "All" or a list of slots, got ' .. tostring(selector), 2)
	end
	return out
end

return table.freeze(WorkSet)
