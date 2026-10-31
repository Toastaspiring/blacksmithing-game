--!strict
-- Scenario checks for the revised craft session machine (Lune 0.8.9):
--   lune run session_scenarios.luau
-- Contract: RULINGS §2.19-2.22 (S3 facade injected; buffer timeline opaque here; no seed re-roll).
local SM = require("./lib/SessionMachine")

local TIMING = {
	countdownMs = 3000,
	earlyTolMs = 250,
	lateSoftMs = 1500,
	lateHardMs = 5000,
	rttAllowMaxMs = 2000,
	readyIdleMs = 120000,
	sessionMaxMs = 600000,
	maxPingSamples = 160,
}

-- Mock S3 facade. The "timeline" is a table {score = x, invalid = reason?, high = bool?, throw = bool?}.
local judgeCalls = 0
local function judge(spec, pattern, timeline, elapsedMs)
	judgeCalls += 1
	if timeline.throw then
		error("judge bug")
	end
	if timeline.invalid then
		return { status = "Invalid", score = 0, rawScore = 0, passed = false, flags = {}, invalidReason = timeline.invalid, breakdown = {} }
	end
	local raw = timeline.score
	local score = raw
	local flags = {}
	if timeline.high then
		table.insert(flags, "TS_ExactHits")
		score = math.min(raw, 0.5)
	end
	return { status = "Ok", score = score, rawScore = raw, passed = score >= 0.5, flags = flags, breakdown = { inZone = raw } }
end

local function spec(durationMs: number, seed: number)
	return { family = "HoldZone", seed = seed, params = {}, durationMs = durationMs, countdownMs = 3000, patternHash = 42, balanceVersion = 1 }
end

local PLAN = {
	{ step = "Smelting", family = "HoldZone", tier = "Normal", difficulty = 0.1, material = "Iron" },
	{ step = "Hammering", family = "TimingStrike", tier = "Hard", difficulty = 0.25, material = "Iron" },
	{ step = "Sharpening", family = "PrecisionTrace", tier = "Hard", difficulty = 0.3, material = "Steel" },
}
local DUR = { 15000, 10800, 20000 }

local passed, failed = 0, 0
local function check(name: string, cond: boolean)
	if cond then
		passed += 1
	else
		failed += 1
		print("FAIL: " .. name)
	end
end

local function openStep(s, i: number, now: number, seed: number, ping: number)
	local c = SM.canOpen(s, i, now)
	assert(c == nil, "canOpen " .. tostring(c))
	SM.beginOpen(s)
	SM.open(s, i, now, seed, spec(DUR[i], seed), { pattern = seed }, ping)
end

