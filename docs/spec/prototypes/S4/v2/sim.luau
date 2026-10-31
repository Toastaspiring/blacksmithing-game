--!strict
-- S4 prototype v2: rarity tuning on S3's final per-run score distributions (final/S3-score-distributions.luau).
-- Craft i of a row = (HoldZone run i, TimingStrike run i, PrecisionTrace run i) of the row's cells: 2,000 crafts,
-- deterministic, the composition S8's T-CR-09 replays. "wide" adds 9 rotations (TS run i+7j, PT run i+13j): 20,000.
-- Formulas: Crafting/Core.luau (SPEC §8). Plans at S3's reference design points (D = 0.10 Normal, 0.30 Hard).
-- usage: lune run sim.luau <mode> [U R E steelT gamma]
--   table  : the published rarity table + target check (defaults from Crafting/Defs)
--   tune   : grid search over (U, R, E, steelT) at the given gamma; feasible box
--   alt    : cap-rule alternatives (Max / Majority / Striking) and fail-factor variants
local Dist = require("../../../final/S3-score-distributions")
local Defs = require("./Crafting/Defs")
local C = require("./Crafting/Core")
local process = require("@lune/process")

local mode = process.args[1] or "table"
local argU, argR, argE, argT, argG = tonumber(process.args[2]), tonumber(process.args[3]), tonumber(process.args[4]),
	tonumber(process.args[5]), tonumber(process.args[6])
if argU then
	Defs.set({ thresholds = { argU, argR, argE } })
end
if argT then
	Defs.set({ steelT = argT })
end
if argG then
	Defs.set({ gamma = argG })
end
local WIDE = process.env.WIDE == "1"

local STEPS = { "Smelting", "Hammering", "Sharpening" }
local FAM = { Smelting = "HoldZone", Hammering = "TimingStrike", Sharpening = "PrecisionTrace" }
local REF_D = { Normal = 0.10, Hard = 0.30 }
local PLANS = {
	{ id = "N/N/N", label = "All-Normal", t = { "Normal", "Normal", "Normal" } },
	{ id = "H/N/N", label = "Smelting Hard only", t = { "Hard", "Normal", "Normal" } },
	{ id = "N/N/H", label = "Sharpening Hard only", t = { "Normal", "Normal", "Hard" } },
	{ id = "N/H/H", label = "Hammering + Sharpening Hard (F3 rapier)", t = { "Normal", "Hard", "Hard" } },
	{ id = "H/N/H", label = "Smelting + Sharpening Hard (F4 cleaver)", t = { "Hard", "Normal", "Hard" } },
	{ id = "H/H/H", label = "All-Hard", t = { "Hard", "Hard", "Hard" } },
}
local PROFS = { "Elite", "Good", "Average", "Poor" }
local MATS = { "Iron", "Steel" }

local function planOf(p: any): any
	local steps = {}
	for i, s in STEPS do
		steps[i] = { index = i, step = s, family = FAM[s], weight = Defs.CraftPlans[1].steps[i].weight, tier = p.t[i], difficulty = REF_D[p.t[i]], material = "Iron" }
	end
	return { equipmentType = "Sword", steps = steps }
end

-- one row = (plan, profile, material): returns per-craft {sum (= sum w s_eff d), cap order, passedHard, anyFail}
local function crafts(p: any, prof: string, mat: string): { any }
	local plan = planOf(p)
	local cols = {}
	for i, s in STEPS do
		cols[i] = Dist.get(FAM[s], p.t[i], mat, prof)
	end
	local n = #cols[1]
	local out = {}
	local reps = if WIDE then 10 else 1
	for j = 0, reps - 1 do
		for i = 1, n do
			local idx = { i, ((i - 1 + 7 * j) % n) + 1, ((i - 1 + 13 * j) % n) + 1 }
			local runs = {}
			local sum = 0
			local anyFail, passedHard = false, false
			for k = 1, 3 do
				local sc = cols[k][idx[k]]
				local passed = sc >= Dist.passThreshold
				runs[k] = { score = sc, passed = passed }
				local ps = plan.steps[k]
				sum += ps.weight * C.effectiveScore(sc, passed, ps.tier) * C.multiplier(ps.tier, ps.difficulty)
				anyFail = anyFail or not passed
				passedHard = passedHard or (passed and ps.tier == "Hard")
			end
			local cap = C.cap(plan, runs)
			table.insert(out, { sum = sum, cap = C.rarityOrder(cap), anyFail = anyFail, passedHard = passedHard })
		end
	end
	return out
