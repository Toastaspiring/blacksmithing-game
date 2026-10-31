--!strict
-- PROTOTYPE toy TimingStrike (S3 owns the real family). Exists only to exercise the S8
-- bot harness: seeded pattern, integer-ms event timeline, replay scoring, validation, flags.
local Rng = require("./Rng")

export type Params = { strikes: number, periodMs: number, jitterMs: number, windowMs: number, passScore: number }
export type Pattern = { targets: { number }, durationMs: number }
export type Event = { t: number }
export type Result = { ok: boolean, code: string?, score: number, pass: boolean, flags: { string } }

local T = {}

local LEAD_IN_MS = 1000
local GRACE_MS = 500
local MAX_EVENTS_PER_STRIKE = 4
local INHUMAN_MIN_STRIKES = 8
local INHUMAN_SD_MS = 2
local EXTRA_EVENT_PENALTY = 0.05

function T.generate(seed: number, p: Params): Pattern
	local r = Rng.new(seed)
	local targets = table.create(p.strikes, 0)
	for i = 1, p.strikes do
		targets[i] = LEAD_IN_MS + (i - 1) * p.periodMs + Rng.nextInt(r, -p.jitterMs, p.jitterMs)
	end
	return { targets = targets, durationMs = LEAD_IN_MS + p.strikes * p.periodMs }
end

local function reject(code: string): Result
	return { ok = false, code = code, score = 0, pass = false, flags = {} }
end

-- Replays a client timeline against the seeded pattern. Never throws on bad input.
function T.score(pattern: Pattern, p: Params, timeline: any): Result
	if type(timeline) ~= "table" then return reject("NotATable") end
	local n = #timeline
	if n > MAX_EVENTS_PER_STRIKE * p.strikes then return reject("TooManyEvents") end
	local last = -1
	for i = 1, n do
		local ev = timeline[i]
		local t = if type(ev) == "table" then ev.t else nil
		if type(t) ~= "number" or t ~= t or t % 1 ~= 0 then return reject("BadTimestamp") end
		if t < last or t < 0 or t > pattern.durationMs + GRACE_MS then return reject("OutOfOrderOrRange") end
		last = t
	end
	-- greedy in-order matching: each target takes the first unused event within ±window
	local used = table.create(n, false)
	local sum, matched, errs = 0, 0, {}
	local j = 1
	for _, target in pattern.targets do
		while j <= n and timeline[j].t < target - p.windowMs do j += 1 end
		if j <= n and math.abs(timeline[j].t - target) <= p.windowMs then
			local e = timeline[j].t - target
			used[j] = true
			sum += 1 - math.abs(e) / p.windowMs
			matched += 1
			table.insert(errs, e)
			j += 1
		end
	end
	local extra = 0
	for i = 1, n do if not used[i] then extra += 1 end end
	local score = math.clamp(sum / p.strikes - EXTRA_EVENT_PENALTY * extra, 0, 1)
	local flags = {}
	if matched >= INHUMAN_MIN_STRIKES then
		local mean = 0
		for _, e in errs do mean += e end
		mean /= matched
		local ss = 0
		for _, e in errs do ss += (e - mean) * (e - mean) end
		if math.sqrt(ss / (matched - 1)) < INHUMAN_SD_MS then table.insert(flags, "InhumanPrecision") end
	end
	return { ok = true, code = nil, score = score, pass = score >= p.passScore, flags = flags }
end

return T
