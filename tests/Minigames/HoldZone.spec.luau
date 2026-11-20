--!strict
-- Minigames/HoldZone (SPEC §6.8, §6.14, §10.6, §16.20, E-S3.7; T-MG-13 (a)): E-S3.7's golden pattern and hash, the
-- 300 ms taps that overheat, the stroke curves (steady temperature per tap rate, the climb from cold, one stroke from
-- rest), holding alone scores 0 (§6.8, Q15's reason for strokes), the session's key pointer = the stateless centerAt on
-- every tick, HzInhumanRate at 29 and 30 presses (it counts downs, not ups), feedback and views (the live score, O14),
-- live = replay, and the S3 prototype's generate, session sums and checks bit for bit (M4's D1).

local Test = require("../lib/Test")
local A = require("../lib/Assert")
local Prop = require("../lib/Prop")
local TestRng = require("../lib/TestRng")
local Tol = require("../lib/Tol")
local DT = require("../../src/shared/Definitions/Types")
local Checks = require("../../src/shared/Minigames/Checks")
local HoldZone = require("../../src/shared/Minigames/HoldZone")
local Params = require("../../src/shared/Minigames/Params")
local Types = require("../../src/shared/Minigames/Types")

-- Through a cast, so luau-lsp stays out of the prototype's loose types: it is reference data, not game code.
local Proto: any = (require :: any)("../../docs/spec/prototypes/S3/v2/HoldZone")

type Pattern = HoldZone.Pattern
type Session = HoldZone.Session
type HoldRecord = Types.HoldRecord
type FeedbackEvent = Types.FeedbackEvent
type FlagId = Types.FlagId
type MinigameResult = Types.MinigameResult

local MATERIALS: { DT.MaterialId } = { "Iron", "Steel" }
local TIERS: { DT.TierId } = { "Normal", "Hard", "Expert", "Master", "Hell" }

local function paramsOf(material: DT.MaterialId, tier: DT.TierId, x: number): { [string]: number }
	return Params.resolve("HoldZone", material, tier, Params.refFactors(x))
end

-- the judge's path without the facade (slice 7): push every record, finish, checks
local function replay(P: Pattern, records: { HoldRecord }): (MinigameResult, { FlagId })
	local S = HoldZone.newSession(P)
	for _, e in ipairs(records) do
		HoldZone.push(S, e)
	end
	local result = HoldZone.finish(S)
	return result, HoldZone.checks(P, records, result)
end

-- golden.luau's flat stroke-model pattern: the zone at 0.5 for 60 s, no ramp
local function flat(durationMs: number): Pattern
	return { p = paramsOf("Iron", "Normal", 0), keysT = { 0, 60000 }, keysC = { 0.5, 0.5 }, durationMs = durationMs,
		rampMs = 0, hash = 0 }
end

-- a session with its per-tick history, every `period` ms a stroke of `pressMs`, advanced to `untilMs`
local function strokes(P: Pattern, period: number, pressMs: number, untilMs: number): Session
	local S = HoldZone.newSession(P)
	S.hist = { T = {}, C = {} }
	local t = 0
	while t < untilMs do
		HoldZone.push(S, { t = t, down = true })
		HoldZone.push(S, { t = t + pressMs, down = false })
		t += period
	end
	HoldZone.advance(S, untilMs)
	return S
end

-- printed to `dp` decimals in the evidence: within half a unit of the last printed digit
local function printed(actual: number, expected: number, dp: number, what: string)
	local unit = 1
	for _ = 1, dp do
		unit /= 10
	end
	A.near(actual, expected, unit / 2 * (1 + 1e-9) + 1e-12, what)
end

local function kinds(events: { FeedbackEvent }): string
	local out: { string } = {}
	for _, e in ipairs(events) do
		table.insert(out, e.kind)
	end
	return table.concat(out, " ")
end

