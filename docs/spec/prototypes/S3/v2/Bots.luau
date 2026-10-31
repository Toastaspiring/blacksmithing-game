--!strict
-- S3 prototype v2: Minigames/Bots, the single player model (RULINGS 2.16-2.18). NOT authoritative code; bots may
-- use libm. Every parameter below is documented in SPEC 6 (player-model table).
-- Client recording rules modelled exactly: button inputs are delivered at the first frame after the physical
-- action and stamped floor(frame - frameDt/2) (TimingStrike also minus timingOffsetMs); trace samples are taken
-- at the first frame at or after each 20 ms due time, stamped floor(frame), grind flag = state at that frame.
local R = require("./Rng")
local HZ = require("./HoldZone")
local TS = require("./TimingStrike")
local PT = require("./PrecisionTrace")

local Bots = {}

function Bots.rng(seed: number, tag: string)
	return R.Rng.new(seed % 4294967296, tag)
end

function Bots.gauss(r: any): number
	local u1 = math.max(r:nextFloat(), 1e-12)
	local u2 = r:nextFloat()
	return math.sqrt(-2 * math.log(u1)) * math.cos(2 * math.pi * u2)
end

function Bots.ou(r: any, x: number, mu: number, sigma: number, tauS: number, dtS: number): number
	local a = math.exp(-dtS / tauS)
	return mu + (x - mu) * a + sigma * math.sqrt(1 - a * a) * Bots.gauss(r)
end

-- frame clock: fps with +-1 ms jitter and hitches (rate per frame, 30-120 ms); random phase vs GO
function Bots.frames(r: any, endMs: number, fps: number, hitchRate: number): { number }
	local f = {}
	local dt = 1000 / fps
	local t = r:range(0, dt)
	while t <= endMs + 2 * dt + 130 do
		table.insert(f, t)
		local step = dt + (r:nextFloat() - 0.5) * 2
		if r:nextFloat() < hitchRate then
			step += r:range(30, 120)
		end
		t += step
	end
	return f
end

-- index of the first frame >= t (binary search)
local function firstFrameAtOrAfter(frames: { number }, t: number): number
	local lo, hi = 1, #frames
	if frames[hi] < t then
		return hi
	end
	while lo < hi do
		local mid = (lo + hi) // 2
		if frames[mid] >= t then
			hi = mid
		else
			lo = mid + 1
		end
	end
	return lo
end
Bots.firstFrameAtOrAfter = firstFrameAtOrAfter

-- centred stamp of an input delivered at frame index k
local function stamp(frames: { number }, k: number): number
	local dt = if k > 1 then frames[k] - frames[k - 1] else frames[k]
	return math.floor(frames[k] - dt / 2)
end
Bots.stamp = stamp

export type Profile = {
	id: string,
	fps: number,
	hitchRate: number,
	extraLagMs: number, -- display + input latency beyond one frame (render lag = extraLagMs + 1000/fps)
	-- TimingStrike
	sigmaMs: number,
	biasMeanMs: number,
	biasSdMs: number,
	lapse: number,
	extraPress: number,
	-- HoldZone (both policies share perception)
	hzDelayMs: number,
	hzNoise: number,
	hzKPred: number,
	hzKZone: number,
	hzBand: number,
	hzMinGapMs: number,
	hzMinHoldMs: number,
	hzLapseRate: number, -- per second
	hzLapseMs: number,
	pumpPeriodMs: number,
	pumpJitterMs: number,
	pumpHoldMs: number,
	pumpHoldJitterMs: number,
	-- PrecisionTrace
	ptTauMs: number,
	ptCross: number,
	ptCrossTauS: number,
	ptTremor: number,
	ptLagMu: number,
	ptLagSigma: number,
	ptLagTauS: number,
	ptLiftRate: number,
	ptStartOff: number,
	ptLatePressMs: number,
	panelPx: number,
}

local function P(t: any): Profile
	return t :: Profile
end

