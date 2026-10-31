--!strict
-- S4 prototype: MVP item stats from physics outputs, material values and effective step scores.
-- Only + - * / sqrt floor min max abs (IEEE-exact) are used.
local Defs = require("./Defs")

export type StatInputs = {
	mass: number, -- mass units (S2)
	reach: number, -- studs, grip point -> furthest point of the striking part (S2)
	balanceOffset: number, -- studs, balance point - guard reference, + toward the tip (S2)
	edgeLength: number, -- studs of sharpenable edge on striking parts (S2, raw)
	bladeHardness: number, -- 0..1, volume-weighted over the Sharpening work set
	bodyToughness: number, -- 0..1, volume-weighted over the Hammering work set
	smelting: number, -- effective scores 0..1 (after the fail rule)
	hammering: number,
	sharpening: number,
}

export type ItemStats = {
	damage: number,
	reach: number,
	durability: number,
	sharpness: number,
	purity: number,
	balance: number,
}

local Stats = {}

local function clamp(x: number, lo: number, hi: number): number
	if x ~= x then
		return lo
	end
	return math.min(hi, math.max(lo, x))
end

local function quantize(x: number, scale: number): number
	return math.floor(x * scale + 0.5) / scale
end

local function lerpFloor(floor: number, s: number): number
	return floor + (1 - floor) * s
end

-- Unquantized intermediate values, exposed for the worked examples and tests.
function Stats.breakdown(i: StatInputs)
	local K = Defs.Stats
	local purity = lerpFloor(K.PurityFloor, clamp(i.smelting, 0, 1))
	local hEff = clamp(i.bladeHardness, 0, 1) * purity
	local kEff = clamp(i.bodyToughness, 0, 1) * purity
	local sharpness = clamp(K.StatMax * hEff * lerpFloor(K.SharpFloor, clamp(i.sharpening, 0, 1)), 0, K.StatMax)
	local durability = clamp(K.StatMax * kEff * lerpFloor(K.DuraFloor, clamp(i.hammering, 0, 1)), 0, K.StatMax)
	local c = clamp(i.edgeLength / K.EdgeRef, 0, 1)
	local fMass = clamp(K.MassBias + (1 - K.MassBias) * math.sqrt(math.max(i.mass, 0) / K.MassRef), K.MassFactorMin, K.MassFactorMax)
	local fEdge = 1 + K.EdgeGain * c * sharpness / K.StatMax
	local fForge = lerpFloor(K.ForgeFloor, clamp(i.hammering, 0, 1))
	local damage = clamp(K.DamageBase * fMass * fEdge * fForge, 0, K.StatMax)
	local beta = i.balanceOffset / math.max(i.reach, K.BalanceReachMin)
	local excess = math.max(0, math.abs(beta - K.BalanceIdeal) - K.BalanceTolerance)
	local balance = K.StatMax * clamp(1 - excess / K.BalanceFalloff, 0, 1)
	return {
		purity = purity,
		hEff = hEff,
		kEff = kEff,
		sharpness = sharpness,
		durability = durability,
		c = c,
		fMass = fMass,
		fEdge = fEdge,
		fForge = fForge,
		damage = damage,
		beta = beta,
		balance = balance,
		reach = math.max(i.reach, 0),
	}
end

function Stats.compute(i: StatInputs): ItemStats
	local b = Stats.breakdown(i)
	return {
		damage = quantize(b.damage, 10),
		reach = quantize(b.reach, 100),
		durability = quantize(b.durability, 10),
		sharpness = quantize(b.sharpness, 10),
		purity = quantize(b.purity, 1000),
		balance = quantize(b.balance, 10),
	}
end

return Stats
