--!strict
-- Physics/Difficulty (SPEC §5.1, §5.3, §5.4; owner S2): a step's difficulty from its work set's factors. Pure; §4.1's
-- determinism rules apply. g, m and d are quantized where they are produced, before any threshold (§5.1), so a
-- recompute at the same versions is bit-identical.
--
--   q          Util/Quantize.q(x, SCALAR_SCALE): the 1e-4 grid
--   softOr     d = q(1 − (1 − m)(1 − g)), in [0, 1] for m and g in it
--   governing  the set's material with the highest (difficultyTerm, hardness), ties by Materials order; nil on an
--              empty set
--   planSteps  the type's enabled CraftPlans steps, in plan order (§4.7: steps holds enabled steps only)
--   step       g = q(Σ w·x), the weights of Definitions/Steps summed in their stored order (FactorId order), each x
--              on the X_GRID inside the sum, so that a factor's last bits (a whole design moved rounds them anew)
--              cannot tip g's 1e-4 rounding; m = q(the material's difficultyTerm); d = softOr(m, g); tierRaw over all
--              tiers, tier over the enabled (Definitions/Tiers); terms in the weights' order, their x as measured; the
--              8 factors copied

local CraftPlans = require("../Definitions/CraftPlans")
local DT = require("../Definitions/Types")
local Materials = require("../Definitions/Materials")
local Steps = require("../Definitions/Steps")
local Tiers = require("../Definitions/Tiers")
local Quantize = require("../Util/Quantize")
local Factors = require("./Factors")
local Shapes = require("./Shapes")

type Prepared = Shapes.Prepared
type FactorValue = Factors.FactorValue

export type StepAnalysis = {
	step: DT.StepId,
	g: number,
	m: number,
	d: number,
	tierRaw: DT.TierId,
	tier: DT.TierId,
	material: DT.MaterialId,
	terms: { { factor: DT.FactorId, w: number, x: number } }, -- the step's weight list (§5)
	factors: { FactorValue }, -- all 8, FactorId order, on this step's work set
}

local X_GRID = 1e9 -- numeric guard, not a tunable: G sums each x rounded to 1/X_GRID (§17.1 O11 (j))

local Difficulty = {}

function Difficulty.q(x: number): number
	return Quantize.q(x, Quantize.SCALAR_SCALE)
end

function Difficulty.softOr(m: number, g: number): number
	return Difficulty.q(1 - (1 - m) * (1 - g))
end

-- parts in blueprint order, set their indices (WorkSet.select's).
function Difficulty.governing(parts: { Prepared }, set: { number }): DT.MaterialId?
	local best: DT.MaterialDef? = nil
	local ordered = Materials.ordered
	for i = 1, #ordered do
		local def = ordered[i]
		local present = false
		for k = 1, #set do
			if parts[set[k]].material == def.id then
				present = true
				break
			end
		end
		if present then
			if best == nil or def.difficultyTerm > best.difficultyTerm
				or (def.difficultyTerm == best.difficultyTerm and def.hardness > best.hardness)
			then
				best = def
			end
		end
	end
	return if best then best.id else nil
end

-- A type without a plan is a caller's bug: canonical data always names a type CraftPlans has.
function Difficulty.planSteps(typeId: DT.EquipmentTypeId): { CraftPlans.PlanStepDef }
	local plan = CraftPlans.get(typeId)
	if plan == nil then
		error("Difficulty.planSteps: no CraftPlans entry for " .. tostring(typeId), 2)
	end
	local out: { CraftPlans.PlanStepDef } = {}
	for i = 1, #plan.steps do
		if plan.steps[i].enabled then
			table.insert(out, plan.steps[i])
		end
	end
	return out
end

local function valueOf(factors: { FactorValue }, factor: DT.FactorId, stepId: DT.StepId): number
	for k = 1, #factors do
		if factors[k].factor == factor then
			return factors[k].x
		end
	end
	error("Difficulty.step: " .. stepId .. " weighs " .. factor .. ", which the factors lack", 3)
end

-- factors: the step's work set's (Factors.measure); material: its governing one. An unknown step or material, or a
-- weight on a factor the list lacks, is a caller's bug.
function Difficulty.step(stepId: DT.StepId, factors: { FactorValue }, material: DT.MaterialId): StepAnalysis
	local def = Steps.get(stepId)
	if def == nil then
		error("Difficulty.step: unknown step " .. tostring(stepId), 2)
	end
	local materialDef = Materials.get(material)
	if materialDef == nil then
		error("Difficulty.step: unknown material " .. tostring(material), 2)
	end
	local weights = def.factorWeights
	local terms: { { factor: DT.FactorId, w: number, x: number } } = table.create(#weights)
	local g = 0
	for i = 1, #weights do
		local factor: DT.FactorId, w = weights[i].factor, weights[i].w
		local x = valueOf(factors, factor, stepId)
		g += w * (math.floor(x * X_GRID + 0.5) / X_GRID)
		terms[i] = { factor = factor, w = w, x = x }
	end
	g = Difficulty.q(g)
	local m = Difficulty.q(materialDef.difficultyTerm)
	local d = Difficulty.softOr(m, g)
	local copies: { FactorValue } = table.create(#factors)
	for k = 1, #factors do
		local f = factors[k]
		copies[k] = { factor = f.factor, raw = f.raw, x = f.x }
	end
	return {
		step = stepId,
		g = g,
		m = m,
		d = d,
		tierRaw = Tiers.tierRawFor(d),
		tier = Tiers.tierFor(d),
		material = material,
		terms = terms,
		factors = copies,
	}
end

return table.freeze(Difficulty)
