--!strict
-- S3 prototype: TimingStrike (Hammering). Closed-form event scoring.
local R = require("./Rng")
local Rng = R.Rng
local HZ = require("./HoldZone") -- for hashInts

export type Cycle = { start: number, period: number, target: number }
export type Pattern = {
	p: { [string]: number },
	cycles: { Cycle },
	M: number, -- judgment half-span (ms)
	W: number, -- effective window half-width (ms)
	durationMs: number,
	hash: number,
}

local TS = {}

function TS.generate(seed: number, p: { [string]: number }): Pattern
	local rT = Rng.new(seed, "TimingStrike.Tempo")
	local rO = Rng.new(seed, "TimingStrike.Offsets")
	local cycles: { Cycle } = {}
	local S = 0
	for i = 1, p.strikes do
		local P = math.floor(p.beatMs * (1 + p.tempoJitter * (2 * rT:nextFloat() - 1)) + 0.5)
		local f = p.offsetMin + (p.offsetMax - p.offsetMin) * rO:nextFloat()
		local T = S + math.floor(f * P + 0.5)
		cycles[i] = { start = S, period = P, target = T }
		S += P
	end
	-- judgment half-span: W + pad, but never overlapping the neighbour's span
	local minGap = math.huge
	for i = 1, #cycles - 1 do
		minGap = math.min(minGap, cycles[i + 1].target - cycles[i].target)
	end
	local M = p.windowMs + p.missPadMs
	if minGap < math.huge then
		M = math.min(M, (minGap - 1) // 2)
	end
	M = math.min(M, cycles[1].target) -- first span starts at >= 0
	local W = math.min(p.windowMs, M)
	local h = 0x811C9DC5
	for _, c in cycles do
		h = HZ.hashInts(h, c.start)
		h = HZ.hashInts(h, c.period)
		h = HZ.hashInts(h, c.target)
	end
	return { p = p, cycles = cycles, M = M, W = W, durationMs = S + p.tailMs, hash = h }
end

function TS.points(pat: Pattern, e: number?): number
	if e == nil then
		return 0
	end
	local a = math.abs(e)
	local W = pat.W
	local pf = pat.p.perfectFrac * W
	if a > W then
		return 0
	elseif a <= pf then
		return 1
	end
	return 1 - (1 - pat.p.edgePoints) * (a - pf) / (W - pf)
end

-- grade labels derive from points: Perfect >= 0.9, Good >= 0.6, Ok > 0, Miss = 0
function TS.grade(pat: Pattern, e: number?): string
	local pts = TS.points(pat, e)
	if pts >= 0.9 then
		return "Perfect"
	elseif pts >= 0.6 then
		return "Good"
	elseif pts > 0 then
		return "Ok"
	end
	return "Miss"
end

export type Session = {
	pat: Pattern,
	i: number, -- next unjudged target
	err: { number | false }, -- per strike: error ms or false (miss, no press)
	judged: { boolean },
	whiffs: number,
	presses: { number },
}

function TS.newSession(pat: Pattern): Session
	return { pat = pat, i = 1, err = {}, judged = {}, whiffs = 0, presses = {} }
end

-- close spans that ended before t (misses)
local function closeUntil(s: Session, t: number)
	local cyc = s.pat.cycles
	while s.i <= #cyc and cyc[s.i].target + s.pat.M < t do
		if not s.judged[s.i] then
			s.err[s.i] = false
			s.judged[s.i] = true
		end
		s.i += 1
	end
end

-- a press at time t (ms)
function TS.press(s: Session, t: number)
	table.insert(s.presses, t)
	closeUntil(s, t)
	local cyc = s.pat.cycles
	local c = cyc[s.i]
	if c and t >= c.target - s.pat.M and t <= c.target + s.pat.M then
		if not s.judged[s.i] then
			s.err[s.i] = t - c.target
			s.judged[s.i] = true
		else
			s.whiffs += 1 -- extra press inside an already-judged span
		end
	else
		s.whiffs += 1 -- press outside any span
	end
end

function TS.advance(s: Session, nowMs: number)
	closeUntil(s, nowMs)
end

export type Result = { score: number, passed: boolean, flags: { string }, errors: { number }, whiffs: number }

local function round4(x: number): number
	return math.floor(x * 10000 + 0.5) / 10000
end

function TS.finish(s: Session): Result
	closeUntil(s, s.pat.durationMs + 1)
	local cyc = s.pat.cycles
	local sum = 0
	local errs = {}
	for i = 1, #cyc do
		local e = s.err[i]
		if e == false or e == nil then
			sum += 0
		else
			sum += TS.points(s.pat, e :: number)
			table.insert(errs, e :: number)
		end
	end
	local score = round4(sum / #cyc)
	return { score = score, passed = score >= s.pat.p.passThreshold, flags = {}, errors = errs, whiffs = s.whiffs }
end

-- impossible-input checks on judged errors
TS.MIN_JUDGED = 8
TS.EXACT_MS = 1
TS.EXACT_FRAC = 0.9
TS.MIN_SD_MS = 1.5
function TS.checks(pat: Pattern, res: Result): { string }
	local flags = {}
	local errs = res.errors
	local n = #errs
	if n >= TS.MIN_JUDGED then
		local exact = 0
		local sum = 0
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
