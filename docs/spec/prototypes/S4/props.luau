--!strict
-- S4 prototype: quick property checks of the §8.6.4 test properties on the prototype modules.
local Defs = require("./Crafting/Defs")
local Quality = require("./Crafting/Quality")
local Rarity = require("./Crafting/Rarity")
local Stats = require("./Crafting/Stats")

math.randomseed(7)
local failures = 0
local function check(cond: boolean, msg: string)
	if not cond then
		failures += 1
		if failures <= 10 then
			print("FAIL: " .. msg)
		end
	end
end

-- weights
local sum = 0
for _, s in Defs.CraftPlans.Sword do
	sum += s.weight
end
check(math.abs(sum - 1) <= 1e-9, "weights sum " .. sum)
print(string.format("weights sum = %.17g", sum))

-- inclusive thresholds
for i, id in Defs.RarityOrder do
	local minQ = Defs.Rarities[id].minQuality
	check(Rarity.fromQuality(minQ) == id, "fromQuality(min) " .. id)
	if i > 1 then
		check(Rarity.fromQuality(minQ - 1e-4) == Defs.RarityOrder[i - 1], "below min " .. id)
	end
end

local TIERS = { "Normal", "Hard" }
local function randomPlan()
	local p = {}
	for i, def in Defs.CraftPlans.Sword do
		p[i] = { step = def.step, weight = def.weight, tier = TIERS[math.random(1, 2)] }
	end
	return p
end

local ord = function(r: string): number
	return Defs.Rarities[r].order
end

for _ = 1, 200000 do
	local plan = randomPlan()
	local results = {}
	for i = 1, 3 do
		local s = math.random()
		results[i] = { score = s, passed = s >= 0.3 }
	end
	local T = if math.random() < 0.5 then 1.0 else 1.1
	local q = Quality.compute(plan, results, T).q
	local rr = Rarity.resolve(q, plan, results)
	check(ord(rr.rarity) <= ord(rr.cap) and ord(rr.rarity) <= ord(rr.byScore), "rarity <= cap, byScore")
	local allNormalOrFailedHard = true
	for i, ps in plan do
		if ps.tier == "Hard" and results[i].passed then
			allNormalOrFailedHard = false
		end
	end
	if allNormalOrFailedHard then
		check(ord(rr.rarity) <= ord("Rare"), "no passed Hard step -> <= Rare")
	end
	-- monotonic in each score, pass pattern fixed
	local k = math.random(1, 3)
	local bumped = table.clone(results)
	bumped[k] = { score = math.min(1, results[k].score + 0.05), passed = results[k].passed }
	check(Quality.compute(plan, bumped, T).q >= q, "monotonic in score")
	-- pass >= fail at equal raw score
	local asPass = table.clone(results)
	asPass[k] = { score = results[k].score, passed = true }
	local asFail = table.clone(results)
	asFail[k] = { score = results[k].score, passed = false }
	check(Quality.compute(plan, asPass, T).q >= Quality.compute(plan, asFail, T).q, "pass >= fail")
	-- stats ranges
	local st = Stats.compute({
		mass = math.random() * 8,
		reach = 0.5 + math.random() * 6,
		balanceOffset = -2 + math.random() * 5,
		edgeLength = math.random() * 12,
		bladeHardness = if math.random() < 0.5 then 0.5 else 0.7,
		bodyToughness = 0.5,
		smelting = math.random(),
		hammering = math.random(),
		sharpening = math.random(),
	})
	check(st.damage >= 9.0 - 1e-9 and st.damage <= 55.25 + 1e-9, "damage range " .. st.damage)
	check(st.sharpness >= 10.5 - 1e-9 and st.sharpness <= 70 + 1e-9, "sharpness range " .. st.sharpness)
	check(st.durability >= 17.5 - 1e-9 and st.durability <= 50 + 1e-9, "durability range " .. st.durability)
	check(st.purity >= 0.7 - 1e-9 and st.purity <= 1 + 1e-9, "purity range")
	check(st.balance >= 0 and st.balance <= 100, "balance range")
end

-- ceiling examples
local function planOf(tiers: { string })
	local p = {}
	for i, def in Defs.CraftPlans.Sword do
		p[i] = { step = def.step, weight = def.weight, tier = tiers[i] }
	end
	return p
end
local function ceiling(plan, T: number): number
	local perfect = { { score = 1, passed = true }, { score = 1, passed = true }, { score = 1, passed = true } }
	return Quality.compute(plan, perfect, T).q
end
print(string.format("ceiling N/N/N Iron %.4f | N/H/H Iron %.4f | H/H/H Steel %.4f", ceiling(planOf({ "Normal", "Normal", "Normal" }), 1.0), ceiling(planOf({ "Normal", "Hard", "Hard" }), 1.0), ceiling(planOf({ "Hard", "Hard", "Hard" }), 1.1)))
print(string.format("planCap N/N/H = %s, N/N/N = %s", Rarity.planCap(planOf({ "Normal", "Normal", "Hard" })), Rarity.planCap(planOf({ "Normal", "Normal", "Normal" }))))
print(if failures == 0 then "ALL PROPERTIES HOLD (200000 random crafts)" else ("FAILURES: " .. failures))
