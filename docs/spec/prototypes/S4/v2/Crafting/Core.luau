--!strict
-- S4 prototype v2: Crafting/{Plan, Quality, Rarity, Stats, Outcome} + Blueprint/WorkSet + Util/Quantize in one file
-- (prototype only; the SPEC splits them per module). Formulas are SPEC §7.1-7.5 and §8 verbatim.
local Defs = require("./Defs")

local M = {}

-- Util/Quantize.q (S1)
local function q(x: number, n: number): number
	assert(x == x and x ~= math.huge and x ~= -math.huge, "non-finite")
	local r = math.round(x * n) / n
	return if r == 0 then 0 else r
end
M.q = q

local function clamp(x: number, lo: number, hi: number): number
	if x ~= x then
		return lo
	end
	return math.min(hi, math.max(lo, x))
end
local function lerp(f: number, s: number): number
	return f + (1 - f) * s
end

-- ================= Blueprint/WorkSet
function M.workSet(parts: { any }, kept: { boolean }, selector: any): { number }
	local out = {}
	for i, p in parts do
		if kept[i] then
			local ok = selector == "All"
			if not ok then
				for _, s in selector do
					if s == p.slot then
						ok = true
						break
					end
				end
			end
			if ok then
				table.insert(out, i)
			end
		end
	end
	return out
end

-- ================= Crafting/Plan
local function planDef(equipmentType: string): any
	local d = Defs.plan[equipmentType]
	assert(d, "no CraftPlans entry for " .. tostring(equipmentType))
	return d
end