Bots.PROFILES = {
	Elite = P({ id = "Elite", fps = 60, hitchRate = 0.003, extraLagMs = 8, sigmaMs = 12, biasMeanMs = 3, biasSdMs = 5, lapse = 0.005, extraPress = 0.0,
		hzDelayMs = 160, hzNoise = 0.004, hzKPred = 0.30, hzKZone = 0.5, hzBand = 0.15, hzMinGapMs = 70, hzMinHoldMs = 60, hzLapseRate = 0, hzLapseMs = 0,
		pumpPeriodMs = 130, pumpJitterMs = 20, pumpHoldMs = 65, pumpHoldJitterMs = 8,
		ptTauMs = 70, ptCross = 0.006, ptCrossTauS = 0.30, ptTremor = 0.0012, ptLagMu = -0.02, ptLagSigma = 0.02, ptLagTauS = 1.0, ptLiftRate = 0, ptStartOff = 0.005, ptLatePressMs = 0, panelPx = 520 }),
	Good = P({ id = "Good", fps = 60, hitchRate = 0.003, extraLagMs = 8, sigmaMs = 25, biasMeanMs = 5, biasSdMs = 10, lapse = 0.02, extraPress = 0.02,
		hzDelayMs = 210, hzNoise = 0.008, hzKPred = 0.22, hzKZone = 0.3, hzBand = 0.25, hzMinGapMs = 90, hzMinHoldMs = 70, hzLapseRate = 0.01, hzLapseMs = 400,
		pumpPeriodMs = 140, pumpJitterMs = 25, pumpHoldMs = 70, pumpHoldJitterMs = 10,
		ptTauMs = 100, ptCross = 0.012, ptCrossTauS = 0.35, ptTremor = 0.0015, ptLagMu = -0.04, ptLagSigma = 0.04, ptLagTauS = 1.0, ptLiftRate = 0.003, ptStartOff = 0.01, ptLatePressMs = 150, panelPx = 520 }),
	Average = P({ id = "Average", fps = 60, hitchRate = 0.003, extraLagMs = 8, sigmaMs = 45, biasMeanMs = 10, biasSdMs = 15, lapse = 0.05, extraPress = 0.02,
		hzDelayMs = 300, hzNoise = 0.020, hzKPred = 0.08, hzKZone = 0.0, hzBand = 0.30, hzMinGapMs = 130, hzMinHoldMs = 90, hzLapseRate = 0.04, hzLapseMs = 700,
		pumpPeriodMs = 180, pumpJitterMs = 40, pumpHoldMs = 90, pumpHoldJitterMs = 10,
		ptTauMs = 160, ptCross = 0.025, ptCrossTauS = 0.40, ptTremor = 0.002, ptLagMu = -0.07, ptLagSigma = 0.08, ptLagTauS = 1.2, ptLiftRate = 0.015, ptStartOff = 0.03, ptLatePressMs = 350, panelPx = 520 }),
	Poor = P({ id = "Poor", fps = 30, hitchRate = 0.006, extraLagMs = 8, sigmaMs = 90, biasMeanMs = 25, biasSdMs = 20, lapse = 0.10, extraPress = 0.04,
		hzDelayMs = 380, hzNoise = 0.035, hzKPred = 0.0, hzKZone = 0.0, hzBand = 0.40, hzMinGapMs = 170, hzMinHoldMs = 120, hzLapseRate = 0.08, hzLapseMs = 900,
		pumpPeriodMs = 220, pumpJitterMs = 50, pumpHoldMs = 110, pumpHoldJitterMs = 15,
		ptTauMs = 200, ptCross = 0.038, ptCrossTauS = 0.45, ptTremor = 0.003, ptLagMu = -0.09, ptLagSigma = 0.11, ptLagTauS = 1.4, ptLiftRate = 0.025, ptStartOff = 0.05, ptLatePressMs = 500, panelPx = 520 }),
}

-- variant with another frame rate (e.g. Average at 30 fps, Elite at 240 fps)
function Bots.variant(base: Profile, fps: number): Profile
	local c = table.clone(base) :: any
	c.fps = fps
	c.id = base.id .. "@" .. fps
	return c :: Profile
end

function Bots.renderLag(prof: Profile): number
	return prof.extraLagMs + 1000 / prof.fps
end