-- a property case at PROP_N_FAST cases in the quick run, and at PROP_N under t.slow (M4's L1 share, D10)
local function sized(t: Test.Api, name: string, body: (n: number) -> ())
	t.it(name, function()
		body(Tol.PROP_N_FAST)
	end)
	t.slow(name .. " (PROP_N cases)", function()
		body(Tol.PROP_N)
	end)
end

-- random OR-state changes: taps of any period and length, now and then a burst, from GO to the end
local function tapStream(rng: TestRng.TestRng, durationMs: number): { HoldRecord }
	local out: { HoldRecord } = {}
	local t = if rng:int(1, 4) == 1 then 0 else rng:int(0, 2000)
	local period = rng:pick({ 25, 33, 90, 180, 260, 400, 900 })
	while t < durationMs - 1 do
		local press = rng:int(1, math.max(1, period - 1))
		table.insert(out, { t = t, down = true })
		local up = t + press
		if up >= durationMs then
			break
		end
		table.insert(out, { t = up, down = false })
		t = up + rng:int(1, period)
		if rng:int(1, 20) == 1 then
			period = rng:pick({ 25, 33, 90, 180, 260, 400, 900 })
		end
	end
	return out
end

return Test.suite("Minigames/HoldZone", function(t)
	t.it("HoldZone is §6.2's FamilyModule: id, generate, hash, newSession, push, advance, view, finish, checks", function()
		-- typed: luau-lsp checks the module against the facade's type (a wider table, by width subtyping)
		local F: Types.FamilyModule<Pattern, HoldRecord, Session, Types.HoldZoneView> = HoldZone
		A.eq(F.id, "HoldZone")
		for _, name in { "generate", "hash", "newSession", "push", "advance", "view", "finish", "checks" } do
			A.eq(type((F :: any)[name]), "function", name)
		end
		A.eq(HoldZone.HZ_TICK_MS, 10)
	end)

	t.it("T-MG-13 E-S3.7's golden: seed 1, Iron/Normal, x = 0, its keys and hash; 300 ms taps overheat (score 0)", function()
		local P = HoldZone.generate(1, paramsOf("Iron", "Normal", 0))
		A.eq(#P.keysT, 10, "10 keys")
		A.eq(#P.keysC, 10)
		local first = { { 0, 0.6323 }, { 3000, 0.6323 }, { 5060, 0.4000 }, { 7180, 0.6523 }, { 9060, 0.4000 } }
		for i, k in ipairs(first) do
			A.eq(P.keysT[i], k[1], "key time " .. i)
			printed(P.keysC[i], k[2], 4, "key centre " .. i)
		end
		A.eq(P.hash, 0x4E2677F2, "hash")
		A.eq(HoldZone.hash(P), P.hash)
		A.eq(P.durationMs, 15000)
		A.eq(P.rampMs, 3000)
		A.truthy(P.keysT[#P.keysT] >= P.durationMs and P.keysT[#P.keysT - 1] < P.durationMs, "keys until t ≥ durationMs")
		-- golden.luau: from GO, a press of 80 ms every 300 ms: steady T 0.854, above the whole zone
		local taps: { HoldRecord } = {}
		local tt = 0
		while tt + 80 < P.durationMs do
			table.insert(taps, { t = tt, down = true })
			table.insert(taps, { t = tt + 80, down = false })
			tt += 300
		end
		local result, flags = replay(P, taps)
		A.eq(result.score, 0, "score 0.0000")
		A.eq(result.breakdown.inZone, 0, "inZone 0.0000")
		A.eq(result.breakdown.strokes, 50, "every down a stroke")
		A.deepEq(flags, {}, "3.3 presses a second are human")
	end)

	t.it("E-S3.7's stroke curves: steady temperature per tap rate, the climb from cold, one stroke from rest", function()
		-- golden.luau: full strokes (50 ms presses) every P ms on the flat 60 s pattern; T's mean and ripple over
		-- ticks 4000–5999
		local rows = {
			{ 1000, 0.335, 0.066 }, { 600, 0.516, 0.038 }, { 400, 0.702, 0.023 }, { 300, 0.854, 0.016 },
			{ 250, 0.958, 0.013 }, { 200, 0.944, 0.008 }, { 150, 0.930, 0.004 }, { 100, 0.916, 0.002 },
		}
		for _, r in rows do
			local S = strokes(flat(60000), r[1], 50, 60000)
			local hist = S.hist :: { T: { [number]: number }, C: { [number]: number } }
			local sum, lo, hi = 0, 1, 0
			for k = 4000, 5999 do
				sum += hist.T[k]
				lo, hi = math.min(lo, hist.T[k]), math.max(hi, hist.T[k])
			end
			printed(sum / 2000, r[2], 3, "steady T, a stroke every " .. r[1] .. " ms")
			printed(hi - lo, r[3], 3, "ripple, a stroke every " .. r[1] .. " ms")
		end
		-- from cold at the refill rate: T after the ticks before 1, 2 and 3 s
		local cold = strokes(flat(10000), 250, 50, 10000)
		local hist = cold.hist :: { T: { [number]: number }, C: { [number]: number } }
		printed(hist.T[99], 0.490, 3, "T(1 s)")
		printed(hist.T[199], 0.774, 3, "T(2 s)")
		printed(hist.T[299], 0.885, 3, "T(3 s)")
		-- one full stroke from rest peaks at +0.166 after 750 ms
		local one = HoldZone.newSession(flat(10000))
		one.hist = { T = {}, C = {} }
		HoldZone.push(one, { t = 0, down = true })
		HoldZone.push(one, { t = 50, down = false })
		HoldZone.advance(one, 5000)
		local peak, at = 0, 0
		local h1 = one.hist :: { T: { [number]: number }, C: { [number]: number } }
		for k = 0, 499 do
			if h1.T[k] > peak then
				peak, at = h1.T[k], k * 10
			end
		end
		printed(peak, 0.166, 3, "one stroke's peak")
		A.eq(at, 750, "at 750 ms")
	end)

	t.it("holding alone scores 0 (§6.8): one press held from GO, released at the end or never", function()
		for _, cell in { { "Iron", "Normal" }, { "Steel", "Hard" } } :: { { any } } do
			for seed = 1, 5 do
				local P = HoldZone.generate(seed, paramsOf(cell[1], cell[2], 0.1))
				local held = replay(P, { { t = 0, down = true } })
				A.eq(held.score, 0, "held from GO")
				A.eq(held.breakdown.strokes, 1, "one stroke")
				local released = replay(P, { { t = 0, down = true }, { t = P.durationMs - 1, down = false } })
				A.eq(released.score, 0, "held, released at the end")
				local idle = replay(P, {})
				A.eq(idle.score, 0, "no input")
				A.eq(idle.breakdown.strokes, 0)
			end
		end
	end)

	t.it("the session's key pointer equals the stateless centerAt on every tick; smoothstep between the keys", function()
		local rng = TestRng.new(0x5EED0007)
		for _ = 1, 12 do
			local material: DT.MaterialId = MATERIALS[rng:int(1, 2)]
			local tier: DT.TierId = TIERS[rng:int(1, 2)]
			local P = HoldZone.generate(rng:u32(), paramsOf(material, tier, rng:float()))
			local S = HoldZone.newSession(P)
			S.hist = { T = {}, C = {} }
			HoldZone.advance(S, P.durationMs + 1)
			local hist = S.hist :: { T: { [number]: number }, C: { [number]: number } }
			for k = 0, P.durationMs // 10 - 1 do
				A.eq(hist.C[k], HoldZone.centerAt(P, k * 10 + 10), "tick " .. k)
			end
			for j = 1, #P.keysT - 1 do
				A.eq(HoldZone.centerAt(P, P.keysT[j]), P.keysC[j], "at key " .. j)
				local mid = HoldZone.centerAt(P, (P.keysT[j] + P.keysT[j + 1]) / 2)
				A.near(mid, (P.keysC[j] + P.keysC[j + 1]) / 2, 1e-12, "halfway between keys " .. j .. " and " .. j + 1)
				A.within(mid, math.min(P.keysC[j], P.keysC[j + 1]), math.max(P.keysC[j], P.keysC[j + 1]), "between")
			end
			A.eq(HoldZone.centerAt(P, P.keysT[#P.keysT] + 5000), P.keysC[#P.keysC], "past the last key")
			A.eq(HoldZone.centerAt(P, -2000), P.keysC[1], "the countdown shows the first centre")
			for i = 1, #P.keysC do
				A.within(P.keysC[i], P.p.targetMin, P.p.targetMax, "centres within [targetMin, targetMax]")
			end
		end
	end)

	t.it("HzInhumanRate at its threshold: 30 presses in one 1000 ms window flag, 29 do not", function()
		local P = HoldZone.generate(1, paramsOf("Iron", "Normal", 0))
		A.eq(Checks.value("HoldZone", "HZ_RATE_MAX_PRESSES"), 30)
		A.eq(Checks.value("HoldZone", "HZ_RATE_WINDOW_MS"), 1000)
		local function taps(n: number, every: number): { HoldRecord }
			local out: { HoldRecord } = {}
			for i = 0, n - 1 do
				table.insert(out, { t = 4000 + i * every, down = true })
				table.insert(out, { t = 4000 + i * every + 10, down = false })
			end
			return out
		end
		local function flagsOf(records: { HoldRecord }): { FlagId }
			local _, flags = replay(P, records)
			return flags
		end
		A.deepEq(flagsOf(taps(30, 34)), { "HzInhumanRate" }, "30 presses over 986 ms")
		A.deepEq(flagsOf(taps(29, 34)), {}, "29 presses")
		A.deepEq(flagsOf(taps(30, 35)), {}, "30 presses over 1015 ms: 29 per window")
		A.deepEq(flagsOf(taps(80, 35)), {}, "80 presses 35 ms apart: still 29 per window")
		-- only downs count: 29 presses and their 29 releases, 58 records in 850 ms, do not flag
		A.deepEq(flagsOf(taps(29, 30)), {}, "29 downs among 58 records")
		-- the downs, not the ups: 30 downs in 986 ms whose last release comes 2 s later (29 ups in any window) flag;
		-- 29 quick downs after a long hold, whose release joins their 29 (30 ups in 979 ms), do not
		local lateUp: { HoldRecord } = {}
		for i = 0, 29 do
			table.insert(lateUp, { t = 4000 + i * 34, down = true })
			table.insert(lateUp, { t = 4000 + i * 34 + (if i == 29 then 2000 else 17), down = false })
		end
		A.deepEq(flagsOf(lateUp), { "HzInhumanRate" }, "30 downs in a window, 29 ups")
		local held: { HoldRecord } = { { t = 1000, down = true }, { t = 3990, down = false } }
		for i = 0, 28 do
			table.insert(held, { t = 4000 + i * 34, down = true })
			table.insert(held, { t = 4000 + i * 34 + 17, down = false })
		end
		A.deepEq(flagsOf(held), {}, "29 downs in a window, 30 ups")
	end)

	t.it("feedback: Go, Stroke with its gain, RampEnd, EnterZone / LeaveZone, End; nothing fires → one shared frozen array", function()
		local P = HoldZone.generate(1, paramsOf("Iron", "Normal", 0))
		local p = P.p
		local S = HoldZone.newSession(P)
		A.eq(kinds(HoldZone.advance(S, 0)), "Go", "Go on the first call")
		local idle = HoldZone.advance(S, 0)
		A.eq(#idle, 0)
		A.truthy(table.isfrozen(idle) and HoldZone.advance(S, 5) == idle, "the same frozen array (D13)")
		local s1 = HoldZone.push(S, { t = 0, down = true })
		A.deepEq(s1, { { kind = "Stroke", t = 0, value = p.strokeGain } }, "a full stroke from rest")
		A.eq(#HoldZone.push(S, { t = 60, down = false }), 0, "an up fires nothing")
		local s2 = HoldZone.push(S, { t = 100, down = true })
		A.eq(s2[1].value, p.strokeGain * math.min(1, 100 / p.refillMs), "the bellows refills: 0.4 of a stroke")
		HoldZone.push(S, { t = 160, down = false })
		-- pump at the refill rate from 300 ms: T climbs into the zone after the ramp
		local all: { FeedbackEvent } = {}
		local tt = 300
		while tt < P.durationMs - 50 do
			HoldZone.push(S, { t = tt, down = true })
			HoldZone.push(S, { t = tt + 50, down = false })
			for _, e in ipairs(HoldZone.advance(S, tt + 50)) do
				table.insert(all, e)
			end
			tt += if HoldZone.view(S, tt).temperature < HoldZone.centerAt(P, tt) then 250 else 600
		end
		for _, e in ipairs(HoldZone.advance(S, P.durationMs + 1)) do
			table.insert(all, e)
		end
		A.eq(all[1].kind, "RampEnd", "the first scored tick")
		A.eq(all[1].t, P.rampMs + 10, "its end time")
		A.eq(all[#all].kind, "End")
		A.eq(all[#all].t, P.durationMs)
		local enters, leaves, inside = 0, 0, false
		for i = 2, #all - 1 do
			local e = all[i]
			if e.kind == "EnterZone" then
				A.falsy(inside, "enter only from outside")
				enters += 1
				inside = true
			elseif e.kind == "LeaveZone" then
				A.truthy(inside, "leave only from inside")
				leaves += 1
				inside = false
			else
				A.fail("unexpected " .. e.kind)
			end
		end
		A.truthy(enters >= 1, "the zone was reached")
		A.truthy(enters - leaves == 0 or enters - leaves == 1, "alternating")
		A.eq(#HoldZone.advance(S, P.durationMs + 100), 0, "End only once")
	end)

	t.it("the view: phases, gauge, zone, the live score (the mean so far, O14), time left; views change nothing", function()
		local P = HoldZone.generate(3, paramsOf("Steel", "Hard", 0.3))
		local p = P.p
		local records: { HoldRecord } = {}
		local tt = 0
		while tt < P.durationMs - 100 do
			table.insert(records, { t = tt, down = true })
			table.insert(records, { t = tt + 60, down = false })
			tt += 280
		end
		local whole = replay(P, records)
		local S = HoldZone.newSession(P)
		local v0 = HoldZone.view(S, -1500)
		A.eq(v0.phase, "Ramp", "the countdown")
		A.deepEq({ v0.temperature, v0.fire, v0.runningScore } :: { any }, { 0, 0, 0 } :: { any }, "cold, nothing scored")
		A.eq(v0.zoneCenter, P.keysC[1])
		A.eq(v0.zoneHalf, p.zoneWidth / 2)
		A.eq(v0.softBand, p.softFrac * p.zoneWidth)
		A.eq(v0.timeLeftMs, P.durationMs + 1500)
		local k = 1
		for now = 0, P.durationMs + 200, 70 do
			while k <= #records and records[k].t <= now do
				HoldZone.push(S, records[k])
				k += 1
			end
			HoldZone.advance(S, now)
			local v = HoldZone.view(S, now)
			A.eq(v.phase, if now < P.rampMs then "Ramp" elseif now < P.durationMs then "Hold" else "Done", "phase at " .. now)
			A.eq(v.temperature, S.T)
			A.eq(v.fire, S.F)
			A.eq(v.zoneCenter, HoldZone.centerAt(P, now))
			A.eq(v.inZone, math.abs(S.T - v.zoneCenter) <= v.zoneHalf)
			A.eq(v.runningScore, if S.n > 0 then math.round(S.credit / S.n * 10000) / 10000 else 0, "the mean so far")
			if now <= P.rampMs then
				A.eq(v.runningScore, 0, "0 until the ramp ends")
			end
			A.eq(v.timeLeftMs, math.max(0, P.durationMs - now))
			HoldZone.view(S, now + 5000) -- a view ahead moves nothing
		end
		A.deepEq(HoldZone.finish(S), whole, "views and advances change no result")
		A.eq(HoldZone.view(S, P.durationMs).runningScore, whole.score, "at the end the live score is the score")
		-- early on, the mean is over the ticks scored so far: a zone at the cold temperature is held from the first tick
		local cold: Pattern = { p = p, keysT = { 0, 60000 }, keysC = { 0, 0 }, durationMs = 10000, rampMs = 0, hash = 0 }
		local C = HoldZone.newSession(cold)
		HoldZone.advance(C, 50)
		A.eq(C.n, 5, "5 scored ticks")
		A.eq(HoldZone.view(C, 50).runningScore, 1, "each in the zone: 1")
	end)

	t.it("the bots' history (S.hist) is perception only: a session that keeps it finishes as one that does not", function()
		local P = HoldZone.generate(1, paramsOf("Iron", "Normal", 0))
		local records = tapStream(TestRng.new(0x5EED0011), P.durationMs)
		local with = HoldZone.newSession(P)
		with.hist = { T = {}, C = {} }
		local without = HoldZone.newSession(P)
		for _, e in ipairs(records) do
			HoldZone.push(with, e)
			HoldZone.push(without, e)
		end
		A.deepEq(HoldZone.finish(with), HoldZone.finish(without), "the same result")
		A.eq(with.n, without.n, "the same scored ticks (the first one ends after rampMs, history or not)")
	end)

	sized(t, "live = replay: advancing between records to any time up to the next one consumes every down alike", function(n: number)
		Prop.check(n, function(rng: TestRng.TestRng): { any }
			local material: DT.MaterialId = MATERIALS[rng:int(1, 2)]
			local tier: DT.TierId = if rng:int(1, 2) == 1 then "Normal" else "Hard"
			local P = HoldZone.generate(rng:u32(), paramsOf(material, tier, rng:float()))
			return { P = P, records = tapStream(rng, P.durationMs), salt = rng:u32() }
		end, function(c: any)
			local P: Pattern = c.P
			local rng = TestRng.new(c.salt)
			local whole = replay(P, c.records)
			local S = HoldZone.newSession(P)
			local h = -50
			for _, e in ipairs(c.records) do
				-- the horizon never passes a record not yet pushed (D4): advance to at most this record's time
				while rng:int(1, 2) == 1 do
					h = math.min(e.t, h + rng:int(0, 120))
					HoldZone.advance(S, h)
				end
				HoldZone.push(S, e)
				h = math.max(h, e.t)
			end
			A.deepEq(HoldZone.finish(S), whole, "live session = replay")
		end)
	end)

	sized(t, "HoldZone = the S3 prototype's generate, session sums and checks, bit for bit, on random configs and taps (D1)", function(n: number)
		Prop.check(n, function(rng: TestRng.TestRng): { any }
			local material: DT.MaterialId = MATERIALS[rng:int(1, 2)]
			local tier: DT.TierId = TIERS[rng:int(1, #TIERS)]
			local p = paramsOf(material, tier, rng:float())
			local seed = rng:u32()
			local P = HoldZone.generate(seed, p)
			return { p = p, seed = seed, records = tapStream(rng, P.durationMs) }
		end, function(c: any)
			local P = HoldZone.generate(c.seed, c.p)
			local Q = Proto.generate(c.seed, c.p)
			A.deepEq(P.keysT, Q.keysT, "key times")
			A.deepEq(P.keysC, Q.keysC, "key centres")
			A.deepEq({ P.durationMs, P.rampMs, P.hash }, { Q.durationMs, Q.rampMs, Q.hash }, "durationMs, rampMs, hash")
			-- the unquantized session state after every tick
			local S = HoldZone.newSession(P)
			local s = Proto.newSession(Q)
			for _, e in ipairs(c.records) do
				HoldZone.push(S, e)
				Proto.push(s, e)
			end
			local result = HoldZone.finish(S)
			local theirs = Proto.finish(s)
			A.deepEq({ S.credit, S.n, S.inZone, S.strokes, S.T, S.F, S.pressT }, { s.credit, s.n, s.inZone, s.strokes, s.T, s.F,
				s.pressT }, "credit, n, inZone, strokes, T, F, last stroke")
			A.eq(result.score, theirs.score, "score")
			A.eq(result.breakdown.inZone, theirs.inZone, "inZone")
			local flags = HoldZone.checks(P, c.records, result)
			local mapped: { FlagId } = {}
			for _, f in ipairs(Proto.checks(Q, c.records, theirs)) do
				A.eq(f, "HZ_InhumanRate", "the prototype's one flag")
				table.insert(mapped, "HzInhumanRate")
			end
			A.deepEq(flags, mapped, "flags")
		end)
	end)
end)
