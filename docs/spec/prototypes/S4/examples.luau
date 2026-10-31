--!strict
-- S4 prototype: worked examples for the stat formulas and Q/rarity.
-- Physics inputs = S2's prototype outputs (proto/S2/run.luau, as of this draft): mass, balance (COM.y - guard
-- centroid Y), reach (grip centroid -> furthest Blade point), edge length, cleaned parts, played tiers.
-- Material shares use analytic part volumes of S2's example blueprints (proto/S2/swords.luau, read-only),
-- overlaps ignored (approximation for the example only; the real module uses S2's owned volumes).
local Defs = require("./Crafting/Defs")
local Stats = require("./Crafting/Stats")
local Quality = require("./Crafting/Quality")
local Rarity = require("./Crafting/Rarity")
local S2Swords = require("../S2/swords")

local PI = math.pi

local function volume(p: any): number
	local x, y, z = p.size[1], p.size[2], p.size[3]
	if p.shape == "Block" then
		return x * y * z
	elseif p.shape == "Wedge" then
		return x * y * z / 2
	elseif p.shape == "CornerWedge" then
		return x * y * z / 6
	elseif p.shape == "Cylinder" then
		local r = math.min(y, z) / 2
		return PI * r * r * x
	elseif p.shape == "Ball" then
		local r = math.min(x, y, z) / 2
		return 4 / 3 * PI * r * r * r
	end
	error("shape " .. tostring(p.shape))
end

-- S2 prototype outputs (copied from `lune run proto/S2/run.luau`)
type Ex = { key: string, bp: any, mass: number, balance: number, reach: number, edge: number, cleaned: { [string]: boolean }, tiers: { string } }
local EXAMPLES: { Ex } = {
	{ key = "Minimal 4-part (Iron)", bp = S2Swords.minimal(), mass = 1.4717, balance = 0.108, reach = 3.103, edge = 5.040, cleaned = {}, tiers = { "Hard", "Normal", "Normal" } },
	{ key = "Arming sword (Iron)", bp = S2Swords.arming("Iron"), mass = 0.8350, balance = 0.177, reach = 3.420, edge = 5.651, cleaned = {}, tiers = { "Normal", "Hard", "Hard" } },
	{ key = "Arming sword (Steel)", bp = S2Swords.arming("Steel"), mass = 0.8329, balance = 0.177, reach = 3.420, edge = 5.651, cleaned = {}, tiers = { "Normal", "Hard", "Hard" } },
	{ key = "Rapier (Steel blade+guard, Iron hilt)", bp = S2Swords.rapier(), mass = 0.4174, balance = 0.242, reach = 4.130, edge = 6.680, cleaned = { TipR = true, TipL = true }, tiers = { "Normal", "Hard", "Hard" } },
	{ key = "Cleaver (Iron)", bp = S2Swords.cleaver(), mass = 3.7236, balance = 0.983, reach = 3.278, edge = 6.198, cleaned = {}, tiers = { "Hard", "Hard", "Hard" } },
	{ key = "Curved sabre (Steel blade+guard, Iron hilt)", bp = S2Swords.sabre(), mass = 0.6818, balance = 0.356, reach = 3.815, edge = 6.715, cleaned = {}, tiers = { "Normal", "Hard", "Hard" } },
}

type Mat = { H: number, K: number, T: number, steelShare: number, volume: number }
local function materials(ex: Ex): Mat
	local vB, hB, vA, kA, tA, vSteel = 0, 0, 0, 0, 0, 0
	for _, p in ex.bp.parts do
		if not ex.cleaned[p.id] then
			local v = volume(p)
			local m = Defs.Materials[p.material]
			vA += v
			kA += v * m.toughness
			tA += v * m.qualityTier
			if p.material == "Steel" then
				vSteel += v
			end
			if p.slot == "Blade" then
				vB += v
				hB += v * m.hardness
			end
		end
	end
	return { H = hB / vB, K = kA / vA, T = tA / vA, steelShare = vSteel / vA, volume = vA }
end

local function inputs(ex: Ex, mt: Mat, sm: number, ham: number, sh: number): Stats.StatInputs
	return {
		mass = ex.mass,
		reach = ex.reach,
		balanceOffset = ex.balance,
		edgeLength = ex.edge,
		bladeHardness = mt.H,
		bodyToughness = mt.K,
		smelting = sm,
		hammering = ham,
		sharpening = sh,
	}
end

print("## Example physics (S2 prototype outputs) and material terms")
print("| Sword | Mass | Reach | Balance offset b | beta = b/R | L_edge | c | F_mass | Balance | H (blade) | K | T (steel share) | S2 tiers S/H/Sh |")
print("|---|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|---|---|")
local mats = {}
for i, ex in EXAMPLES do
	local mt = materials(ex)
	mats[i] = mt
	local b = Stats.breakdown(inputs(ex, mt, 0.6, 0.6, 0.6))
	print(string.format("| %s | %.3f | %.2f | %.3f | %.3f | %.2f | %.2f | %.3f | %.0f | %.2f | %.2f | %.4f (%.0f %%) | %s |", ex.key, ex.mass, ex.reach, ex.balance, b.beta, ex.edge, b.c, b.fMass, b.balance, mt.H, mt.K, mt.T, 100 * mt.steelShare, table.concat(ex.tiers, "/")))
end

local PLAYERS = {
	{ name = "Bad (raw 0.40 / 0.40 / 0.24, all failed -> s_eff 0.30 / 0.30 / 0.18)", sm = 0.30, ham = 0.30, sh = 0.18 },
	{ name = "Average (0.60)", sm = 0.60, ham = 0.60, sh = 0.60 },
	{ name = "Good (0.78)", sm = 0.78, ham = 0.78, sh = 0.78 },
	{ name = "Excellent (0.90)", sm = 0.90, ham = 0.90, sh = 0.90 },
	{ name = "Flawless (1.00)", sm = 1.0, ham = 1.0, sh = 1.0 },
}

print("")
print("## Stats: Damage / Durability / Sharpness / Purity / Balance (Reach = physics)")
print("| Sword | Player | Damage | Durability | Sharpness | Purity | Balance |")
print("|---|---|---:|---:|---:|---:|---:|")
for i, ex in EXAMPLES do
	for _, p in PLAYERS do
		local st = Stats.compute(inputs(ex, mats[i], p.sm, p.ham, p.sh))
		print(string.format("| %s | %s | %.1f | %.1f | %.1f | %.0f%% | %.1f |", ex.key, p.name, st.damage, st.durability, st.sharpness, st.purity * 100, st.balance))
	end
end

print("")
print("## Worked example: S2 arming sword, Good player (0.78 / 0.78 / 0.78)")
for _, i in { 2, 3 } do
	local ex = EXAMPLES[i]
	local b = Stats.breakdown(inputs(ex, mats[i], 0.78, 0.78, 0.78))
	local st = Stats.compute(inputs(ex, mats[i], 0.78, 0.78, 0.78))
	print(string.format("%s: P %.4f h %.4f k %.4f Sharp %.3f Dura %.3f c %.4f F_mass %.4f F_edge %.4f F_forge %.4f Damage %.3f beta %.4f Balance %.2f | stored dmg %.1f reach %.2f dura %.1f sharp %.1f pur %.3f bal %.1f",
		ex.key, b.purity, b.hEff, b.kEff, b.sharpness, b.durability, b.c, b.fMass, b.fEdge, b.fForge, b.damage, b.beta, b.balance, st.damage, st.reach, st.durability, st.sharpness, st.purity, st.balance))
end

print("")
print("## Mixed material T: S2 arming sword with a Steel blade (blade + tips), Iron guard/grip/pommel")
do
	local bp = S2Swords.arming("Iron")
	local vSteel, vIron = 0, 0
	for _, p in bp.parts do
		if p.slot == "Blade" then
			vSteel += volume(p)
		else
			vIron += volume(p)
		end
	end
	local T = Quality.materialTier({ Iron = vIron, Steel = vSteel })
	print(string.format("blade (steel) %.4f stud^3, rest (iron) %.4f stud^3 -> T = %.4f", vSteel, vIron, T))
	_G.T_MIXED = T
end

print("")
print("## Q / rarity worked examples (Sword plan weights 0.25 / 0.40 / 0.35)")
local function plan(tiers: { string })
	local p = {}
	for i, def in Defs.CraftPlans.Sword do
		p[i] = { step = def.step, weight = def.weight, tier = tiers[i] }
	end
	return p
end
local TMIX = _G.T_MIXED :: number
local CASES = {
	{ name = "A. Average, iron, all Normal", T = 1.0, tiers = { "Normal", "Normal", "Normal" }, r = { { 0.62, true }, { 0.58, true }, { 0.60, true } } },
	{ name = "B. Good, steel, Smelt H / Ham N / Sharp H", T = 1.10, tiers = { "Hard", "Normal", "Hard" }, r = { { 0.70, true }, { 0.80, true }, { 0.66, true } } },
	{ name = "C. As B but Sharpening failed (raw 0.28)", T = 1.10, tiers = { "Hard", "Normal", "Hard" }, r = { { 0.70, true }, { 0.80, true }, { 0.28, false } } },
	{ name = "D. Excellent, iron, all Hard", T = 1.0, tiers = { "Hard", "Hard", "Hard" }, r = { { 0.82, true }, { 0.80, true }, { 0.78, true } } },
	{ name = "E. Excellent, steel, all Normal (cap binds)", T = 1.10, tiers = { "Normal", "Normal", "Normal" }, r = { { 0.95, true }, { 0.92, true }, { 0.93, true } } },
	{ name = "F. Excellent, iron, only Sharpening Hard, Hard step failed (raw 0.29)", T = 1.0, tiers = { "Normal", "Normal", "Hard" }, r = { { 0.95, true }, { 0.95, true }, { 0.29, false } } },
	{ name = "G. S2 arming, steel blade + iron rest, Good, N/H/H", T = TMIX, tiers = { "Normal", "Hard", "Hard" }, r = { { 0.80, true }, { 0.70, true }, { 0.72, true } } },
}
print("| Case | Tiers | s (raw, pass) | s_eff | sum w*s_eff*d | T | Q | by score | cap (step) | Rarity |")
print("|---|---|---|---|---:|---:|---:|---|---|---|")
for _, c in CASES do
	local p = plan(c.tiers)
	local results = {}
	local rawTxt, effTxt = {}, {}
	for i, x in c.r do
		results[i] = { score = x[1], passed = x[2] }
		table.insert(rawTxt, string.format("%.2f%s", x[1], if x[2] then "" else " FAIL"))
	end
	local qr = Quality.compute(p, results, c.T)
	local sum = 0
	for _, t in qr.terms do
		sum += t.contribution
		table.insert(effTxt, string.format("%.3f", t.effectiveScore))
	end
	local rr = Rarity.resolve(qr.q, p, results)
	print(string.format("| %s | %s | %s | %s | %.4f | %.4f | %.4f | %s | %s (%s) | **%s** |", c.name, table.concat(c.tiers, "/"), table.concat(rawTxt, " / "), table.concat(effTxt, " / "), sum, c.T, qr.q, rr.byScore, rr.cap, rr.capStep or "base", rr.rarity))
end
