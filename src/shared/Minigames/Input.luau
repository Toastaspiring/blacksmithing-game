--!strict
-- Minigames/Input (SPEC §6.2, §6.6, §12.5; owner S3): the Recorder, the only producer of timeline records (S6's
-- InputCapture, Bots, autoplay). It turns the step's inputs into the records the live session is pushed and the
-- client submits, so an unmodified client never sends a timeline decode refuses. Pure: the caller passes the clock.
--
--   Input.new(spec, timingOffsetMs, goClockS)   clockS below is on goClockS's clock (os.clock() in S6; seconds with
--                                     GO = 0 in Bots); timingOffsetMs is S6's sanitized integer setting (§9.3)
--   :go(held, u?, v?, grind?)         the first call, on the first frame at or after GO; calls before it are ignored
--                                     (countdown inputs, §6.6). HoldZone records {t = 0, down} when held (one stroke);
--                                     TimingStrike records nothing (a strike needs a press after GO, M4's D9);
--                                     PrecisionTrace records the cursor at t = 0, grinding = grind or held
--   :button(down, clockS, frameDtS)   Space OR LMB's logical state, on change (S6 ORs them): stamped at the frame's
--                                     centre, t = max(0, floor((clockS − goClockS)·1000 − frameDtS·1000/2)); then
--                                     TimingStrike subtracts timingOffsetMs, floored at 0; then t = max(t, the last
--                                     record's t, the horizon). HoldZone records OR-state changes (no new press once
--                                     MAX_RECORDS − 1 are recorded, so the release always fits); TimingStrike records
--                                     each press, an up → down change (none past MAX_RECORDS); the trace nothing
--   :cursor(u, v, grind, clockS)      PrecisionTrace only, every frame: t = max(0, floor((clockS − goClockS)·1000)),
--                                     recorded at the first call with t at or past the next due time (a multiple of
--                                     PT_EVAL_MS after the last record), u and v as round(·PT_FIXED_POINT) clamped to
--                                     the panel; at most floor(durationMs / PT_EVAL_MS) + 1 records (§6.6 Caps)
--   :release()                        focus lost or menu opened (§6.6): HoldZone records an up at the latest known time
--                                     (the last record's or the horizon) when down; TimingStrike lets the next press
--                                     count; the trace records nothing (the next cursor carries the grind state)
--   :records()                        a frozen copy, at submit time
--   :horizonMs(clockS, frameDtS)      the time the host may advance the live session to (M4's D4): HoldZone and
--                                     TimingStrike, the latest button stamp asked for, in the records' time base (so
--                                     TimingStrike's lags the frame by the offset, or leads it for a negative one);
--                                     PrecisionTrace, its latest record's
--   :since(count)                     records count + 1 … #, for the host's per-frame push
--
-- Records past durationMs are dropped; records are frozen when made; a HoldZone state changes only when its record is
-- made. Live = replay (§6.4 rule 7) holds by construction: every record is stamped at or after every horizon handed
-- out, so the host loop (§12.5: push since(pushed), advance(session, horizonMs(...)), view; at GO + durationMs push
-- since(pushed) once more, then finish) shows the session every record before any tick or span the replay would
-- process after it, whatever the timing offset. The stamps are the S3 prototype bots' (a press delivered at frame f is
-- floor(f − dt/2), a trace sample floor(f)), so bots that drive this Recorder reproduce the prototype's timelines.

local MinigameFamilies = require("../Definitions/MinigameFamilies")
local DT = require("../Definitions/Types")
local PrecisionTrace = require("./PrecisionTrace")
local Types = require("./Types")

type Recorder = Types.Recorder
type StepSpec = Types.StepSpec
type HoldRecord = Types.HoldRecord
type TraceRecord = Types.TraceRecord

-- a Recorder's state; its methods are the frozen metatable's
type State = {
	family: DT.FamilyId,
	durationMs: number,
	maxRecords: number,
	offsetMs: number, -- TimingStrike's timing offset; 0 for the others
	goClockS: number,
	went: boolean, -- go was called
	down: boolean, -- HoldZone: the recorded OR-state; TimingStrike: the logical state (a press is up → down)
	list: { any }, -- the records (not `records`: that is a method)
	lastT: number, -- the last record's t
	horizonMax: number, -- the latest horizon handed out
	due: number, -- PrecisionTrace: the next due time
}

local Q = PrecisionTrace.PT_FIXED_POINT
local U_MAX = PrecisionTrace.PT_PANEL_ASPECT * PrecisionTrace.PT_FIXED_POINT
local V_MAX = PrecisionTrace.PT_FIXED_POINT
local EVAL_MS = PrecisionTrace.PT_EVAL_MS

-- since hands this out when no record is new (no table per frame)
local NONE: { any } = table.freeze({})

local function state(self: Recorder): State
	return (self :: any) :: State
end

-- a panel coordinate as a record field: round(x·Q) clamped to [0, max]; NaN reads 0
local function fixed(x: number, max: number): number
	if x ~= x then
		return 0
	end
	return math.clamp(math.round(x * Q), 0, max)
end

-- §6.6's button time: the frame's centre, floored at 0; TimingStrike's minus the offset, floored at 0
local function buttonStamp(s: State, clockS: number, frameDtS: number): number
	local t = math.max(0, math.floor((clockS - s.goClockS) * 1000 - frameDtS * 1000 / 2))
	return math.max(0, t - s.offsetMs)
end

local function add(s: State, r: any, t: number)
	table.insert(s.list, r)
	s.lastT = t
end

local function go(self: Recorder, held: boolean, u: number?, v: number?, grind: boolean?)
	local s = state(self)
	if s.went then
		return
	end
	if s.family == "HoldZone" then
		if held then
			add(s, table.freeze({ t = 0, down = true }), 0)
			s.down = true
		end
	elseif s.family == "TimingStrike" then
		s.down = held
	else
		if u == nil or v == nil then
			error("Input: PrecisionTrace's go needs the cursor (u, v)", 2)
		end
		local g = if grind == nil then held else grind
		add(s, table.freeze({ t = 0, u = fixed(u, U_MAX), v = fixed(v, V_MAX), grind = g }), 0)
		s.due = EVAL_MS
	end
	s.went = true
end

local function button(self: Recorder, down: boolean, clockS: number, frameDtS: number)
	local s = state(self)
	if not s.went or s.family == "PrecisionTrace" then
		return
	end
	if s.family == "TimingStrike" then
		if down and not s.down then
			local t = math.max(buttonStamp(s, clockS, frameDtS), s.lastT, s.horizonMax)
			if t <= s.durationMs and #s.list < s.maxRecords then
				add(s, t, t)
			end
		end
		s.down = down
		return
	end
	if down == s.down then
		return
	end
	local t = math.max(buttonStamp(s, clockS, frameDtS), s.lastT, s.horizonMax)
	if t > s.durationMs or (down and #s.list >= s.maxRecords - 1) then
		return
	end
	add(s, table.freeze({ t = t, down = down }), t)
	s.down = down
end

local function cursor(self: Recorder, u: number, v: number, grind: boolean, clockS: number)
	local s = state(self)
	if not s.went or s.family ~= "PrecisionTrace" then
		return
	end
	local t = math.max(0, math.floor((clockS - s.goClockS) * 1000))
	if t < s.due or t <= s.lastT or t > s.durationMs or #s.list >= s.maxRecords then
		return
	end
	add(s, table.freeze({ t = t, u = fixed(u, U_MAX), v = fixed(v, V_MAX), grind = grind }), t)
	-- the smallest multiple of EVAL_MS after t: the prototype's `while due <= t do due += EVAL_MS end`
	s.due = (math.floor(t / EVAL_MS) + 1) * EVAL_MS
end

local function release(self: Recorder)
	local s = state(self)
	if not s.went then
		return
	end
	if s.family == "HoldZone" then
		if s.down then
			local t = math.max(s.lastT, s.horizonMax)
			if t <= s.durationMs then
				add(s, table.freeze({ t = t, down = false }), t)
				s.down = false
			end
		end
	elseif s.family == "TimingStrike" then
		s.down = false
	end
end

local function records(self: Recorder): { any }
	return table.freeze(table.clone(state(self).list))
end

local function horizonMs(self: Recorder, clockS: number, frameDtS: number): number
	local s = state(self)
	if not s.went then
		return s.horizonMax
	elseif s.family == "PrecisionTrace" then
		return s.lastT
	end
	s.horizonMax = math.max(s.horizonMax, buttonStamp(s, clockS, frameDtS))
	return s.horizonMax
end

local function since(self: Recorder, count: number): { any }
	local list = state(self).list
	local n = #list
	if count >= n then
		return NONE
	end
	local out = table.create(n - count)
	for i = count + 1, n do
		out[i - count] = list[i]
	end
	return out
end

-- typed as the Recorder, so luau-lsp checks every method against Types.Recorder
local METHODS: Recorder = table.freeze({
	go = go,
	button = button,
	cursor = cursor,
	release = release,
	records = records,
	horizonMs = horizonMs,
	since = since,
})
local INSTANCE = table.freeze({ __index = METHODS })

local Input = {}

function Input.new(spec: StepSpec, timingOffsetMs: number, goClockS: number): Recorder
	local family: DT.FamilyId = spec.family
	local maxRecords = MinigameFamilies.MAX_RECORDS[family]
	if maxRecords == nil or (family ~= "HoldZone" and family ~= "TimingStrike" and family ~= "PrecisionTrace") then
		error("Input.new: no input rule for " .. tostring(family), 2)
	end
	local offset = timingOffsetMs
	if type(offset) ~= "number" or math.floor(offset) ~= offset or math.abs(offset) == math.huge then
		error("Input.new: timingOffsetMs must be an integer (the sanitized setting), got " .. tostring(offset), 2)
	end
	if type(goClockS) ~= "number" or goClockS ~= goClockS or math.abs(goClockS) == math.huge then
		error("Input.new: goClockS must be a finite number, got " .. tostring(goClockS), 2)
	end
	local s: State = {
		family = family,
		durationMs = spec.durationMs,
		maxRecords = maxRecords,
		offsetMs = if family == "TimingStrike" then offset else 0,
		goClockS = goClockS,
		went = false,
		down = false,
		list = {},
		lastT = 0,
		horizonMax = 0,
		due = 0,
	}
	return (setmetatable(s :: any, INSTANCE) :: any) :: Recorder
end

return table.freeze(Input)
