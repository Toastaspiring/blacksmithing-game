--!strict
-- T-BP-14 Blueprint/WorkSet (SPEC §7.1, §7.2, §8.5, E-S8.5): the selector Physics and Crafting share. Kept parts only,
-- Sharpening Blade only, ascending indices. Fixtures give the worked cases, Gen.validSword the properties.

local Test = require("../lib/Test")
local A = require("../lib/Assert")
local Gen = require("../lib/Gen")
local Prop = require("../lib/Prop")
local TestRng = require("../lib/TestRng")
local Tol = require("../lib/Tol")
local Blueprints = require("../fixtures/Blueprints")
local Drafts = require("./Drafts")
local Balance = require("../../src/shared/Definitions/Balance")
local CraftPlans = require("../../src/shared/Definitions/CraftPlans")
local EquipmentTypes = require("../../src/shared/Definitions/EquipmentTypes")
local Limits = require("../../src/shared/Definitions/Limits")
local Materials = require("../../src/shared/Definitions/Materials")
local Versions = require("../../src/shared/Definitions/Versions")
local WorkSet = require("../../src/shared/Blueprint/WorkSet")

type TestRng = TestRng.TestRng

local CTX = Gen.context(Limits, EquipmentTypes.get("Sword") :: any, Materials.enabled, Versions.BLUEPRINT_SCHEMA,
	Balance.Geometry)
local SLOTS: { string } = {}
for _, slot in (EquipmentTypes.get("Sword") :: any).slots do
	table.insert(SLOTS, slot.id)
end

-- PartData's id unions are narrower than the plain strings of tests/lib: the spec talks to the module in `any`.
local function workSet(parts: any, kept: { boolean }, selector: any): { number }
	return WorkSet.select(parts, kept, selector)
end

local function expectList(actual: { number }, expected: { number }, what: string)
	A.eq(table.concat(actual, ","), table.concat(expected, ","), what)
end

local function allKept(parts: any): { boolean }
	local kept: { boolean } = {}
	for i = 1, #parts do
		kept[i] = true
	end
	return kept
end

local function keptExcept(parts: any, cleaned: { number }): { boolean }
	local kept = allKept(parts)
	for _, i in cleaned do
		kept[i] = false
	end
	return kept
end

-- A part with only the fields the selector reads filled in meaningfully.
local function part(id: number, slot: string): any
	return Drafts.part(id, slot, "Block", "Iron", { 0, 1, 0 }, { 0, 0, 0, 1 }, { 0.3, 0.3, 0.3 })
end

local function worksOn(step: string): any
	for _, row in CraftPlans.Sword.steps do
		if row.step == step then
			return row.worksOn
		end
	end
	error("no plan row for " .. step)
end

