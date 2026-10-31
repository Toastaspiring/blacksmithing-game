--!strict
-- quick sweep of HoldZone dynamics to find a challenging-but-fair Normal/Hard
local HZ = require("./HoldZone")
local Bots = require("./Bots")
local process = require("@lune/process")
local N = tonumber(process.args[1]) or 120

type Prof = { delay: number, noise: number, kpred: number, kzone: number, band: number, minGap: number, minHold: number, lapseRate: number, lapseMs: number }
local PROFILES: { [string]: Prof } = {
	elite = { delay = 160, noise = 0.004, kpred = 0.30, kzone = 0.5, band = 0.15, minGap = 70, minHold = 60, lapseRate = 0, lapseMs = 0 },
	good = { delay = 210, noise = 0.008, kpred = 0.22, kzone = 0.3, band = 0.25, minGap = 90, minHold = 70, lapseRate = 0.01, lapseMs = 400 },
	poor = { delay = 300, noise = 0.020, kpred = 0.08, kzone = 0.0, band = 0.30, minGap = 130, minHold = 90, lapseRate = 0.04, lapseMs = 700 },
}

local function runHuman(pat: HZ.Pattern, prof: Prof, botSeed: number): HZ.Result
	local s = HZ.newSession(pat);
	(s :: any).hist = { T = {}, C = {}, F = {} }
	local hist = (s :: any).hist
	local r = Bots.rng(botSeed, "hz-human")
	local frames = Bots.frames(r, pat.durationMs)
	local down, lastToggle, freezeUntil, lastFrame = false, -1e9, -1, 0
	local h = pat.p.zoneWidth / 2
	for _, f in frames do
		if f >= pat.durationMs then
			break
		end
		if prof.lapseRate > 0 and f > freezeUntil and r:nextFloat() < prof.lapseRate * (f - lastFrame) / 1000 then
			freezeUntil = f + prof.lapseMs
		end
		lastFrame = f
		if f > freezeUntil then
			local kObs = (f - prof.delay) // HZ.TICK_MS
			local Tobs, Cobs, vT, vC = 0, pat.keysC[1], 0, 0
			if kObs >= 10 and hist.T[kObs] then
				Tobs = hist.T[kObs] + prof.noise * Bots.gauss(r)
				Cobs = hist.C[kObs]
				vT = (hist.T[kObs] - hist.T[kObs - 10]) / 0.1
				vC = (hist.C[kObs] - hist.C[kObs - 10]) / 0.1
			end
			local pred = Tobs + vT * (prof.kpred + prof.delay / 1000)
			local target = Cobs + vC * (prof.kzone + prof.delay / 1000)
			local b = prof.band * h
			if not down and pred < target - b and f - lastToggle >= prof.minGap then
				down, lastToggle = true, f
				HZ.push(s, { t = f, down = true })
			elseif down and pred > target + b and f - lastToggle >= prof.minHold then
				down, lastToggle = false, f
				HZ.push(s, { t = f, down = false })
			end
		end
		HZ.advance(s, f)
	end
	return HZ.finish(s)
end

local BASE = {
	durationMs = 15000, rampMs = 3000, zoneWidth = 0.20, driftSpeed = 0.06, heatRate = 0.6, heatDecay = 0.3,
	fireLagMs = 300, minStrokeMs = 60, targetMin = 0.4, targetMax = 0.8, segMinMs = 900, segMaxMs = 2200,
	holdChance = 0.25, softFrac = 0.5, passThreshold = 0.5,
}

local function with(over: { [string]: number }): { [string]: number }
	local p = table.clone(BASE)
	for k, v in over do
		p[k] = v
	end
	return p
end

local CONFIGS = {
	{ "N Iron V0", with({ heatRate = 1.2, heatDecay = 0.6, zoneWidth = 0.14, driftSpeed = 0.12, fireLagMs = 400, holdChance = 0.25, durationMs = 15000, segMinMs = 900, segMaxMs = 2200 }) },
	{ "N Iron V1 (drift x1.2 dur x1.2)", with({ heatRate = 1.2, heatDecay = 0.6, zoneWidth = 0.14, driftSpeed = 0.144, fireLagMs = 400, holdChance = 0.25, durationMs = 18000, segMinMs = 900, segMaxMs = 2200 }) },
	{ "N Steel V0", with({ heatRate = 1.26, heatDecay = 0.63, zoneWidth = 0.1316, driftSpeed = 0.126, fireLagMs = 400, holdChance = 0.25, durationMs = 15000, segMinMs = 900, segMaxMs = 2200 }) },
	{ "H Iron V0", with({ heatRate = 1.38, heatDecay = 0.69, zoneWidth = 0.119, driftSpeed = 0.144, fireLagMs = 400, holdChance = 0.2, durationMs = 15000, segMinMs = 810, segMaxMs = 1980 }) },
	{ "H Iron V1", with({ heatRate = 1.38, heatDecay = 0.69, zoneWidth = 0.119, driftSpeed = 0.1728, fireLagMs = 400, holdChance = 0.2, durationMs = 18000, segMinMs = 810, segMaxMs = 1980 }) },
	{ "H Steel V0", with({ heatRate = 1.449, heatDecay = 0.7245, zoneWidth = 0.11186, driftSpeed = 0.1512, fireLagMs = 400, holdChance = 0.2, durationMs = 15000, segMinMs = 810, segMaxMs = 1980 }) },
	{ "H Steel V1", with({ heatRate = 1.449, heatDecay = 0.7245, zoneWidth = 0.11186, driftSpeed = 0.18144, fireLagMs = 400, holdChance = 0.2, durationMs = 18000, segMinMs = 810, segMaxMs = 1980 }) },
}

print(Bots.HEADER)
for _, cfg in CONFIGS do
	local label, p = cfg[1] :: string, cfg[2] :: { [string]: number }
	for _, bot in { "elite", "good", "poor" } do
		local scores, passes, flags = {}, {}, {}
		for i = 1, N do
			local pat = HZ.generate((i * 2654435761) % 4294967296, p)
			local res = runHuman(pat, PROFILES[bot], i * 7919 + 17)
			scores[i], passes[i], flags[i] = res.score, res.passed, false
		end
		print(Bots.row(label .. " " .. bot, Bots.stats(scores, passes, flags)))
	end
end
