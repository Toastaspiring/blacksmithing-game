--!strict
-- Minigames/Params (SPEC §6.5, §12.2 Intro, E-S3.3; owner S3): a step's minigame parameters from its family's
-- Definitions row, the step's governing material, its played tier and its design factors. Pure.
--
--   p_final = round_q(clamp(p_base · m_material · m_tier · m_design, min, max))                      (§6.5)
--   m_material  the material's column (a missing material or column: × 1)
--   m_tier      the tier's column, by Tiers order (a missing column: × 1); an unknown tier is a caller bug
--   m_design    clamp(1 + Σ k·clamp(x_f, 0, 1), designClamp) over the parameter's design terms, in their order; x_f is
--               the x of the first FactorValue naming f (missing: 0)
--   then max(min), then min(max), then round_q(v) = math.round(v / q)·q
--
-- Every step of a row is the S3 prototype's expression in its order (docs/spec/prototypes/S3/v2/Params.luau: the
-- product left to right, the design sum from 1 in term order, the clamps, the quantum), which made E-S3's resolved
-- values, hashes and distributions; a regrouping moves last bits only the full-precision check can see.
-- resolve and explain read the enabled family's row from Definitions/MinigameFamilies (prepare's input is
-- server-made, so an unknown or disabled family errors); resolveDef is the same on a given row (P-ORDER's tests);
-- refFactors builds the uniform reference design the bots and tests use.

local MinigameFamilies = require("../Definitions/MinigameFamilies")
local Tiers = require("../Definitions/Tiers")
local DT = require("../Definitions/Types")
local Types = require("./Types")

type FactorValue = Types.FactorValue
type MinigameFamilyDef = MinigameFamilies.MinigameFamilyDef
type MinigameParamDef = MinigameFamilies.MinigameParamDef

-- one parameter's columns and value, as the Intro screen shows them (§12.2)
export type Explained = { base: number, mMaterial: number, mTier: number, mDesign: number, final: number }

-- "FactorId order" (Definitions/Types, §5.2): refFactors' order (Params.spec holds it to Definitions/Validate's list)
local FACTOR_ORDER: { DT.FactorId } =
	{ "PartCount", "Thinness", "Asymmetry", "SurfaceComplexity", "EdgeLength", "Joints", "MaterialMix", "Volume" }
table.freeze(FACTOR_ORDER)

-- the x of the first FactorValue naming f, 0 when none does
local function xOf(factors: { FactorValue }, f: DT.FactorId): number
	for _, fv in ipairs(factors) do
		if fv.factor == f then
			return fv.x
		end
	end
	return 0
end

local function tierOrder(tier: DT.TierId, fn: string): number
	local def = Tiers.get(tier)
	if def == nil then
		error(string.format("Params.%s: no tier %s", fn, tostring(tier)), 3)
	end
	return def.order
end

-- one parameter at a material, a tier column index and the factors: (m_material, m_tier, m_design, p_final)
local function evaluate(p: MinigameParamDef, material: DT.MaterialId, order: number, factors: { FactorValue })
	: (number, number, number, number)
	local materialColumn = p.material
	local mMat = if materialColumn then (materialColumn[material] or 1) else 1
	local tierColumn = p.tier
	local mTier = if tierColumn then tierColumn[order] else 1
	local mDesign = 1
	local design = p.design
	if design then
		local sum = 1
		for _, term in ipairs(design) do
			sum += term.k * math.clamp(xOf(factors, term.factor), 0, 1)
		end
		local c = p.designClamp :: { number }
		mDesign = math.clamp(sum, c[1], c[2])
	end
	local v = p.base * mMat * mTier * mDesign
	local lo, hi, q = p.min, p.max, p.quantum
	if lo then
		v = math.max(v, lo)
	end
	if hi then
		v = math.min(v, hi)
	end
	if q then
		v = math.round(v / q) * q
	end
	return mMat, mTier, mDesign, v
end

local function enabledFamily(family: DT.FamilyId, fn: string): MinigameFamilyDef
	local def = MinigameFamilies.get(family)
	if def == nil or not def.enabled then
		error(string.format("Params.%s: %s is not an enabled minigame family", fn, tostring(family)), 3)
	end
	return def
end

local Params = {}

-- every parameter of the row, by name
function Params.resolveDef(def: MinigameFamilyDef, material: DT.MaterialId, tier: DT.TierId, factors: { FactorValue })
	: { [string]: number }
	local order = tierOrder(tier, "resolveDef")
	local out: { [string]: number } = {}
	for _, p in ipairs(def.params) do
		local _, _, _, v = evaluate(p, material, order, factors)
		out[p.name] = v
	end
	return out
end

function Params.resolve(family: DT.FamilyId, material: DT.MaterialId, tier: DT.TierId, factors: { FactorValue })
	: { [string]: number }
	return Params.resolveDef(enabledFamily(family, "resolve"), material, tier, factors)
end

-- every parameter's base, its three modifiers and its final value (= resolve's), for the Intro screen (§12.2)
function Params.explain(family: DT.FamilyId, material: DT.MaterialId, tier: DT.TierId, factors: { FactorValue })
	: { [string]: Explained }
	local def = enabledFamily(family, "explain")
	local order = tierOrder(tier, "explain")
	local out: { [string]: Explained } = {}
	for _, p in ipairs(def.params) do
		local mMat, mTier, mDesign, v = evaluate(p, material, order, factors)
		out[p.name] = { base = p.base, mMaterial = mMat, mTier = mTier, mDesign = mDesign, final = v }
	end
	return out
end

-- all 8 factors at raw = x and x = x, in FactorId order: the uniform reference design (bots, tests; §6.13's x)
function Params.refFactors(x: number): { FactorValue }
	local out: { FactorValue } = {}
	for i = 1, #FACTOR_ORDER do -- indexed: luau-lsp widens an ipairs value of a string-literal union to string
		out[i] = { factor = FACTOR_ORDER[i], raw = x, x = x }
	end
	return out
end

return table.freeze(Params)
