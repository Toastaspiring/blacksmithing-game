--!strict
-- S3 prototype: p_final = p_base * m_material * m_tier * m_design, per family parameter.
-- tier columns: Normal, Hard, Expert, Master, Hell (Expert+ are placeholders, not enabled in the MVP)

export type ParamDef = {
	base: number,
	mat: { [string]: number }, -- Iron, Steel
	tier: { number }, -- 5 entries
	design: { [string]: number }?, -- factor -> k (signed slope)
	dclamp: { number }?, -- {lo, hi} clamp of m_design
	round: number?, -- quantum for integer params (e.g. 10 ms); nil = keep float
	min: number?,
	max: number?,
}

local TIERS = { "Normal", "Hard", "Expert", "Master", "Hell" }
local TIER_INDEX = { Normal = 1, Hard = 2, Expert = 3, Master = 4, Hell = 5 }

local W = { 1.00, 0.75, 0.60, 0.50, 0.40 } -- width-like (smaller = harder)
local S = { 1.00, 1.25, 1.50, 1.75, 2.00 } -- speed-like (bigger = harder)

local DEFS: { [string]: { [string]: ParamDef } } = {
	HoldZone = {
		durationMs = { base = 15000, mat = { Iron = 1, Steel = 1 }, tier = { 1, 1, 1.1, 1.2, 1.3 }, design = { Volume = 0.2 }, dclamp = { 1, 1.2 }, round = 10 },
		rampMs = { base = 3000, mat = { Iron = 1, Steel = 1 }, tier = { 1, 1, 1, 1, 1 }, round = 10 },
		zoneWidth = { base = 0.14, mat = { Iron = 1, Steel = 0.94 }, tier = { 1, 0.88, 0.76, 0.66, 0.56 }, design = { Volume = -0.1 }, dclamp = { 0.9, 1 } },
		driftSpeed = { base = 0.12, mat = { Iron = 1, Steel = 1.05 }, tier = { 1, 1.15, 1.3, 1.45, 1.6 }, design = { Volume = 0.25 }, dclamp = { 1, 1.25 } },
		heatDecay = { base = 0.60, mat = { Iron = 1, Steel = 1.05 }, tier = { 1, 1.12, 1.24, 1.36, 1.48 } },
		fullHeat = { base = 2.0, mat = { Iron = 1, Steel = 1 }, tier = { 1, 1, 1, 1, 1 } },
		fireLagMs = { base = 400, mat = { Iron = 1, Steel = 1 }, tier = { 1, 1, 1, 1, 1 }, round = 1 },
		minStrokeMs = { base = 60, mat = { Iron = 1, Steel = 1 }, tier = { 1, 1, 1, 1, 1 }, round = 1 },
		targetMin = { base = 0.40, mat = { Iron = 1, Steel = 1.125 }, tier = { 1, 1, 1, 1, 1 } },
		targetMax = { base = 0.80, mat = { Iron = 1, Steel = 1.0625 }, tier = { 1, 1, 1, 1, 1 } },
		segMinMs = { base = 900, mat = { Iron = 1, Steel = 1 }, tier = { 1, 0.9, 0.8, 0.7, 0.6 }, round = 10 },
		segMaxMs = { base = 2200, mat = { Iron = 1, Steel = 1 }, tier = { 1, 0.9, 0.8, 0.7, 0.6 }, round = 10 },
		holdChance = { base = 0.25, mat = { Iron = 1, Steel = 1 }, tier = { 1, 0.8, 0.6, 0.4, 0.2 } },
		softFrac = { base = 0.5, mat = { Iron = 1, Steel = 1 }, tier = { 1, 1, 1, 1, 1 } },
		passThreshold = { base = 0.5, mat = { Iron = 1, Steel = 1 }, tier = { 1, 1, 1, 1, 1 } },
	},
	TimingStrike = {
		strikes = { base = 12, mat = { Iron = 1, Steel = 1 }, tier = { 1, 1.25, 1.5, 1.75, 2.0 }, design = { PartCount = 0.5 }, dclamp = { 1, 1.5 }, round = 1, min = 8, max = 32 },
		beatMs = { base = 900, mat = { Iron = 1, Steel = 0.95 }, tier = { 1, 0.85, 0.75, 0.65, 0.58 }, round = 1, min = 450 },
		windowMs = { base = 80, mat = { Iron = 1, Steel = 0.92 }, tier = { 1, 0.8, 0.65, 0.55, 0.45 }, design = { Thinness = -0.15 }, dclamp = { 0.85, 1 }, round = 1, min = 20 },
		perfectFrac = { base = 0.12, mat = { Iron = 1, Steel = 1 }, tier = { 1, 1, 1, 1, 1 } },
		edgePoints = { base = 0.20, mat = { Iron = 1, Steel = 1 }, tier = { 1, 1, 1, 1, 1 } },
		tempoJitter = { base = 0.08, mat = { Iron = 1, Steel = 1 }, tier = { 1, 1.5, 2, 2.5, 3 }, design = { Asymmetry = 0.5 }, dclamp = { 1, 1.5 }, max = 0.3 },
		offsetMin = { base = 0.40, mat = { Iron = 1, Steel = 1 }, tier = { 1, 1, 1, 1, 1 } },
		offsetMax = { base = 0.75, mat = { Iron = 1, Steel = 1 }, tier = { 1, 1, 1, 1, 1 } },
		missPadMs = { base = 90, mat = { Iron = 1, Steel = 1 }, tier = { 1, 1, 1, 1, 1 }, round = 1 },
		tailMs = { base = 400, mat = { Iron = 1, Steel = 1 }, tier = { 1, 1, 1, 1, 1 }, round = 10 },
		passThreshold = { base = 0.5, mat = { Iron = 1, Steel = 1 }, tier = { 1, 1, 1, 1, 1 } },
	},
	PrecisionTrace = {
		halfWidth = { base = 0.037, mat = { Iron = 1, Steel = 0.92 }, tier = { 1, 0.88, 0.76, 0.66, 0.56 }, design = { Thinness = -0.15 }, dclamp = { 0.85, 1 }, min = 0.012 },
		coreFrac = { base = 0.10, mat = { Iron = 1, Steel = 1 }, tier = { 1, 1, 1, 1, 1 } },
		pacerSpeed = { base = 0.30, mat = { Iron = 1, Steel = 1.05 }, tier = { 1, 1.12, 1.24, 1.36, 1.48 }, design = { Asymmetry = 0.15 }, dclamp = { 1, 1.15 } },
		paceTol = { base = 0.12, mat = { Iron = 1, Steel = 1 }, tier = { 1, 0.85, 0.7, 0.6, 0.5 } },
		paceFall = { base = 0.24, mat = { Iron = 1, Steel = 1 }, tier = { 1, 0.85, 0.7, 0.6, 0.5 } },
		perturbAmp = { base = 0.020, mat = { Iron = 1, Steel = 1 }, tier = { 1, 1.25, 1.5, 1.75, 2.0 }, design = { SurfaceComplexity = 0.5 }, dclamp = { 1, 1.5 } },
		bumpDensity = { base = 1.0, mat = { Iron = 1, Steel = 1 }, tier = { 1, 1.3, 1.6, 1.9, 2.2 } },
		bumpWidth = { base = 0.25, mat = { Iron = 1, Steel = 1 }, tier = { 1, 0.9, 0.8, 0.7, 0.6 } },
		leadInMs = { base = 600, mat = { Iron = 1, Steel = 1 }, tier = { 1, 1, 1, 1, 1 }, round = 20 },
		tailMs = { base = 400, mat = { Iron = 1, Steel = 1 }, tier = { 1, 1, 1, 1, 1 }, round = 20 },
		wAccuracy = { base = 0.7, mat = { Iron = 1, Steel = 1 }, tier = { 1, 1, 1, 1, 1 } },
		passThreshold = { base = 0.5, mat = { Iron = 1, Steel = 1 }, tier = { 1, 1, 1, 1, 1 } },
	},
}

