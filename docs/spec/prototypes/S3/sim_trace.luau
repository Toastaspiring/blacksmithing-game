--!strict
-- S3 prototype: PrecisionTrace path derivation + bots
local PT = require("./PrecisionTrace")
local Params = require("./Params")
local Bots = require("./Bots")
local process = require("@lune/process")
local N = tonumber(process.args[1]) or 200
local ONLY = process.args[2]

-- reference blade edges (blueprint X-Y studs, base -> tip)
local function straightDouble(halfW: number, len: number, taperFrom: number)
	return {
		{ { halfW, 0 }, { halfW, taperFrom }, { 0, len } },
		{ { -halfW, 0 }, { -halfW, taperFrom }, { 0, len } },
	}
end
local function sabre()
	local e = {}
	for i = 0, 16 do
		local y = 3.2 * i / 16
		table.insert(e, { 0.24 + 0.35 * (y / 3.4) ^ 2, y })
	end
	table.insert(e, { 0.62, 3.45 })
	return { e }
end
local function flamberge(vox: number)
	local a, b = {}, {}
	local function q(x: number): number
		return math.floor(x / vox + 0.5) * vox
	end
	for i = 0, 60 do
		local y = 3.0 * i / 60
		local w = 0.24 + 0.05 * math.sin(2 * math.pi * y / 0.55)
		table.insert(a, { q(w), q(y) })
		table.insert(b, { q(-w), q(y) })
	end
	table.insert(a, { 0, 3.7 })
	table.insert(b, { 0, 3.7 })
	return { a, b }
end

local BLADES = {
	{ "longsword", straightDouble(0.22, 3.6, 2.9) },
	{ "sabre (1 edge)", sabre() },
	{ "flamberge (voxel 0.05)", flamberge(0.05) },
	{ "dagger", straightDouble(0.16, 1.5, 1.1) },
	{ "none -> fallback", nil },
}

type Prof = { tau: number, sCross: number, tCross: number, tremor: number, lagMu: number, lagSigma: number, tLag: number, liftRate: number, startOff: number, pressMs: number }
local PROFILES: { [string]: Prof } = {
	elite = { tau = 70, sCross = 0.006, tCross = 0.3, tremor = 0.0012, lagMu = -0.02, lagSigma = 0.02, tLag = 1.0, liftRate = 0, startOff = 0.005, pressMs = 0 },
	good = { tau = 100, sCross = 0.012, tCross = 0.35, tremor = 0.0015, lagMu = -0.04, lagSigma = 0.04, tLag = 1.0, liftRate = 0.003, startOff = 0.01, pressMs = 150 },
	poor = { tau = 160, sCross = 0.025, tCross = 0.4, tremor = 0.002, lagMu = -0.07, lagSigma = 0.08, tLag = 1.2, liftRate = 0.015, startOff = 0.03, pressMs = 350 },
}
local PANEL_PX = 500

local function normalAt(pat: PT.Pattern, s: number): (number, number)
	local u1, v1 = PT.pointAt(pat, math.max(0, s - 0.01))
	local u2, v2 = PT.pointAt(pat, math.min(pat.L, s + 0.01))
	local tu, tv = u2 - u1, v2 - v1
	local l = math.sqrt(tu * tu + tv * tv)
	if l == 0 then
		return 0, 0
	end
	return -tv / l, tu / l
end

local function q(x: number): number
	return math.floor(x * PT.Q + 0.5)
end

