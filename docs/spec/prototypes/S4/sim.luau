--!strict
-- S4 prototype: Monte Carlo of Q and rarity for plausible score profiles.
-- Usage: lune run sim.luau [mode] [dropScale]
--   mode = "table" (default): rarity mix with the thresholds in Crafting/Defs.luau
--   mode = "tune": grid-search Uncommon/Rare/Epic thresholds against the design targets
--   mode = "sens": sensitivity of the table to the Hard score drop and the fail threshold
local process = require("@lune/process")
local Defs = require("./Crafting/Defs")
local Quality = require("./Crafting/Quality")
local Rarity = require("./Crafting/Rarity")

local MODE = process.args[1] or "table"
-- CAP_RULE=max (spec rule: highest cap among passed steps) | majority (tier reached by >= 50% of the step weight)
local CAP_RULE = process.env.CAP_RULE or "max"
-- PHI=<x> overrides failScoreFactor on Normal and Hard (comparison runs for the fail-rule decision)
if process.env.PHI then
	local phi = tonumber(process.env.PHI) :: number
	Defs.Tiers.Normal.failScoreFactor = phi
	Defs.Tiers.Hard.failScoreFactor = phi
end
-- WEIGHTS=equal replaces the Sword plan weights by 1/3 each (comparison run for the step-weight decision)
if process.env.WEIGHTS == "equal" then
	for _, def in Defs.CraftPlans.Sword do
		def.weight = 1 / 3
	end
end
local N = 20000
math.randomseed(20261031)

-- ---------------------------------------------------------------- score model (ASSUMPTIONS, S3 tunes the real minigames)
-- mu      : mean raw score on a Normal step with Iron
-- sdStep  : per-step noise
-- sdForm  : per-craft "form" shared by all steps of one craft (correlates the three scores)
-- dropHard: mean score lost on a Hard step (harder parameters)
type Profile = { name: string, mu: number, sdStep: number, sdForm: number, dropHard: number }
local PROFILES: { Profile } = {
	{ name = "Bad", mu = 0.40, sdStep = 0.12, sdForm = 0.06, dropHard = 0.15 },
	{ name = "Average", mu = 0.60, sdStep = 0.10, sdForm = 0.05, dropHard = 0.13 },
	{ name = "Good", mu = 0.76, sdStep = 0.08, sdForm = 0.04, dropHard = 0.11 },
	{ name = "Excellent", mu = 0.88, sdStep = 0.06, sdForm = 0.03, dropHard = 0.09 },
}
if (process.env.MODEL or "s4") == "s3" then
	PROFILES = {
		{ name = "Poor", mu = 0, sdStep = 0, sdForm = 0, dropHard = 0 },
		{ name = "Good", mu = 0, sdStep = 0, sdForm = 0, dropHard = 0 },
		{ name = "Elite", mu = 0, sdStep = 0, sdForm = 0, dropHard = 0 },
	}
end
local STEEL_DROP = 0.03 -- Steel: "slightly tighter windows"
local FAIL_BELOW = 0.50 -- S3 prototype rule (Params.passThreshold): fail <=> raw score < 0.50

type PlanSpec = { name: string, tiers: { string } }
local PLANS: { PlanSpec } = {
	{ name = "All-Normal", tiers = { "Normal", "Normal", "Normal" } },
	{ name = "Mixed-1 (Sharp H)", tiers = { "Normal", "Normal", "Hard" } },
	{ name = "Mixed-2 (Ham+Sharp H)", tiers = { "Normal", "Hard", "Hard" } },
	{ name = "All-Hard", tiers = { "Hard", "Hard", "Hard" } },
}
local MATERIALS = { "Iron", "Steel" }

local function randn(): number
	local u1 = math.random()
	local u2 = math.random()
	if u1 < 1e-12 then
		u1 = 1e-12
	end
	return math.sqrt(-2 * math.log(u1)) * math.cos(2 * math.pi * u2)
end

local function clamp01(x: number): number
	return math.min(1, math.max(0, x))
end

local function makePlan(spec: PlanSpec)
	local plan = {}
	for i, def in Defs.CraftPlans.Sword do
		plan[i] = { step = def.step, weight = def.weight, tier = spec.tiers[i] }
	end
	return plan
