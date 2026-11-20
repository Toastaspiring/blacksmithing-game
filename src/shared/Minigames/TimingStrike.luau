--!strict
-- Minigames/TimingStrike (SPEC §6.9, §6.14, §10.6, §16.21, E-S3.4; owner S3): Hammering. A marker sweeps the dial
-- once per cycle of P_i ms and the player strikes as it crosses the cycle's window; the record is the press time t
-- (ms from GO, the timing offset already applied by Input). Closed-form scoring. Pure.
--
--   generate(seed, p)   rT, rO = Rng.new(seed, "TimingStrike.Tempo"), Rng.new(seed, "TimingStrike.Offsets"); S = 0
--                       per cycle i = 1…strikes: P_i = round(beatMs·(1 + tempoJitter·(2·rT:nextFloat() − 1)))
--                       T_i = S + round((offsetMin + (offsetMax − offsetMin)·rO:nextFloat())·P_i);  S += P_i
--                       M = min(windowMs + missPadMs, floor((minGap − 1)/2), T_1), W = min(windowMs, M)
--                       core = min(W, max(perfectFrac·W, TS_PERFECT_CORE_MIN_MS)), durationMs = S + tailMs
--                       hash: FNV-1a over (start_i, period_i, target_i)
--   points(P, e)        a miss (nil) or |e| > W → 0; |e| ≤ core → 1; else 1 − (1 − edgePoints)·(|e| − core)/(W − core)
--   push(S, t)          closes the spans with T_i + M < t (each unjudged one a Miss), then judges the current span
--                       when T_i − M ≤ t ≤ T_i + M and it is undecided (the first press decides: err_i = t − T_i);
--                       any other press is a whiff, which changes nothing
--   advance(S, now)     closes the spans with T_i + M < now;  finish closes every span
--   finish              score = q(Σ points / N), the sum in cycle order; breakdown judged (spans with a press within
--                       ±M), perfect / good / ok (judged presses by grade; a 0-point press counts in judged only),
--                       miss, whiffs, bestCombo, meanAbsErrMs and meanErrMs over the judged errors in cycle order (§6.14)
--   checks              with n ≥ TS_MIN_JUDGED judged errors: TsExactHits when ≥ ceil(TS_EXACT_FRAC·n) have |e| ≤
--                       TS_EXACT_MS; TsLowVariance when their sample SD < TS_MIN_SD_MS (§10.6, Definitions' rows)
--
-- Every expression is the S3 prototype's in its order (docs/spec/prototypes/S3/v2/TimingStrike.luau), which made
-- E-S3's hashes, goldens and distributions (M4's D1). Live = replay (§6.4 rule 7): a span closes only once now >
-- T_i + M, and the host advances the live session to the Recorder's horizon, so it decides every span as the replay
-- does. The view follows the raw clock in sweep units (fractions of the current cycle), so the host plays the beat cue
-- CycleStart at GO (view.cycle is 1 from the countdown on) and whenever view.cycle changes; decisions (Miss, Strike,
-- lastGrade, combo, the live score) follow the Recorder's horizon, which trails the view's clock by half a frame and
-- the timing offset (and runs ahead of it for a negative offset of more than half a frame), as the replay's do (M4's
-- D12).
-- Combo, feedback only: +1 for each span decided with points above 0; a span decided with 0 points (a miss, or a
-- press past W) resets it; whiffs leave it alone **[Decision to confirm]** (§17.1 O13). Live score: the mean points of
-- the spans decided so far **[Decision to confirm]** (§17.1 O14). Neither is stored nor moves the score.

local DT = require("../Definitions/Types")
local Quantize = require("../Util/Quantize")
local Checks = require("./Checks")
local Rng = require("./Rng")
local Types = require("./Types")

type FeedbackEvent = Types.FeedbackEvent
type FlagId = Types.FlagId
type Grade = Types.Grade
type MinigameResult = Types.MinigameResult
type TimingStrikeView = Types.TimingStrikeView

