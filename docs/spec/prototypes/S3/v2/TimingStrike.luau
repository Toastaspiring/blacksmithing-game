--!strict
-- S3 prototype v2: TimingStrike (Hammering). Closed-form event scoring.
-- v2: full-points core = max(perfectFrac * W, PERFECT_CORE_MIN_MS); signed meanErrMs in the breakdown;
-- round4 = math.round; sample SD (n - 1).
local R = require("./Rng")
local Rng = R.Rng
local HZ = require("./HoldZone")

export type Cycle = { start: number, period: number, target: number }
export type Pattern = { p: { [string]: number }, cycles: { Cycle }, M: number, W: number, core: number, durationMs: number, hash: number }

local TS = {}
TS.PERFECT_CORE_MIN_MS = 10
TS.MIN_JUDGED = 8
TS.EXACT_MS = 1
TS.EXACT_FRAC = 0.9
TS.MIN_SD_MS = 1.5

function TS.generate(seed: number, p: { [string]: number }): Pattern
	local rT = Rng.new(seed, "TimingStrike.Tempo")
	local rO = Rng.new(seed, "TimingStrike.Offsets")
	local cycles: { Cycle } = {}
	local S = 0
	for i = 1, p.strikes do
		local P = math.round(p.beatMs * (1 + p.tempoJitter * (2 * rT:nextFloat() - 1)))
		local f = p.offsetMin + (p.offsetMax - p.offsetMin) * rO:nextFloat()
		local T = S + math.round(f * P)
		cycles[i] = { start = S, period = P, target = T }
		S += P
	end
	local minGap = math.huge
	for i = 1, #cycles - 1 do
		minGap = math.min(minGap, cycles[i + 1].target - cycles[i].target)
	end
	local M = p.windowMs + p.missPadMs
	if minGap < math.huge then
		M = math.min(M, (minGap - 1) // 2)
	end
	M = math.min(M, cycles[1].target)
	local W = math.min(p.windowMs, M)
	local core = math.min(W, math.max(p.perfectFrac * W, TS.PERFECT_CORE_MIN_MS))
	local h = 0x811C9DC5
	for _, c in cycles do
		h = HZ.hashU32(h, c.start)
		h = HZ.hashU32(h, c.period)
		h = HZ.hashU32(h, c.target)
	end
	return { p = p, cycles = cycles, M = M, W = W, core = core, durationMs = S + p.tailMs, hash = h }
end

function TS.points(pat: Pattern, e: number?): number
	if e == nil then
		return 0
	end
	local a = math.abs(e)
	local W, core = pat.W, pat.core
	if a > W then
		return 0
	elseif a <= core then
		return 1
	end
	return 1 - (1 - pat.p.edgePoints) * (a - core) / (W - core)
end

export type Session = { pat: Pattern, i: number, err: { number | false }, judged: { boolean }, whiffs: number }

function TS.newSession(pat: Pattern): Session
	return { pat = pat, i = 1, err = {}, judged = {}, whiffs = 0 }
end

local function closeBefore(s: Session, t: number)
	local cyc = s.pat.cycles
	while s.i <= #cyc and cyc[s.i].target + s.pat.M < t do
		if not s.judged[s.i] then
			s.err[s.i] = false
			s.judged[s.i] = true
		end
		s.i += 1
	end
end

function TS.press(s: Session, t: number)
	closeBefore(s, t)
	local c = s.pat.cycles[s.i]
	if c and t >= c.target - s.pat.M and t <= c.target + s.pat.M and not s.judged[s.i] then
		s.err[s.i] = t - c.target
		s.judged[s.i] = true
	else
		s.whiffs += 1
	end
end

function TS.advance(s: Session, nowMs: number)
	closeBefore(s, nowMs)
end

export type Result = { score: number, rawScore: number, passed: boolean, flags: { string }, errors: { number }, whiffs: number, meanErrMs: number, perfect: number }

function TS.finish(s: Session): Result
	closeBefore(s, s.pat.durationMs + 1)
	local cyc = s.pat.cycles
	local sum, esum, perfect = 0, 0, 0
	local errs = {}
	for i = 1, #cyc do
		local e = s.err[i]
		if e ~= false and e ~= nil then
			local pts = TS.points(s.pat, e :: number)
			sum += pts
			esum += e :: number
			if pts >= 0.9 then
				perfect += 1
			end
			table.insert(errs, e :: number)
		end
	end
	local score = HZ.round4(sum / #cyc)
	return { score = score, rawScore = score, passed = score >= s.pat.p.passThreshold, flags = {}, errors = errs, whiffs = s.whiffs, meanErrMs = if #errs > 0 then esum / #errs else 0, perfect = perfect }
end

function TS.checks(pat: Pattern, res: Result): { string }
	local flags = {}
	local errs = res.errors
	local n = #errs
	if n >= TS.MIN_JUDGED then
		local exact, sum = 0, 0
		for _, e in errs do
			if math.abs(e) <= TS.EXACT_MS then
				exact += 1
			end
			sum += e
		end
		local mean = sum / n
		local ss = 0
		for _, e in errs do
			ss += (e - mean) * (e - mean)
		end
		local sd = math.sqrt(ss / (n - 1))
		if exact >= math.ceil(TS.EXACT_FRAC * n) then
			table.insert(flags, "TS_ExactHits")
		end
		if sd < TS.MIN_SD_MS then
			table.insert(flags, "TS_LowVariance")
		end
	end
	return flags
end

function TS.replay(pat: Pattern, presses: { number }): Result
	local s = TS.newSession(pat)
	for _, t in presses do
		TS.press(s, t)
	end
	local res = TS.finish(s)
	res.flags = TS.checks(pat, res)
	return res
end

return TS
