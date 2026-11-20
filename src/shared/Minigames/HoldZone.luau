--!strict
-- Minigames/HoldZone (SPEC §6.8, §6.14, §10.6, §16.20, E-S3.7; owner S3): Smelting. Each press of Space or LMB is one
-- bellows stroke; the fire F dies down between strokes, the temperature T relaxes toward fullHeat·F, and the player
-- keeps T inside a zone that drifts on a seeded path; the first rampMs are unscored. The records are the OR-state's
-- changes {t, down} from GO; ups travel in the timeline but no score reads them (holding adds nothing). A fixed-step
-- simulation. Pure.
--
--   generate(seed, p)   rng = Rng.new(seed, "HoldZone.Target"); lo, hi = targetMin, targetMax; c0 = lo + (hi − lo)·
--                       rng:range(0.3, 0.7); keys (0, c0), (rampMs, c0); until t ≥ durationMs: seg = rng:int(segMinMs,
--                       segMaxMs); unless rng:chance(holdChance): mag = driftSpeed·seg/1000·rng:range(0.5, 1),
--                       s = rng:sign(), nc = c + s·mag, reflected to c − s·mag outside [lo, hi], then clamped;
--                       t += seg; key (t, nc).  hash: FNV-1a over (t_j, round(c_j·10^6))
--   centerAt(P, t)      smoothstep from key j to j + 1, j the largest index ≤ #keys − 1 with t_j ≤ t
--   advance(S, now)     integrates the ticks k (t = HZ_TICK_MS·k) with k < floor(durationMs/HZ_TICK_MS) and t < now:
--                       every pushed down with e.t ≤ t is a stroke, F = F + g·(1 − F) with g = strokeGain·min(1,
--                       (e.t − last stroke)/refillMs); then F = F − F·decay (decay = 10/fireDecayMs, once), T =
--                       clamp(T + heatDecay·(fullHeat·F − T)·0.010, 0, 1); a tick with t + 10 > rampMs scores
--                       d = |T − center(t + 10)|: 1 when d ≤ h = zoneWidth/2 (in the zone), else max(0, 1 − (d − h)/
--                       (softFrac·zoneWidth))
--   finish              score = q(credit / scored ticks), 0 with none; breakdown inZone (the scored ticks' share in the
--                       zone) and strokes (§6.14)
--   checks              HzInhumanRate when HZ_RATE_MAX_PRESSES downs fall in one HZ_RATE_WINDOW_MS window (§10.6)
--
-- Every expression is the S3 prototype's in its order (docs/spec/prototypes/S3/v2/HoldZone.luau), which made E-S3's
-- hashes, goldens and distributions (M4's D1): note F − F·(10/fireDecayMs), not §6.8's F·10/fireDecayMs, which rounds
-- differently. Live = replay (§6.4 rule 7): advance integrates only ticks before `now`, and the host advances to the
-- Recorder's horizon, which no later record precedes, so a live tick consumes exactly the downs the replay's does.
-- The session keeps the prototype's forward key pointer; centerAt is the same lookup from the first key (the view's).
-- Live score: the mean credit of the scored ticks so far **[Decision to confirm]** (§17.1 O14); display only.

local DT = require("../Definitions/Types")
local Quantize = require("../Util/Quantize")
local Checks = require("./Checks")
local Rng = require("./Rng")
local Types = require("./Types")

type FeedbackEvent = Types.FeedbackEvent
type FlagId = Types.FlagId
type HoldRecord = Types.HoldRecord
type HoldZoneView = Types.HoldZoneView
type MinigameResult = Types.MinigameResult

export type Pattern = {
	p: { [string]: number },
	keysT: { number }, -- ms from GO, non-decreasing: (0, c0), (rampMs, c0), then one per segment
	keysC: { number }, -- zone centres (gauge units)
	durationMs: number,
	rampMs: number,
	hash: number,
}
export type Session = {
	pat: Pattern,
	events: { HoldRecord }, -- the pushed records
	ei: number, -- the next record a tick consumes
	k: number, -- the next tick
	T: number, -- temperature after the last tick
	F: number, -- fire after the last tick
	pressT: number, -- the last stroke's time
	credit: number,
	n: number, -- scored ticks
	inZone: number, -- scored ticks in the zone
	strokes: number,
	seg: number, -- the key pointer
	-- per tick k: T and the zone centre at the tick's end; filled only when set (the bots' perception, tests)
	hist: { T: { [number]: number }, C: { [number]: number } }?,
	-- presentation (feedback); no score reads them
	lastDownT: number,
	went: boolean,
	scored: boolean,
	wasIn: boolean,
}