local function human(pat: PT.Pattern, prof: Prof, seed: number): { PT.Sample }
	local r = Bots.rng(seed, "pt-human")
	local frames = Bots.frames(r, pat.durationMs)
	local su, sv = PT.pointAt(pat, 0)
	local cu, cv = su + prof.startOff * Bots.gauss(r), sv + prof.startOff * Bots.gauss(r)
	local lag, cross = prof.lagMu, 0
	local pressAt = if r:nextFloat() < 0.7 then 0 else prof.pressMs
	local liftUntil = -1
	local samples: { PT.Sample } = {}
	local nextDue = 0
	local fi = 1
	local lastGrind: boolean? = nil
	local dt = 2
	local t = 0
	while t <= pat.durationMs and fi <= #frames do
		local dts = dt / 1000
		lag = Bots.ou(r, lag, prof.lagMu, prof.lagSigma, prof.tLag, dts)
		cross = Bots.ou(r, cross, 0, prof.sCross * math.sqrt(pat.speed / 0.3), prof.tCross, dts)
		local sStar = PT.pacerArc(pat, t)
		local sT = math.clamp(sStar + lag, 0, pat.L)
		if t < pat.leadInMs then
			sT = 0
		end
		local pu, pv = PT.pointAt(pat, sT)
		local nu, nv = normalAt(pat, sT)
		local du, dv = pu + cross * nu, pv + cross * nv
		local a = dt / prof.tau
		cu += (du - cu) * a
		cv += (dv - cv) * a
		if prof.liftRate > 0 and t > liftUntil and r:nextFloat() < prof.liftRate * dts then
			liftUntil = t + r:range(150, 400)
		end
		while fi <= #frames and frames[fi] <= t do
			local f = frames[fi]
			local grind = f >= pressAt and f > liftUntil
			if f >= nextDue or grind ~= lastGrind then
				local mu = cu + prof.tremor * Bots.gauss(r)
				local mv = cv + prof.tremor * Bots.gauss(r)
				-- integer mouse pixels on a PANEL_PX-high panel
				mu = math.floor(mu * PANEL_PX + 0.5) / PANEL_PX
				mv = math.floor(mv * PANEL_PX + 0.5) / PANEL_PX
				local smp = { t = f, u = math.clamp(q(mu), 0, q(PT.PANEL_W)), v = math.clamp(q(mv), 0, PT.Q), grind = grind }
				if #samples > 0 and samples[#samples].t == f then
					samples[#samples] = smp
				else
					table.insert(samples, smp)
				end
				lastGrind = grind
				while nextDue <= f do
					nextDue += PT.EVAL_MS
				end
			end
			fi += 1
		end
		t += dt
	end
	return samples
end

local function perfect(pat: PT.Pattern, noise: number, every: number, seed: number): { PT.Sample }
	local r = Bots.rng(seed, "pt-cheat")
	local out = {}
	local t = 0
	while t <= pat.durationMs do
		local u, v = PT.pointAt(pat, PT.pacerArc(pat, t))
		if noise > 0 then
			u += noise * Bots.gauss(r)
			v += noise * Bots.gauss(r)
		end
		table.insert(out, { t = t, u = q(u), v = q(v), grind = true })
		t += every
	end
	return out
end

local function lazy(pat: PT.Pattern): { PT.Sample }
	local u, v = PT.pointAt(pat, 0)
	local out = {}
	local t = 0
	while t <= pat.durationMs do
		table.insert(out, { t = t, u = q(u), v = q(v), grind = true })
		t += 20
	end
	return out
end

-- path derivation report
local pN = Params.resolve("PrecisionTrace", "Iron", "Normal", nil)
local pH = Params.resolve("PrecisionTrace", "Iron", "Hard", nil)
print("| blade | source pts | path pts | L (panel u) | travel Normal ms | travel Hard ms | fallback | gen ms |")
print("|---|---|---|---|---|---|---|---|")
local sources = {}
for _, b in BLADES do
	local name, edge = b[1] :: string, b[2] :: any
	local src = PT.edgeToPanel(edge)
	sources[name] = src
	local t0 = os.clock()
	local pat = PT.generate(42, pN, src)
	local gen = (os.clock() - t0) * 1000
	local patH = PT.generate(42, pH, src)
	print(string.format("| %s | %d | %d | %.3f | %d | %d | %s | %.1f |", name, if src then #src // 2 else 0, #pat.pu, pat.L, pat.travelMs, patH.travelMs, tostring(pat.usedFallback), gen))
end

-- dump one path for inspection (longsword, Normal & Hard)
do
	local pat = PT.generate(7, pH, sources["flamberge (voxel 0.05)"])
	local parts = {}
	for i = 1, #pat.pu, 25 do
		table.insert(parts, string.format("(%.3f,%.3f)", pat.pu[i], pat.pv[i]))
	end
	print("flamberge Hard seed 7 every 25th pt:", table.concat(parts, " "))
end

local function batch(label: string, material: string, tier: string, factors: { [string]: number }?, bot: string, blade: string)
	local p = Params.resolve("PrecisionTrace", material, tier, factors)
	local scores, passes, flags = {}, {}, {}
	local accS, paceS, covS = 0, 0, 0
	local devS, jerkS = 0, 0
	local flagCount: { [string]: number } = {}
	for i = 1, N do
		local pat = PT.generate((i * 2654435761 + 999) % 4294967296, p, sources[blade])
		local samples
		if bot == "perfect" then
			samples = perfect(pat, 0, 20, i)
		elseif bot == "perfectNoisy" then
			samples = perfect(pat, 0.004, 20, i)
		elseif bot == "sparse200" then
			samples = perfect(pat, 0, 200, i)
		elseif bot == "lazy" then
			samples = lazy(pat)
		else
			samples = human(pat, PROFILES[bot], i * 7919 + 5)
		end
		local res = PT.replay(pat, samples)
		local _, metrics = PT.checks(pat, samples)
		scores[i], passes[i], flags[i] = res.score, res.passed, #res.flags > 0
		for _, f in res.flags do
			flagCount[f] = (flagCount[f] or 0) + 1
		end
		accS += res.accuracy
		paceS += res.pacing
		covS += res.coverage
		devS += metrics.meanDev
		jerkS += metrics.meanJerk
	end
	local fl = {}
	for f, c in flagCount do
		table.insert(fl, string.format("%s %.1f%%", f, 100 * c / N))
	end
	table.sort(fl)
	print(
		Bots.row(string.format("%s %s/%s", label, material, tier), Bots.stats(scores, passes, flags))
			.. string.format(" A %.3f P %.3f C %.3f | dev %.4f jerk %.5f | %s", accS / N, paceS / N, covS / N, devS / N, jerkS / N, table.concat(fl, ", "))
	)
end

print(Bots.HEADER)
local blade = "longsword"
for _, tier in { "Normal", "Hard" } do
	for _, bot in { "perfect", "perfectNoisy", "sparse200", "elite", "good", "poor", "lazy" } do
		if not ONLY or ONLY == bot then
			batch(bot, "Iron", tier, nil, bot, blade)
		end
	end
end
for _, bot in { "elite", "good", "poor" } do
	batch(bot .. " Steel", "Steel", "Hard", nil, bot, blade)
	batch(bot .. " flamberge complex", "Steel", "Hard", { Thinness = 1, SurfaceComplexity = 1, Asymmetry = 1 }, bot, "flamberge (voxel 0.05)")
	batch(bot .. " sabre", "Iron", "Normal", nil, bot, "sabre (1 edge)")
	batch(bot .. " dagger", "Iron", "Hard", nil, bot, "dagger")
end
