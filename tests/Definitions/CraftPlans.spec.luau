--!strict
-- tests/Definitions/CraftPlans.spec.luau — Definitions/CraftPlans (SPEC §7.1, §8.5, §16.11; T-DEF-03).
-- S4's Plan.validateDefs (M5) repeats the weight and reference checks at boot; these cases pin the data now.

local A = require("../lib/Assert")
local Dump = require("../lib/Dump")
local Test = require("../lib/Test")
local TestRng = require("../lib/TestRng")
local Tol = require("../lib/Tol")
local H = require("./DefsHelpers")
local Balance = require("../../src/shared/Definitions/Balance")
local CraftPlans = require("../../src/shared/Definitions/CraftPlans")
local EquipmentTypes = require("../../src/shared/Definitions/EquipmentTypes")
local Stats = require("../../src/shared/Definitions/Stats")
local Steps = require("../../src/shared/Definitions/Steps")

return Test.suite("Definitions/CraftPlans", function(t)
	t.it("Sword plays Smelting 0.25 All · Hammering 0.40 All · Sharpening 0.35 {Blade} (§7.1, Q12)", function()
		local plan = CraftPlans.get("Sword")
		assert(plan)
		A.eq(plan, CraftPlans.Sword, "CraftPlans[type]")
		A.eq(plan.type, "Sword")
		local all: any, blade: any = "All", { "Blade" }
		A.deepEq(plan.steps, {
			{ step = "Smelting", weight = 0.25, worksOn = all, feeds = { "Purity" }, enabled = true },
			{ step = "Hammering", weight = 0.40, worksOn = all, feeds = { "Damage", "Durability" }, enabled = true },
			{ step = "Sharpening", weight = 0.35, worksOn = blade, feeds = { "Sharpness", "Damage" }, enabled = true },
		})
		A.deepEq(CraftPlans.ordered, { plan })
	end)

	t.it("T-DEF-03 enabled weights sum to 1 ± WEIGHT_SUM_TOL; steps, slots and feeds resolve", function()
		for _, plan in CraftPlans.ordered do
			local et = EquipmentTypes.get(plan.type)
			A.truthy(et ~= nil, plan.type .. " is an equipment type")
			assert(et)
			local slotIds: { [string]: boolean } = {}
			for _, s in et.slots do
				slotIds[s.id] = true
			end
			local sum = 0
			local seen: { [string]: boolean } = {}
			for _, row in plan.steps do
				local step = Steps.get(row.step)
				A.truthy(step ~= nil, row.step .. " is a step")
				A.falsy(seen[row.step], row.step .. " plays once")
				seen[row.step] = true
				A.truthy(row.weight > 0, row.step .. " weight")
				if row.enabled then
					sum += row.weight
					A.truthy(step ~= nil and step.enabled, row.step .. " is an enabled step")
				end
				if row.worksOn ~= "All" then
					local list: { string } = row.worksOn :: any
					A.truthy(#list > 0, row.step .. " works on some slot")
					for _, slot in list do
						A.truthy(slotIds[slot], row.step .. " works on " .. slot .. ", a slot of " .. plan.type)
					end
				end
				for _, stat in row.feeds do
					A.truthy(Stats.isEnabled(stat), row.step .. " feeds the enabled stat " .. stat)
				end
			end
			A.near(sum, 1, Balance.Quality.WEIGHT_SUM_TOL, plan.type .. " enabled weights")
		end
	end)

	t.it("every enabled equipment type has a plan, and only those types", function()
		for _, et in EquipmentTypes.enabled do
			A.truthy(CraftPlans.get(et.id) ~= nil, et.id)
		end
		for _, plan in CraftPlans.ordered do
			A.truthy(EquipmentTypes.isEnabled(plan.type), plan.type)
		end
	end)

	t.it("plan order follows the steps' catalogue order (each step plays once, in order)", function()
		for _, plan in CraftPlans.ordered do
			local last = -math.huge
			for _, row in plan.steps do
				local step = Steps.get(row.step)
				assert(step)
				A.truthy(step.order > last, row.step)
				last = step.order
			end
		end
	end)

	t.it("frozen; P-TOTAL get never throws and returns nil for anything but a known type", function()
		local frozen, at = H.isDeepFrozen(CraftPlans)
		A.truthy(frozen, "not frozen at " .. tostring(at))
		local rng = TestRng.new(0xC4AF7001)
		for _ = 1, Tol.FUZZ_N_GARBAGE do
			local g = H.garbage(rng)
			local ok, got = pcall(CraftPlans.get, g)
			A.truthy(ok, "get threw on " .. Dump.short(g))
			if g ~= "Sword" then
				A.eq(got, nil, Dump.short(g))
			end
		end
		A.eq(CraftPlans.get("Axe"), nil)
		A.eq(CraftPlans.get("sword"), nil)
	end)
end)
