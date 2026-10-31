--!strict
-- Prototype of src/shared/Session/SessionMachine.luau (pure: no Roblox APIs).
-- Revised to the final contract (RULINGS §2.19-2.22): the clock, seeds, pings, the prepared S3 StepSpec/pattern
-- and S3's Minigames.judge are injected. CraftService wraps it with remotes, timers, the AnalysisQueue and persistence.

export type State = "Ready" | "Playing" | "Finalizing" | "Completed" | "Aborted"
export type AbortReason = "Abandoned" | "Left" | "Idle" | "SessionTimeout" | "ServerClosing" | "InvalidInput"
	| "DataUnavailable" | "CharacterLost" | "Internal"

export type Timing = {
	countdownMs: number,
	earlyTolMs: number,
	lateSoftMs: number,
	lateHardMs: number,
	rttAllowMaxMs: number,
	readyIdleMs: number,
	sessionMaxMs: number,
	maxPingSamples: number,
}

-- S4 PlannedStep subset the machine reads.
export type PlanStep = { step: string, family: string, tier: string, difficulty: number, material: string }

-- S3 shapes (subset).
export type StepSpec = { family: string, seed: number, params: { [string]: number }, source: { number }?,
	durationMs: number, countdownMs: number, patternHash: number, balanceVersion: number }
export type MinigameResult = { status: "Ok" | "Invalid", score: number, rawScore: number, passed: boolean,
	flags: { string }, invalidReason: string?, breakdown: { [string]: number } }
export type Judge = (spec: StepSpec, pattern: any, timeline: any, elapsedMs: number) -> MinigameResult

-- S4 StepRun + S5 fields (flags never leave the server).
export type StepRun = { seed: number, score: number, passed: boolean, timedOut: boolean, durationMs: number,
	flags: { string }, rawScore: number, elapsedMs: number, breakdown: { [string]: number }? }

export type StepRuntime = {
	plan: PlanStep,
	seed: number?,
	spec: StepSpec?,
	pattern: any,
	openedAtMs: number?,
	pings: { number },
	run: StepRun?,
}

export type Session = {
	id: string,
	userId: number,
	blueprintId: string,
	state: State,
	current: number,
	steps: { StepRuntime },
	createdAtMs: number,
	expiresAtMs: number,
	idleDeadlineMs: number,
	opening: boolean, -- a first open is in flight (CraftService yields on the AnalysisQueue)
	abortReason: AbortReason?,
	timing: Timing,
}

export type OpenView = StepSpec & { sessionId: string, stepIndex: number, stepId: string, tier: string, lateAllowanceMs: number }
export type SubmitResult = { run: StepRun, duplicate: boolean, next: "Ready" | "Finalize", violation: ("Soft" | "Hard")? }
export type Event = { kind: "StepTimedOut", stepIndex: number, run: StepRun, next: "Ready" | "Finalize" }
	| { kind: "Aborted", reason: AbortReason }

local SessionMachine = {}

