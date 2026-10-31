--!strict
-- S3 prototype v2: p_final = round_q(clamp(p_base * m_material * m_tier * m_design, min, max)).
-- Layout as in Definitions/MinigameFamilies: ordered param arrays, design terms as arrays in FactorId order,
-- material and tier columns as lookups (never iterated). Expert..Hell columns are placeholders.
-- Design factor sets follow RULINGS 2.12: Smelting {Volume}; Hammering {Thinness, Asymmetry, SurfaceComplexity};
-- Sharpening {SurfaceComplexity, Asymmetry} (EdgeLength acts through the path).

export type DesignTerm = { factor: string, k: number }
export type ParamDef = {
	name: string,
	base: number,
	material: { [string]: number }?, -- missing material = 1
	tier: { number }?, -- Normal, Hard, Expert, Master, Hell; missing = 1
	design: { DesignTerm }?,
	designClamp: { number }?,
	quantum: number?,
	min: number?,
	max: number?,
}
export type FamilyDef = { id: string, params: { ParamDef } }

local TIER_INDEX = { Normal = 1, Hard = 2, Expert = 3, Master = 4, Hell = 5 }
local FACTOR_ORDER = { "Volume", "PartCount", "Thinness", "Asymmetry", "SurfaceComplexity", "EdgeLength", "Joints", "MaterialMix" }

local DEFS: { [string]: FamilyDef } = {
	HoldZone = {
		id = "HoldZone",
		params = {
			{ name = "durationMs", base = 15000, tier = { 1, 1, 1.1, 1.2, 1.3 }, design = { { factor = "Volume", k = 0.2 } }, designClamp = { 1, 1.2 }, quantum = 10 },
			{ name = "rampMs", base = 3000, quantum = 10 },
			{ name = "zoneWidth", base = 0.090, material = { Steel = 0.98 }, tier = { 1, 0.96, 0.88, 0.80, 0.72 }, design = { { factor = "Volume", k = -0.10 } }, designClamp = { 0.9, 1 } },
			{ name = "driftSpeed", base = 0.21, material = { Steel = 1.01 }, tier = { 1, 1.05, 1.15, 1.25, 1.35 }, design = { { factor = "Volume", k = 0.15 } }, designClamp = { 1, 1.15 } },
			{ name = "heatDecay", base = 1.0, tier = { 1, 1.05, 1.12, 1.20, 1.28 } },
			{ name = "fullHeat", base = 2.4 },
			{ name = "strokeGain", base = 0.25 },
			{ name = "refillMs", base = 250, quantum = 10 },
			{ name = "fireDecayMs", base = 600, quantum = 10 },
			{ name = "targetMin", base = 0.40, material = { Steel = 1.08 } },
			{ name = "targetMax", base = 0.80, material = { Steel = 1.04 } },
			{ name = "segMinMs", base = 900, tier = { 1, 0.9, 0.8, 0.7, 0.6 }, quantum = 10 },
			{ name = "segMaxMs", base = 2200, tier = { 1, 0.9, 0.8, 0.7, 0.6 }, quantum = 10 },
			{ name = "holdChance", base = 0.25, tier = { 1, 0.8, 0.6, 0.4, 0.2 } },
			{ name = "softFrac", base = 0.5 },
			{ name = "passThreshold", base = 0.5 },
		},
	},
	TimingStrike = {
		id = "TimingStrike",
		params = {
			{ name = "strikes", base = 12, tier = { 1, 1.25, 1.5, 1.75, 2.0 }, quantum = 1, min = 8, max = 32 },
			{ name = "beatMs", base = 900, material = { Steel = 0.98 }, tier = { 1, 0.85, 0.75, 0.65, 0.58 }, design = { { factor = "SurfaceComplexity", k = -0.10 } }, designClamp = { 0.9, 1 }, quantum = 1, min = 450 },
			{ name = "windowMs", base = 110, material = { Steel = 0.98 }, tier = { 1, 0.94, 0.80, 0.70, 0.60 }, design = { { factor = "Thinness", k = -0.15 } }, designClamp = { 0.85, 1 }, quantum = 1, min = 20 },
			{ name = "perfectFrac", base = 0.12, tier = { 1, 0.80, 0.70, 0.60, 0.50 } },
			{ name = "edgePoints", base = 0.20, tier = { 1, 0.50, 0.40, 0.30, 0.20 } },
			{ name = "tempoJitter", base = 0.08, tier = { 1, 1.5, 2, 2.5, 3 }, design = { { factor = "Asymmetry", k = 0.5 } }, designClamp = { 1, 1.5 }, max = 0.3 },
			{ name = "offsetMin", base = 0.40 },
			{ name = "offsetMax", base = 0.75 },
			{ name = "missPadMs", base = 90, quantum = 1 },
			{ name = "tailMs", base = 400, quantum = 10 },
			{ name = "passThreshold", base = 0.5 },
		},
	},
	PrecisionTrace = {
		id = "PrecisionTrace",
		params = {
			{ name = "halfWidth", base = 0.041, material = { Steel = 0.98 }, tier = { 1, 0.95, 0.85, 0.76, 0.68 }, design = { { factor = "SurfaceComplexity", k = -0.10 } }, designClamp = { 0.9, 1 }, min = 0.012 },
			{ name = "coreFrac", base = 0.10 },
			{ name = "pacerSpeed", base = 0.30, material = { Steel = 1.01 }, tier = { 1, 1.05, 1.15, 1.25, 1.35 }, design = { { factor = "Asymmetry", k = 0.15 } }, designClamp = { 1, 1.15 } },
			{ name = "paceTol", base = 0.12, tier = { 1, 0.85, 0.7, 0.6, 0.5 } },
			{ name = "paceFall", base = 0.24, tier = { 1, 0.85, 0.7, 0.6, 0.5 } },
			{ name = "perturbAmp", base = 0.020, tier = { 1, 1.25, 1.5, 1.75, 2.0 }, design = { { factor = "SurfaceComplexity", k = 0.5 } }, designClamp = { 1, 1.5 } },
			{ name = "bumpDensity", base = 1.0, tier = { 1, 1.3, 1.6, 1.9, 2.2 } },
			{ name = "bumpWidth", base = 0.25, tier = { 1, 0.9, 0.8, 0.7, 0.6 } },
			{ name = "leadInMs", base = 600, quantum = 20 },
			{ name = "tailMs", base = 400, quantum = 20 },
			{ name = "wAccuracy", base = 0.7 },
			{ name = "passThreshold", base = 0.5 },
		},
	},
}