end

local cache: { [string]: { any } } = {}
local function rowKey(pi: number, prof: string, mat: string): string
	return pi .. "/" .. prof .. "/" .. mat
end
local function getRow(pi: number, prof: string, mat: string): { any }
	local k = rowKey(pi, prof, mat)
	if not cache[k] then
		cache[k] = crafts(PLANS[pi], prof, mat)
	end
	return cache[k]
end

-- shares C/U/R/E for thresholds th = {U, R, E} and material tier T
local function shares(row: { any }, T: number, th: { number }): ({ number }, number, number, number)
	local cnt = { 0, 0, 0, 0 }
	local qsum, fails, capped = 0, 0, 0
	for _, c in row do
		local qv = C.q(T * c.sum, 1e4)
		qsum += qv
		local byScore = if qv >= th[3] then 4 elseif qv >= th[2] then 3 elseif qv >= th[1] then 2 else 1
		local r = math.min(byScore, c.cap)
		if byScore > c.cap then
			capped += 1
		end
		cnt[r] += 1
		if c.anyFail then
			fails += 1
		end
	end
	local n = #row
	for i = 1, 4 do
		cnt[i] = cnt[i] / n
	end
	return cnt, qsum / n, fails / n, capped / n
end

local function Tof(mat: string): number
	return Defs.material[mat].qualityTier
end
local function thresholds(): { number }
	return { Defs.rarity.Uncommon.minQuality, Defs.rarity.Rare.minQuality, Defs.rarity.Epic.minQuality }
end

