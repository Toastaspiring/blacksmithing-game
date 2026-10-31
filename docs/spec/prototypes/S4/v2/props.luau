--!strict
-- S4 prototype v2: outcome properties (the T-CR-03..06 invariants) on Crafting/Core.luau.
-- Random crafts from a fixed xorshift seed + the exhaustive cap grid (2^3 tiers x 11^3 scores x 2 materials).
-- usage: lune run props.luau [nRandom]
local Defs = require("./Crafting/Defs")
local C = require("./Crafting/Core")
local process = require("@lune/process")

local N = tonumber(process.args[1]) or 200000
local x = 20261031
local function rnd(): number
	x = bit32.bxor(x, bit32.lshift(x, 13))
	x = bit32.bxor(x, bit32.rshift(x, 17))
	x = bit32.bxor(x, bit32.lshift(x, 5))
	return x / 4294967296
end
local fails = 0
local function check(ok: boolean, what: string)
	if not ok then
		fails += 1
		if fails <= 20 then
			print("FAIL " .. what)
		end
	end
end

check(#C.validateDefs() == 0, "weights")
local IDS = { "Smelting", "Hammering", "Sharpening" }
local W = { 0.25, 0.40, 0.35 }
local function plan(tiers: { string }, D: { number }): any
	local steps = {}
	for i = 1, 3 do
		steps[i] = { index = i, step = IDS[i], family = Defs.StepFamily[IDS[i]], weight = W[i], tier = tiers[i], difficulty = D[i], material = "Iron" }
	end
	return { equipmentType = "Sword", steps = steps }
end
local function randTier(): (string, number)
	if rnd() < 0.5 then
		return "Normal", math.floor(rnd() * 1999) / 1e4
	end
	return "Hard", 0.2 + math.floor(rnd() * 8001) / 1e4
end
local order = C.rarityOrder

-- multiplier: grows with D inside a tier, Hard at its threshold beats Normal at its top
do
	local prev = -1
	for k = 0, 1999 do
		local m = C.multiplier("Normal", k / 1e4)
		check(m >= prev, "d monotone Normal")
		prev = m
	end
	check(C.multiplier("Hard", 0.2) > C.multiplier("Normal", 0.1999), "tier step pays")
	prev = -1
	for k = 2000, 10000 do
		local m = C.multiplier("Hard", k / 1e4)
		check(m >= prev, "d monotone Hard")
		prev = m
	end
end

for _ = 1, N do
	local tiers, D, runs = {}, {}, {}
	for i = 1, 3 do
		tiers[i], D[i] = randTier()
		local s = math.floor(rnd() * 10001) / 1e4
		runs[i] = { score = s, passed = s >= 0.5 }
	end
	local p = plan(tiers, D)
	local T = if rnd() < 0.5 then 1.0 else Defs.material.Steel.qualityTier
	local qr = C.quality(p, runs, T)
	local rr = C.resolve(qr.q, p, runs)
	check(order(rr.rarity) <= order(rr.cap) and order(rr.rarity) <= order(rr.byScore), "rarity <= cap, byScore")
	local passedHard = false
	for i = 1, 3 do
		passedHard = passedHard or (runs[i].passed and tiers[i] == "Hard")
	end
	check(passedHard or order(rr.rarity) <= order("Rare"), "no Epic without a passed Hard step")
	-- monotone in each raw score (same pass pattern), pass >= fail at the same raw score
	local k = 1 + math.floor(rnd() * 3)
	local r2 = table.clone(runs)
	local up = math.min(1, runs[k].score + 0.01)
	if (up >= 0.5) == runs[k].passed then
		r2[k] = { score = up, passed = runs[k].passed }
		check(C.quality(p, r2, T).q >= qr.q, "Q monotone in score")
	end
	local r3 = table.clone(runs)
	r3[k] = { score = runs[k].score, passed = true }
	local r4 = table.clone(runs)
	r4[k] = { score = runs[k].score, passed = false }
	check(C.quality(p, r3, T).q >= C.quality(p, r4, T).q, "pass >= fail")
	-- monotone in T and in D (within the same tier)
	check(C.quality(p, runs, T + 0.01).q >= qr.q, "Q monotone in T")
	local p2 = plan(tiers, D)
	local tk = p2.steps[k]
	local dmax = if tk.tier == "Normal" then 0.1999 else 1.0
	tk.difficulty = math.min(dmax, tk.difficulty + 0.01)
	check(C.quality(p2, runs, T).q >= qr.q, "Q monotone in D")
	-- stats ranges with random physics inputs
	local inp = { mass = rnd() * 6, reach = 0.5 + rnd() * 4.5, balance = -1 + rnd() * 3, edgeLength = rnd() * 8, cutIndex = rnd(),
		hardness = 0.45 + rnd() * 0.25, toughness = 0.5 + rnd() * 0.05, smelting = runs[1].score, hammering = runs[2].score, sharpening = runs[3].score }
	local st = C.stats("Sword", inp)
	for _, id in { "Damage", "Sharpness", "Durability", "Purity", "Balance" } do
		check(st[id] >= 0 and st[id] <= 100, "stat range " .. id)
	end
	check(st.Reach == C.q(inp.reach, 1e4), "Reach = physics reach")
end

-- thresholds inclusive
for _, r in Defs.Rarities do
	if r.enabled and r.order > 1 then
		check(C.fromQuality(r.minQuality) == r.id, "inclusive " .. r.id)
		check(order(C.fromQuality(C.q(r.minQuality - 1e-4, 1e4))) == r.order - 1, "below " .. r.id)
	end
end

-- exhaustive cap grid: 2^3 tier patterns x 11^3 scores x 2 materials
local grid = 0
for mask = 0, 7 do
	local tiers = {}
	for i = 1, 3 do
		tiers[i] = if bit32.btest(mask, bit32.lshift(1, i - 1)) then "Hard" else "Normal"
	end
	local p = plan(tiers, { if tiers[1] == "Hard" then 0.3 else 0.1, if tiers[2] == "Hard" then 0.3 else 0.1, if tiers[3] == "Hard" then 0.3 else 0.1 })
	for a = 0, 10 do
		for b = 0, 10 do
			for c = 0, 10 do
				for _, T in { 1.0, Defs.material.Steel.qualityTier } do
					local runs = { { score = a / 10, passed = a >= 5 }, { score = b / 10, passed = b >= 5 }, { score = c / 10, passed = c >= 5 } }
					local qr = C.quality(p, runs, T)
					local rr = C.resolve(qr.q, p, runs)
					local want = "Rare"
					for i = 1, 3 do
						if tiers[i] == "Hard" and runs[i].passed then
							want = "Epic"
						end
					end
					check(rr.cap == want, "cap grid")
					local expect = if order(rr.byScore) <= order(want) then rr.byScore else want
					check(rr.rarity == expect, "final = min(byScore, cap)")
					grid += 1
				end
			end
		end
	end
end

-- ignored (not kept) parts change neither T, H nor K
do
	local core = { type = "Sword", parts = { { slot = "Blade", material = "Iron" }, { slot = "Blade", material = "Steel" }, { slot = "Grip", material = "Iron" } } }
	local ph = { kept = { true, false, true }, ownedVolume = { 0.03, 0.002, 0.02 } }
	local ph2 = { kept = { true, true, true }, ownedVolume = { 0.03, 0.002, 0.02 } }
	check(C.materialTier(core, ph) == 1.0, "ignored part T")
	check(math.abs(C.volMean(core, ph, { 1, 2 }, "hardness", 100) - 0.45) < 1e-12, "ignored part H")
	check(C.materialTier(core, ph2) > 1.0, "kept steel part counts")
end

print(string.format("props: %d random crafts, %d cap-grid cases, %d failures", N, grid, fails))