end

type Cell = {
	profile: string,
	plan: string,
	material: string,
	qs: { number }, -- all Q, sorted
	qe: { number }, -- Q of crafts whose cap >= Epic, sorted
	anyFail: number,
	failRate: { number }, -- per step
	meanQ: number,
	meanS: number,
}

-- ---------------------------------------------------------------- MODEL=s3: S3's prototype bot curves
-- (proto/S3/out_{hz,ts,pt}.txt: mean, p10, p90 per bot and config; sd = (p90 - p10) / 2.563).
-- Steel/Normal is not in S3's tables: estimated as Iron/Normal minus the Iron->Steel drop S3 measured at Hard.
-- S3's pass rule: passed <=> score >= 0.5 (Params.passThreshold).
local MODEL = process.env.MODEL or "s4"
type Curve = { m: number, p10: number, p90: number }
local S3 = {
	-- family -> bot -> config -> curve
	Smelting = {
		poor = { IN = { m = 0.656, p10 = 0.589, p90 = 0.726 }, IH = { m = 0.567, p10 = 0.496, p90 = 0.632 }, SH = { m = 0.560, p10 = 0.493, p90 = 0.626 } },
		good = { IN = { m = 0.819, p10 = 0.750, p90 = 0.886 }, IH = { m = 0.691, p10 = 0.620, p90 = 0.759 }, SH = { m = 0.684, p10 = 0.612, p90 = 0.749 } },
		elite = { IN = { m = 0.930, p10 = 0.887, p90 = 0.970 }, IH = { m = 0.818, p10 = 0.745, p90 = 0.886 }, SH = { m = 0.812, p10 = 0.739, p90 = 0.883 } },
	},
	Hammering = {
		poor = { IN = { m = 0.608, p10 = 0.479, p90 = 0.734 }, IH = { m = 0.500, p10 = 0.373, p90 = 0.620 }, SH = { m = 0.465, p10 = 0.339, p90 = 0.585 } },
		good = { IN = { m = 0.821, p10 = 0.742, p90 = 0.894 }, IH = { m = 0.738, p10 = 0.650, p90 = 0.823 }, SH = { m = 0.707, p10 = 0.611, p90 = 0.800 } },
		elite = { IN = { m = 0.953, p10 = 0.924, p90 = 0.979 }, IH = { m = 0.917, p10 = 0.880, p90 = 0.951 }, SH = { m = 0.902, p10 = 0.862, p90 = 0.941 } },
	},
	Sharpening = {
		poor = { IN = { m = 0.608, p10 = 0.506, p90 = 0.703 }, IH = { m = 0.505, p10 = 0.376, p90 = 0.626 }, SH = { m = 0.435, p10 = 0.320, p90 = 0.564 } },
		good = { IN = { m = 0.867, p10 = 0.836, p90 = 0.895 }, IH = { m = 0.830, p10 = 0.783, p90 = 0.869 }, SH = { m = 0.794, p10 = 0.729, p90 = 0.852 } },
		elite = { IN = { m = 0.955, p10 = 0.941, p90 = 0.968 }, IH = { m = 0.940, p10 = 0.924, p90 = 0.955 }, SH = { m = 0.928, p10 = 0.908, p90 = 0.946 } },
	},
}
local S3_PASS = 0.5
local function s3Curve(step: string, bot: string, tier: string, material: string): (number, number)
	local f = (S3 :: any)[step][bot]
	local c: Curve
	if material == "Iron" then
		c = if tier == "Hard" then f.IH else f.IN
	elseif tier == "Hard" then
		c = f.SH
	else
		c = { m = f.IN.m - (f.IH.m - f.SH.m), p10 = f.IN.p10 - (f.IH.p10 - f.SH.p10), p90 = f.IN.p90 - (f.IH.p90 - f.SH.p90) }
	end
	return c.m, (c.p90 - c.p10) / 2.563
end

