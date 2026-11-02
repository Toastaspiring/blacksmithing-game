--!strict
-- Definitions/CraftPlans (SPEC §7.1, §8.5, §16.11; owner S4): the only source of which steps a type plays, in which
-- order, on which parts (worksOn: "All" or a list of slots, kept parts only, through Blueprint/WorkSet), with which
-- quality weight and feeding which stats (UI). The family comes from Definitions/Steps.
-- Per EquipmentTypeId an ordered, append-only list: rows are never deleted or reordered; a retired row keeps its
-- weight with enabled = false, so every recorded step can still be weighted on recompute (§7.5). Enabled weights sum
-- to 1 ± WEIGHT_SUM_TOL (S4's Plan.validateDefs, injected into Validate.validateAll).
-- Sword weights 25 / 40 / 35 % [Decision to confirm] (Q12); equal thirds keep every target in its band (E-S4.6).
-- Phase 2 hook: Quenching ({"Blade", "Guard"}), Assembly and Finishing ("All") are appended and the enabled weights
-- rebalanced; another type is one more entry (a hammer has no Sharpening).
--   CraftPlans.get(type)   the type's plan, nil for unknown types (CraftPlans[type], §2.1)
--   CraftPlans.ordered     every plan, in EquipmentTypes order: what validators iterate

local Catalog = require("./Catalog")
local DT = require("./Types")

export type WorkSelector = "All" | { DT.SlotId }
export type PlanStepDef = {
	step: DT.StepId,
	weight: number,
	worksOn: WorkSelector,
	feeds: { DT.StatId },
	enabled: boolean,
}
export type CraftPlanDef = { type: DT.EquipmentTypeId, steps: { PlanStepDef } }

local BLADE: { DT.SlotId } = { "Blade" }

local SWORD: CraftPlanDef = {
	type = "Sword",
	steps = {
		{ step = "Smelting", weight = 0.25, worksOn = "All", feeds = { "Purity" }, enabled = true },
		{ step = "Hammering", weight = 0.40, worksOn = "All", feeds = { "Damage", "Durability" }, enabled = true },
		{ step = "Sharpening", weight = 0.35, worksOn = BLADE, feeds = { "Sharpness", "Damage" }, enabled = true },
	},
}

local ORDERED: { CraftPlanDef } = { SWORD }

local byType: { [string]: CraftPlanDef } = {}
for _, plan in ORDERED do
	if byType[plan.type] then
		error("CraftPlans: two plans for " .. plan.type)
	end
	byType[plan.type] = plan
end

local function get(equipmentType: string): CraftPlanDef?
	if type(equipmentType) ~= "string" then
		return nil
	end
	return byType[equipmentType]
end

export type CraftPlans = {
	Sword: CraftPlanDef,
	ordered: { CraftPlanDef },
	get: (equipmentType: string) -> CraftPlanDef?,
}

local CraftPlans: CraftPlans = {
	Sword = SWORD,
	ordered = ORDERED,
	get = get,
}

Catalog.deepFreeze(byType)
return Catalog.deepFreeze(CraftPlans)
