--!strict
-- Minigames/Bots (SPEC §6.12, §6.13, §16.23, E-S3.2; owner S3): the player models. Not authoritative (§6.4: "all of
-- Minigames/ except Bots"): the tests, S3's tuning, S4's distributions and Studio's autoplay use them; the judge never
-- does. Pure and seeded (no clock); the human models use libm (Box–Muller, the OU process) on lines tagged
-- allow-transcendental (§14.4), so their records can differ between C runtimes where the judge's cannot (M4's D14).
-- Every record goes through Input's Recorder, the only producer of records (§6.2), so a bot's timeline is one an
-- unmodified client could send, and it passes the judge's caps (L6).
--
--   PROFILES                   §6.12's Elite, Good, Average, Poor, field for field the S3 prototype's (with the hold
--                              policy's hzBand, hzMinGapMs, hzMinHoldMs and the panel's panelPx, which §6.12 omits)
--   variant(profile, fps, panelPx?)   the same player on another device: "Average@30", "Elite@30/360"
--   play(spec, pattern, who, seed, opts?)   one run's records: who is a profile (the human model), "Perfect", "Exact"
--                              or "Idle" (no input); opts.offsetMs is the Recorder's timingOffsetMs (TimingStrike's),
--                              opts.policy HoldZone's "pump" (the default) or "hold", opts.fps the TimingStrike Perfect's
--                              frame rate (60), opts.noise and opts.everyMs the trace Perfect's white noise (0) and
--                              cadence (PT_EVAL_MS)
--   run(cell)                  cell.n runs of one cell, the prototype's Sim.run: pattern seeds seedOf(i, salt), bot seeds
--                              i·7919 + salt·31 + 17 (salt 1 by default), every factor at x (BOT_REF_X[tier] by default),
--                              through Minigames.prepare and Minigames.replay; the trace on cell.edge (none: the fallback
--                              plays). Returns the raw scores (the prototype's: it never clamps), passed (⇔ rawScore ≥ the
--                              pass line, T-MG-14) and flagged; cell.each sees every run
--   autoplaySource(records)    for MinigameHost.setInputSource (§12.5): a function of t (ms from GO) giving the records
--                              due by t that it has not handed out yet, in order
--   stats(scores, passes, flags?)   mean, p10, p50, p90, the pass and flag rates (E-S3.2's table)
--   seedOf(i, salt)            (i·2654435761 + salt·40503 + 12345) mod 2^32
--
-- Who plays how (§6.12; the prototype's policies, docs/spec/prototypes/S3/v2/Bots.luau, with its Rng tags and its draw
-- order, so the build reproduces its scores: Minigames/Reference's parity):
--   a profile    TimingStrike tsHuman ("bot-ts"): presses at target + lag + bias + σ·N(0, 1) with lapses and extra
--                presses, delivered at the next frame; HoldZone hzHuman ("bot-hz-<policy>"): a delayed, noisy view of
--                its own live session (advanced to the Recorder's horizon each frame), pumping taps or holding;
--                PrecisionTrace ptHuman ("bot-pt"): a 2 ms hand model chasing the pacer, sampled at the due frames
--   "Perfect"    TimingStrike: the exact targets at the next frame of an opts.fps device ("bot-ts-perfect");
--                HoldZone: strokes chosen each tick by a BOT_HZ_PERFECT_LOOKAHEAD_MS look-ahead on the exact state
--                (flagged HzInhumanRate); PrecisionTrace: on the pacer every opts.everyMs ("bot-pt-cheat")
--   "Exact"      E-S8.5's cheat: TimingStrike's presses at the exact targets, unquantized; the others as "Perfect"
-- Bots that act at an exact integer ms (every Perfect but TimingStrike's, every Exact) pass the Recorder
-- clockS = (t + 0.5)/1000 and frameDtS = 0, so it records t itself (M4's D7). Where the records differ from the
-- prototype's, no score or flag does: the trace's first record is at t = 0, the cursor at GO (§6.2, I7), where the
-- prototype's is at its first frame; the Recorder drops a record past durationMs, where the prototype's TimingStrike
-- keeps it at durationMs (a whiff) and its HoldZone drops one at durationMs too (no tick reads it).

local Versions = require("../Definitions/Versions")
local DT = require("../Definitions/Types")
local HoldZone = require("./HoldZone")
local Input = require("./Input")
local Minigames = require("./Minigames")
local Params = require("./Params")
local PrecisionTrace = require("./PrecisionTrace")
local Rng = require("./Rng")
local TimingStrike = require("./TimingStrike")
local Types = require("./Types")

type MinigameResult = Types.MinigameResult
type Recorder = Types.Recorder
type StepSpec = Types.StepSpec

export type Profile = {
	id: string,
	fps: number,
	hitchRate: number, -- per frame: a hitch of 30–120 ms
	extraLagMs: number, -- display and input latency beyond one frame: the player sees extraLagMs + 1000/fps late
	-- TimingStrike
	sigmaMs: number,
	biasMeanMs: number,
	biasSdMs: number,
	lapse: number,
	extraPress: number,
	-- HoldZone (both policies share the perception)
	hzDelayMs: number,
	hzNoise: number,
	hzKPred: number,
	hzKZone: number,
	hzBand: number, -- hold policy: the hysteresis band, × zoneWidth/2
	hzMinGapMs: number, -- hold policy
	hzMinHoldMs: number, -- hold policy
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
export type Policy = "pump" | "hold"
export type Who = Profile | "Perfect" | "Exact" | "Idle"
export type PlayOptions = { offsetMs: number?, policy: Policy?, fps: number?, noise: number?, everyMs: number? }
-- S2's edge as Sharpening takes it (PrepareInput.edge)
export type Edge = { chains: { Types.EdgeChain }, gripPoint: DT.Vec3, gripAxis: Types.Vec2 }
export type Cell = {
	family: DT.FamilyId,
	material: DT.MaterialId,
	tier: DT.TierId,
	x: number?, -- every factor's x; BOT_REF_X[tier] by default
	profile: string | Profile, -- a PROFILES name or a profile, "Perfect", "Exact" or "Idle"
	n: number,
	salt: number?, -- 1 by default (the prototype's distributions)
	edge: Edge?, -- Sharpening's edge (none: the fallback plays)
	fps: number?, -- the profile on this device; TimingStrike Perfect's frame rate
	panelPx: number?,
	policy: Policy?,
	offsetMs: number?,
	noise: number?,
	everyMs: number?,
	each: ((i: number, spec: StepSpec, pattern: any, records: { any }, result: MinigameResult) -> ())?,
}
export type Stats = { mean: number, p10: number, p50: number, p90: number, pass: number, flag: number, n: number }

local M32 = 4294967296 -- 2^32

local BOT_REF_X = table.freeze({ Normal = 0.10, Hard = 0.30 }) -- every factor's x: §6.13's reference design per tier
local BOT_EXTRA_LAG_MS = 8 -- ms: latency beyond one frame
local BOT_PANEL_PX = 520 -- px: S6's canvas height
local BOT_HZ_PERFECT_LOOKAHEAD_MS = 300 -- ms: the Perfect HoldZone controller's horizon
local BOT_RUNS_PER_CELL = 2000 -- runs: the distributions for S4

local EVAL_MS = PrecisionTrace.PT_EVAL_MS
local TICK_MS = HoldZone.HZ_TICK_MS

local function P(t: { [string]: any }): Profile
	return table.freeze(t) :: any
end

-- §6.12's table; the prototype's v2 Bots.PROFILES value for value
local PROFILES = table.freeze({
	Elite = P({ id = "Elite", fps = 60, hitchRate = 0.003, extraLagMs = BOT_EXTRA_LAG_MS, sigmaMs = 12, biasMeanMs = 3,
		biasSdMs = 5, lapse = 0.005, extraPress = 0.0,
		hzDelayMs = 160, hzNoise = 0.004, hzKPred = 0.30, hzKZone = 0.5, hzBand = 0.15, hzMinGapMs = 70, hzMinHoldMs = 60,
		hzLapseRate = 0, hzLapseMs = 0, pumpPeriodMs = 130, pumpJitterMs = 20, pumpHoldMs = 65, pumpHoldJitterMs = 8,
		ptTauMs = 70, ptCross = 0.006, ptCrossTauS = 0.30, ptTremor = 0.0012, ptLagMu = -0.02, ptLagSigma = 0.02,
		ptLagTauS = 1.0, ptLiftRate = 0, ptStartOff = 0.005, ptLatePressMs = 0, panelPx = BOT_PANEL_PX }),
	Good = P({ id = "Good", fps = 60, hitchRate = 0.003, extraLagMs = BOT_EXTRA_LAG_MS, sigmaMs = 25, biasMeanMs = 5,
		biasSdMs = 10, lapse = 0.02, extraPress = 0.02,
		hzDelayMs = 210, hzNoise = 0.008, hzKPred = 0.22, hzKZone = 0.3, hzBand = 0.25, hzMinGapMs = 90, hzMinHoldMs = 70,
		hzLapseRate = 0.01, hzLapseMs = 400, pumpPeriodMs = 140, pumpJitterMs = 25, pumpHoldMs = 70, pumpHoldJitterMs = 10,
		ptTauMs = 100, ptCross = 0.012, ptCrossTauS = 0.35, ptTremor = 0.0015, ptLagMu = -0.04, ptLagSigma = 0.04,
		ptLagTauS = 1.0, ptLiftRate = 0.003, ptStartOff = 0.01, ptLatePressMs = 150, panelPx = BOT_PANEL_PX }),
	Average = P({ id = "Average", fps = 60, hitchRate = 0.003, extraLagMs = BOT_EXTRA_LAG_MS, sigmaMs = 45,
		biasMeanMs = 10, biasSdMs = 15, lapse = 0.05, extraPress = 0.02,
		hzDelayMs = 300, hzNoise = 0.020, hzKPred = 0.08, hzKZone = 0.0, hzBand = 0.30, hzMinGapMs = 130, hzMinHoldMs = 90,
		hzLapseRate = 0.04, hzLapseMs = 700, pumpPeriodMs = 180, pumpJitterMs = 40, pumpHoldMs = 90, pumpHoldJitterMs = 10,
		ptTauMs = 160, ptCross = 0.025, ptCrossTauS = 0.40, ptTremor = 0.002, ptLagMu = -0.07, ptLagSigma = 0.08,
		ptLagTauS = 1.2, ptLiftRate = 0.015, ptStartOff = 0.03, ptLatePressMs = 350, panelPx = BOT_PANEL_PX }),
	Poor = P({ id = "Poor", fps = 30, hitchRate = 0.006, extraLagMs = BOT_EXTRA_LAG_MS, sigmaMs = 90, biasMeanMs = 25,
		biasSdMs = 20, lapse = 0.10, extraPress = 0.04,
		hzDelayMs = 380, hzNoise = 0.035, hzKPred = 0.0, hzKZone = 0.0, hzBand = 0.40, hzMinGapMs = 170, hzMinHoldMs = 120,
		hzLapseRate = 0.08, hzLapseMs = 900, pumpPeriodMs = 220, pumpJitterMs = 50, pumpHoldMs = 110, pumpHoldJitterMs = 15,
		ptTauMs = 200, ptCross = 0.038, ptCrossTauS = 0.45, ptTremor = 0.003, ptLagMu = -0.09, ptLagSigma = 0.11,
		ptLagTauS = 1.4, ptLiftRate = 0.025, ptStartOff = 0.05, ptLatePressMs = 500, panelPx = BOT_PANEL_PX }),
})

-- ── the player model's noise and frames (the prototype's, draw for draw) ──────────────────────────────────────────

-- a bot's stream: any integer seed, reduced to a u32 (Rng.new takes nothing else)
local function rngOf(seed: number, tag: string): Rng.Rng
	return Rng.new(seed % M32, tag)
end

-- N(0, 1) by Box–Muller: two draws
local function gauss(r: Rng.Rng): number
	local u1 = math.max(r:nextFloat(), 1e-12)
	local u2 = r:nextFloat()
	return math.sqrt(-2 * math.log(u1)) * math.cos(2 * math.pi * u2) -- allow-transcendental: player model noise (§6.12)
end

-- one step of an Ornstein–Uhlenbeck process toward mu: one gauss
local function ou(r: Rng.Rng, x: number, mu: number, sigma: number, tauS: number, dtS: number): number
	local a = math.exp(-dtS / tauS) -- allow-transcendental: player model noise (§6.12)
	return mu + (x - mu) * a + sigma * math.sqrt(1 - a * a) * gauss(r)
end

-- the device's frame times (ms from GO): fps ±1 ms with a random phase against GO, a 30–120 ms hitch with chance
-- hitchRate per frame, until past the step
local function framesOf(r: Rng.Rng, endMs: number, fps: number, hitchRate: number): { number }
	local f: { number } = {}
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

-- the first frame at or after t (the last frame when none is)
local function firstAtOrAfter(frames: { number }, t: number): number
	local lo, hi = 1, #frames
	if frames[hi] < t then
		return hi
	end
	while lo < hi do
		local mid = math.floor((lo + hi) / 2)
		if frames[mid] >= t then
			hi = mid
		else
			lo = mid + 1
		end
	end
	return lo
end

-- the player sees the game this late (ms)
local function renderLag(prof: Profile): number
	return prof.extraLagMs + 1000 / prof.fps
end

-- the button's state reaching the Recorder at frame k, with that frame's clock and delta
local function button(rec: Recorder, frames: { number }, k: number, down: boolean)
	local f = frames[k]
	local dt = if k > 1 then f - frames[k - 1] else f
	rec:button(down, f / 1000, dt / 1000)
end

-- a TimingStrike press at frame k: down and up in the frame (the up records nothing; the next press counts)
local function press(rec: Recorder, frames: { number }, k: number)
	button(rec, frames, k, true)
	button(rec, frames, k, false)
end

-- the records made since `pushed`, pushed into the bot's own live session; the new count
local function pushNew(S: any, rec: Recorder, pushed: number): number
	local new = rec:since(pushed)
	for _, r in ipairs(new) do
		HoldZone.push(S, r)
	end
	return pushed + #new
end

-- ── TimingStrike ────────────────────────────────────────────────────────────────────────────────────────────────

local function tsHuman(spec: StepSpec, pat: TimingStrike.Pattern, prof: Profile, seed: number, offsetMs: number): { any }
	local r = rngOf(seed, "bot-ts")
	local frames = framesOf(r, pat.durationMs, prof.fps, prof.hitchRate)
	local p = pat.p
	local lag = renderLag(prof)
	local bias = prof.biasMeanMs + prof.biasSdMs * gauss(r) -- per player (per run)
	local sigma = prof.sigmaMs * (1 + 0.2 * math.max(0, 1000 / p.beatMs - 1)) * (1 + p.tempoJitter)
	local phys: { number } = {}
	for _, c in ipairs(pat.cycles) do
		if r:nextFloat() < prof.lapse then
			if r:nextFloat() < 0.5 then
				table.insert(phys, c.target + r:range(-300, 300))
			end
		else
			local t = c.target + lag + bias + sigma * gauss(r)
			table.insert(phys, t)
			if r:nextFloat() < prof.extraPress then
				table.insert(phys, t + r:range(80, 150))
			end
		end
	end
	table.sort(phys)
	local rec = Input.new(spec, offsetMs, 0)
	rec:go(false)
	for _, t in ipairs(phys) do
		press(rec, frames, firstAtOrAfter(frames, math.max(t, 0)))
	end
	return rec:records()
end

-- exact intent, no latency, on an fps device: each target delivered at the next frame
local function tsPerfect(spec: StepSpec, pat: TimingStrike.Pattern, fps: number, seed: number, offsetMs: number): { any }
	local r = rngOf(seed, "bot-ts-perfect")
	local frames = framesOf(r, pat.durationMs, fps, 0)
	local rec = Input.new(spec, offsetMs, 0)
	rec:go(false)
	for _, c in ipairs(pat.cycles) do
		press(rec, frames, firstAtOrAfter(frames, c.target))
	end
	return rec:records()
end

-- E-S8.5's Exact: every target, unquantized (D7's clocks)
local function tsExact(spec: StepSpec, pat: TimingStrike.Pattern, offsetMs: number): { any }
	local rec = Input.new(spec, offsetMs, 0)
	rec:go(false)
	for _, c in ipairs(pat.cycles) do
		local clock = (c.target + 0.5) / 1000
		rec:button(true, clock, 0)
		rec:button(false, clock, 0)
	end
	return rec:records()
end

-- ── HoldZone ────────────────────────────────────────────────────────────────────────────────────────────────────

-- "hold": hold and release with hysteresis; "pump": a tap of pumpHoldMs every pumpPeriodMs while the predicted needle
-- is below the (anticipated) zone centre. Both read the bot's own live session through a delay and noise; a physical
-- action reaches the Recorder at the next frame.
local function hzHuman(spec: StepSpec, pat: HoldZone.Pattern, prof: Profile, seed: number, policy: Policy): { any }
	local S = HoldZone.newSession(pat)
	local hist = { T = {} :: { [number]: number }, C = {} :: { [number]: number } }
	S.hist = hist
	local r = rngOf(seed, "bot-hz-" .. policy)
	local frames = framesOf(r, pat.durationMs, prof.fps, prof.hitchRate)
	local delay = prof.hzDelayMs + renderLag(prof)
	local h = pat.p.zoneWidth / 2
	local rec = Input.new(spec, 0, 0)
	local pushed = 0
	local down = false -- the physical state
	local lastToggle, freezeUntil, lastFrame = -1e9, -1, 0
	local releaseAt, nextDecide = -1, 0
	local pending: { { t: number, down: boolean } } = {} -- physical actions not yet delivered
	for k, f in ipairs(frames) do
		if k == 1 then
			rec:go(false)
		end
		-- the physical actions made before this frame reach the game now
		while #pending > 0 and pending[1].t <= f do
			local a = table.remove(pending, 1) :: { t: number, down: boolean }
			button(rec, frames, k, a.down)
		end
		pushed = pushNew(S, rec, pushed)
		local dt = if k > 1 then f - frames[k - 1] else f
		HoldZone.advance(S, rec:horizonMs(f / 1000, dt / 1000))
		if f >= pat.durationMs then
			break
		end
		if prof.hzLapseRate > 0 and f > freezeUntil and r:nextFloat() < prof.hzLapseRate * (f - lastFrame) / 1000 then
			freezeUntil = f + prof.hzLapseMs
		end
		lastFrame = f
		-- the needle and the zone as the player sees them: delay ms late, the needle noisy; 100 ms velocities
		local function observe(): (number, number)
			local kObs = math.floor((f - delay) / TICK_MS)
			local Tobs, Cobs, vT, vC = 0, pat.keysC[1], 0, 0
			if kObs >= 10 and hist.T[kObs] then
				Tobs = hist.T[kObs] + prof.hzNoise * gauss(r)
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
	return rec:records()
end

-- Perfect (test-only ceiling, §6.12): the exact state, the exact future zone, no latency. At each tick, a stroke now
-- against none, each followed by BOT_HZ_PERFECT_LOOKAHEAD_MS without strokes (squared error to the zone, ties to no
-- stroke); a stroke is a press held for one tick. The zone centres come from one table per pattern, the same values
-- the prototype recomputes per look-ahead step.
local function hzPerfect(spec: StepSpec, pat: HoldZone.Pattern): { any }
	local S = HoldZone.newSession(pat)
	local p = pat.p
	local decay = TICK_MS / p.fireDecayMs
	local dts = TICK_MS / 1000
	local H = BOT_HZ_PERFECT_LOOKAHEAD_MS / TICK_MS
	local K = math.floor(pat.durationMs / TICK_MS)
	local centre = table.create(K + H)
	for m = 1, K + H do
		centre[m] = HoldZone.centerAt(pat, m * TICK_MS)
	end
	local rec = Input.new(spec, 0, 0)
	rec:go(false)
	local pushed = 0
	local down = false
	for k = 0, K - 1 do
		local t = k * TICK_MS
		HoldZone.advance(S, t) -- the state after the ticks before t
		local clock = (t + 0.5) / 1000
		if down then
			down = false
			rec:button(false, clock, 0)
		else
			local bestCost, bestStroke = math.huge, false
			for option = 0, 1 do
				local stroke = option == 1
				local T, F = S.T, S.F
				if stroke then
					local g = p.strokeGain * math.min(1, (t - S.pressT) / p.refillMs)
					F = F + g * (1 - F)
				end
				local cost = 0
				for j = 0, H - 1 do
					F = F - F * decay
					T = math.clamp(T + p.heatDecay * (p.fullHeat * F - T) * dts, 0, 1)
					local c = centre[k + j + 1]
					cost += (T - c) * (T - c)
				end
				if cost < bestCost then
					bestCost, bestStroke = cost, stroke
				end
			end
			if bestStroke then
				down = true
				rec:button(true, clock, 0)
			end
		end
		pushed = pushNew(S, rec, pushed)
	end
	return rec:records()
end

-- ── PrecisionTrace ──────────────────────────────────────────────────────────────────────────────────────────────

-- the path's left normal at arc s, from its points 0.01 u either side
local function normalAt(pat: PrecisionTrace.Pattern, s: number): (number, number)
	local u1, v1 = PrecisionTrace.pointAt(pat, math.max(0, s - 0.01))
	local u2, v2 = PrecisionTrace.pointAt(pat, math.min(pat.L, s + 0.01))
	local tu, tv = u2 - u1, v2 - v1
	local l = math.sqrt(tu * tu + tv * tv)
	if l == 0 then
		return 0, 0
	end
	return -tv / l, tu / l
end

-- A hand chasing the pacer every 2 ms (the player sees it renderLag late): an along-track lag and a cross-track offset
-- (OU), a first-order chase, lifts. At each frame where a sample is due (floor(f) at or past the next multiple of
-- PT_EVAL_MS after the last sample: the Recorder's rule), the tremor is drawn and the position, in whole panel pixels,
-- reaches the Recorder; at the first frame the same position goes to go (the cursor at GO) and to cursor, so the
-- stream draws exactly as the prototype's (M4's plan [3.11]).
local function ptHuman(spec: StepSpec, pat: PrecisionTrace.Pattern, prof: Profile, seed: number): { any }
	local r = rngOf(seed, "bot-pt")
	local frames = framesOf(r, pat.durationMs, prof.fps, prof.hitchRate)
	local lagMs = renderLag(prof)
	local su, sv = PrecisionTrace.pointAt(pat, 0)
	local cu, cv = su + prof.ptStartOff * gauss(r), sv + prof.ptStartOff * gauss(r)
	local lag, cross = prof.ptLagMu, 0
	local pressAt = if r:nextFloat() < 0.7 then 0 else prof.ptLatePressMs
	local liftUntil = -1
	local rec = Input.new(spec, 0, 0)
	local nextDue = 0
	local fi = 1
	local dt = 2
	local t = 0
	local sScale = math.sqrt(pat.speed / 0.3)
	local px = prof.panelPx
	while t <= pat.durationMs and fi <= #frames do
		local dts = dt / 1000
		lag = ou(r, lag, prof.ptLagMu, prof.ptLagSigma, prof.ptLagTauS, dts)
		cross = ou(r, cross, 0, prof.ptCross * sScale, prof.ptCrossTauS, dts)
		local sStar = PrecisionTrace.pacerArc(pat, t - lagMs)
		local sT = math.clamp(sStar + lag, 0, pat.L)
		if t - lagMs < pat.leadInMs then
			sT = 0
		end
		local pu, pv = PrecisionTrace.pointAt(pat, sT)
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
				local mu = cu + prof.ptTremor * gauss(r)
				local mv = cv + prof.ptTremor * gauss(r)
				mu = math.floor(mu * px + 0.5) / px
				mv = math.floor(mv * px + 0.5) / px
				if fi == 1 then
					rec:go(grind, mu, mv, grind)
				end
				rec:cursor(mu, mv, grind, f / 1000)
				while nextDue <= fm do
					nextDue += EVAL_MS
				end
			end
			fi += 1
		end
		t += dt
	end
	return rec:records()
end

-- on the pacer every everyMs from GO, grinding, with optional white noise (§6.12's Perfect; T-MG-10's cheats)
local function ptPerfect(spec: StepSpec, pat: PrecisionTrace.Pattern, noise: number, everyMs: number, seed: number): { any }
	local r = rngOf(seed, "bot-pt-cheat")
	local rec = Input.new(spec, 0, 0)
	local t = 0
	while t <= pat.durationMs do
		local u, v = PrecisionTrace.pointAt(pat, PrecisionTrace.pacerArc(pat, t))
		if noise > 0 then
			u += noise * gauss(r)
			v += noise * gauss(r)
		end
		if t == 0 then
			rec:go(true, u, v, true)
		else
			rec:cursor(u, v, true, (t + 0.5) / 1000)
		end
		t += everyMs
	end
	return rec:records()
end

-- ── the API ─────────────────────────────────────────────────────────────────────────────────────────────────────

local Bots = {
	PROFILES = PROFILES,
	BOT_REF_X = BOT_REF_X,
	BOT_EXTRA_LAG_MS = BOT_EXTRA_LAG_MS,
	BOT_PANEL_PX = BOT_PANEL_PX,
	BOT_HZ_PERFECT_LOOKAHEAD_MS = BOT_HZ_PERFECT_LOOKAHEAD_MS,
	BOT_RUNS_PER_CELL = BOT_RUNS_PER_CELL,
}

function Bots.seedOf(i: number, salt: number): number
	return (i * 2654435761 + salt * 40503 + 12345) % M32
end

function Bots.variant(base: Profile, fps: number, panelPx: number?): Profile
	local c = table.clone(base) :: any
	c.fps = fps
	c.id = base.id .. "@" .. fps
	if panelPx then
		c.panelPx = panelPx
		c.id ..= "/" .. panelPx
	end
	return table.freeze(c) :: Profile
end

function Bots.play(spec: StepSpec, pattern: any, who: Who, seed: number, opts: PlayOptions?): { any }
	local o: PlayOptions = opts or {}
	local family: DT.FamilyId = spec.family
	local offsetMs = o.offsetMs or 0
	if who == "Idle" then
		return Input.new(spec, offsetMs, 0):records() -- no input: not even GO's cursor
	elseif family == "TimingStrike" then
		if who == "Exact" then
			return tsExact(spec, pattern, offsetMs)
		elseif who == "Perfect" then
			return tsPerfect(spec, pattern, o.fps or 60, seed, offsetMs)
		end
		return tsHuman(spec, pattern, who :: Profile, seed, offsetMs)
	elseif family == "HoldZone" then
		if who == "Exact" or who == "Perfect" then
			return hzPerfect(spec, pattern)
		end
		return hzHuman(spec, pattern, who :: Profile, seed, o.policy or "pump")
	elseif family == "PrecisionTrace" then
		if who == "Exact" then
			return ptPerfect(spec, pattern, 0, EVAL_MS, seed)
		elseif who == "Perfect" then
			return ptPerfect(spec, pattern, o.noise or 0, o.everyMs or EVAL_MS, seed)
		end
		return ptHuman(spec, pattern, who :: Profile, seed)
	end
	error("Bots.play: no player model for " .. tostring(family), 2)
end

-- a cell's player: a name of PROFILES (on cell.fps and cell.panelPx's device when given), a profile, or an extreme
local function whoOf(cell: Cell): Who
	local name = cell.profile
	if name == "Perfect" or name == "Exact" or name == "Idle" then
		return name :: any
	end
	local prof: Profile
	if type(name) == "string" then
		local found = (PROFILES :: any)[name]
		if found == nil then
			error("Bots.run: no profile " .. name, 3)
		end
		prof = found
	else
		prof = name
	end
	if cell.fps or cell.panelPx then
		prof = Bots.variant(prof, cell.fps or prof.fps, cell.panelPx)
	end
	return prof
end

function Bots.run(cell: Cell): ({ number }, { boolean }, { boolean })
	local x = cell.x or (BOT_REF_X :: any)[cell.tier]
	local factors = Params.refFactors(x)
	local who: Who = whoOf(cell)
	local salt = cell.salt or 1
	local opts: PlayOptions = { offsetMs = cell.offsetMs, policy = cell.policy, fps = cell.fps, noise = cell.noise,
		everyMs = cell.everyMs }
	local each = cell.each
	local scores: { number }, passes: { boolean }, flagged: { boolean } = {}, {}, {}
	for i = 1, cell.n do
		local spec, pattern = Minigames.prepare({
			family = cell.family,
			seed = Bots.seedOf(i, salt),
			material = cell.material,
			tier = cell.tier,
			factors = factors,
			edge = cell.edge,
			balanceVersion = Versions.BALANCE_VERSION,
		})
		local records = Bots.play(spec, pattern, who, i * 7919 + salt * 31 + 17, opts)
		local result = Minigames.replay(spec, pattern, records)
		scores[i] = result.rawScore
		passes[i] = result.passed
		flagged[i] = #result.flags > 0
		if each then
			each(i, spec, pattern, records, result)
		end
	end
	return scores, passes, flagged
end

function Bots.autoplaySource(records: { any }): (t: number) -> { any }
	local NONE: { any } = table.freeze({})
	local i = 1
	return function(t: number): { any }
		local due: { any }? = nil
		while i <= #records do
			local r = records[i]
			if (if type(r) == "number" then r else r.t) > t then
				break
			end
			due = due or {}
			table.insert(due :: { any }, r)
			i += 1
		end
		return due or NONE
	end
end

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

return table.freeze(Bots)
