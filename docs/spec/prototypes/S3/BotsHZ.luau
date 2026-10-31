--!strict
-- HoldZone scripted bots (not authoritative code)
local HZ = require("./HoldZone")
local Bots = require("./Bots")

export type Prof = { delay: number, noise: number, kpred: number, kzone: number, band: number, minGap: number, minHold: number, lapseRate: number, lapseMs: number }

local M = {}
M.PROFILES = {
	elite = { delay = 160, noise = 0.004, kpred = 0.30, kzone = 0.5, band = 0.15, minGap = 70, minHold = 60, lapseRate = 0, lapseMs = 0 },
	good = { delay = 210, noise = 0.008, kpred = 0.22, kzone = 0.3, band = 0.25, minGap = 90, minHold = 70, lapseRate = 0.01, lapseMs = 400 },
	poor = { delay = 300, noise = 0.020, kpred = 0.08, kzone = 0.0, band = 0.30, minGap = 130, minHold = 90, lapseRate = 0.04, lapseMs = 700 },
} :: { [string]: Prof }

-- closed-loop human: observes delayed state, hysteresis around the (anticipated) zone centre.
-- returns events and the LIVE session result (push/advance per frame, exactly like the client)
function M.human(pat: HZ.Pattern, prof: Prof, botSeed: number): ({ HZ.HoldEvent }, HZ.Result)
	local s = HZ.newSession(pat);
	(s :: any).hist = { T = {}, C = {}, F = {} }
	local hist = (s :: any).hist
	local r = Bots.rng(botSeed, "hz-human")
	local frames = Bots.frames(r, pat.durationMs)
	local down, lastToggle, freezeUntil, lastFrame = false, -1e9, -1, 0
	local events: { HZ.HoldEvent } = {}
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
				local e = { t = f, down = true }
				table.insert(events, e)
				HZ.push(s, e)
			elseif down and pred > target + b and f - lastToggle >= prof.minHold then
				down, lastToggle = false, f
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

-- model-predictive controller with exact state and future zone; minGap = min ms between toggles
function M.mpc(pat: HZ.Pattern, minGap: number): ({ HZ.HoldEvent }, HZ.Result)
	local s = HZ.newSession(pat)
	local p = pat.p
	local alpha = HZ.TICK_MS / p.fireLagMs
	local dts = HZ.TICK_MS / 1000
	local H = 60
	local down, lastToggle = false, -1e9
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
				down, lastToggle = want, t
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

-- naive cheater: bang-bang at tick rate with exact state (no motor limits)
function M.pwm(pat: HZ.Pattern): ({ HZ.HoldEvent }, HZ.Result)
	local s = HZ.newSession(pat)
	local down = false
	local events: { HZ.HoldEvent } = {}
	local K = pat.durationMs // HZ.TICK_MS
	local seg = { seg = 1 }
	for k = 0, K - 1 do
		local t = k * HZ.TICK_MS
		local c = HZ.centerAt(pat, seg, t + HZ.TICK_MS)
		local want = s.T < c
		if want ~= down then
			down = want
			local e = { t = t, down = want }
			table.insert(events, e)
			HZ.push(s, e)
		end
		HZ.advance(s, t)
	end
	local res = HZ.finish(s)
	res.flags = HZ.checks(pat, events)
	return events, res
end

return M