return Test.suite("Blueprint/WorkSet", function(t)
	t.it("T-BP-14 the module is frozen", function()
		A.truthy(table.isfrozen(WorkSet), "module frozen")
	end)

	t.it("T-BP-14 the Sword plan: Smelting and Hammering work every kept part, Sharpening the Blade only", function()
		local want: { [string]: { number } } =
			{ F1 = { 4, 5 }, F2 = { 4 }, F3 = { 6, 7 }, F4 = { 4, 5 }, F5 = { 4, 5 } }
		for _, id in Blueprints.order do
			local parts = Blueprints.get(id).core.parts
			local kept = allKept(parts)
			local every: { number } = {}
			for i = 1, #parts do
				every[i] = i
			end
			expectList(workSet(parts, kept, worksOn("Smelting")), every, id .. " Smelting")
			expectList(workSet(parts, kept, worksOn("Hammering")), every, id .. " Hammering")
			expectList(workSet(parts, kept, worksOn("Sharpening")), want[id], id .. " Sharpening")
		end
	end)

	t.it("T-BP-14 cleaned parts are in no work set: hidden cores and specks buy nothing (§7.2)", function()
		local parts = Blueprints.get("F1").core.parts -- 1 Pommel, 2 Grip, 3 Guard, 4 and 5 Blade
		local cleanedBlade = keptExcept(parts, { 4 })
		expectList(workSet(parts, cleanedBlade, "All"), { 1, 2, 3, 5 }, "All without part 4")
		expectList(workSet(parts, cleanedBlade, worksOn("Sharpening")), { 5 }, "Blade without part 4")
		local cleanedHilt = keptExcept(parts, { 1, 3 })
		expectList(workSet(parts, cleanedHilt, "All"), { 2, 4, 5 }, "All without pommel and guard")
		expectList(workSet(parts, cleanedHilt, worksOn("Sharpening")), { 4, 5 }, "the Blade set does not care")
		local bladeGone = keptExcept(parts, { 4, 5 })
		expectList(workSet(parts, bladeGone, worksOn("Sharpening")), {}, "no kept Blade part: V5 and Plan.build's call")
		expectList(workSet(parts, keptExcept(parts, { 1, 2, 3, 4, 5 }), "All"), {}, "nothing kept")
	end)

	t.it("T-BP-14 ascending indices of the array, not ids, whatever order the selector names its slots in", function()
		local parts = {
			part(40, "Blade"),
			part(7, "Guard"),
			part(12, "Grip"),
			part(3, "Blade"),
			part(9, "Pommel"),
			part(1, "Guard"),
		}
		local kept = allKept(parts)
		expectList(workSet(parts, kept, { "Blade" }), { 1, 4 }, "indices, not the ids 40 and 3")
		expectList(workSet(parts, kept, { "Blade", "Guard" }), { 1, 2, 4, 6 }, "Phase 2's Quenching selector")
		expectList(workSet(parts, kept, { "Guard", "Blade" }), { 1, 2, 4, 6 }, "the selector's order does not matter")
		expectList(workSet(parts, kept, { "Blade", "Blade" }), { 1, 4 }, "a slot named twice takes a part once")
		expectList(workSet(parts, kept, { "Grip", "Pommel", "Guard", "Blade" }), { 1, 2, 3, 4, 5, 6 }, "all four = All")
	end)

	t.it("T-BP-14 a selector that matches nothing gives an empty set; no parts give an empty set", function()
		local parts = Blueprints.get("F2").core.parts
		local kept = allKept(parts)
		expectList(workSet(parts, kept, {}), {}, "no slots")
		expectList(workSet(parts, kept, { "Head" }), {}, "a slot of another type")
		expectList(workSet({}, {}, "All"), {}, "no parts, All")
		expectList(workSet({}, {}, { "Blade" }), {}, "no parts, Blade")
	end)

	t.it("T-BP-14 only slot and kept decide: shape, material and transform are ignored", function()
		local a = Blueprints.core("F1")
		local b = Blueprints.core("F5") -- F1 with the blade in Iron
		for _, p in b.parts do
			p.shape = "Ball"
			p.pos = { 9, 9, 9 }
		end
		local kept = keptExcept(a.parts, { 2 })
		local selectors: { any } = { "All", { "Blade", "Grip" } }
		for _, selector in selectors do
			expectList(workSet(a.parts, kept, selector), workSet(b.parts, kept, selector), "same slots, same kept")
		end
	end)

	t.it("T-BP-14 a new array each call, frozen inputs are enough, the plan's own rows work", function()
		local parts = Blueprints.get("F3").core.parts -- deep-frozen
		local kept = table.freeze(allKept(parts))
		local first = workSet(parts, kept, worksOn("Sharpening")) -- a frozen plan row
		local second = workSet(parts, kept, worksOn("Sharpening"))
		A.falsy(first == second, "a new array")
		A.deepEq(first, second, "P-DET")
		A.falsy(table.isfrozen(first), "the caller owns it")
		table.insert(first, 99)
		expectList(second, { 6, 7 }, "no shared state")
		expectList(workSet(parts, kept, worksOn("Sharpening")), { 6, 7 }, "no module state")
	end)

	t.it("T-BP-14 agrees with its definition on generated designs; All is the union of the slots (PROP_N)", function()
		Prop.check(Tol.PROP_N, function(rng: TestRng): any
			local core = Gen.validSword(rng, CTX)
			local kept: { boolean } = {}
			for i = 1, #core.parts do
				kept[i] = rng:float() < 0.75
			end
			local selector: { string } = {}
			for _, slot in SLOTS do
				if rng:float() < 0.5 then
					table.insert(selector, rng:int(1, #selector + 1), slot)
				end
			end
			return { parts = core.parts, kept = kept, selector = selector, flip = rng:int(1, #core.parts) }
		end, function(input: any)
			local parts, kept, selector, flip = input.parts, input.kept, input.selector, input.flip
			local before = Drafts.deepCopy(input)
			local got = workSet(parts, kept, selector)
			local want: { number } = {}
			for i, p in parts do
				if kept[i] and table.find(selector, p.slot) then
					table.insert(want, i)
				end
			end
			expectList(got, want, "kept and matched, ascending")
			for k = 2, #got do
				A.truthy(got[k - 1] < got[k], "strictly ascending")
			end

			local inAll: { [number]: boolean } = {}
			local all = workSet(parts, kept, "All")
			for _, i in all do
				A.truthy(kept[i], "All holds kept parts only")
				inAll[i] = true
			end
			local count = 0
			for i = 1, #kept do
				if kept[i] then
					count += 1
				end
			end
			A.eq(#all, count, "All holds every kept part")
			local total = 0
			for _, slot in SLOTS do
				local one = workSet(parts, kept, { slot })
				total += #one
				for _, i in one do
					A.eq(parts[i].slot, slot, "this slot")
					A.truthy(inAll[i], "a subset of All")
				end
			end
			A.eq(total, #all, "the slots partition All")

			-- a part's flag moves that part only
			local flipped = table.clone(kept)
			flipped[flip] = not flipped[flip]
			local other = workSet(parts, flipped, "All")
			A.eq(math.abs(#other - #all), 1, "one part in or out")
			A.eq(table.find(other, flip) ~= nil, flipped[flip], "that part")
			A.deepEq(input, before, "P-NOMUT")
		end)
	end)

	t.it("T-BP-14 a kept that is not one boolean per part, or an unknown selector, is a caller's bug", function()
		local parts = Blueprints.get("F2").core.parts -- 4 parts
		A.throws(function()
			workSet(parts, { true, true, true }, "All")
		end, "kept")
		A.throws(function()
			workSet(parts, { true, true, true, true, true }, { "Blade" })
		end, "kept")
		A.throws(function()
			workSet({}, { true }, "All")
		end, "kept")
		local kept = allKept(parts)
		local bad: { any } = { "Blade", "all", "", 1, true }
		for k = 1, #bad + 1 do -- the last one is nil
			A.throws(function()
				workSet(parts, kept, bad[k])
			end, "selector")
		end
	end)
end)