export type Cycle = { start: number, period: number, target: number }
export type Pattern = {
	p: { [string]: number },
	cycles: { Cycle },
	M: number, -- half-span (ms): presses within ±M of the target are judged
	W: number, -- half-window (ms): presses within ±W score
	core: number, -- full-points core (ms)
	durationMs: number,
	hash: number,
}
export type Session = {
	pat: Pattern,
	i: number, -- the first span not yet closed
	err: { number | false }, -- per decided span: its judged error, or false for a miss
	judged: { boolean }, -- per span: decided
	whiffs: number,
	-- presentation (views and feedback); finish reads only bestCombo
	decided: number,
	pointsSum: number,
	combo: number,
	bestCombo: number,
	lastGrade: Grade?,
	lastErrorMs: number?,
	ended: boolean,
}

local FAMILY: DT.FamilyId = "TimingStrike"
local TS_PERFECT_CORE_MIN_MS = 10 -- ms: the full-points core's floor (≥ 9 ms at every MVP tier; §16.21)
local TS_GRADE_PERFECT = 0.9 -- points
local TS_GRADE_GOOD = 0.6 -- points
local TS_OFFSET_OFFER_MIN_JUDGED = 8 -- judged strikes before the results card offers an offset (§6.9)

-- typed, so luau-lsp keeps the literal types (M1's lesson)
local PERFECT: Grade = "Perfect"
local GOOD: Grade = "Good"
local OK: Grade = "Ok"
local MISS: Grade = "Miss"
local TS_EXACT_HITS: FlagId = "TsExactHits"
local TS_LOW_VARIANCE: FlagId = "TsLowVariance"

-- push and advance hand this out when nothing fires (no table per call, M4's D13)
local NONE: { FeedbackEvent } = table.freeze({})

local function q(x: number): number
	return Quantize.q(x, Quantize.SCALAR_SCALE)
end

local TimingStrike = {
	id = FAMILY,
	TS_PERFECT_CORE_MIN_MS = TS_PERFECT_CORE_MIN_MS,
	TS_GRADE_PERFECT = TS_GRADE_PERFECT,
	TS_GRADE_GOOD = TS_GRADE_GOOD,
	TS_OFFSET_OFFER_MIN_JUDGED = TS_OFFSET_OFFER_MIN_JUDGED,
}

function TimingStrike.generate(seed: number, p: { [string]: number }, _source: { number }?): Pattern
	local rT = Rng.new(seed, Rng.TAGS.TimingStrikeTempo)
	local rO = Rng.new(seed, Rng.TAGS.TimingStrikeOffsets)
	local cycles: { Cycle } = {}
	local S = 0
	for i = 1, p.strikes do
		local P = math.round(p.beatMs * (1 + p.tempoJitter * (2 * rT:nextFloat() - 1)))
		local f = p.offsetMin + (p.offsetMax - p.offsetMin) * rO:nextFloat()
		local T = S + math.round(f * P)
		cycles[i] = table.freeze({ start = S, period = P, target = T })
		S += P
	end
	local minGap = math.huge
	for i = 1, #cycles - 1 do
		minGap = math.min(minGap, cycles[i + 1].target - cycles[i].target)
	end
	local M = p.windowMs + p.missPadMs
	if minGap < math.huge then
		M = math.min(M, math.floor((minGap - 1) / 2))
	end
	M = math.min(M, cycles[1].target)
	local W = math.min(p.windowMs, M)
	local core = math.min(W, math.max(p.perfectFrac * W, TS_PERFECT_CORE_MIN_MS))
	local h = Rng.FNV_BASIS
	for _, c in ipairs(cycles) do
		h = Rng.hashU32(h, c.start)
		h = Rng.hashU32(h, c.period)
		h = Rng.hashU32(h, c.target)
	end
	return table.freeze({
		p = p,
		cycles = table.freeze(cycles),
		M = M,
		W = W,
		core = core,
		durationMs = S + p.tailMs,
		hash = h,
	})
end

function TimingStrike.hash(P: Pattern): number
	return P.hash
end

function TimingStrike.points(P: Pattern, e: number?): number
	if e == nil then
		return 0
	end
	local a = math.abs(e)
	local W, core = P.W, P.core
	if a > W then
		return 0
	elseif a <= core then
		return 1
	end
	return 1 - (1 - P.p.edgePoints) * (a - core) / (W - core)
end

function TimingStrike.grade(points: number): Grade
	if points >= TS_GRADE_PERFECT then
		return PERFECT
	elseif points >= TS_GRADE_GOOD then
		return GOOD
	elseif points > 0 then
		return OK
	end
	return MISS
end

-- the |e| (ms) at which a press earns `pts` points: a grade band's edge (E-S3.4)
function TimingStrike.bandMs(P: Pattern, pts: number): number
	return P.core + (1 - pts) / (1 - P.p.edgePoints) * (P.W - P.core)
end

function TimingStrike.newSession(P: Pattern): Session
	return {
		pat = P,
		i = 1,
		err = {},
		judged = {},
		whiffs = 0,
		decided = 0,
		pointsSum = 0,
		combo = 0,
		bestCombo = 0,
		lastGrade = nil,
		lastErrorMs = nil,
		ended = false,
	}
end

-- a span decided with `pts` points and judged error e (nil: a miss): the combo, the live score, the last grade
local function decide(S: Session, pts: number, e: number?)
	S.decided += 1
	S.pointsSum += pts
	if pts > 0 then
		S.combo += 1
		if S.combo > S.bestCombo then
			S.bestCombo = S.combo
		end
	else
		S.combo = 0
	end
	S.lastGrade = TimingStrike.grade(pts)
	S.lastErrorMs = e
end

local function add(events: { FeedbackEvent }?, e: FeedbackEvent): { FeedbackEvent }
	local out = events or {}
	table.insert(out, e)
	return out
end

-- closes the spans with T_i + M < t: an undecided one is a miss. Its events, or nil when none fire.
local function closeBefore(S: Session, t: number): { FeedbackEvent }?
	local pat = S.pat
	local cyc = pat.cycles
	local events: { FeedbackEvent }? = nil
	while S.i <= #cyc and cyc[S.i].target + pat.M < t do
		local i = S.i
		if not S.judged[i] then
			S.err[i] = false
			S.judged[i] = true
			decide(S, 0, nil)
			events = add(events, { kind = "Miss", t = cyc[i].target + pat.M, i = i })
		end
		S.i += 1
	end
	if S.i > #cyc and not S.ended then
		S.ended = true
		events = add(events, { kind = "End", t = cyc[#cyc].target + pat.M })
	end
	return events
end

-- one press: the Misses it closes, then Strike (i, label = grade, value = error ms) or Whiff
function TimingStrike.push(S: Session, t: number): { FeedbackEvent }
	local events = closeBefore(S, t)
	local pat = S.pat
	local c = pat.cycles[S.i]
	if c and t >= c.target - pat.M and t <= c.target + pat.M and not S.judged[S.i] then
		local e = t - c.target
		S.err[S.i] = e
		S.judged[S.i] = true
		local pts = TimingStrike.points(pat, e)
		decide(S, pts, e)
		return add(events, { kind = "Strike", t = t, i = S.i, value = e, label = TimingStrike.grade(pts) })
	end
	S.whiffs += 1
	return add(events, { kind = "Whiff", t = t })
end

-- Miss per span closed undecided, End once every span is closed (CycleStart comes from view.cycle, D12)
function TimingStrike.advance(S: Session, nowMs: number): { FeedbackEvent }
	return closeBefore(S, nowMs) or NONE
end

-- the judged errors of the decided spans, in cycle order
local function judgedErrors(S: Session): { number }
	local errs: { number } = {}
	for i = 1, #S.pat.cycles do
		local e = S.err[i]
		if type(e) == "number" then
			table.insert(errs, e)
		end
	end
	return errs
end

-- the judged errors of a press list, in cycle order: the session's own rules, so finish and checks agree
function TimingStrike.judgeErrors(P: Pattern, presses: { number }): { number }
	local S = TimingStrike.newSession(P)
	for _, t in ipairs(presses) do
		TimingStrike.push(S, t)
	end
	closeBefore(S, P.durationMs + 1)
	return judgedErrors(S)
end

function TimingStrike.finish(S: Session): MinigameResult
	local pat = S.pat
	closeBefore(S, pat.durationMs + 1)
	local cyc = pat.cycles
	local sum = 0
	local perfect, good, ok = 0, 0, 0
	for i = 1, #cyc do
		local e = S.err[i]
		if type(e) == "number" then
			local pts = TimingStrike.points(pat, e)
			sum += pts
			if pts >= TS_GRADE_PERFECT then
				perfect += 1
			elseif pts >= TS_GRADE_GOOD then
				good += 1
			elseif pts > 0 then
				ok += 1
			end
		end
	end
	local score = q(sum / #cyc)
	local errs = judgedErrors(S)
	local abs: { number } = {}
	for i, e in ipairs(errs) do
		abs[i] = math.abs(e)
	end
	return {
		status = "Ok",
		score = score,
		rawScore = score,
		passed = score >= pat.p.passThreshold,
		flags = {},
		invalidReason = nil,
		breakdown = {
			judged = #errs,
			perfect = perfect,
			good = good,
			ok = ok,
			miss = #cyc - #errs,
			whiffs = S.whiffs,
			bestCombo = S.bestCombo,
			meanAbsErrMs = Checks.mean(abs),
			meanErrMs = Checks.mean(errs),
		},
		elapsedMs = 0,
	}
end

function TimingStrike.checks(P: Pattern, presses: { number }, _result: MinigameResult): { FlagId }
	local flags: { FlagId } = {}
	local errs = TimingStrike.judgeErrors(P, presses)
	local n = #errs
	if n >= Checks.value(FAMILY, "TS_MIN_JUDGED") then
		local exactMs = Checks.value(FAMILY, "TS_EXACT_MS")
		local exact = 0
		for i = 1, n do
			if math.abs(errs[i]) <= exactMs then
				exact += 1
			end
		end
		-- in byte order (§10.5)
		if exact >= math.ceil(Checks.value(FAMILY, "TS_EXACT_FRAC") * n) then
			table.insert(flags, TS_EXACT_HITS)
		end
		if Checks.sampleSd(errs) < Checks.value(FAMILY, "TS_MIN_SD_MS") then
			table.insert(flags, TS_LOW_VARIANCE)
		end
	end
	return flags
end

-- The dial at nowMs (the raw clock), in sweep units: cycle i holds start_i ≤ nowMs < start_i + P_i (1 before GO, N
-- in the tail); marker, the window and its grade bands are fractions of that cycle; next is the following window in its
-- own cycle's units. Decisions come from the session as advanced.
function TimingStrike.view(S: Session, nowMs: number): TimingStrikeView
	local pat = S.pat
	local cyc = pat.cycles
	local n = #cyc
	local i = 1
	while i < n and cyc[i + 1].start <= nowMs do
		i += 1
	end
	local c = cyc[i]
	local P = c.period
	local nc = cyc[i + 1]
	local nextWindow = if nc then { windowCenter = (nc.target - nc.start) / nc.period, windowHalf = pat.W / nc.period }
		else nil
	return {
		t = nowMs,
		cycle = i,
		cycles = n,
		marker = math.clamp((nowMs - c.start) / P, 0, 1),
		windowCenter = (c.target - c.start) / P,
		windowHalf = pat.W / P,
		perfectHalf = TimingStrike.bandMs(pat, TS_GRADE_PERFECT) / P,
		goodHalf = TimingStrike.bandMs(pat, TS_GRADE_GOOD) / P,
		next = nextWindow,
		lastGrade = S.lastGrade,
		lastErrorMs = S.lastErrorMs,
		combo = S.combo,
		runningScore = if S.decided > 0 then q(S.pointsSum / S.decided) else 0,
		timeLeftMs = math.max(0, pat.durationMs - nowMs),
	}
end

return table.freeze(TimingStrike)