local function resolve(family: string, material: string, tier: string, factors: { [string]: number }?): { [string]: number }
	local defs = DEFS[family]
	assert(defs, "unknown family")
	local ti = TIER_INDEX[tier]
	assert(ti, "unknown tier")
	local out: { [string]: number } = {}
	-- deterministic key order not needed (no accumulation across keys)
	for name, d in defs do
		local mMat = d.mat[material] or 1
		local mTier = d.tier[ti]
		local mDesign = 1
		if d.design and factors then
			local sum = 1
			-- sorted factor names so the summation order is fixed
			local names = {}
			for f in d.design do
				table.insert(names, f)
			end
			table.sort(names)
			for _, f in names do
				local x = factors[f] or 0
				x = math.clamp(x, 0, 1)
				sum += d.design[f] * x
			end
			local lo, hi = 0, math.huge
			if d.dclamp then
				lo, hi = d.dclamp[1], d.dclamp[2]
			end
			mDesign = math.clamp(sum, lo, hi)
		end
		local v = d.base * mMat * mTier * mDesign
		if d.min then
			v = math.max(v, d.min)
		end
		if d.max then
			v = math.min(v, d.max)
		end
		if d.round then
			v = math.floor(v / d.round + 0.5) * d.round
		end
		out[name] = v
	end
	return out
end

return {
	DEFS = DEFS,
	TIERS = TIERS,
	resolve = resolve,
}