-- Plan.build(core, analysis): one PlannedStep per ENABLED CraftPlans row, copying S2's step analysis.
function M.build(core: any, analysis: any): any
	local def = planDef(core.type)
	local steps = {}
	local k = 0
	for _, sd in def.steps do
		if sd.enabled then
			k += 1
			local a = analysis.steps[k]
			assert(a and a.step == sd.step, "analysis steps must follow CraftPlans order")
			local W = M.workSet(core.parts, analysis.physics.kept, sd.worksOn)
			assert(#W > 0, "empty work set (validation V7 guarantees a kept Blade part)")
			assert(Defs.tier[a.tier].enabled, "played tier must be enabled")
			table.insert(steps, { index = k, step = sd.step, family = Defs.StepFamily[sd.step], weight = sd.weight,
				tier = a.tier, tierRaw = a.tierRaw or a.tier, difficulty = a.d, material = a.material, workParts = W })
		end
	end
	return { equipmentType = core.type, balanceVersion = 1, steps = steps }
end

-- Plan.fromHistory(core, analysis, records): recompute path. Recorded tier / difficulty / material are facts;
-- weights are the CURRENT rows of the recorded steps (disabled rows included), renormalized over those steps.
function M.fromHistory(core: any, analysis: any, records: { any }): any
	local def = planDef(core.type)
	local wsum = 0
	local rows = {}
	for i, r in records do
		local row = nil
		for _, sd in def.steps do
			if sd.step == r.step then
				row = sd
				break
			end
		end
		assert(row, "recorded step without a CraftPlans row: " .. tostring(r.step))
		rows[i] = row
		wsum += row.weight
	end
	assert(wsum > 0, "zero weight")
	local steps = {}
	for i, r in records do
		local row = rows[i]
		local W = M.workSet(core.parts, analysis.physics.kept, row.worksOn)
		assert(#W > 0, "empty work set")
		steps[i] = { index = i, step = r.step, family = r.family, weight = row.weight / wsum, tier = r.tier, tierRaw = r.tier,
			difficulty = r.difficulty, material = r.material, workParts = W }
	end
	return { equipmentType = core.type, balanceVersion = 1, steps = steps }
end

function M.validateDefs(): { string }
	local problems = {}
	for _, def in Defs.CraftPlans do
		local s = 0
		for _, sd in def.steps do
			if sd.enabled then
				s += sd.weight
			end
		end
		if math.abs(s - 1) > Defs.Quality.WEIGHT_SUM_TOL then
			table.insert(problems, def.type .. ": enabled weights sum to " .. s)
		end
	end
	return problems
end

-- ================= Crafting/Quality
function M.effectiveScore(score: number, passed: boolean, tier: string): number
	local s = clamp(score, 0, 1)
	return if passed then s else s * Defs.tier[tier].failScoreFactor
end

-- d_i = d(tier) * (1 + gamma * (D - dMin(tier)))
function M.multiplier(tier: string, difficulty: number): number
	local t = Defs.tier[tier]
	return t.qualityMultiplier * (1 + Defs.Quality.DESIGN_GAMMA * math.max(0, difficulty - t.dMin))
end

-- kept-volume-weighted mean over the given part indices of a per-material value
local function volMean(core: any, physics: any, idx: { number }?, field: string, scale: number): number
	local v, acc = 0, 0
	local n = if idx then #idx else #core.parts
	for j = 1, n do
		local i = if idx then idx[j] else j
		if physics.kept[i] then
			local vol = physics.ownedVolume[i]
			if vol > 0 then
				v += vol
				acc += vol * Defs.material[core.parts[i].material][field] / scale
			end
		end
	end
	assert(v > 0, "work set has no kept volume")
	return acc / v
end
M.volMean = volMean

function M.materialTier(core: any, physics: any): number
	return q(volMean(core, physics, nil, "qualityTier", 1), 1e4)
end

-- Q = q(T * sum_i w_i * s_eff_i * d_i)
function M.quality(plan: any, runs: { any }, T: number): any
	assert(#runs == #plan.steps, "one run per planned step")
	local sum = 0
	local terms = {}
	for i, ps in plan.steps do
		local r = runs[i]
		local s = M.effectiveScore(r.score, r.passed, ps.tier)
		local d = M.multiplier(ps.tier, ps.difficulty)
		local c = ps.weight * s * d
		sum += c
		terms[i] = { step = ps.step, weight = ps.weight, effectiveScore = s, multiplier = d, contribution = c }
	end
	return { q = q(T * sum, 1e4), materialTier = T, terms = terms }
end

function M.ceiling(plan: any, T: number): number
	local sum = 0
	for _, ps in plan.steps do
		sum += ps.weight * M.multiplier(ps.tier, ps.difficulty)
	end
	return q(T * sum, 1e4)
end

-- ================= Crafting/Rarity
function M.rarityOrder(id: string): number
	return Defs.rarity[id].order
end

function M.fromQuality(qv: number): string
	local best = "Common"
	for _, r in Defs.Rarities do
		if r.enabled and qv >= r.minQuality then
			best = r.id
		end
	end
	return best
end

-- cap: highest rarityCap over steps, a failed step counting as FAILED_STEP_CAP_TIER (Max rule, Q10 default)
function M.cap(plan: any, runs: { any }): (string, string?)
	local base = Defs.Quality.FAILED_STEP_CAP_TIER
	local cap = Defs.tier[base].rarityCap
	local capStep: string? = nil
	local rule = Defs.Quality.CAP_RULE
	if rule == "Majority" then
		-- alternative (b): the highest tier reached (passed) by steps carrying >= 50 % of the weight
		for _, t in Defs.Tiers do
			if t.enabled and t.order > Defs.tier[base].order then
				local w = 0
				local first: string? = nil
				for i, ps in plan.steps do
					if runs[i].passed and Defs.tier[ps.tier].order >= t.order then
						w += ps.weight
						first = first or ps.step
					end
				end
				if w >= 0.5 - 1e-9 and M.rarityOrder(t.rarityCap) > M.rarityOrder(cap) then
					cap, capStep = t.rarityCap, first
				end
			end
		end
		return cap, capStep
	end
	for i, ps in plan.steps do
		local eligible = not (rule == "Striking" and ps.step == "Smelting")
		local tierForCap = if runs[i].passed and eligible then ps.tier else base
		local c = Defs.tier[tierForCap].rarityCap
		if M.rarityOrder(c) > M.rarityOrder(cap) then
			cap, capStep = c, ps.step
		end
	end
	return cap, capStep
end

function M.planCap(plan: any): (string, string?)
	local all = {}
	for i in plan.steps do
		all[i] = { score = 1, passed = true }
	end
	return M.cap(plan, all)
end

function M.resolve(qv: number, plan: any, runs: { any }): any
	local byScore = M.fromQuality(qv)
	local cap, capStep = M.cap(plan, runs)
	local final = if M.rarityOrder(byScore) <= M.rarityOrder(cap) then byScore else cap
	return { rarity = final, byScore = byScore, cap = cap, capStep = capStep }
end

-- ================= Crafting/Stats
local function findStep(plan: any, id: string): (any, number)
	for i, ps in plan.steps do
		if ps.step == id then
			return ps, i
		end
	end
	error("plan lacks " .. id)
end

function M.statInputs(core: any, physics: any, plan: any, runs: { any }): any
	local K = Defs.Stats[core.type]
	local sm, ism = findStep(plan, "Smelting")
	local ham, iham = findStep(plan, "Hammering")
	local sh, ish = findStep(plan, "Sharpening")
	return {
		mass = physics.mass, reach = physics.reach, balance = physics.balance,
		edgeLength = physics.edgeLength, cutIndex = physics.cutIndex,
		hardness = volMean(core, physics, sh.workParts, "hardness", K.MATERIAL_SCALE),
		toughness = volMean(core, physics, ham.workParts, "toughness", K.MATERIAL_SCALE),
		smelting = M.effectiveScore(runs[ism].score, runs[ism].passed, sm.tier),
		hammering = M.effectiveScore(runs[iham].score, runs[iham].passed, ham.tier),
		sharpening = M.effectiveScore(runs[ish].score, runs[ish].passed, sh.tier),
	}
end

function M.breakdown(eqType: string, i: any): any
	local K = Defs.Stats[eqType]
	local P = lerp(K.PURITY_FLOOR, clamp(i.smelting, 0, 1))
	local h = clamp(i.hardness, 0, 1) * P
	local k = clamp(i.toughness, 0, 1) * P
	local sharp = clamp(K.STAT_MAX * h * lerp(K.SHARP_FLOOR, clamp(i.sharpening, 0, 1)), 0, K.STAT_MAX)
	local dura = clamp(K.STAT_MAX * k * lerp(K.DURA_FLOOR, clamp(i.hammering, 0, 1)), 0, K.STAT_MAX)
	local c = clamp(i.cutIndex, 0, 1) * clamp(i.edgeLength / K.EDGE_REF, 0, 1)
	local fMass = clamp(K.MASS_BIAS + (1 - K.MASS_BIAS) * math.sqrt(math.max(i.mass, 0) / K.MASS_REF), K.MASS_FACTOR_MIN, K.MASS_FACTOR_MAX)
	local fEdge = 1 + K.EDGE_GAIN * c * sharp / K.STAT_MAX
	local fForge = lerp(K.FORGE_FLOOR, clamp(i.hammering, 0, 1))
	local damage = clamp(K.DAMAGE_BASE * fMass * fEdge * fForge, 0, K.STAT_MAX)
	local beta = i.balance / math.max(i.reach, K.BALANCE_REACH_MIN)
	local e = math.max(0, math.abs(beta - K.BALANCE_IDEAL) - K.BALANCE_TOLERANCE)
	local balance = K.STAT_MAX * clamp(1 - e / K.BALANCE_FALLOFF, 0, 1)
	return { purity = P, hEff = h, kEff = k, sharpness = sharp, durability = dura, c = c, fMass = fMass, fEdge = fEdge,
		fForge = fForge, damage = damage, beta = beta, balance = balance, reach = math.max(i.reach, 0) }
end

function M.stats(eqType: string, i: any): { [string]: number }
	local b = M.breakdown(eqType, i)
	return { Damage = q(b.damage, 1e4), Sharpness = q(b.sharpness, 1e4), Durability = q(b.durability, 1e4),
		Purity = q(100 * b.purity, 1e4), Balance = q(b.balance, 1e4), Reach = q(b.reach, 1e4) }
end

-- ================= Crafting/Outcome
function M.compute(core: any, physics: any, plan: any, runs: { any }): any
	local T = M.materialTier(core, physics)
	local quality = M.quality(plan, runs, T)
	local inputs = M.statInputs(core, physics, plan, runs)
	return { stats = M.stats(core.type, inputs), quality = quality, rarity = M.resolve(quality.q, plan, runs), inputs = inputs }
end

function M.preview(core: any, physics: any, plan: any): any
	local T = M.materialTier(core, physics)
	local cap, capStep = M.planCap(plan)
	local function at(score: number): { [string]: number }
		local runs = {}
		for i in plan.steps do
			runs[i] = { score = score, passed = true }
		end
		return M.stats(core.type, M.statInputs(core, physics, plan, runs))
	end
	local mult = {}
	for i, ps in plan.steps do
		mult[i] = M.multiplier(ps.tier, ps.difficulty)
	end
	return { materialTier = T, rarityCap = cap, capStep = capStep, qualityCeiling = M.ceiling(plan, T), multipliers = mult,
		gamma = Defs.Quality.DESIGN_GAMMA, potential = { low = at(0.5), high = at(1.0) } }
end

return M
