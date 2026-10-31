--!strict
-- S3 prototype: HoldZone bots at Normal / Hard
local HZ = require("./HoldZone")
local Params = require("./Params")
local Bots = require("./Bots")

local process = require("@lune/process")
local N = tonumber(process.args[1]) or 300

type Prof = { delay: number, noise: number, kpred: number, kzone: number, band: number, minGap: number, minHold: number, lapseRate: number, lapseMs: number }

local PROFILES: { [string]: Prof } = {
	elite = { delay = 160, noise = 0.004, kpred = 0.45, kzone = 0.5, band = 0.15, minGap = 70, minHold = 60, lapseRate = 0, lapseMs = 0 },
	good = { delay = 210, noise = 0.008, kpred = 0.35, kzone = 0.3, band = 0.25, minGap = 90, minHold = 70, lapseRate = 0.01, lapseMs = 400 },
	poor = { delay = 300, noise = 0.020, kpred = 0.12, kzone = 0.0, band = 0.30, minGap = 130, minHold = 90, lapseRate = 0.04, lapseMs = 700 },
}

local function runHuman(pat: HZ.Pattern, prof: Prof, botSeed: number): ({ HZ.HoldEvent }, HZ.Result)
	local s = HZ.newSession(pat);
	(s :: any).hist = { T = {}, C = {}, F = {} }
	local hist = (s :: any).hist
	local r = Bots.rng(botSeed, "hz-human")
	local frames = Bots.frames(r, pat.durationMs)
	local down = false
	local lastToggle = -1e9
	local freezeUntil = -1
	local events: { HZ.HoldEvent } = {}
	local h = pat.p.zoneWidth / 2
	local lastFrame = 0
	for _, f in frames do
		if f >= pat.durationMs then
			break
		end
		-- lapse (attention drop): keep current input for lapseMs
		if prof.lapseRate > 0 and f > freezeUntil and r:nextFloat() < prof.lapseRate * (f - lastFrame) / 1000 then
			freezeUntil = f + prof.lapseMs
		end
		lastFrame = f
		if f > freezeUntil then
			local kObs = (f - prof.delay) // HZ.TICK_MS
			local Tobs, Cobs, vT, vC
			if kObs >= 10 and hist.T[kObs] then
				Tobs = hist.T[kObs] + prof.noise * Bots.gauss(r)
				Cobs = hist.C[kObs]
				vT = (hist.T[kObs] - hist.T[kObs - 10]) / 0.1
				vC = (hist.C[kObs] - hist.C[kObs - 10]) / 0.1
			else
				Tobs, Cobs, vT, vC = 0, pat.keysC[1], 0, 0
			end
			local pred = Tobs + vT * prof.kpred
			local target = Cobs + vC * prof.kzone
			local b = prof.band * h
			if not down and pred < target - b and f - lastToggle >= prof.minGap then
				down = true
				lastToggle = f
				local e = { t = f, down = true }
				table.insert(events, e)
				HZ.push(s, e)
			elseif down and pred > target + b and f - lastToggle >= prof.minHold then
				down = false
				lastToggle = f
				local e = { t = f, down = false }
				table.insert(events, e)
				HZ.push(s, e)
			end
		end
		HZ.advance(s, f)
	end
	local res = HZ.finish(s)
	res.flags = HZ.checks(pat, events)
	return events, res
end

-- model-predictive "perfect" controller with exact state; decides every tick (10 ms) or every minGap ms
local function runMPC(pat: HZ.Pattern, minGap: number): ({ HZ.HoldEvent }, HZ.Result)
	local s = HZ.newSession(pat)
	local p = pat.p
	local alpha = HZ.TICK_MS / p.fireLagMs
	local dts = HZ.TICK_MS / 1000
	local H = 60
	local down = false
	local lastToggle = -1e9
	local events: { HZ.HoldEvent } = {}
	local K = pat.durationMs // HZ.TICK_MS
	for k = 0, K - 1 do
		local t = k * HZ.TICK_MS
		if t - lastToggle >= minGap then
			local best, bestCost = 0, math.huge
			for _, u in { 0, 1 } do
				local T, F = s.T, s.F
				local seg = { seg = 1 }
				local cost = 0
				for j = 1, H do
					F = F + (u - F) * alpha
					T = math.clamp(T + p.heatDecay * (p.fullHeat * F - T) * dts, 0, 1)
					local c = HZ.centerAt(pat, seg, t + j * HZ.TICK_MS)
					cost += (T - c) ^ 2
				end
				if cost < bestCost then
					best, bestCost = u, cost
				end
			end
			local want = best == 1
			if want ~= down then
				down = want
				lastToggle = t
				local e = { t = t, down = want }
				table.insert(events, e)
				HZ.push(s, e)
			end
		end
		HZ.advance(s, t)
	end
	local res = HZ.finish(s)
	res.flags = HZ.checks(pat, events)
	return events, res
end

local function runBatch(label: string, material: string, tier: string, factors: { [string]: number }?, bot: string)
	local p = Params.resolve("HoldZone", material, tier, factors)
	local scores, passes, flags = {}, {}, {}
	local presses = 0
	for i = 1, N do
		local pat = HZ.generate((i * 2654435761) % 4294967296, p)
		local ev, res
		if bot == "mpc" then
			ev, res = runMPC(pat, 0)
		elseif bot == "mpc100" then
			ev, res = runMPC(pat, 100)
		else
			ev, res = runHuman(pat, PROFILES[bot], i * 7919 + 17)
		end
		for _, e in ev do
			if e.down then
				presses += 1
			end
		end
		scores[i] = res.score
		passes[i] = res.passed
		flags[i] = #res.flags > 0
	end
	local st = Bots.stats(scores, passes, flags)
	print(Bots.row(string.format("%s %s/%s", label, material, tier), st) .. string.format(" presses/s %.1f", presses / N / (p.durationMs / 1000)))
end

print(Bots.HEADER)
for _, tier in { "Normal", "Hard" } do
	for _, bot in { "mpc", "mpc100", "elite", "good", "poor" } do
		runBatch(bot, "Iron", tier, nil, bot)
	end
end
for _, bot in { "good", "poor" } do
	runBatch(bot .. " (Vol=1)", "Steel", "Hard", { Volume = 1 }, bot)
end
-- print a resolved param set for reference
for _, tier in { "Normal", "Hard" } do
	local p = Params.resolve("HoldZone", "Iron", tier, nil)
	local keys = {}
	for k in p do
		table.insert(keys, k)
	end
	table.sort(keys)
	local parts = {}
	for _, k in keys do
		table.insert(parts, k .. "=" .. tostring(p[k]))
	end
	print(tier, table.concat(parts, " "))
end