local function median(xs: { number }): number
	local n = #xs
	if n == 0 then
		return 0
	end
	local c = table.clone(xs)
	table.sort(c)
	if n % 2 == 1 then
		return c[(n + 1) // 2]
	end
	return (c[n // 2] + c[n // 2 + 1]) / 2
end

local function allowance(s: Session, st: StepRuntime): number
	return math.min(2 * median(st.pings), s.timing.rttAllowMaxMs)
end

local function deadlineOf(s: Session, st: StepRuntime): number
	local spec = st.spec :: StepSpec
	return (st.openedAtMs :: number) + s.timing.countdownMs + spec.durationMs + s.timing.lateHardMs + allowance(s, st)
end

local function enterReady(s: Session, nowMs: number)
	s.state = "Ready"
	s.idleDeadlineMs = nowMs + s.timing.readyIdleMs
end

function SessionMachine.new(id: string, userId: number, blueprintId: string, plan: { PlanStep }, nowMs: number, timing: Timing): Session
	local steps: { StepRuntime } = {}
	for i, p in plan do
		steps[i] = { plan = p, pings = {} }
	end
	return {
		id = id,
		userId = userId,
		blueprintId = blueprintId,
		state = "Ready",
		current = 1,
		steps = steps,
		createdAtMs = nowMs,
		expiresAtMs = nowMs + timing.sessionMaxMs,
		idleDeadlineMs = nowMs + timing.readyIdleMs,
		opening = false,
		timing = timing,
	}
end

local function isLive(s: Session): boolean
	return s.state == "Ready" or s.state == "Playing"
end

-- nil = a first open of `index` may start (CraftService then draws the seed and prepares off-frame).
function SessionMachine.canOpen(s: Session, index: number, nowMs: number): string?
	if not isLive(s) then
		return "E_NO_SESSION"
	end
	if s.state == "Playing" then
		return if index == s.current then "Reopen" else "E_WRONG_STATE"
	end
	if index ~= s.current then
		return "E_WRONG_STATE"
	end
	if s.opening then
		return "E_BUSY"
	end
	if nowMs > s.expiresAtMs then
		return "E_SESSION_EXPIRED"
	end
	return nil
end

function SessionMachine.beginOpen(s: Session)
	s.opening = true
end

function SessionMachine.cancelOpen(s: Session)
	s.opening = false
end

-- Ready(i) -> Playing(i). Called after the yield, once CraftService re-checked canOpen; `nowMs` = reply time.
function SessionMachine.open(s: Session, index: number, nowMs: number, seed: number, spec: StepSpec, pattern: any, pingMs: number)
	assert(s.state == "Ready" and index == s.current, "open: wrong state")
	local st = s.steps[index]
	st.seed = seed
	st.spec = spec
	st.pattern = pattern
	st.openedAtMs = nowMs
	st.pings = { pingMs }
	s.opening = false
	s.state = "Playing"
end

function SessionMachine.openView(s: Session, index: number, nowMs: number): OpenView?
	if s.state ~= "Playing" or index ~= s.current then
		return nil
	end
	local st = s.steps[index]
	local spec = st.spec :: StepSpec
	local view = table.clone(spec) :: any
	view.countdownMs = math.max(0, s.timing.countdownMs - (nowMs - (st.openedAtMs :: number)))
	view.sessionId = s.id
	view.stepIndex = index
	view.stepId = st.plan.step
	view.tier = st.plan.tier
	view.lateAllowanceMs = s.timing.lateSoftMs + allowance(s, st)
	return view :: OpenView
end

-- RTT sample (GetNetworkPing, ms) from the 250 ms sweep while Playing; bounded count.
function SessionMachine.ping(s: Session, pingMs: number)
	if s.state ~= "Playing" then
		return
	end
	local st = s.steps[s.current]
	if #st.pings < s.timing.maxPingSamples then
		table.insert(st.pings, pingMs)
	end
end

local function advance(s: Session, nowMs: number): "Ready" | "Finalize"
	if s.current >= #s.steps then
		s.state = "Finalizing"
		return "Finalize"
	end
	s.current += 1
	enterReady(s, nowMs)
	return "Ready"
end

local function timedOutRun(st: StepRuntime): StepRun
	return { seed = st.seed :: number, score = 0, passed = false, timedOut = true, durationMs = (st.spec :: StepSpec).durationMs, flags = {},
		rawScore = 0, elapsedMs = 0 }
end

-- recvMs = arrival time stamped by the Router (never after a yield).
function SessionMachine.submit(s: Session, judge: Judge, index: number, recvMs: number, timeline: any, clientScore: number): (string?, SubmitResult?)
	local st = s.steps[index]
	if st ~= nil and st.run ~= nil then
		-- First submission wins: the stored run, no second judge.
		return nil, { run = st.run :: StepRun, duplicate = true, next = if s.state == "Finalizing" or s.state == "Completed" then "Finalize" else "Ready" }
	end
	if not isLive(s) then
		return "E_NO_SESSION", nil
	end
	if s.state ~= "Playing" or index ~= s.current then
		return "E_WRONG_STATE", nil
	end
	local t = s.timing
	local spec = st.spec :: StepSpec
	if recvMs > deadlineOf(s, st) then
		st.run = timedOutRun(st)
		return nil, { run = st.run :: StepRun, duplicate = false, next = advance(s, recvMs) }
	end
	local e = recvMs - (st.openedAtMs :: number) - t.countdownMs
	if e < spec.durationMs - t.earlyTolMs then
		return "E_TOO_EARLY", nil -- state unchanged; CraftService strikes "TooEarly"
	end
	local r = judge(spec, st.pattern, timeline, e) -- a throw propagates: state unchanged, CraftService aborts Internal
	if r.status == "Invalid" then
		s.state = "Aborted" -- CraftService: Hard strike, telemetry StepRejected{reason = r.invalidReason}
		s.abortReason = "InvalidInput"
		return "E_INVALID_INPUT", nil
	end
	local flags = table.clone(r.flags)
	if e > spec.durationMs + t.lateSoftMs + allowance(s, st) then
		table.insert(flags, "LateSubmit")
	end
	if clientScore ~= r.rawScore then
		table.insert(flags, "ScoreMismatch")
	end
	st.run = { seed = st.seed :: number, score = r.score, passed = r.passed, timedOut = false,
		durationMs = spec.durationMs, flags = flags, rawScore = r.rawScore, elapsedMs = e, breakdown = r.breakdown }
	return nil, { run = st.run :: StepRun, duplicate = false, next = advance(s, recvMs),
		violation = if #flags > 0 then "Soft" else nil }
end

-- Client reported a persistent pattern-hash mismatch after an idempotent re-open: abort, no strike, no re-roll.
function SessionMachine.desync(s: Session, index: number): string?
	if s.state ~= "Playing" or index ~= s.current then
		return "E_WRONG_STATE"
	end
	s.state = "Aborted"
	s.abortReason = "Internal"
	return nil
end

function SessionMachine.complete(s: Session): boolean
	if s.state ~= "Finalizing" then
		return false
	end
	s.state = "Completed"
	return true
end

function SessionMachine.abort(s: Session, reason: AbortReason): boolean
	if s.state == "Completed" or s.state == "Aborted" then
		return false
	end
	s.state = "Aborted"
	s.abortReason = reason
	s.opening = false
	return true
end

-- 250 ms sweep: step deadline, idle and lifetime limits. A session whose first open is in flight is skipped.
function SessionMachine.tick(s: Session, nowMs: number): { Event }
	local events: { Event } = {}
	if s.state == "Playing" then
		local st = s.steps[s.current]
		if nowMs > deadlineOf(s, st) then
			st.run = timedOutRun(st)
			local idx = s.current
			local nxt = advance(s, nowMs)
			table.insert(events, { kind = "StepTimedOut", stepIndex = idx, run = st.run :: StepRun, next = nxt })
		end
	elseif s.state == "Ready" and not s.opening then
		if nowMs > s.idleDeadlineMs then
			SessionMachine.abort(s, "Idle")
			table.insert(events, { kind = "Aborted", reason = "Idle" })
		elseif nowMs > s.expiresAtMs then
			SessionMachine.abort(s, "SessionTimeout")
			table.insert(events, { kind = "Aborted", reason = "SessionTimeout" })
		end
	end
	return events
end

SessionMachine._median = median
return SessionMachine