local function find(family: string, name: string): ParamDef
	for _, d in DEFS[family].params do
		if d.name == name then
			return d
		end
	end
	error("no param " .. family .. "." .. name)
end

-- factors: array {{factor, x}} (S2 per-step FactorValue) or a map {factor = x} (scripts)
local function factorX(factors: any, f: string): number
	if factors == nil then
		return 0
	end
	if factors[1] ~= nil then
		for _, fv in factors do
			if fv.factor == f then
				return fv.x
			end
		end
		return 0
	end
	return factors[f] or 0
end

local function resolve(family: string, material: string, tier: string, factors: any?): { [string]: number }
	local fam = DEFS[family]
	assert(fam, "unknown family")
	local ti = TIER_INDEX[tier]
	assert(ti, "unknown tier")
	local out: { [string]: number } = {}
	for _, d in fam.params do
		local mMat = if d.material then (d.material[material] or 1) else 1
		local mTier = if d.tier then d.tier[ti] else 1
		local mDesign = 1
		if d.design then
			local sum = 1
			for _, term in d.design do -- array in FactorId order: fixed summation order
				sum += term.k * math.clamp(factorX(factors, term.factor), 0, 1)
			end
			local c = d.designClamp :: { number }
			mDesign = math.clamp(sum, c[1], c[2])
		end
		local v = d.base * mMat * mTier * mDesign
		if d.min then
			v = math.max(v, d.min)
		end
		if d.max then
			v = math.min(v, d.max)
		end
		if d.quantum then
			v = math.round(v / d.quantum) * d.quantum
		end
		out[d.name] = v
	end
	return out
end

-- uniform reference design: every factor of the step's weight list at x
local function refFactors(x: number): { [string]: number }
	local m = {}
	for _, f in FACTOR_ORDER do
		m[f] = x
	end
	return m
end

return {
	DEFS = DEFS,
	TIER_INDEX = TIER_INDEX,
	FACTOR_ORDER = FACTOR_ORDER,
	find = find,
	resolve = resolve,
	refFactors = refFactors,
}
