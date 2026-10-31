--!strict
-- S4 prototype: Q -> rarity, rarity cap from the steps played, final rarity = min(byScore, cap).
local Defs = require("./Defs")

export type PlannedStep = { step: string, tier: string }
export type StepResult = { score: number, passed: boolean }
export type RarityResult = { rarity: string, byScore: string, cap: string, capStep: string? }

local Rarity = {}

function Rarity.order(id: string): number
	return Defs.Rarities[id].order
end

-- Highest rarity whose minQuality <= q (Common has minQuality 0, so every q >= 0 maps somewhere).
-- `thresholds` (optional, rarity order -> minQuality) lets the tuning sim override the data.
function Rarity.fromQuality(q: number, thresholds: { number }?): string
	local best = Defs.RarityOrder[1]
	for i, id in Defs.RarityOrder do
		local minQ = if thresholds then thresholds[i] else Defs.Rarities[id].minQuality
		if q >= minQ then
			best = id
		end
	end
	return best
end

-- Cap = highest rarityCap over the plan's steps, where a failed step counts as FailedStepCapTier.
-- capStep = first step (plan order) that reached that cap and is above the base cap; nil if base.
function Rarity.cap(plan: { PlannedStep }, results: { StepResult }): (string, string?)
	local baseTier = Defs.Quality.FailedStepCapTier
	local cap = Defs.Tiers[baseTier].rarityCap
	local capStep: string? = nil
	for i, ps in plan do
		local tierForCap = if results[i].passed then ps.tier else baseTier
		local c = Defs.Tiers[tierForCap].rarityCap
		if Defs.Rarities[c].order > Defs.Rarities[cap].order then
			cap = c
			capStep = ps.step
		end
	end
	return cap, capStep
end

-- Cap the plan would have if every step passes (editor/forge preview: "Rarity cap: Epic").
function Rarity.planCap(plan: { PlannedStep }): string
	local all: { StepResult } = {}
	for i in plan do
		all[i] = { score = 1, passed = true }
	end
	local cap = Rarity.cap(plan, all)
	return cap
end

function Rarity.resolve(q: number, plan: { PlannedStep }, results: { StepResult }, thresholds: { number }?): RarityResult
	local byScore = Rarity.fromQuality(q, thresholds)
	local cap, capStep = Rarity.cap(plan, results)
	local final = if Defs.Rarities[byScore].order <= Defs.Rarities[cap].order then byScore else cap
	return { rarity = final, byScore = byScore, cap = cap, capStep = capStep }
end

return Rarity