-- 1. Happy path: open, idempotent re-open (same spec and seed, remaining countdown), submit, duplicate submit.
do
	judgeCalls = 0
	local now = 0
	local s = SM.new("S1", 1, "B1", PLAN, now, TIMING)
	for i = 1, 3 do
		now += 1000
		openStep(s, i, now, 1000 + i, 120)
		now += 500
		check("re-open allowed " .. i, SM.canOpen(s, i, now) == "Reopen")
		local v = SM.openView(s, i, now)
		check("re-open same seed/hash, remaining countdown " .. i, v ~= nil and v.seed == 1000 + i and v.patternHash == 42 and v.countdownMs == 2500 and v.stepIndex == i)
		now += 2500 + DUR[i] + 150
		local e, o = SM.submit(s, judge, i, now, { score = 0.8 }, 0.8)
		check("submit " .. i, e == nil and o ~= nil and not o.duplicate and o.run.score == 0.8 and o.run.passed and #o.run.flags == 0 and o.violation == nil)
		local e2, o2 = SM.submit(s, judge, i, now + 50, { score = 1.0 }, 1.0)
		check("duplicate keeps first run " .. i, e2 == nil and o2 ~= nil and o2.duplicate and o2.run.score == 0.8)
	end
	check("finalizing after last step", s.state == "Finalizing")
	check("judge ran exactly 3 times", judgeCalls == 3)
	check("complete once", SM.complete(s) == true and SM.complete(s) == false and s.state == "Completed")
end

-- 2. Out of order and wrong state.
do
	local s = SM.new("S2", 1, "B1", PLAN, 0, TIMING)
	check("cannot open step 2 first", SM.canOpen(s, 2, 100) == "E_WRONG_STATE")
	check("cannot submit before open", SM.submit(s, judge, 1, 200, { score = 1 }, 1) == "E_WRONG_STATE")
	openStep(s, 1, 0, 7, 100)
	check("cannot open step 2 while playing 1", SM.canOpen(s, 2, 500) == "E_WRONG_STATE")
end

-- 3. Too early: refused, state unchanged; inside the tolerance accepted.
do
	local s = SM.new("S3", 1, "B1", PLAN, 0, TIMING)
	openStep(s, 1, 0, 7, 100)
	local e = SM.submit(s, judge, 1, 3000 + 15000 - 251, { score = 1 }, 1)
	check("too early rejected, still Playing", e == "E_TOO_EARLY" and s.state == "Playing")
	local e2, o2 = SM.submit(s, judge, 1, 3000 + 15000 - 250, { score = 1 }, 1)
	check("at the early bound accepted", e2 == nil and o2 ~= nil and o2.run.score == 1)
end

-- 4. Late bands: soft (scored + LateSubmit), hard bound inclusive, beyond = timeout.
do
	local function fresh(id: string)
		local s = SM.new(id, 1, "B1", PLAN, 0, TIMING)
		openStep(s, 1, 0, 7, 100) -- A = 2 * median(100) = 200
		return s
	end
	local s0 = fresh("S4a")
	local v = SM.openView(s0, 1, 0)
	check("late allowance = LATE_SOFT + A", v ~= nil and v.lateAllowanceMs == 1700)
	local _, o0 = SM.submit(s0, judge, 1, 3000 + 15000 + 1700, { score = 1 }, 1)
	check("at the soft bound: no flag", o0 ~= nil and #o0.run.flags == 0)
	local _, o1 = SM.submit(fresh("S4b"), judge, 1, 3000 + 15000 + 1701, { score = 1 }, 1)
	check("soft late: scored + LateSubmit", o1 ~= nil and o1.run.score == 1 and o1.run.flags[1] == "LateSubmit" and o1.violation == "Soft")
	local s2 = fresh("S4c")
	local _, o2 = SM.submit(s2, judge, 1, 3000 + 15000 + 5200, { score = 1 }, 1)
	check("at the hard bound: still scored", o2 ~= nil and not o2.run.timedOut and o2.run.score == 1)
	local s3 = fresh("S4d")
	local _, o3 = SM.submit(s3, judge, 1, 3000 + 15000 + 5201, { score = 1 }, 1)
	check("beyond the hard bound: timeout, session continues", o3 ~= nil and o3.run.timedOut and o3.run.score == 0 and not o3.run.passed and s3.state == "Ready" and s3.current == 2)
end

-- 5. Sweep timeout, then idle abort.
do
	local s = SM.new("S5", 1, "B1", PLAN, 0, TIMING)
	openStep(s, 1, 0, 7, 1500) -- A capped at 2000 -> deadline 3000 + 15000 + 5000 + 2000 = 25000
	check("no timeout at the deadline", #SM.tick(s, 25000) == 0)
	local ev = SM.tick(s, 25001)
	check("timeout event", #ev == 1 and ev[1].kind == "StepTimedOut" and s.state == "Ready")
	check("no idle abort at the limit", #SM.tick(s, 25001 + 120000) == 0)
	local ev3 = SM.tick(s, 25001 + 120001)
	check("idle abort", #ev3 == 1 and ev3[1].kind == "Aborted" and s.abortReason == "Idle")
	check("no submit after abort", SM.submit(s, judge, 2, 200000, { score = 1 }, 1) == "E_NO_SESSION")
end

-- 6. Invalid aborts the craft; a HIGH flag is clamped by the judge and the step still passes.
do
	local s = SM.new("S6", 1, "B1", PLAN, 0, TIMING)
	openStep(s, 1, 0, 7, 100)
	local _, o = SM.submit(s, judge, 1, 18100, { score = 0.97, high = true }, 0.97)
	check("HIGH flag: clamped to the pass line, passes, flag kept, no mismatch",
		o ~= nil and o.run.score == 0.5 and o.run.passed and o.run.rawScore == 0.97 and #o.run.flags == 1 and o.run.flags[1] == "TS_ExactHits")
	openStep(s, 2, 19000, 8, 100)
	local e = SM.submit(s, judge, 2, 19000 + 3000 + 10800 + 100, { invalid = "NotAlternating" }, 0.5)
	check("Invalid aborts with InvalidInput", e == "E_INVALID_INPUT" and s.state == "Aborted" and s.abortReason == "InvalidInput")
end

-- 7. A throwing judge leaves the state unchanged (CraftService then aborts with Internal).
do
	local s = SM.new("S7", 1, "B1", PLAN, 0, TIMING)
	openStep(s, 1, 0, 7, 100)
	local ok = pcall(SM.submit, s, judge, 1, 18100, { throw = true }, 0.5)
	check("throw propagates, state unchanged", not ok and s.state == "Playing" and s.steps[1].run == nil)
	check("abort Internal afterwards", SM.abort(s, "Internal") and s.abortReason == "Internal")
end

-- 8. Lifetime: open refused after expiry, sweep aborts a Ready session.
do
	local s = SM.new("S8", 1, "B1", PLAN, 0, TIMING)
	s.idleDeadlineMs = 10 ^ 9
	check("open refused after expiry", SM.canOpen(s, 1, 600001) == "E_SESSION_EXPIRED")
	local ev = SM.tick(s, 600001)
	check("sweep aborts expired session", #ev == 1 and s.abortReason == "SessionTimeout")
end

-- 9. Abandon is idempotent; terminal states refuse everything.
do
	local s = SM.new("S9", 1, "B1", PLAN, 0, TIMING)
	check("abandon once", SM.abort(s, "Abandoned") == true and SM.abort(s, "Abandoned") == false)
	check("no open after abandon", SM.canOpen(s, 1, 10) == "E_NO_SESSION")
end

-- 10. Last step times out via the sweep -> Finalize; a late duplicate gets the stored timeout.
do
	local s = SM.new("S10", 1, "B1", PLAN, 0, TIMING)
	local now = 0
	for i = 1, 2 do
		openStep(s, i, now, i, 100)
		now += 3000 + DUR[i] + 100
		SM.submit(s, judge, i, now, { score = 0.6 }, 0.6)
		now += 1000
	end
	openStep(s, 3, now, 3, 100)
	local ev = SM.tick(s, now + 3000 + 20000 + 5200 + 1)
	check("last-step timeout finalizes", #ev == 1 and ev[1].kind == "StepTimedOut" and ev[1].next == "Finalize" and s.state == "Finalizing")
	local e, o = SM.submit(s, judge, 3, now + 40000, { score = 1 }, 1)
	check("late duplicate gets the stored timeout", e == nil and o ~= nil and o.duplicate and o.run.timedOut)
end

-- 11. RTT allowance = 2 x median of samples: a lag spike at open does not buy slack (R3-20).
do
	local s = SM.new("S11", 1, "B1", PLAN, 0, TIMING)
	openStep(s, 1, 0, 7, 1500) -- lag-switched sample at open
	for _ = 1, 20 do
		SM.ping(s, 100)
	end
	local v = SM.openView(s, 1, 0)
	check("median resists one inflated sample (A = 200)", v ~= nil and v.lateAllowanceMs == 1500 + 200)
	local _, o = SM.submit(s, judge, 1, 3000 + 15000 + 1800, { score = 1 }, 1)
	check("submission beyond D + LATE_SOFT + A(median) is flagged", o ~= nil and o.run.flags[1] == "LateSubmit")
	local s2 = SM.new("S11b", 1, "B1", PLAN, 0, TIMING)
	openStep(s2, 1, 0, 7, 100)
	for _ = 1, 300 do
		SM.ping(s2, 900)
	end
	check("sample count is bounded", #s2.steps[1].pings == TIMING.maxPingSamples)
end

-- 12. ScoreMismatch compares clientScore with rawScore exactly (round4 values).
do
	local s = SM.new("S12", 1, "B1", PLAN, 0, TIMING)
	openStep(s, 1, 0, 7, 100)
	local _, o = SM.submit(s, judge, 1, 18100, { score = 0.7342 }, 0.7341)
	check("mismatch flagged", o ~= nil and o.run.flags[1] == "ScoreMismatch" and o.run.score == 0.7342)
end

-- 13. Desync: abort Internal in Playing(i), refused elsewhere; the seed never changes on re-open.
do
	local s = SM.new("S13", 1, "B1", PLAN, 0, TIMING)
	check("desync refused in Ready", SM.desync(s, 1) == "E_WRONG_STATE")
	openStep(s, 1, 0, 77, 100)
	local v1 = SM.openView(s, 1, 4000)
	check("re-open after the countdown: countdown 0, same seed", v1 ~= nil and v1.countdownMs == 0 and v1.seed == 77)
	check("desync aborts with Internal", SM.desync(s, 1) == nil and s.state == "Aborted" and s.abortReason == "Internal")
end

-- 14. A first open in flight: second open refused (E_BUSY), sweep skips the session, abort clears the flag.
do
	local s = SM.new("S14", 1, "B1", PLAN, 0, TIMING)
	SM.beginOpen(s)
	check("second open while one is in flight", SM.canOpen(s, 1, 10) == "E_BUSY")
	check("sweep skips a session that is opening", #SM.tick(s, 200000) == 0 and s.state == "Ready")
	SM.cancelOpen(s)
	check("idle abort after the open is cancelled", #SM.tick(s, 200000) == 1 and s.abortReason == "Idle")
end

-- Durations (MVP maxima: HoldZone 18 s (Volume 1.2), TimingStrike <= 11.5 s, PrecisionTrace <= 31 s).
do
	local worst = 0
	for _, d in { 18000, 11500, 31000 } do
		worst += TIMING.readyIdleMs + TIMING.countdownMs + d + TIMING.lateHardMs + TIMING.rttAllowMaxMs
	end
	local nominal = 0
	for _, d in { 15000, 10800, 20000 } do
		nominal += 4000 + TIMING.countdownMs + d + 200
	end
	print(string.format("compliant worst-case session = %.1f s (SESSION_MAX %d s)", worst / 1000, TIMING.sessionMaxMs // 1000))
	print(string.format("nominal session (4 s result card, 200 ms RTT, D = 15/10.8/20 s) = %.1f s", nominal / 1000))
end

print(string.format("session scenarios: %d passed, %d failed", passed, failed))