local FAMILY: DT.FamilyId = "HoldZone"
local HZ_TICK_MS = 10 -- ms: integer tick boundaries (§16.20)

local RAMP: "Ramp" = "Ramp"
local HOLD: "Hold" = "Hold"
local DONE: "Done" = "Done"
local HZ_INHUMAN_RATE: FlagId = "HzInhumanRate"

-- push and advance hand this out when nothing fires (no table per call, M4's D13)
local NONE: { FeedbackEvent } = table.freeze({})

local function q(x: number): number
	return Quantize.q(x, Quantize.SCALAR_SCALE)
end

local function add(events: { FeedbackEvent }?, e: FeedbackEvent): { FeedbackEvent }
	local out = events or {}
	table.insert(out, e)
	return out
end

-- the key segment of t, from key `from` on: the largest j ≤ #keys − 1 with keysT[j] ≤ t (the prototype's pointer)
local function segmentOf(P: Pattern, from: number, t: number): number
	local kt = P.keysT
	local j = from
	while j < #kt - 1 and kt[j + 1] <= t do
		j += 1
	end
	return j
end

-- the zone centre at t on segment j: smoothstep from key j to key j + 1
local function centerFrom(P: Pattern, j: number, t: number): number
	local kt, kc = P.keysT, P.keysC
	local t0: number, t1: number? = kt[j], kt[j + 1]
	local c0, c1 = kc[j], kc[j + 1]
	if t1 == nil or t1 <= t0 then
		return c0
	end
	local s = (t - t0) / (t1 - t0)
	if s > 1 then
		s = 1
	end
	local e = s * s * (3 - 2 * s)
	return c0 + (c1 - c0) * e
end

local HoldZone = {
	id = FAMILY,
	HZ_TICK_MS = HZ_TICK_MS,
}

function HoldZone.generate(seed: number, p: { [string]: number }, _source: { number }?): Pattern
	local rng = Rng.new(seed, Rng.TAGS.HoldZoneTarget)
	local lo, hi = p.targetMin, p.targetMax
	local c0 = lo + (hi - lo) * rng:range(0.3, 0.7)
	local keysT, keysC = { 0, p.rampMs }, { c0, c0 }
	local t, c = p.rampMs, c0
	while t < p.durationMs do
		local seg = rng:int(p.segMinMs, p.segMaxMs)
		local nc = c
		if not rng:chance(p.holdChance) then
			local mag = p.driftSpeed * seg / 1000 * rng:range(0.5, 1.0)
			local sgn = rng:sign()
			nc = c + sgn * mag
			if nc > hi or nc < lo then
				nc = c - sgn * mag
			end
			nc = math.clamp(nc, lo, hi)
		end
		t += seg
		c = nc
		table.insert(keysT, t)
		table.insert(keysC, c)
	end
	local h = Rng.FNV_BASIS
	for i = 1, #keysT do
		h = Rng.hashU32(h, keysT[i])
		h = Rng.hashU32(h, math.round(keysC[i] * 1000000))
	end
	return table.freeze({
		p = p,
		keysT = table.freeze(keysT),
		keysC = table.freeze(keysC),
		durationMs = p.durationMs,
		rampMs = p.rampMs,
		hash = h,
	})
end

function HoldZone.hash(P: Pattern): number
	return P.hash
end

-- stateless: the view's lookup, and the bots' (the session keeps its own pointer; a test pins them equal per tick)
function HoldZone.centerAt(P: Pattern, t: number): number
	return centerFrom(P, segmentOf(P, 1, t), t)
end

function HoldZone.newSession(P: Pattern): Session
	return {
		pat = P,
		events = {},
		ei = 1,
		k = 0,
		T = 0,
		F = 0,
		pressT = -P.p.refillMs,
		credit = 0,
		n = 0,
		inZone = 0,
		strokes = 0,
		seg = 1,
		hist = nil,
		lastDownT = -P.p.refillMs,
		went = false,
		scored = false,
		wasIn = false,
	}
end

-- a record; a down is a Stroke whose value is its gain g, from the pushed times (the tick consumes it later)
function HoldZone.push(S: Session, e: HoldRecord): { FeedbackEvent }
	table.insert(S.events, e)
	if not e.down then
		return NONE
	end
	local p = S.pat.p
	local g = p.strokeGain * math.min(1, (e.t - S.lastDownT) / p.refillMs)
	S.lastDownT = e.t
	return { { kind = "Stroke", t = e.t, value = g } }
end

-- Go on the first call; per integrated tick, at its end time: RampEnd at the first scored one, EnterZone / LeaveZone
-- when a scored tick's zone state changes (out before the first), End at the last tick
function HoldZone.advance(S: Session, nowMs: number): { FeedbackEvent }
	local pat = S.pat
	local p = pat.p
	local K = math.floor(pat.durationMs / HZ_TICK_MS)
	local decay = HZ_TICK_MS / p.fireDecayMs
	local dts = HZ_TICK_MS / 1000
	local h = p.zoneWidth / 2
	local soft = p.softFrac * p.zoneWidth
	local evs = S.events
	local out: { FeedbackEvent }? = nil
	if not S.went then
		S.went = true
		out = add(out, { kind = "Go", t = 0 })
	end
	while S.k < K and S.k * HZ_TICK_MS < nowMs do
		local t = S.k * HZ_TICK_MS
		while S.ei <= #evs and evs[S.ei].t <= t do
			local e = evs[S.ei]
			if e.down then
				local g = p.strokeGain * math.min(1, (e.t - S.pressT) / p.refillMs)
				S.F = S.F + g * (1 - S.F)
				S.pressT = e.t
				S.strokes += 1
			end
			S.ei += 1
		end
		S.F = S.F - S.F * decay
		local T = S.T + p.heatDecay * (p.fullHeat * S.F - S.T) * dts
		if T < 0 then
			T = 0
		elseif T > 1 then
			T = 1
		end
		S.T = T
		local tEnd = t + HZ_TICK_MS
		local hist = S.hist
		if tEnd > pat.rampMs or hist then
			S.seg = segmentOf(pat, S.seg, tEnd)
			local c = centerFrom(pat, S.seg, tEnd)
			if hist then
				hist.T[S.k] = T
				hist.C[S.k] = c
			end
			if tEnd > pat.rampMs then
				local d = math.abs(T - c)
				local inside = d <= h
				local cr
				if inside then
					cr = 1
					S.inZone += 1
				else
					cr = 1 - (d - h) / soft
					if cr < 0 then
						cr = 0
					end
				end
				S.credit += cr
				S.n += 1
				if not S.scored then
					S.scored = true
					out = add(out, { kind = "RampEnd", t = tEnd })
				end
				if inside ~= S.wasIn then
					S.wasIn = inside
					out = add(out, { kind = if inside then "EnterZone" else "LeaveZone", t = tEnd })
				end
			end
		end
		S.k += 1
		if S.k == K then
			out = add(out, { kind = "End", t = tEnd })
		end
	end
	return out or NONE
end

function HoldZone.finish(S: Session): MinigameResult
	HoldZone.advance(S, S.pat.durationMs + 1)
	local score = if S.n > 0 then q(S.credit / S.n) else 0
	return {
		status = "Ok",
		score = score,
		rawScore = score,
		passed = score >= S.pat.p.passThreshold,
		flags = {},
		invalidReason = nil,
		breakdown = { inZone = if S.n > 0 then S.inZone / S.n else 0, strokes = S.strokes },
		elapsedMs = 0,
	}
end

function HoldZone.checks(_P: Pattern, records: { HoldRecord }, _result: MinigameResult): { FlagId }
	local downs: { number } = {}
	for _, e in ipairs(records) do
		if e.down then
			table.insert(downs, e.t)
		end
	end
	local flags: { FlagId } = {}
	local most = Checks.maxInWindow(downs, Checks.value(FAMILY, "HZ_RATE_WINDOW_MS"))
	if most >= Checks.value(FAMILY, "HZ_RATE_MAX_PRESSES") then
		table.insert(flags, HZ_INHUMAN_RATE)
	end
	return flags
end

-- The gauge at nowMs (the raw clock): T and F after the last integrated tick, the zone at nowMs
function HoldZone.view(S: Session, nowMs: number): HoldZoneView
	local pat = S.pat
	local p = pat.p
	local center = HoldZone.centerAt(pat, nowMs)
	local half = p.zoneWidth / 2
	return {
		t = nowMs,
		phase = if nowMs < pat.rampMs then RAMP elseif nowMs < pat.durationMs then HOLD else DONE,
		temperature = S.T,
		fire = S.F,
		zoneCenter = center,
		zoneHalf = half,
		softBand = p.softFrac * p.zoneWidth,
		inZone = math.abs(S.T - center) <= half,
		runningScore = if S.n > 0 then q(S.credit / S.n) else 0,
		timeLeftMs = math.max(0, pat.durationMs - nowMs),
	}
end

return table.freeze(HoldZone)