-- ============ targets (SPEC §8 rarity targets; RULINGS §2.16 + R4b-10; T9-T11 are S4's own)
-- { id, plan index, profile, material, rarity index (1 C .. 4 E) or "CU", lo, hi, required }
local TARGETS = {
	{ id = "T1", pi = 1, prof = "Average", mat = "Iron", what = "R+", lo = 0, hi = 0.15, req = true, text = "Average, all-Normal Iron: Rare <= 15 % (mostly Common/Uncommon)" },
	{ id = "T2", pi = 1, prof = "Good", mat = "Iron", what = "R", lo = 0.30, hi = 0.60, req = true, text = "Good, all-Normal Iron: Rare 30-60 %" },
	{ id = "T3", pi = 6, prof = "Good", mat = "Iron", what = "E", lo = 0.05, hi = 0.25, req = true, text = "Good, all-Hard Iron: Epic 5-25 %" },
	{ id = "T4", pi = 6, prof = "Good", mat = "Steel", what = "E", lo = 0.05, hi = 0.25, req = true, text = "Good, all-Hard Steel: Epic 5-25 %" },
	{ id = "T5", pi = 6, prof = "Elite", mat = "Iron", what = "E", lo = 0.40, hi = 1, req = true, text = "Elite, all-Hard Iron: Epic >= 40 %" },
	{ id = "T6", pi = 6, prof = "Elite", mat = "Steel", what = "E", lo = 0.40, hi = 1, req = true, text = "Elite, all-Hard Steel: Epic >= 40 %" },
	{ id = "T7", pi = 3, prof = "Elite", mat = "Iron", what = "E", lo = 0, hi = 0.60, req = true, text = "Elite, Sharpening-Hard-only Iron: Epic <= 60 % (one Hard step is no guarantee)" },
	{ id = "T8", pi = 3, prof = "Elite", mat = "Steel", what = "E", lo = 0, hi = 0.60, req = true, text = "Elite, Sharpening-Hard-only Steel: Epic <= 60 % (R4b-10)" },
	{ id = "T9", pi = 1, prof = "Average", mat = "Iron", what = "U+", lo = 0.50, hi = 1, req = false, text = "Average, all-Normal Iron: Uncommon or better >= 50 %" },
	{ id = "T10", pi = 1, prof = "Poor", mat = "Iron", what = "C", lo = 0.70, hi = 1, req = false, text = "Poor, all-Normal Iron: Common >= 70 %" },
	{ id = "T11", pi = 1, prof = "Average", mat = "Steel", what = "R+", lo = 0, hi = 0.25, req = false, text = "Average, all-Normal Steel: Rare <= 25 %" },
}

local function value(sh: { number }, what: string): number
	if what == "C" then
		return sh[1]
	elseif what == "U+" then
		return sh[2] + sh[3] + sh[4]
	elseif what == "R" then
		return sh[3]
	elseif what == "R+" then
		return sh[3] + sh[4]
	else
		return sh[4]
	end
end

-- fast path for the grid: sorted Q per (row, T), and sorted Q of the crafts whose cap reached Epic
local sortedCache: { [string]: any } = {}
local function sortedQ(pi: number, prof: string, mat: string, T: number): any
	local k = rowKey(pi, prof, mat) .. "@" .. T
	local s = sortedCache[k]
	if not s then
		local all, epic = {}, {}
		for _, c in getRow(pi, prof, mat) do
			local qv = C.q(T * c.sum, 1e4)
			table.insert(all, qv)
			if c.cap >= 4 then
				table.insert(epic, qv)
			end
		end
		table.sort(all)
		table.sort(epic)
		s = { all = all, epic = epic, n = #all }
		sortedCache[k] = s
	end
	return s
end
local function countGE(a: { number }, x: number): number
	local lo, hi = 1, #a + 1 -- first index with a[i] >= x
	while lo < hi do
		local mid = (lo + hi) // 2
		if a[mid] >= x then
			hi = mid
		else
			lo = mid + 1
		end
	end
	return #a - lo + 1
end
local function fastValue(s: any, th: { number }, what: string): number
	local n = s.n
	local e = countGE(s.epic, th[3]) / n
	if what == "E" then
		return e
	elseif what == "R+" then
		return countGE(s.all, th[2]) / n
	elseif what == "R" then
		return countGE(s.all, th[2]) / n - e
	elseif what == "U+" then
		return countGE(s.all, th[1]) / n
	else
		return 1 - countGE(s.all, th[1]) / n
	end
end

local function checkTargets(th: { number }, steelT: number, verbose: boolean): (boolean, boolean, number)
	local allReq, all = true, true
	local minMargin = math.huge
	for _, t in TARGETS do
		local T = if t.mat == "Steel" then steelT else 1.0
		local v
		if verbose then
			v = value((shares(getRow(t.pi, t.prof, t.mat), T, th)), t.what)
		else
			v = fastValue(sortedQ(t.pi, t.prof, t.mat, T), th, t.what)
		end
		local ok = v >= t.lo - 1e-12 and v <= t.hi + 1e-12
		local margin = math.min(if t.lo > 0 then v - t.lo else math.huge, if t.hi < 1 then t.hi - v else math.huge)
		if t.req then
			allReq = allReq and ok
			minMargin = math.min(minMargin, margin)
		end
		all = all and ok
		if verbose then
			print(string.format("  %-4s %-78s %6.1f %%  %s (margin %+.1f)", t.id, t.text, v * 100, if ok then "ok" else "MISS", margin * 100))
		end
	end
	return allReq, all, minMargin
end

local function epicWithoutHard(): number
	local bad = 0
	local th = thresholds()
	for pi in PLANS do
		for _, prof in PROFS do
			for _, mat in MATS do
				for _, c in getRow(pi, prof, mat) do
					local qv = C.q(Tof(mat) * c.sum, 1e4)
					if qv >= th[3] and c.cap >= 4 and not c.passedHard then
						bad += 1
					end
					if c.cap >= 4 and not c.passedHard then
						bad += 1000000 -- cap must never reach Epic without a passed Hard step
					end
				end
			end
		end
	end
	return bad
end

local function printTable()
	local th = thresholds()
	print(string.format("# rarity mix, thresholds U %.2f R %.2f E %.2f, T Steel %.2f, gamma %.2f, phi %.2f, cap rule %s, %d crafts/row",
		th[1], th[2], th[3], Tof("Steel"), Defs.Quality.DESIGN_GAMMA, Defs.tier.Normal.failScoreFactor, Defs.Quality.CAP_RULE, #getRow(1, "Good", "Iron")))
	print("| Profile | Plan S/H/Sh | Iron C / U / R / E % | Iron mean Q | Steel C / U / R / E % | Steel mean Q | crafts with a fail % Iron / Steel | cap-bound % Iron / Steel |")
	print("|---|---|---|---:|---|---:|---|---|")
	for _, prof in PROFS do
		for pi, p in PLANS do
			local cells = {}
			local qs, fs, cs = {}, {}, {}
			for _, mat in MATS do
				local sh, mq, fr, cb = shares(getRow(pi, prof, mat), Tof(mat), th)
				table.insert(cells, string.format("%.0f / %.0f / %.0f / %.0f", sh[1] * 100, sh[2] * 100, sh[3] * 100, sh[4] * 100))
				table.insert(qs, string.format("%.3f", mq))
				table.insert(fs, string.format("%.0f", fr * 100))
				table.insert(cs, string.format("%.0f", cb * 100))
			end
			print(string.format("| %s | %s | %s | %s | %s | %s | %s / %s | %s / %s |", prof, p.id, cells[1], qs[1], cells[2], qs[2], fs[1], fs[2], cs[1], cs[2]))
		end
	end
end

if mode == "table" then
	printTable()
	print("# targets")
	local okReq, okAll, m = checkTargets(thresholds(), Tof("Steel"), true)
	print(string.format("required targets %s, all targets %s, min required margin %.1f points; Epic-without-passed-Hard violations: %d",
		if okReq then "PASS" else "FAIL", if okAll then "PASS" else "FAIL", m * 100, epicWithoutHard()))
elseif mode == "tune" then
	-- grid over U, R, E (0.01 steps) for each Steel T; report the feasible box and the max-min-margin triple
	local steelTs = { 1.00, 1.02, 1.03, 1.04, 1.05, 1.06, 1.07, 1.08, 1.10 }
	for _, sT in steelTs do
		local n, best, bestTh = 0, -math.huge, nil
		local box = { { 9, -9 }, { 9, -9 }, { 9, -9 } }
		for e = 90, 125 do
			for r = 70, 95 do
				for u = 40, 69 do
					local th = { u / 100, r / 100, e / 100 }
					local okReq, okAll, m = checkTargets(th, sT, false)
					if okReq and okAll then
						n += 1
						for k = 1, 3 do
							box[k][1] = math.min(box[k][1], th[k])
							box[k][2] = math.max(box[k][2], th[k])
						end
						if m > best then
							best, bestTh = m, th
						end
					end
				end
			end
		end
		if bestTh then
			print(string.format("steelT %.2f gamma %.2f: %d feasible triples; U %.2f-%.2f, R %.2f-%.2f, E %.2f-%.2f; best min margin %.1f at %.2f / %.2f / %.2f",
				sT, Defs.Quality.DESIGN_GAMMA, n, box[1][1], box[1][2], box[2][1], box[2][2], box[3][1], box[3][2], best * 100, bestTh[1], bestTh[2], bestTh[3]))
		else
			print(string.format("steelT %.2f gamma %.2f: no feasible triple", sT, Defs.Quality.DESIGN_GAMMA))
		end
	end
elseif mode == "alt" then
	for _, rule in { "Max", "Majority", "Striking" } do
		Defs.set({ capRule = rule })
		table.clear(cache)
		print("## cap rule " .. rule)
		printTable()
		checkTargets(thresholds(), Tof("Steel"), true)
	end
	Defs.set({ capRule = "Max" })
	for _, phi in { 0.5, 1.0 } do
		Defs.set({ phi = phi })
		table.clear(cache)
		print(string.format("## phi %.2f", phi))
		printTable()
		checkTargets(thresholds(), Tof("Steel"), true)
	end
	Defs.set({ phi = 0.75 })
	Defs.set({ weights = { 1 / 3, 1 / 3, 1 / 3 } })
	table.clear(cache)
	print("## equal weights")
	printTable()
	checkTargets(thresholds(), Tof("Steel"), true)
end
