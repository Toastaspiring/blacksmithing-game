--!strict
-- Minigames/Input (SPEC §6.2, §6.6, §12.5; T-MG-15, T-MG-16, M4's D4, D7, D9 and L6): the Recorder's stamps (the
-- frame's centre; D7's exact clocks give every integer ms; the S3 prototype bots' stamps on random frames, which the
-- bots rely on), the timing offset (TimingStrike's alone; the unquantized Exact presses keep their flag decisions; the
-- human players stay unflagged at every offset), releases on focus loss, each family's records and caps, the horizon
-- and why the host advances to it, the host loop (§12.5) finishing as the judge, and L6's proof: no Recorder makes more
-- than floor(durationMs / PT_EVAL_MS) + 1 trace records, whatever its frames, hitches and focus losses, so the judge may
-- refuse more.

local Test = require("../lib/Test")
local A = require("../lib/Assert")
local Prop = require("../lib/Prop")
local TestRng = require("../lib/TestRng")
local Tol = require("../lib/Tol")
local Edges = require("../fixtures/Edges")
local H = require("./MinigamesHelpers")
local MF = require("../../src/shared/Definitions/MinigameFamilies")
local DT = require("../../src/shared/Definitions/Types")
local Bots = require("../../src/shared/Minigames/Bots")
local Input = require("../../src/shared/Minigames/Input")
local Minigames = require("../../src/shared/Minigames/Minigames")
local Params = require("../../src/shared/Minigames/Params")
local PrecisionTrace = require("../../src/shared/Minigames/PrecisionTrace")
local Timeline = require("../../src/shared/Minigames/Timeline")
local TimingStrike = require("../../src/shared/Minigames/TimingStrike")
local Types = require("../../src/shared/Minigames/Types")

-- Through a cast, so luau-lsp stays out of the prototype's loose types: it is reference data, not game code.
local ProtoBots: any = (require :: any)("../../docs/spec/prototypes/S3/v2/Bots")
local ProtoRng: any = (require :: any)("../../docs/spec/prototypes/S3/v2/Rng")

type StepSpec = Types.StepSpec
type Recorder = Types.Recorder

local OFFSETS = { -120, -60, 0, 60, 120 }
local EVAL = PrecisionTrace.PT_EVAL_MS
local HZ: DT.FamilyId = "HoldZone"
local TS: DT.FamilyId = "TimingStrike"

-- a spec with only what the Recorder reads: the family and the duration
local function specOf(family: DT.FamilyId, durationMs: number): StepSpec
	return {
		family = family,
		seed = 1,
		params = {},
		source = nil,
		durationMs = durationMs,
		countdownMs = 3000,
		patternHash = 0,
		balanceVersion = 1,
	}
end

-- a press of the button at ms t exactly (D7: clockS = (t + 0.5)/1000, frameDtS = 0), released 1 ms later
local function pressAt(rec: Recorder, t: number)
	rec:button(true, (t + 0.5) / 1000, 0)
	rec:button(false, (t + 1.5) / 1000, 0)
end

-- the step's records decode, and the judge plays them: Ok (an honest timeline is never refused)
local function judgedOk(spec: StepSpec, pattern: any, records: { any }, what: string): Types.MinigameResult
	local result = Minigames.judge(spec, pattern, Minigames.encode(spec, records), 0)
	A.eq(result.status, "Ok", what .. ": judged Ok")
	return result
end

-- T-MG-15 with bots on n runs: Elite@240 and Good unflagged at every offset, TimingStrike Iron/Normal at BOT_REF_X,
-- the pinned names "T-MG-15 <profile> <offset>" (D11; precomputed on the S3 prototype: 0 of 1,000 at every offset)
local function tmg15(n: number)
	local players: { { name: string, profile: string, fps: number? } } =
		{ { name = "Elite@240", profile = "Elite", fps = 240 }, { name = "Good", profile = "Good", fps = nil } }
	for _, pl in players do
		for _, offset in OFFSETS do
			local name = string.format("T-MG-15 %s %d", pl.name, offset)
			local _, _, flagged = Bots.run({ family = "TimingStrike", material = "Iron", tier = "Normal", profile = pl.profile,
				fps = pl.fps, offsetMs = offset, n = n, salt = H.configSalt(name) })
			for i = 1, n do
				A.falsy(flagged[i], name .. ": run " .. i .. " flagged")
			end
		end
	end
end
local T_MG_15_FAST = 20 -- runs per profile and offset in the quick run (L5's 3 s share; the slow case runs 1,000)

-- a property case at PROP_N_FAST cases in the quick run and PROP_N under t.slow
local function sized(t: Test.Api, name: string, body: (n: number) -> ())
	t.it(name, function()
		body(Tol.PROP_N_FAST)
	end)
	t.slow(name .. " (PROP_N cases)", function()
		body(Tol.PROP_N)
	end)
end

return Test.suite("Minigames/Input", function(t)
	t.it("Input.new takes a minigame family, an integer timing offset and a finite GO clock", function()
		local rec = Input.new(specOf("HoldZone", 15000), 0, 12.5)
		for _, name in { "go", "button", "cursor", "release", "records", "horizonMs", "since" } do
			A.eq(type((rec :: any)[name]), "function", name)
		end
		A.throws(function()
			Input.new(specOf("RhythmSequence", 15000), 0, 0)
		end, "no input rule")
		A.throws(function()
			Input.new(specOf("TimingStrike", 15000), 12.5, 0)
		end, "integer")
		A.throws(function()
			Input.new(specOf("TimingStrike", 15000), 0 / 0, 0)
		end, "integer")
		A.throws(function()
			Input.new(specOf("TimingStrike", 15000), 0, math.huge)
		end, "finite")
	end)

	t.it("stamps (§6.6): a button at its frame's centre and a trace sample at its frame, from GO, floored at 0", function()
		local rec = Input.new(specOf("HoldZone", 15000), 0, 100)
		rec:button(true, 100.5, 0.016) -- before go: ignored (countdown)
		rec:go(false)
		rec:button(true, 100.003, 0.016) -- 3 − 8 ms: 0
		rec:button(false, 101, 0.016) -- 1000 − 8
		rec:button(true, 101.2504, 0.0331) -- floor(1250.4 − 16.55)
		A.deepEq(rec:records(), { { t = 0, down = true }, { t = 992, down = false }, { t = 1233, down = true } })
		local trace = Input.new(specOf("PrecisionTrace", 15000), 0, 100)
		trace:go(true, 1, 0.5)
		trace:cursor(1, 0.5, true, 100.0209)
		trace:cursor(1, 0.5, true, 100.0659)
		A.deepEq({ trace:records()[2].t, trace:records()[3].t }, { 20, 65 }, "floor((clock − go)·1000)")
	end)

	t.it("D7: an exact time t passed as clockS = (t + 0.5)/1000 with frameDtS = 0 records t, where t/1000 would not", function()
		-- (t/1000)·1000 falls one ulp below t for 372 integers t ≤ 60000; every one of them is tried, and a 7th of
		-- the others
		local spec = specOf("TimingStrike", 60001)
		local rec = Input.new(spec, 0, 0)
		rec:go(false)
		local count, below, n = 0, 0, 0
		for tt = 0, 60000 do
			local short = (tt / 1000) * 1000 < tt
			if short or tt % 7 == 0 then
				if n == MF.MAX_RECORDS[TS] then
					rec = Input.new(spec, 0, 0)
					rec:go(false)
					n = 0
				end
				pressAt(rec, tt)
				n += 1
				A.eq(rec:since(n - 1)[1], tt, "the exact clock of " .. tt)
				count += 1
				below += if short then 1 else 0
			end
		end
		A.eq(below, 372, "the integers where t/1000 falls short")
		A.truthy(count > 8800, "about 8,900 times tried")
		local naive = Input.new(spec, 0, 0)
		naive:go(false)
		naive:button(true, 1001 / 1000, 0)
		A.eq(naive:records()[1], 1000, "t/1000 records 1001 one ms early: why D7's clocks exist")
	end)

	t.it("the stamps are the S3 prototype bots' on random frames: floor(f − dt/2) for a press, floor(f) for a sample", function()
		-- slice 8's bots drive this Recorder; the prototype stamped its records itself (Bots.stamp, ptHuman)
		local r = ProtoRng.Rng.new(7, "input-stamps")
		local checked = 0
		for run = 1, 12 do
			local fps = ({ 30, 60, 144, 240 })[(run - 1) % 4 + 1]
			local frames = ProtoBots.frames(r, 4000, fps, 0.01)
			local zone = Input.new(specOf("HoldZone", 1000000), 0, 0)
			local trace = Input.new(specOf("PrecisionTrace", 1000000), 0, 0)
			zone:go(false)
			trace:go(false, 0, 0)
			-- the prototype's ptHuman: a sample at the first frame with floor(f) ≥ nextDue, then nextDue past it
			local protoTimes: { number } = {}
			local nextDue = 0
			for k, f in ipairs(frames) do
				local dt = if k > 1 then f - frames[k - 1] else f
				zone:button(k % 2 == 1, f / 1000, dt / 1000)
				A.eq(zone:since(k - 1)[1].t, ProtoBots.stamp(frames, k), "a press delivered at frame " .. k)
				trace:cursor(0, 0, true, f / 1000)
				local fm = math.floor(f)
				if fm >= nextDue then
					table.insert(protoTimes, fm)
					while nextDue <= fm do
						nextDue += 20
					end
				end
				checked += 1
			end
			-- the Recorder's first sample is GO's (t = 0, I7); after it, the prototype's samples from 20 ms on
			local times: { number } = {}
			for i, sample in ipairs(trace:records()) do
				if i > 1 then
					table.insert(times, sample.t)
				end
			end
			local expected: { number } = {}
			for _, tt in ipairs(protoTimes) do
				if tt >= 20 then
					table.insert(expected, tt)
				end
			end
			A.deepEq(times, expected, "the trace's sample times at " .. fps .. " fps")
		end
		A.truthy(checked > 3000, "frames checked")
	end)

	t.it("T-MG-15: a TimingStrike press stamped t records max(0, t − timingOffsetMs); HoldZone and the trace ignore the offset", function()
		for _, offset in OFFSETS do
			local ts = Input.new(specOf("TimingStrike", 15000), offset, 0)
			ts:go(false)
			for _, tt in { 30, 119, 121, 1000, 5000 } do
				pressAt(ts, tt)
			end
			local expected: { number } = {}
			for _, tt in { 30, 119, 121, 1000, 5000 } do
				table.insert(expected, math.max(0, tt - offset))
			end
			A.deepEq(ts:records(), expected, "offset " .. offset .. ": presses in the first offset ms floor to 0")
			-- a press whose frame's centre falls before GO is stamped 0 first, then offset (§6.6's order)
			local early = Input.new(specOf("TimingStrike", 15000), offset, 0)
			early:go(false)
			early:button(true, 0.003, 0.016)
			A.deepEq(early:records(), { math.max(0, 0 - offset) }, "offset " .. offset .. ": max(0, max(0, 3 − 8) − offset)")
			local zone = Input.new(specOf("HoldZone", 15000), offset, 0)
			local trace = Input.new(specOf("PrecisionTrace", 15000), offset, 0)
			zone:go(true)
			trace:go(true, 1, 0.5)
			for _, tt in { 30, 119, 1000, 5000 } do
				zone:button(false, (tt + 0.5) / 1000, 0)
				zone:button(true, (tt + 2.5) / 1000, 0)
				trace:cursor(1.5, 0.25, true, (tt + 0.5) / 1000)
			end
			A.deepEq(zone:records(), { { t = 0, down = true }, { t = 30, down = false }, { t = 32, down = true },
				{ t = 119, down = false }, { t = 121, down = true }, { t = 1000, down = false },
				{ t = 1002, down = true }, { t = 5000, down = false }, { t = 5002, down = true } },
				"HoldZone at offset " .. offset)
			A.eq(#trace:records(), 5, "the trace at offset " .. offset)
			A.deepEq(trace:records()[3], { t = 119, u = 24576, v = 4096, grind = true }, "the trace at offset " .. offset)
		end
	end)

	t.it("T-MG-15: the unquantized Exact presses err by −offset at every offset: TsLowVariance always, TsExactHits only at 0", function()
		local spec, P = H.prepared("TimingStrike", "Iron", "Normal", 0, 1)
		for _, offset in OFFSETS do
			local rec = Input.new(spec, offset, 0)
			rec:go(false)
			for _, c in ipairs(P.cycles) do
				pressAt(rec, c.target)
			end
			local records = rec:records()
			local errs = TimingStrike.judgeErrors(P, records)
			A.eq(#errs, #P.cycles, "every press judged (|offset| ≤ M)")
			for _, e in ipairs(errs) do
				A.eq(e, -offset, "each error is −offset")
			end
			local result = judgedOk(spec, P, records, "offset " .. offset)
			A.deepEq(result.flags, if offset == 0 then { "TsExactHits", "TsLowVariance" } else { "TsLowVariance" },
				"offset " .. offset .. ": a shift moves every error alike")
			A.eq(result.score, math.min(result.rawScore, spec.params.passThreshold), "clamped at the pass line")
		end
	end)

	t.it("T-MG-15 with bots: Elite@240 and Good stay unflagged at every timing offset (20 runs each)", function()
		tmg15(T_MG_15_FAST)
	end)

	t.slow("T-MG-15 with bots: Elite@240 and Good stay unflagged at every timing offset (1,000 runs each)", function()
		tmg15(1000)
	end)

	t.it("T-MG-16: releases always recorded on focus loss or menu, once, and a held button counts only after a new press", function()
		local specZ, Z = H.prepared("HoldZone", "Iron", "Normal", 0, 1)
		-- go held, then focus lost: an up at the latest known time
		local a = Input.new(specZ, 0, 0)
		a:go(true)
		a:horizonMs(0.5, 0.016)
		a:release()
		A.deepEq(a:records(), { { t = 0, down = true }, { t = 492, down = false } }, "go(true), release()")
		-- press, release(), then the physical up: one up, not two
		local b = Input.new(specZ, 0, 0)
		b:go(false)
		b:button(true, 1.0, 0)
		b:release()
		b:button(false, 1.2, 0)
		A.deepEq(b:records(), { { t = 1000, down = true }, { t = 1000, down = false } }, "button, release, button(false)")
		-- release() while up records nothing; after release a held key counts only through a new press
		b:release()
		A.eq(#b:records(), 2, "release() while up")
		b:button(true, 1.5, 0)
		A.deepEq(b:records()[3], { t = 1500, down = true }, "a new press after the release")
		-- TimingStrike: release() lets the next press count
		local specT, T = H.prepared("TimingStrike", "Iron", "Normal", 0, 1)
		local c = Input.new(specT, 0, 0)
		c:go(true) -- held through GO: no strike (D9)
		c:button(true, 0.4, 0)
		A.eq(#c:records(), 0, "a key held through GO is no press")
		c:release()
		c:button(true, 0.4895, 0)
		A.deepEq(c:records(), { 489 }, "release() lets the next press count")
		-- PrecisionTrace records nothing on release() (nor on a button)
		local specP, Pt = H.prepared("PrecisionTrace", "Iron", "Normal", 0, 1, Edges.arming)
		local d = Input.new(specP, 0, 0)
		d:go(true, 1, 0.5)
		d:release()
		d:button(true, 0.3, 0.016)
		d:release()
		A.eq(#d:records(), 1, "the trace records nothing on release")
		-- every resulting timeline decodes and judges Ok
		judgedOk(specZ, Z, a:records(), "HoldZone a")
		judgedOk(specZ, Z, b:records(), "HoldZone b")
		judgedOk(specT, T, c:records(), "TimingStrike")
		judgedOk(specP, Pt, d:records(), "PrecisionTrace")
	end)

	t.it("HoldZone: OR-state changes only, up to MAX_RECORDS (no press at MAX_RECORDS − 1); none past durationMs or before go", function()
		local spec = specOf("HoldZone", 30000)
		local rec = Input.new(spec, 0, 0)
		rec:button(true, 0.1, 0)
		A.eq(#rec:records(), 0, "before go")
		rec:go(false)
		rec:button(false, 0.1, 0)
		rec:button(true, 0.2, 0)
		rec:button(true, 0.3, 0)
		A.eq(#rec:records(), 1, "changes only")
		rec:button(false, 0.4, 0)
		local max = MF.MAX_RECORDS[HZ]
		local tt = 1
		while #rec:records() < max - 2 do
			rec:button(true, tt / 1000, 0)
			rec:button(false, (tt + 0.5) / 1000, 0)
			tt += 1
		end
		rec:button(true, 25, 0)
		A.eq(#rec:records(), max - 1, "a press at MAX_RECORDS − 2 records")
		rec:button(false, 25.1, 0)
		A.eq(#rec:records(), max, "its release fits")
		rec:button(true, 26, 0)
		rec:button(false, 26.1, 0)
		A.eq(#rec:records(), max, "no press at MAX_RECORDS")
		local late = Input.new(spec, 0, 0)
		late:go(false)
		late:button(true, 29.9995, 0)
		late:button(false, 30.0015, 0)
		late:button(true, 30.1, 0)
		A.deepEq(late:records(), { { t = 29999, down = true } }, "past durationMs dropped; the timeline may end down")
		late:horizonMs(30.1, 0)
		late:release()
		A.eq(#late:records(), 1, "nor a release past the end")
		A.eq(#Timeline.decode(Timeline.encode("HoldZone", 30000, 0, rec:records()), "HoldZone", 30000) :: { any },
			max, "the capped timeline decodes")
	end)

	t.it("TimingStrike: presses only, a held key does not repeat (D9), none past MAX_RECORDS or durationMs", function()
		local spec = specOf("TimingStrike", 20000)
		local rec = Input.new(spec, 0, 0)
		rec:go(false)
		rec:button(true, 1, 0)
		rec:button(true, 1.1, 0)
		rec:button(false, 1.2, 0)
		rec:button(false, 1.3, 0)
		A.deepEq(rec:records(), { 1000 }, "one press per up → down")
		for i = 1, 600 do
			pressAt(rec, 1000 + 10 * i)
		end
		A.eq(#rec:records(), MF.MAX_RECORDS[TS], "dropped past MAX_RECORDS")
		local late = Input.new(spec, -100, 0)
		late:go(false)
		pressAt(late, 19950)
		A.deepEq(late:records(), {}, "19950 + 100 is past durationMs: dropped")
	end)

	t.it("PrecisionTrace: the cursor at GO, then one sample at the first frame at or after each due time, in the panel", function()
		local spec = specOf("PrecisionTrace", 1000)
		local rec = Input.new(spec, 0, 0)
		rec:cursor(1, 0.5, true, 0.01)
		A.eq(#rec:records(), 0, "before go")
		A.throws(function()
			rec:go(false)
		end, "needs the cursor")
		rec:go(false, 1, 0.5) -- grind = held when nil
		rec:go(true, 2, 0.5) -- a second go: ignored
		local grinding = Input.new(spec, 0, 0)
		grinding:go(false, 1, 0.5, true)
		A.eq(grinding:records()[1].grind, true, "go's grind flag wins over held")
		local lifted = Input.new(spec, 0, 0)
		lifted:go(true, 1, 0.5, false)
		A.eq(lifted:records()[1].grind, false, "a held button with grinding toggled off")
		rec:cursor(1.1, 0.5, true, 0.019) -- before the due time 20
		rec:cursor(1.2, 0.5, true, 0.0335) -- 33: recorded, due 40
		rec:cursor(1.3, 0.5, false, 0.039)
		rec:cursor(1.4, 0.5, false, 0.040) -- 40
		rec:cursor(1.5, 0.5, true, 0.099) -- 99: due 100
		rec:cursor(-5, 7, true, 0.1) -- out of the panel: clamped
		rec:cursor(0 / 0, 0 / 0, true, 0.12) -- NaN reads 0
		rec:cursor(3.00002, 1.00002, true, 0.14) -- rounds to the panel's edge
		rec:button(true, 0.15, 0.016)
		rec:cursor(1, 0.5, true, 1.0005) -- 1000 = durationMs: recorded
		rec:cursor(1, 0.5, true, 1.0205) -- past the end
		A.deepEq(rec:records(), {
			{ t = 0, u = 16384, v = 8192, grind = false },
			{ t = 33, u = 19661, v = 8192, grind = true },
			{ t = 40, u = 22938, v = 8192, grind = false },
			{ t = 99, u = 24576, v = 8192, grind = true },
			{ t = 100, u = 0, v = 16384, grind = true },
			{ t = 120, u = 0, v = 0, grind = true },
			{ t = 140, u = 49152, v = 16384, grind = true },
			{ t = 1000, u = 16384, v = 8192, grind = true },
		})
		A.deepEq(Timeline.decode(Minigames.encode(spec, rec:records()), "PrecisionTrace", 1000), rec:records(),
			"the trace decodes")
	end)

	t.it("the horizon (D4): the latest button stamp asked for, TimingStrike's minus the offset; later records never before it", function()
		local zone = Input.new(specOf("HoldZone", 15000), 60, 0)
		A.eq(zone:horizonMs(1, 0.016), 0, "before go")
		zone:go(false)
		A.eq(zone:horizonMs(1, 0.016), 992, "HoldZone: the frame's centre (no offset)")
		A.eq(zone:horizonMs(0.5, 0.016), 992, "never back")
		zone:button(true, 0.9, 0) -- stamped 900, recorded at the horizon
		A.deepEq(zone:records(), { { t = 992, down = true } }, "clamped to the horizon")
		local ts = Input.new(specOf("TimingStrike", 15000), 60, 0)
		ts:go(false)
		A.eq(ts:horizonMs(1, 0.016), 932, "TimingStrike: minus the offset")
		pressAt(ts, 950) -- 950 − 60 = 890 < 932
		A.deepEq(ts:records(), { 932 }, "clamped to the horizon")
		local trace = Input.new(specOf("PrecisionTrace", 15000), 0, 0)
		trace:go(true, 1, 0.5)
		trace:cursor(1, 0.5, true, 0.0255)
		A.eq(trace:horizonMs(0.0405, 0.016), 25, "the trace: its latest record")
	end)

	t.it("D4's reason: with timingOffsetMs +120 a host advancing to the raw frame time misses a press the replay judges", function()
		-- E-S3.4's pattern: span 1 is T_1 ± M = 489 ± 200, W = 110. The press is physically at T_1 + M + 15 = 704, its
		-- frame's centre 699, recorded at 579 with the offset: error +90, inside W. A raw-clock host has already closed
		-- span 1 at the frame before it (694 > 689); the horizon host had advanced only to 689 − 120 = 569
		local spec, P = H.prepared("TimingStrike", "Iron", "Normal", 0, 1)
		local frames: { number } = {}
		for f = 4, 2000, 10 do
			table.insert(frames, f)
		end
		local opts = { frames = frames, offsetMs = 120, buttons = { { t = 704, down = true }, { t = 760, down = false } } }
		local horizon = H.play(spec, P, opts)
		local raw = H.play(spec, P, { frames = frames, offsetMs = 120, buttons = opts.buttons, rawClock = true })
		A.deepEq(horizon.records, { 579 }, "the press, stamped at its frame's centre (704 − 5) less 120")
		local judged = Minigames.judge(spec, P, Minigames.encode(spec, horizon.records), 0)
		A.eq(judged.breakdown.judged, 1, "the replay judges it")
		A.truthy(judged.rawScore > 0, "for points")
		A.eq(horizon.finish.score, judged.rawScore, "advancing to the horizon: live = replay")
		A.deepEq(horizon.finish.breakdown, judged.breakdown, "the same breakdown")
		A.eq(raw.finish.breakdown.judged, 0, "the raw clock closed span 1 first: the press is a whiff")
		A.truthy(raw.finish.score < judged.rawScore, "and the client's score falls short of the server's")
	end)

	t.it("records() is a frozen copy and since(count) the records after count; every record is frozen", function()
		local rec = Input.new(specOf("HoldZone", 15000), 0, 0)
		rec:go(true)
		rec:button(false, 0.1, 0)
		local r1 = rec:records()
		A.truthy(table.isfrozen(r1), "frozen")
		A.truthy(table.isfrozen(r1[1]) and table.isfrozen(r1[2]), "records frozen")
		rec:button(true, 0.2, 0)
		A.eq(#r1, 2, "a copy")
		A.eq(#rec:since(3), 0, "nothing new")
		A.deepEq(rec:since(1), { { t = 100, down = false }, { t = 200, down = true } }, "since(1)")
		A.deepEq(rec:since(0), rec:records(), "since(0)")
		A.eq(rec:since(3), rec:since(5), "no table per frame when nothing is new")
	end)

	sized(t, "the host loop (§12.5, D4) finishes as the judge: random frames, offsets, focus losses, inputs after the last frame", function(n: number)
		Prop.check(n, function(rng: TestRng.TestRng): { family: DT.FamilyId, seed: number, run: number }
			local family: DT.FamilyId = H.FAMILIES[rng:int(1, 3)]
			return { family = family, seed = rng:u32(), run = rng:u32() }
		end, function(c: { family: DT.FamilyId, seed: number, run: number })
			local rng = TestRng.new(c.run)
			local material: DT.MaterialId = H.MATERIALS[rng:int(1, 2)]
			local tier: DT.TierId = H.TIERS[rng:int(1, 2)]
			local spec, P = H.prepared(c.family, material, tier, rng:pick(H.XS), c.seed, Edges.arming)
			local D = spec.durationMs
			local frames = H.frames(rng, D, rng:pick({ 4, 16, 33 }), 34, 120)
			local buttons: { H.Action } = {}
			local releases: { number } = {}
			local cursor: ((number) -> (number, number, boolean))? = nil
			if c.family == "TimingStrike" then
				for _, cy in ipairs((P :: TimingStrike.Pattern).cycles) do
					local at = cy.target + rng:range(-40, 160)
					table.insert(buttons, { t = at, down = true })
					table.insert(buttons, { t = at + rng:range(30, 90), down = false })
				end
			elseif c.family == "HoldZone" then
				local at = rng:range(0, 300)
				while at < D + 50 do
					table.insert(buttons, { t = at, down = true })
					at += rng:range(20, 150)
					table.insert(buttons, { t = at, down = false })
					at += rng:pick({ 40, 120, 250, 400 })
				end
			else
				local Pt = P :: PrecisionTrace.Pattern
				local lag, noise = rng:range(-150, 150), rng:pick({ 0, 0.01, 0.05 })
				local lift = rng:range(0, D)
				cursor = function(f: number): (number, number, boolean)
					local u, v = PrecisionTrace.pointAt(Pt, PrecisionTrace.pacerArc(Pt, f - lag))
					local wobble = noise * (((f * 7) // 13) % 5 - 2) / 2
					return u + wobble, v - wobble, f < lift or f > lift + 300
				end
			end
			table.sort(buttons, function(a: H.Action, b: H.Action): boolean
				return a.t < b.t
			end)
			for _ = 1, rng:int(0, 3) do
				table.insert(releases, rng:range(0, D))
			end
			table.sort(releases)
			local played = H.play(spec, P, { frames = frames, offsetMs = rng:pick({ -120, -35, 0, 35, 120 }),
				heldAtGo = rng:int(1, 4) == 1, buttons = buttons, releases = releases, cursor = cursor, viewEvery = 50 })
			local judged = judgedOk(spec, P, played.records, c.family)
			A.eq(played.finish.score, judged.rawScore, "the client's finish = the judge's rawScore, bit for bit")
			A.deepEq(played.finish.breakdown, judged.breakdown, "the same breakdown")
			A.deepEq(Minigames.replay(spec, P, played.records), judged, "replay = judge")
			-- the live score after the last tick is the score (O14)
			A.eq(Minigames.get(c.family).view(played.session, D).runningScore, judged.rawScore, "the live score ends at the score")
		end)
	end)

	t.it("the host loop pushes once more before finish: a down the last scored tick reads, made after the last frame", function()
		local spec, P = H.prepared("HoldZone", "Iron", "Normal", 0, 1)
		local D = spec.durationMs
		-- 30 fps frames ending at D − 15: a press at D − 12, delivered at GO + D, is stamped D − 12 − dt/2 and read by
		-- the last tick (D − 10); only the final push shows it to the client's session
		local frames: { number } = {}
		local f = D - 15
		while f > 0 do
			table.insert(frames, 1, f)
			f -= 33.25
		end
		local buttons: { H.Action } = { { t = D - 12, down = true } }
		local played = H.play(spec, P, { frames = frames, buttons = buttons })
		local skipped = H.play(spec, P, { frames = frames, buttons = buttons, skipFinalPush = true })
		A.eq(#played.records, 1, "one down")
		local t1 = played.records[1].t
		-- after the last frame's horizon (its centre, D − 15 − 16.6), so its tick was not integrated live; at or before
		-- the last tick's time (D − 10), so the last tick reads it
		A.truthy(t1 > math.floor(frames[#frames] - (frames[#frames] - frames[#frames - 1]) / 2) and t1 <= D - 10,
			"made after the last frame's push, read by the last tick: " .. t1)
		local judged = judgedOk(spec, P, played.records, "HoldZone")
		A.eq(judged.breakdown.strokes, 1, "the stroke counts")
		A.eq(played.finish.score, judged.rawScore, "live = replay")
		A.deepEq(played.finish.breakdown, judged.breakdown, "the same breakdown")
		A.eq(skipped.finish.breakdown.strokes, 0, "without the final push the client's session never sees it")
	end)

	sized(t, "L6: no Recorder makes more than floor(durationMs / PT_EVAL_MS) + 1 trace records (frames 1–100 ms, hitches, focus losses)", function(n: number)
		-- every MVP tier's longest step: leadInMs + PT_TRAVEL_MAX_MS + tailMs
		local longest = 0
		for mi = 1, #H.MATERIALS do
			local material: DT.MaterialId = H.MATERIALS[mi]
			for ti = 1, #H.TIERS do
				local tier: DT.TierId = H.TIERS[ti]
				for _, x in { 0, 1 } do
					local p = Params.resolve("PrecisionTrace", material, tier, Params.refFactors(x))
					longest = math.max(longest, p.leadInMs + PrecisionTrace.PT_TRAVEL_MAX_MS + p.tailMs)
				end
			end
		end
		A.eq(longest, 31000, "the longest MVP trace step")
		A.eq(math.floor(longest / EVAL) + 1, 1551, "§6.6's 1,551")
		type Case = { durationMs: number, step: number, phase: number, hitchRate: number, seed: number }
		Prop.check(n, function(rng: TestRng.TestRng): Case
			return {
				durationMs = if rng:int(1, 2) == 1 then longest else rng:int(0, longest),
				step = rng:range(1, 100),
				phase = rng:float(),
				hitchRate = rng:pick({ 0, 0.01, 0.1 }),
				seed = rng:u32(),
			}
		end, function(c: Case)
			local rng = TestRng.new(c.seed)
			local spec = specOf("PrecisionTrace", c.durationMs)
			local rec = Input.new(spec, 0, 1000)
			local f = c.phase * c.step
			local first = true
			while f <= c.durationMs + 300 do
				local clock = 1000 + f / 1000
				if first then
					rec:go(rng:int(1, 2) == 1, rng:range(-1, 4), rng:range(-1, 2))
					first = false
				end
				if rng:int(1, 200) == 1 then
					rec:release()
				end
				if rng:int(1, 20) == 1 then
					rec:button(rng:int(1, 2) == 1, clock, c.step / 1000)
				end
				rec:cursor(rng:range(-1, 4), rng:range(-1, 2), rng:int(1, 8) > 1, clock)
				if rng:int(1, 3) == 1 then
					rec:horizonMs(clock, c.step / 1000)
				end
				f += math.max(0.01, c.step + rng:range(-1, 1)) + (if rng:float() < c.hitchRate then rng:range(0, 250) else 0)
			end
			local records = rec:records()
			A.truthy(#records <= math.floor(c.durationMs / EVAL) + 1, string.format("%d records over %d ms",
				#records, c.durationMs))
			local back = Timeline.decode(Minigames.encode(spec, records), "PrecisionTrace", c.durationMs)
			A.eq(#(back :: { any }), #records, "decode accepts every record")
			-- the proof's invariant: GO's record at t = 0, then each record in a later 20 ms slot than the one before
			A.eq(records[1].t, 0, "GO's record")
			for i = 2, #records do
				A.truthy(math.floor(records[i].t / EVAL) > math.floor(records[i - 1].t / EVAL), "record " .. i
					.. " in a later slot")
			end
		end)
		-- and on real steps, the judge never refuses an honest trace as TooMany
		local rng = TestRng.new(0x16C0DE)
		for k = 1, math.max(1, n // 25) do
			local tier: DT.TierId = H.TIERS[rng:int(1, 2)]
			local e: Edges.Edge = (Edges :: any)[Edges.order[rng:int(1, #Edges.order)]]
			local spec, P = H.prepared("PrecisionTrace", "Iron", tier, rng:pick(H.XS), rng:u32(), e)
			local played = H.play(spec, P, { frames = H.frames(rng, spec.durationMs, 1, 3, 250), cursor = function(f: number)
				local u, v = PrecisionTrace.pointAt(P, PrecisionTrace.pacerArc(P, f))
				return u, v, true
			end })
			A.truthy(#played.records <= Minigames.recordCap(spec), "within the cap, run " .. k)
			judgedOk(spec, P, played.records, "a real step at 1–3 ms frames, run " .. k)
		end
	end)
end)