---------------------------------------------------------------------------- TimingStrike
-- returns recorded press times (client rule), timingOffsetMs subtracted
function Bots.tsHuman(pat: TS.Pattern, prof: Profile, seed: number, offsetMs: number?): { number }
	local r = Bots.rng(seed, "bot-ts")
	local frames = Bots.frames(r, pat.durationMs, prof.fps, prof.hitchRate)
	local p = pat.p
	local lag = Bots.renderLag(prof)
	local bias = prof.biasMeanMs + prof.biasSdMs * Bots.gauss(r) -- per player (per run)
	local sigma = prof.sigmaMs * (1 + 0.2 * math.max(0, 1000 / p.beatMs - 1)) * (1 + p.tempoJitter)
	local phys = {}
	for _, c in pat.cycles do
		if r:nextFloat() < prof.lapse then
			if r:nextFloat() < 0.5 then
				table.insert(phys, c.target + r:range(-300, 300))
			end
		else
			local t = c.target + lag + bias + sigma * Bots.gauss(r)
			table.insert(phys, t)
			if r:nextFloat() < prof.extraPress then
				table.insert(phys, t + r:range(80, 150))
			end
		end
	end
	table.sort(phys)
	local out = {}
	local off = offsetMs or 0
	for _, t in phys do
		local k = firstFrameAtOrAfter(frames, math.max(t, 0))
		local q = math.clamp(stamp(frames, k) - off, 0, pat.durationMs)
		if #out > 0 and q < out[#out] then
			q = out[#out]
		end
		table.insert(out, q)
	end
	return out
end

-- Perfect: exact intent, no latency, at the given fps (centred stamp)
function Bots.tsPerfect(pat: TS.Pattern, fps: number, seed: number): { number }
	local r = Bots.rng(seed, "bot-ts-perfect")
	local frames = Bots.frames(r, pat.durationMs, fps, 0)
	local out = {}
	for _, c in pat.cycles do
		local k = firstFrameAtOrAfter(frames, c.target)
		local q = math.clamp(stamp(frames, k), 0, pat.durationMs)
		if #out > 0 and q < out[#out] then
			q = out[#out]
		end
		table.insert(out, q)
	end
	return out
end

---------------------------------------------------------------------------- HoldZone
-- policy "hold": hold/release with hysteresis; policy "pump": taps of pumpHoldMs every pumpPeriodMs while the
-- predicted needle is below the (anticipated) zone centre. Both use the same delayed, noisy perception.
-- Returns events (stamped) and the live result.
function Bots.hzHuman(pat: HZ.Pattern, prof: Profile, seed: number, policy: string): ({ HZ.HoldEvent }, HZ.Result)
	local s = HZ.newSession(pat)
	s.hist = { T = {}, C = {} }
	local hist = s.hist
	local r = Bots.rng(seed, "bot-hz-" .. policy)
	local frames = Bots.frames(r, pat.durationMs, prof.fps, prof.hitchRate)
	local delay = prof.hzDelayMs + Bots.renderLag(prof)
	local h = pat.p.zoneWidth / 2
	local events: { HZ.HoldEvent } = {}
	local down = false -- physical state
	local lastToggle, freezeUntil, lastFrame = -1e9, -1, 0
	local releaseAt, nextDecide = -1, 0
	local pending: { { t: number, down: boolean } } = {} -- physical actions waiting for delivery
	for k, f in frames do
		-- deliver physical actions that happened before this frame
		while #pending > 0 and pending[1].t <= f do
			local a = table.remove(pending, 1) :: { t: number, down: boolean }
			local t = math.clamp(stamp(frames, k), 0, pat.durationMs)
			if #events > 0 and t < events[#events].t then
				t = events[#events].t
			end
			if t < pat.durationMs then
				local e = { t = t, down = a.down }
				table.insert(events, e)
				HZ.push(s, e)
			end
		end
		HZ.advance(s, math.clamp(stamp(frames, k), 0, pat.durationMs))
		if f >= pat.durationMs then
			break
		end
		if prof.hzLapseRate > 0 and f > freezeUntil and r:nextFloat() < prof.hzLapseRate * (f - lastFrame) / 1000 then
			freezeUntil = f + prof.hzLapseMs
		end
		lastFrame = f
		local function observe(): (number, number)
			local kObs = math.floor((f - delay) / HZ.TICK_MS)
			local Tobs, Cobs, vT, vC = 0, pat.keysC[1], 0, 0
			if kObs >= 10 and hist.T[kObs] then
				Tobs = hist.T[kObs] + prof.hzNoise * Bots.gauss(r)
				Cobs = hist.C[kObs]
				vT = (hist.T[kObs] - hist.T[kObs - 10]) / 0.1
				vC = (hist.C[kObs] - hist.C[kObs - 10]) / 0.1
			end
			local pred = Tobs + vT * (prof.hzKPred + delay / 1000)
			local target = Cobs + vC * (prof.hzKZone + delay / 1000)
			return pred, target
		end
		if policy == "pump" then
			if down and f >= releaseAt then
				down = false
				table.insert(pending, { t = f, down = false })
			end
			if not down and f >= nextDecide and f > freezeUntil then
				nextDecide = f + prof.pumpPeriodMs + r:range(-prof.pumpJitterMs, prof.pumpJitterMs)
				local pred, target = observe()
				if pred < target then
					down = true
					releaseAt = f + prof.pumpHoldMs + r:range(-prof.pumpHoldJitterMs, prof.pumpHoldJitterMs)
					table.insert(pending, { t = f, down = true })
				end
			end
		elseif f > freezeUntil then
			local pred, target = observe()
			local b = prof.hzBand * h
			if not down and pred < target - b and f - lastToggle >= prof.hzMinGapMs then
				down, lastToggle = true, f
				table.insert(pending, { t = f, down = true })
			elseif down and pred > target + b and f - lastToggle >= prof.hzMinHoldMs then
				down, lastToggle = false, f
				table.insert(pending, { t = f, down = false })
			end
		end
	end
	local res = HZ.finish(s)
	res.flags = HZ.checks(pat, events, res)
	return events, res
end

-- Perfect (test-only ceiling): exact state, exact future zone, no latency; at each 10 ms tick compares "stroke now"
-- with "no stroke" over an 800 ms look-ahead without further strokes (squared error), presses for one tick.
function Bots.hzPerfect(pat: HZ.Pattern): ({ HZ.HoldEvent }, HZ.Result)
	local s = HZ.newSession(pat)
	local p = pat.p
	local decay = HZ.TICK_MS / p.fireDecayMs
	local dts = HZ.TICK_MS / 1000
	local H = 30
	local events: { HZ.HoldEvent } = {}
	local K = pat.durationMs // HZ.TICK_MS
	local down = false
	for k = 0, K - 1 do
		local t = k * HZ.TICK_MS
		HZ.advance(s, t) -- state after ticks < t
		if down then
			down = false
			local e = { t = t, down = false }
			table.insert(events, e)
			HZ.push(s, e)
		else
			local bestCost, bestStroke = math.huge, false
			for _, stroke in { false, true } do
				local T, F = s.T, s.F
				if stroke then
					local g = p.strokeGain * math.min(1, (t - s.pressT) / p.refillMs)
					F = F + g * (1 - F)
				end
				local seg = { seg = 1 }
				local cost = 0
				for j = 0, H - 1 do
					F = F - F * decay
					T = math.clamp(T + p.heatDecay * (p.fullHeat * F - T) * dts, 0, 1)
					local c = HZ.centerAt(pat, seg, t + (j + 1) * HZ.TICK_MS)
					cost += (T - c) * (T - c)
				end
				if cost < bestCost then
					bestCost, bestStroke = cost, stroke
				end
			end
			if bestStroke then
				down = true
				local e = { t = t, down = true }
				table.insert(events, e)
				HZ.push(s, e)
			end
		end
	end
	local res = HZ.finish(s)
	res.flags = HZ.checks(pat, events, res)
	return events, res
end

---------------------------------------------------------------------------- PrecisionTrace
local function normalAt(pat: PT.Pattern, sArc: number): (number, number)
	local u1, v1 = PT.pointAt(pat, math.max(0, sArc - 0.01))
	local u2, v2 = PT.pointAt(pat, math.min(pat.L, sArc + 0.01))
	local tu, tv = u2 - u1, v2 - v1
	local l = math.sqrt(tu * tu + tv * tv)
	if l == 0 then
		return 0, 0
	end
	return -tv / l, tu / l
end

local function q16(x: number): number
	return math.round(x * PT.Q)
end

function Bots.ptHuman(pat: PT.Pattern, prof: Profile, seed: number): { PT.Sample }
	local r = Bots.rng(seed, "bot-pt")
	local frames = Bots.frames(r, pat.durationMs, prof.fps, prof.hitchRate)
	local lagMs = Bots.renderLag(prof)
	local su, sv = PT.pointAt(pat, 0)
	local cu, cv = su + prof.ptStartOff * Bots.gauss(r), sv + prof.ptStartOff * Bots.gauss(r)
	local lag, cross = prof.ptLagMu, 0
	local pressAt = if r:nextFloat() < 0.7 then 0 else prof.ptLatePressMs
	local liftUntil = -1
	local samples: { PT.Sample } = {}
	local nextDue = 0
	local fi = 1
	local dt = 2
	local t = 0
	local sScale = math.sqrt(pat.speed / 0.3)
	local px = prof.panelPx
	while t <= pat.durationMs and fi <= #frames do
		local dts = dt / 1000
		lag = Bots.ou(r, lag, prof.ptLagMu, prof.ptLagSigma, prof.ptLagTauS, dts)
		cross = Bots.ou(r, cross, 0, prof.ptCross * sScale, prof.ptCrossTauS, dts)
		local sStar = PT.pacerArc(pat, t - lagMs) -- the player sees the pacer lagMs late
		local sT = math.clamp(sStar + lag, 0, pat.L)
		if t - lagMs < pat.leadInMs then
			sT = 0
		end
		local pu, pv = PT.pointAt(pat, sT)
		local nu, nv = normalAt(pat, sT)
		local du, dv = pu + cross * nu, pv + cross * nv
		local a = dt / prof.ptTauMs
		cu += (du - cu) * a
		cv += (dv - cv) * a
		if prof.ptLiftRate > 0 and t > liftUntil and r:nextFloat() < prof.ptLiftRate * dts then
			liftUntil = t + r:range(150, 400)
		end
		while fi <= #frames and frames[fi] <= t do
			local f = frames[fi]
			local fm = math.floor(f)
			if fm >= nextDue and fm <= pat.durationMs then
				local grind = f >= pressAt and f > liftUntil
				local mu = cu + prof.ptTremor * Bots.gauss(r)
				local mv = cv + prof.ptTremor * Bots.gauss(r)
				mu = math.floor(mu * px + 0.5) / px
				mv = math.floor(mv * px + 0.5) / px
				local smp = { t = fm, u = math.clamp(q16(mu), 0, q16(PT.PANEL_W)), v = math.clamp(q16(mv), 0, PT.Q), grind = grind }
				if #samples == 0 or samples[#samples].t < fm then
					table.insert(samples, smp)
				end
				while nextDue <= fm do
					nextDue += PT.EVAL_MS
				end
			end
			fi += 1
		end
		t += dt
	end
	return samples
end

-- fabricated: exactly on the pacer every `every` ms, optional white noise
function Bots.ptPerfect(pat: PT.Pattern, noise: number, every: number, seed: number): { PT.Sample }
	local r = Bots.rng(seed, "bot-pt-cheat")
	local out = {}
	local t = 0
	while t <= pat.durationMs do
		local u, v = PT.pointAt(pat, PT.pacerArc(pat, t))
		if noise > 0 then
			u += noise * Bots.gauss(r)
			v += noise * Bots.gauss(r)
		end
		table.insert(out, { t = t, u = math.clamp(q16(u), 0, 3 * PT.Q), v = math.clamp(q16(v), 0, PT.Q), grind = true })
		t += every
	end
	return out
end

---------------------------------------------------------------------------- stats
export type Stats = { mean: number, p10: number, p50: number, p90: number, pass: number, flag: number, n: number }
function Bots.stats(scores: { number }, passes: { boolean }, flags: { boolean }?): Stats
	local s = table.clone(scores)
	table.sort(s)
	local n = #s
	local sum, pc, fc = 0, 0, 0
	for i = 1, n do
		sum += scores[i]
		if passes[i] then
			pc += 1
		end
		if flags and flags[i] then
			fc += 1
		end
	end
	local function q(p: number): number
		return s[math.clamp(math.floor(p * (n - 1) + 0.5) + 1, 1, n)]
	end
	return { mean = sum / n, p10 = q(0.10), p50 = q(0.5), p90 = q(0.90), pass = pc / n, flag = fc / n, n = n }
end

return Bots