local function capMajority(plan, results): string
	local base = Defs.Quality.FailedStepCapTier
	for k = #Defs.TierOrder, 1, -1 do
		local t = Defs.TierOrder[k]
		local w = 0
		for i, ps in plan do
			local tierForCap = if results[i].passed then ps.tier else base
			if Defs.Tiers[tierForCap].order >= Defs.Tiers[t].order then
				w += ps.weight
			end
		end
		if w >= 0.5 - 1e-9 then
			return Defs.Tiers[t].rarityCap
		end
	end
	return Defs.Tiers[base].rarityCap
end

local function simulateCell(p: Profile, spec: PlanSpec, material: string, dropScale: number, failBelow: number): Cell
	local plan = makePlan(spec)
	local T = Defs.Materials[material].qualityTier
	local matDrop = if material == "Steel" then STEEL_DROP else 0
	local qs, qe = {}, {}
	local anyFail, sumQ, sumS = 0, 0, 0
	local failRate = { 0, 0, 0 }
	for _ = 1, N do
		local form = randn() * p.sdForm
		local results = {}
		local failed = false
		for i, ps in plan do
			local s, passed
			if MODEL == "s3" then
				local m, sd = s3Curve(ps.step, string.lower(p.name), ps.tier, material)
				s = clamp01(m + randn() * sd)
				passed = s >= S3_PASS
			else
				local mean = p.mu + form - matDrop - (if ps.tier == "Hard" then p.dropHard * dropScale else 0)
				s = clamp01(mean + randn() * p.sdStep)
				passed = s >= failBelow
			end
			if not passed then
				failed = true
				failRate[i] += 1
			end
			results[i] = { score = s, passed = passed }
			sumS += s
		end
		local q = Quality.compute(plan, results, T).q
		local cap = if CAP_RULE == "majority" then capMajority(plan, results) else (Rarity.cap(plan, results))
		table.insert(qs, q)
		if Defs.Rarities[cap].order >= Defs.Rarities.Epic.order then
			table.insert(qe, q)
		end
		if failed then
			anyFail += 1
		end
		sumQ += q
	end
	table.sort(qs)
	table.sort(qe)
	for i = 1, 3 do
		failRate[i] /= N
	end
	return {
		profile = p.name,
		plan = spec.name,
		material = material,
		qs = qs,
		qe = qe,
		anyFail = anyFail / N,
		failRate = failRate,
		meanQ = sumQ / N,
		meanS = sumS / (3 * N),
	}
end

