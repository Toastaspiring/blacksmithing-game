--!strict
-- S4 prototype: quality score Q = T_material * sum_i w_i * s_eff_i * d_i
local Defs = require("./Defs")

export type PlannedStep = { step: string, weight: number, tier: string }
export type StepResult = { score: number, passed: boolean }
export type QualityTerm = { step: string, weight: number, effectiveScore: number, multiplier: number, contribution: number }
export type QualityResult = { q: number, materialTier: number, terms: { QualityTerm } }

local Quality = {}

local function clamp01(x: number): number
	if x ~= x then
		return 0 -- NaN guard
	end
	if x < 0 then
		return 0
	elseif x > 1 then
		return 1
	end
	return x
end

-- Round half up to a fixed grid; scale is a literal power of ten (no pow() in authoritative paths).
local function quantize(x: number, scale: number): number
	return math.floor(x * scale + 0.5) / scale
end
Quality.quantize = quantize

function Quality.effectiveScore(score: number, passed: boolean, tier: string): number
	local s = clamp01(score)
	if passed then
		return s
	end
	return s * Defs.Tiers[tier].failScoreFactor
end

-- volumes: material id -> kept volume (stud^3). Iterates Defs.MaterialOrder (fixed order => bit-exact sums).
function Quality.materialTier(volumes: { [string]: number }): number
	local total, acc = 0, 0
	for _, id in Defs.MaterialOrder do
		local v = volumes[id]
		if v ~= nil and v > 0 then
			total += v
			acc += v * Defs.Materials[id].qualityTier
		end
	end
	if total <= 0 then
		return Defs.Materials.Iron.qualityTier
	end
	return acc / total
end

function Quality.compute(plan: { PlannedStep }, results: { StepResult }, materialTier: number): QualityResult
	local terms: { QualityTerm } = {}
	local sum = 0
	for i, ps in plan do
		local r = results[i]
		local s = Quality.effectiveScore(r.score, r.passed, ps.tier)
		local d = Defs.Tiers[ps.tier].qualityMultiplier
		local c = ps.weight * s * d
		sum += c
		table.insert(terms, { step = ps.step, weight = ps.weight, effectiveScore = s, multiplier = d, contribution = c })
	end
	return { q = quantize(materialTier * sum, Defs.Quality.Scale), materialTier = materialTier, terms = terms }
end

return Quality