-- fraction of `arr` (sorted asc) with value >= t, relative to N
local function fracGE(arr: { number }, t: number): number
	local lo, hi = 1, #arr + 1
	while lo < hi do
		local mid = (lo + hi) // 2
		if arr[mid] >= t then
			hi = mid
		else
			lo = mid + 1
		end
	end
	return (#arr - lo + 1) / N
end

type Mix = { C: number, U: number, R: number, E: number }
local function mix(cell: Cell, tU: number, tR: number, tE: number): Mix
	local geU = fracGE(cell.qs, tU)
	local geR = fracGE(cell.qs, tR)
	local E = fracGE(cell.qe, tE)
	return { C = 1 - geU, U = geU - geR, R = geR - E, E = E }
end

local function simulateAll(dropScale: number, failBelow: number): { [string]: Cell }
	local cells = {}
	for _, p in PROFILES do
		for _, spec in PLANS do
			for _, m in MATERIALS do
				cells[p.name .. "|" .. spec.name .. "|" .. m] = simulateCell(p, spec, m, dropScale, failBelow)
			end
		end
	end
	return cells
end

local function pct(x: number): string
	return string.format("%5.1f", 100 * x)
end

local function printTable(cells: { [string]: Cell }, tU: number, tR: number, tE: number)
	print(string.format("Thresholds: Uncommon >= %.2f, Rare >= %.2f, Epic >= %.2f (caps: Normal->Rare, Hard->Epic; cap rule: %s)", tU, tR, tE, CAP_RULE))
	print("| Player | Plan (Smelt/Ham/Sharp) | Mat | Common % | Uncommon % | Rare % | Epic % | mean Q | mean s | craft with >=1 fail % | capped % |")
	print("|---|---|---|---:|---:|---:|---:|---:|---:|---:|---:|")
	for _, p in PROFILES do
		for _, spec in PLANS do
			for _, m in MATERIALS do
				local c = cells[p.name .. "|" .. spec.name .. "|" .. m]
				local x = mix(c, tU, tR, tE)
				local capped = fracGE(c.qs, tE) - fracGE(c.qe, tE) -- Q reached Epic but the cap held it at Rare
				print(string.format("| %s | %s | %s | %s | %s | %s | %s | %.3f | %.3f | %s | %s |", p.name, spec.name, m, pct(x.C), pct(x.U), pct(x.R), pct(x.E), c.meanQ, c.meanS, pct(c.anyFail), pct(capped)))
			end
		end
	end
end

-- compact: one row per player x plan, "C / U / R / E" per material, plus mean Q and fail share
local function printCompact(cells: { [string]: Cell }, tU: number, tR: number, tE: number)
	print(string.format("Thresholds: Uncommon >= %.2f, Rare >= %.2f, Epic >= %.2f; cap rule %s; score model %s; N = %d crafts per cell", tU, tR, tE, CAP_RULE, MODEL, N))
	print("| Player | Plan (Smelt / Ham / Sharp) | Iron C / U / R / E % | Iron mean Q | Steel C / U / R / E % | Steel mean Q | crafts with a fail % (Iron / Steel) |")
	print("|---|---|---|---:|---|---:|---|")
	local function f(x: number): string
		return string.format("%.0f", 100 * x)
	end
	for _, p in PROFILES do
		for _, spec in PLANS do
			local ci = cells[p.name .. "|" .. spec.name .. "|Iron"]
			local cs = cells[p.name .. "|" .. spec.name .. "|Steel"]
			local xi, xs = mix(ci, tU, tR, tE), mix(cs, tU, tR, tE)
			print(string.format("| %s | %s | %s / %s / %s / %s | %.2f | %s / %s / %s / %s | %.2f | %s / %s |", p.name, spec.name,
				f(xi.C), f(xi.U), f(xi.R), f(xi.E), ci.meanQ, f(xs.C), f(xs.U), f(xs.R), f(xs.E), cs.meanQ, f(ci.anyFail), f(cs.anyFail)))
		end
	end
end

-- ---------------------------------------------------------------- design targets for the tuning search
type Target = { cell: string, label: string, f: (Mix) -> number } -- f returns margin (>= 0 means satisfied)
local TARGETS: { Target } = {
	{ cell = "Average|All-Normal|Iron", label = "avg N iron: C+U >= 90%", f = function(x) return (x.C + x.U) - 0.90 end },
	{ cell = "Average|All-Normal|Iron", label = "avg N iron: U >= 55%", f = function(x) return x.U - 0.55 end },
	{ cell = "Average|All-Normal|Steel", label = "avg N steel: R <= 25%", f = function(x) return 0.25 - x.R end },
	{ cell = "Bad|All-Normal|Iron", label = "bad N iron: C >= 70%", f = function(x) return x.C - 0.70 end },
	{ cell = "Good|All-Normal|Iron", label = "good N iron: R >= 55%", f = function(x) return x.R - 0.55 end },
	{ cell = "Excellent|All-Normal|Iron", label = "exc N iron: R >= 90%", f = function(x) return x.R - 0.90 end },
	{ cell = "Average|All-Hard|Iron", label = "avg H iron: E <= 2%", f = function(x) return 0.02 - x.E end },
	{ cell = "Average|All-Hard|Steel", label = "avg H steel: E <= 2%", f = function(x) return 0.02 - x.E end },
	{ cell = "Good|All-Hard|Iron", label = "good H iron: E >= 5%", f = function(x) return x.E - 0.05 end },
	{ cell = "Good|All-Hard|Iron", label = "good H iron: E <= 45%", f = function(x) return 0.45 - x.E end },
	{ cell = "Excellent|All-Hard|Iron", label = "exc H iron: E >= 60%", f = function(x) return x.E - 0.60 end },
	{ cell = "Excellent|Mixed-1 (Sharp H)|Iron", label = "exc 1xH iron: E <= 60%", f = function(x) return 0.60 - x.E end },
}

local function tune(cells: { [string]: Cell })
	local best, bestMargin = nil :: { number }?, -math.huge
	local feasible = 0
	local range = { U = { math.huge, -math.huge }, R = { math.huge, -math.huge }, E = { math.huge, -math.huge } }
	for iu = 30, 60 do
		local tU = iu / 100
		for ir = 55, 90 do
			local tR = ir / 100
			for ie = 80, 120 do
				local tE = ie / 100
				if tU < tR and tR < tE then
					local minMargin = math.huge
					for _, t in TARGETS do
						local m = t.f(mix(cells[t.cell], tU, tR, tE))
						if m < minMargin then
							minMargin = m
						end
					end
					if minMargin >= 0 then
						feasible += 1
						range.U[1] = math.min(range.U[1], tU)
						range.U[2] = math.max(range.U[2], tU)
						range.R[1] = math.min(range.R[1], tR)
						range.R[2] = math.max(range.R[2], tR)
						range.E[1] = math.min(range.E[1], tE)
						range.E[2] = math.max(range.E[2], tE)
					end
					if minMargin > bestMargin then
						bestMargin = minMargin
						best = { tU, tR, tE }
					end
				end
			end
		end
	end
	print(string.format("feasible threshold triples: %d", feasible))
	if feasible > 0 then
		print(string.format("feasible ranges: Uncommon [%.2f, %.2f]  Rare [%.2f, %.2f]  Epic [%.2f, %.2f]", range.U[1], range.U[2], range.R[1], range.R[2], range.E[1], range.E[2]))
	end
	if best then
		print(string.format("max-min-margin triple: Uncommon %.2f, Rare %.2f, Epic %.2f (min margin %.3f)", best[1], best[2], best[3], bestMargin))
	end
	return best
end

local function printTargets(cells: { [string]: Cell }, tU: number, tR: number, tE: number)
	print("target check:")
	for _, t in TARGETS do
		if cells[t.cell] == nil then
			continue
		end
		local m = t.f(mix(cells[t.cell], tU, tR, tE))
		print(string.format("  %-28s margin %+.3f %s", t.label, m, if m >= 0 then "OK" else "FAIL"))
	end
end

local tU, tR, tE = Defs.Rarities.Uncommon.minQuality, Defs.Rarities.Rare.minQuality, Defs.Rarities.Epic.minQuality
-- optional overrides: lune run sim.luau table 0.45 0.70 0.92
if process.args[2] then
	tU = tonumber(process.args[2]) :: number
	tR = tonumber(process.args[3]) :: number
	tE = tonumber(process.args[4]) :: number
end

if MODE == "tune" then
	local cells = simulateAll(1, FAIL_BELOW)
	local best = tune(cells)
	if best then
		printTargets(cells, best[1], best[2], best[3])
	end
	print("--- with the Defs thresholds")
	printTargets(cells, tU, tR, tE)
elseif MODE == "compact" then
	local cells = simulateAll(1, FAIL_BELOW)
	printCompact(cells, tU, tR, tE)
	print("")
	printTargets(cells, tU, tR, tE)
elseif MODE == "sens" then
	for _, cfg in { { 0.6, FAIL_BELOW, "Hard drop x0.6" }, { 1.4, FAIL_BELOW, "Hard drop x1.4" }, { 1, 0.20, "fail below 0.20" }, { 1, 0.30, "fail below 0.30" }, { 1, 0.40, "fail below 0.40" } } do
		print("=== sensitivity: " .. cfg[3])
		local cells = simulateAll(cfg[1], cfg[2])
		printTargets(cells, tU, tR, tE)
		print("")
	end
else
	local cells = simulateAll(1, FAIL_BELOW)
	printTable(cells, tU, tR, tE)
	print("")
	printTargets(cells, tU, tR, tE)
	-- per-step fail rates for the Average and Bad profiles (sanity: Normal 'Low', Hard 'Medium')
	print("")
	print("per-step fail rate (Smelt/Ham/Sharp), Iron:")
	for _, p in PROFILES do
		for _, spec in { PLANS[1], PLANS[4] } do
			local c = cells[p.name .. "|" .. spec.name .. "|Iron"]
			print(string.format("  %-9s %-10s %s / %s / %s", p.name, spec.name, pct(c.failRate[1]), pct(c.failRate[2]), pct(c.failRate[3])))
		end
	end
end
