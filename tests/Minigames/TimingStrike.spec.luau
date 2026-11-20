--!strict
-- Minigames/TimingStrike (SPEC §6.9, §6.14, §10.6, §16.21, E-S3.4; T-MG-07's core floor, T-MG-13 (a)): E-S3.4's golden
-- pattern, worked presses and grade bands; points, grades and bands (the breakdown's count on a grade line); how a
-- press decides its span; the inhuman-input checks at their thresholds; the full-points core ≥ 9 ms at every tier
-- (T-MG-11's deterministic half); the dial on the raw clock (view.cycle changes exactly at each start_i, D12);
-- feedback, the combo (O13) and the live score (O14); live = replay; and the S3 prototype's generate, replay and checks
-- bit for bit (M4's D1: the prototype made E-S3's hashes and distributions).

local Test = require("../lib/Test")
local A = require("../lib/Assert")
local Dump = require("../lib/Dump")
local Prop = require("../lib/Prop")
local TestRng = require("../lib/TestRng")
local Tol = require("../lib/Tol")
local DT = require("../../src/shared/Definitions/Types")
local Checks = require("../../src/shared/Minigames/Checks")
local Params = require("../../src/shared/Minigames/Params")
local TimingStrike = require("../../src/shared/Minigames/TimingStrike")
local Types = require("../../src/shared/Minigames/Types")

-- Through a cast, so luau-lsp stays out of the prototype's loose types: it is reference data, not game code.
local Proto: any = (require :: any)("../../docs/spec/prototypes/S3/v2/TimingStrike")

type Pattern = TimingStrike.Pattern
type FeedbackEvent = Types.FeedbackEvent
type FlagId = Types.FlagId
type MinigameResult = Types.MinigameResult

local MATERIALS: { DT.MaterialId } = { "Iron", "Steel" }
local TIERS: { DT.TierId } = { "Normal", "Hard", "Expert", "Master", "Hell" }
local PROTO_FLAG: { [string]: FlagId } = { TS_ExactHits = "TsExactHits", TS_LowVariance = "TsLowVariance" }

local function patternOf(material: DT.MaterialId, tier: DT.TierId, x: number, seed: number): Pattern
	return TimingStrike.generate(seed, Params.resolve("TimingStrike", material, tier, Params.refFactors(x)))
end

-- the golden pattern: seed 1, Iron/Normal, x = 0 (E-S3.4)
local function golden(): Pattern
	return patternOf("Iron", "Normal", 0, 1)
end

-- the judge's path without the facade (slice 7): push every press, finish, checks
local function replay(P: Pattern, presses: { number }): (MinigameResult, { FlagId })
	local S = TimingStrike.newSession(P)
	for _, t in ipairs(presses) do
		TimingStrike.push(S, t)
	end
	local result = TimingStrike.finish(S)
	return result, TimingStrike.checks(P, presses, result)
end

-- a press at T_i + errs[i] per cycle; false: no press
local function pressesAt(P: Pattern, errs: { number | false }): { number }
	local out: { number } = {}
	for i, c in ipairs(P.cycles) do
		local e = errs[i]
		if type(e) == "number" then
			table.insert(out, c.target + e)
		end
	end
	return out
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

return Test.suite("Minigames/TimingStrike", function(t)
	t.it("TimingStrike is §6.2's FamilyModule: id, generate, hash, newSession, push, advance, view, finish, checks", function()
		-- typed: luau-lsp checks the module against the facade's type (a wider table, by width subtyping)
		local F: Types.FamilyModule<Pattern, number, TimingStrike.Session, Types.TimingStrikeView> = TimingStrike
		A.eq(F.id, "TimingStrike")
		for _, name in { "generate", "hash", "newSession", "push", "advance", "view", "finish", "checks" } do
			A.eq(type((F :: any)[name]), "function", name)
		end
	end)

	t.it("T-MG-13 E-S3.4's golden: seed 1, Iron/Normal, x = 0, its hash and the worked presses", function()
		local P = golden()
		A.eq(#P.cycles, 12, "N")
		A.eq(P.W, 110, "W")
		printed(P.core, 13.2, 1, "core")
		A.eq(P.M, 200, "M")
		A.eq(P.durationMs, 10971, "durationMs")
		A.eq(P.hash, 0xE2D4F2AE, "hash")
		A.eq(TimingStrike.hash(P), P.hash)
		for i, e in ipairs({ { 489, 847 }, { 1479, 896 }, { 2354, 871 }, { 3031, 878 } }) do
			A.eq(P.cycles[i].target, e[1], "target " .. i)
			A.eq(P.cycles[i].period, e[2], "period " .. i)
		end
		-- errors 0, +6, −15, +35, +79, none, −81, then 5 exact
		local errs: { number | false } = { 0, 6, -15, 35, 79, false, -81, 0, 0, 0, 0, 0 }
		local expected = { 1, 1, 0.9851, 0.8198, 0.4562, 0, 0.4397, 1, 1, 1, 1, 1 }
		for i, e in ipairs(errs) do
			local pts = TimingStrike.points(P, if type(e) == "number" then e else nil)
			printed(pts, expected[i], 4, "points of span " .. i)
		end
		local result, flags = replay(P, pressesAt(P, errs))
		A.eq(result.status, "Ok")
		A.eq(result.score, 0.8084, "score")
		A.eq(result.rawScore, result.score)
		A.truthy(result.passed, "0.8084 ≥ 0.50")
		A.deepEq(flags, {}, "a human spread is unflagged")
		local b = result.breakdown
		printed(b.meanErrMs, 2.18, 2, "meanErrMs")
		A.eq(b.meanErrMs, 24 / 11, "(0 + 6 − 15 + 35 + 79 − 81) / 11")
		A.eq(b.meanAbsErrMs, 216 / 11, "(6 + 15 + 35 + 79 + 81) / 11")
		A.deepEq(
			{ b.judged, b.perfect, b.good, b.ok, b.miss, b.whiffs, b.bestCombo },
			{ 11, 8, 1, 2, 1, 0, 6 },
			"judged, perfect, good, ok, miss, whiffs, bestCombo"
		)
	end)

	t.it("T-MG-13 E-S3.4's windows and grade bands (seed 1) at x = 0 and 1", function()
		-- {material, tier, x, W, core, M, Perfect ≤, Good ≤} as golden.luau prints them
		local rows: { { any } } = {
			{ "Iron", "Normal", 0, 110, 13.2, 200, 25.3, 61.6 },
			{ "Iron", "Normal", 1, 94, 11.3, 184, 21.6, 52.6 },
			{ "Iron", "Hard", 0, 103, 10.0, 193, 20.3, 51.3 },
			{ "Iron", "Hard", 1, 88, 10.0, 178, 18.7, 44.7 },
			{ "Steel", "Hard", 0, 101, 10.0, 191, 20.1, 50.4 },
			{ "Steel", "Hard", 1, 86, 10.0, 176, 18.4, 43.8 },
		}
		for _, r in rows do
			local P = patternOf(r[1], r[2], r[3], 1)
			local what = string.format("%s/%s x = %d", r[1], r[2], r[3])
			A.eq(P.W, r[4], what .. " W")
			printed(P.core, r[5], 1, what .. " core")
			A.eq(P.M, r[6], what .. " M")
			printed(TimingStrike.bandMs(P, TimingStrike.TS_GRADE_PERFECT), r[7], 1, what .. " Perfect band")
			printed(TimingStrike.bandMs(P, TimingStrike.TS_GRADE_GOOD), r[8], 1, what .. " Good band")
		end
	end)

	t.it("no span opens before GO: an early first target bounds M (M = T_1), then W and the core with it", function()
		-- the shipped offsets put T_1 near half a beat, far past M; offsets near 0 bring it inside the first span
		local p = table.clone(Params.resolve("TimingStrike", "Iron", "Normal", Params.refFactors(0)))
		p.offsetMin, p.offsetMax = 0.02, 0.05
		for seed = 1, 6 do
			local P = TimingStrike.generate(seed, p)
			local T1 = P.cycles[1].target
			A.truthy(T1 < p.windowMs + p.missPadMs, "an early target")
			A.eq(P.M, T1, "M = T_1: the first span opens at GO")
			A.eq(P.W, math.min(p.windowMs, T1))
			A.eq(P.core, math.min(P.W, math.max(p.perfectFrac * P.W, TimingStrike.TS_PERFECT_CORE_MIN_MS)))
			local Q = Proto.generate(seed, p)
			A.deepEq({ P.M, P.W, P.core } :: { any }, { Q.M, Q.W, Q.core } :: { any }, "as the prototype")
			A.deepEq(TimingStrike.judgeErrors(P, { 0 }), { -T1 }, "a press at GO is judged")
		end
	end)

	t.it("the breakdown counts a press by its grade, on a grade line too (Iron/Hard x = 0.2: W 100, |e| 20 → 0.9)", function()
		local P = patternOf("Iron", "Hard", 0.2, 1)
		A.eq(P.W, 100)
		A.eq(P.core, 10)
		A.eq(TimingStrike.points(P, 20), 0.9, "exactly the Perfect line")
		A.eq(TimingStrike.grade(TimingStrike.points(P, 20)), "Perfect")
		local S = TimingStrike.newSession(P)
		TimingStrike.push(S, P.cycles[1].target + 20)
		local r = TimingStrike.finish(S)
		A.eq(r.breakdown.perfect, 1, "graded Perfect, counted Perfect")
		A.eq(r.breakdown.good, 0)
	end)

	t.it("points, grades and bands: the core, the window edge, the slope, §16.21's grade lines", function()
		local P = golden()
		local W, core, edge = P.W, P.core, P.p.edgePoints
		A.eq(TimingStrike.points(P, nil), 0, "a miss")
		A.eq(TimingStrike.points(P, 0), 1)
		A.eq(TimingStrike.points(P, core), 1, "the core's edge is full points")
		A.eq(TimingStrike.points(P, -13), 1, "inside the core, early")
		A.eq(TimingStrike.points(P, W), 1 - (1 - edge) * (W - core) / (W - core), "the window edge")
		A.near(TimingStrike.points(P, W), edge, 1e-12, "edgePoints at ±W")
		A.eq(TimingStrike.points(P, W + 1), 0, "past the window")
		A.eq(TimingStrike.points(P, -(W + 1)), 0)
		for e = 0, 120 do
			A.eq(TimingStrike.points(P, e), TimingStrike.points(P, -e), "symmetric at " .. e)
			if e > 0 then
				A.truthy(TimingStrike.points(P, e) <= TimingStrike.points(P, e - 1), "non-increasing in |e|")
			end
		end
		A.eq(TimingStrike.TS_GRADE_PERFECT, 0.9)
		A.eq(TimingStrike.TS_GRADE_GOOD, 0.6)
		A.eq(TimingStrike.TS_OFFSET_OFFER_MIN_JUDGED, 8)
		for _, g in { { 1, "Perfect" }, { 0.9, "Perfect" }, { 0.8999, "Good" }, { 0.6, "Good" }, { 0.5999, "Ok" },
			{ 1e-9, "Ok" }, { 0, "Miss" } } :: { { any } } do
			A.eq(TimingStrike.grade(g[1]), g[2], "grade of " .. tostring(g[1]))
		end
		-- a band is the |e| that earns its points
		for _, pts in { 0.9, 0.6, 0.3 } do
			A.near(TimingStrike.points(P, TimingStrike.bandMs(P, pts)), pts, 1e-12, "points at bandMs(" .. pts .. ")")
		end
		A.eq(TimingStrike.bandMs(P, 1), core)
		A.near(TimingStrike.bandMs(P, edge), W, 1e-12)
	end)

	t.it("a press decides its span once: whiffs before the span, between spans and a second press", function()
		local P = golden()
		local c1, c2 = P.cycles[1], P.cycles[2]
		local M = P.M
		-- too early for span 1, span 1 at its earliest, a second press in span 1, span 2 at its latest, then one past it
		local presses = { c1.target - M - 1, c1.target - M, c1.target, c2.target + M, c2.target + M + 1 }
		local result = replay(P, presses)
		A.deepEq(TimingStrike.judgeErrors(P, presses), { -M, M }, "the first press in ±M decides")
		A.eq(result.breakdown.whiffs, 3, "3 whiffs")
		A.eq(result.breakdown.judged, 2)
		A.eq(result.breakdown.miss, 10)
		A.eq(result.breakdown.ok + result.breakdown.good + result.breakdown.perfect, 0, "both past W: 0 points")
		A.eq(result.score, 0)
		A.falsy(result.passed)
		-- the spans never overlap: the next span opens after this one closes
		for i = 1, #P.cycles - 1 do
			A.truthy(P.cycles[i].target + M < P.cycles[i + 1].target - M, "spans " .. i .. " and " .. i + 1 .. " apart")
		end
		A.truthy(P.cycles[#P.cycles].target + M < P.durationMs, "the last span closes before the end")
		-- no press at all: every span a miss, score 0, unflagged
		local idle, flags = replay(P, {})
		A.eq(idle.score, 0)
		A.eq(idle.breakdown.miss, 12)
		A.eq(idle.breakdown.meanErrMs, 0)
		A.deepEq(flags, {})
	end)

	t.it("checks at their thresholds: TS_MIN_JUDGED, TS_EXACT_MS, TS_EXACT_FRAC and TS_MIN_SD_MS (strict)", function()
		local P = golden() -- 12 cycles
		local function flagsOf(errs: { number | false }): { FlagId }
			local presses = pressesAt(P, errs)
			local _, flags = replay(P, presses)
			return flags
		end
		A.eq(Checks.value("TimingStrike", "TS_MIN_JUDGED"), 8)
		-- exact presses: 7 judged are too few to judge, 8 flag both
		A.deepEq(flagsOf({ 0, 0, 0, 0, 0, 0, 0 }), {}, "7 judged")
		A.deepEq(flagsOf({ 0, 0, 0, 0, 0, 0, 0, 0 }), { "TsExactHits", "TsLowVariance" }, "8 judged, sorted")
		-- n = 12: ceil(0.90 · 12) = 11 within ±1 ms (1 counts, 2 does not); one far press keeps the SD high
		A.deepEq(flagsOf({ 1, -1, 0, 1, -1, 0, 1, -1, 0, 1, -1, 40 }), { "TsExactHits" }, "11 of 12 within 1 ms")
		A.deepEq(flagsOf({ 2, -1, 0, 1, -1, 0, 1, -1, 0, 1, -1, 40 }), {}, "10 of 12")
		A.deepEq(flagsOf({ -2, -1, 0, 1, -1, 0, 1, -1, 0, 1, -1, 40 }), {}, "|−2| is not exact")
		-- the SD threshold is strict: {−3, 0 ×7, 3} has SD √(18/8) = 1.5 exactly; {−3, 0 ×8, 3} √(18/9) < 1.5
		A.eq(Checks.sampleSd({ -3, 0, 0, 0, 0, 0, 0, 0, 3 }), 1.5)
		A.deepEq(flagsOf({ -3, 0, 0, 0, 0, 0, 0, 0, 3 }), {}, "SD 1.5: not below")
		A.deepEq(flagsOf({ -3, 0, 0, 0, 0, 0, 0, 0, 0, 3 }), { "TsLowVariance" }, "SD 1.414")
		-- a constant offset is no defence: every error −60 ms (a 60 ms timing offset on exact times)
		A.deepEq(flagsOf(table.create(12, -60)), { "TsLowVariance" }, "a shift keeps the SD at 0")
		-- a judged press past W still counts as judged for the checks
		A.deepEq(flagsOf(table.create(12, P.W + 1)), { "TsLowVariance" }, "0-point presses, all alike")
		-- checks reads the presses through the session's own rules (whiffs and misses ignored)
		local presses = pressesAt(P, table.create(12, 0))
		table.insert(presses, 1, 5) -- a whiff before span 1
		table.insert(presses, presses[3]) -- a second press in span 2
		table.sort(presses)
		A.eq(#TimingStrike.judgeErrors(P, presses), 12)
	end)

	t.it("T-MG-07 the full-points core ≥ 9 ms at every tier, material and x ∈ {0, 0.1, …, 1}", function()
		local lowest = math.huge
		-- indexed and annotated: luau-lsp widens an unannotated id local to string
		for mi = 1, #MATERIALS do
			local material: DT.MaterialId = MATERIALS[mi]
			for ti = 1, #TIERS do
				local tier: DT.TierId = TIERS[ti]
				for xi = 0, 10 do
					local x = xi / 10
					for seed = 1, 8 do
						local P = patternOf(material, tier, x, seed)
						local what = string.format("%s/%s x = %s seed %d", material, tier, tostring(x), seed)
						A.eq(P.core, math.min(P.W, math.max(P.p.perfectFrac * P.W, TimingStrike.TS_PERFECT_CORE_MIN_MS)),
							what .. ": core = min(W, max(perfectFrac·W, TS_PERFECT_CORE_MIN_MS))")
						A.truthy(P.core >= 9, what .. ": core ≥ 9 ms (§16.21)")
						lowest = math.min(lowest, P.core)
					end
				end
			end
		end
		A.eq(TimingStrike.TS_PERFECT_CORE_MIN_MS, 10)
		A.eq(lowest, 10, "the floor binds at Hard and above")
	end)

	t.it("the dial follows the raw clock: view.cycle changes exactly at each start_i, however far the session ran", function()
		local P = golden()
		local N = #P.cycles
		local sessions = { TimingStrike.newSession(P), TimingStrike.newSession(P), TimingStrike.newSession(P) }
		TimingStrike.advance(sessions[2], 4000)
		for _, tp in ipairs(pressesAt(P, table.create(N, 3))) do
			TimingStrike.push(sessions[3], tp)
		end
		TimingStrike.advance(sessions[3], P.durationMs + 1)
		for k, S in ipairs(sessions) do
			A.eq(TimingStrike.view(S, -3000).cycle, 1, "the countdown shows cycle 1")
			for i, c in ipairs(P.cycles) do
				local what = string.format("session %d, cycle %d", k, i)
				local v = TimingStrike.view(S, c.start)
				A.eq(v.cycle, i, what .. " at start_i")
				A.eq(v.marker, 0, what .. ": the marker at 12 o'clock")
				if i > 1 then
					A.eq(TimingStrike.view(S, c.start - 1).cycle, i - 1, what .. " a ms earlier")
				end
				A.eq(v.windowCenter, (c.target - c.start) / c.period)
				A.eq(v.windowHalf, P.W / c.period)
				A.eq(v.perfectHalf, TimingStrike.bandMs(P, 0.9) / c.period)
				A.eq(v.goodHalf, TimingStrike.bandMs(P, 0.6) / c.period)
				A.truthy(v.perfectHalf < v.goodHalf and v.goodHalf < v.windowHalf, what .. ": bands nest")
				local nc = P.cycles[i + 1]
				if nc then
					A.deepEq(v.next, { windowCenter = (nc.target - nc.start) / nc.period, windowHalf = P.W / nc.period },
						what .. ": the ghost window")
				else
					A.eq(v.next, nil, "no ghost on the last cycle")
				end
				A.eq(TimingStrike.view(S, c.target).marker, (c.target - c.start) / c.period, what .. ": marker on target")
			end
			local tail = TimingStrike.view(S, P.durationMs - 1)
			A.eq(tail.cycle, N, "the tail stays on the last cycle")
			A.eq(tail.marker, 1, "the marker rests at the end")
			A.eq(tail.cycles, N)
			A.eq(tail.timeLeftMs, 1)
			A.eq(TimingStrike.view(S, P.durationMs + 500).timeLeftMs, 0)
		end
	end)

	t.it("feedback: Strike, Whiff, Miss from a press and from advance, End once; nothing fires → one shared frozen array", function()
		local P = golden()
		local S = TimingStrike.newSession(P)
		local c = P.cycles
		local idle = TimingStrike.advance(S, 100)
		A.eq(#idle, 0)
		A.truthy(table.isfrozen(idle), "frozen")
		A.truthy(TimingStrike.advance(S, 200) == idle, "the same array every time (D13)")
		-- a Perfect strike on span 1
		local e1 = TimingStrike.push(S, c[1].target + 4)
		A.eq(kinds(e1), "Strike")
		A.deepEq(e1[1], { kind = "Strike", t = c[1].target + 4, i = 1, value = 4, label = "Perfect" })
		A.eq(kinds(TimingStrike.push(S, c[1].target + 5)), "Whiff", "a second press")
		-- span 1 closes judged (no event); span 2 closes unjudged: a Miss when advance passes T_2 + M
		A.eq(#TimingStrike.advance(S, c[2].target + P.M), 0, "span 2 still open at T_2 + M")
		local miss = TimingStrike.advance(S, c[2].target + P.M + 1)
		A.deepEq(miss, { { kind = "Miss", t = c[2].target + P.M, i = 2 } }, "span 2 missed")
		-- a press that first closes span 3 unjudged, then strikes span 4 late: Miss then Strike (Good)
		local e4 = TimingStrike.push(S, c[4].target + 40)
		A.eq(kinds(e4), "Miss Strike")
		A.eq(e4[1].i, 3)
		A.deepEq(e4[2], { kind = "Strike", t = c[4].target + 40, i = 4, value = 40, label = "Good" })
		-- the rest: End fires once, when every span is closed
		local tail = TimingStrike.advance(S, P.durationMs + 1)
		A.eq(kinds(tail), "Miss Miss Miss Miss Miss Miss Miss Miss End", "spans 5–12, then End")
		A.eq(tail[#tail].t, c[12].target + P.M)
		A.eq(#TimingStrike.advance(S, P.durationMs + 2), 0, "End only once")
		A.eq(kinds(TimingStrike.push(S, P.durationMs)), "Whiff", "a press after the last span")
		A.eq(TimingStrike.finish(S).breakdown.whiffs, 2)
	end)

	t.it("combo +1 per span with points, reset by a 0-point span, whiffs aside (O13); the live score is the mean so far (O14)", function()
		local P = golden()
		local S = TimingStrike.newSession(P)
		local c = P.cycles
		local W = P.W
		local function v(): Types.TimingStrikeView
			return TimingStrike.view(S, 0)
		end
		-- combo, last grade, last error
		local function state(): { any }
			local view = v()
			return { view.combo, view.lastGrade or "-", view.lastErrorMs or "-" }
		end
		A.deepEq(state(), { 0, "-", "-" } :: { any }, "nothing decided")
		A.eq(v().runningScore, 0, "0 before the first decision")
		TimingStrike.push(S, c[1].target) -- Perfect, 1 point
		A.deepEq(state(), { 1, "Perfect", 0 } :: { any })
		A.eq(v().runningScore, 1)
		TimingStrike.push(S, c[2].target - 40) -- Good
		local p2 = TimingStrike.points(P, -40)
		A.deepEq(state(), { 2, "Good", -40 } :: { any })
		A.eq(v().runningScore, math.round((1 + p2) / 2 * 10000) / 10000, "q of the mean")
		TimingStrike.push(S, c[2].target) -- a whiff: changes nothing
		A.eq(v().combo, 2, "a whiff leaves the combo")
		TimingStrike.push(S, c[4].target + W + 1) -- span 3 missed (0 points), then span 4 judged past W (0 points)
		A.deepEq(state(), { 0, "Miss", W + 1 } :: { any })
		TimingStrike.push(S, c[5].target + W) -- Ok (edgePoints)
		A.deepEq(state(), { 1, "Ok", W } :: { any })
		A.eq(v().runningScore, math.round((1 + p2 + 0 + 0 + TimingStrike.points(P, W)) / 5 * 10000) / 10000)
		for i = 6, 12 do
			TimingStrike.push(S, c[i].target)
		end
		A.eq(v().combo, 8, "spans 5–12")
		TimingStrike.advance(S, P.durationMs + 1)
		local result = TimingStrike.finish(S)
		A.eq(result.breakdown.bestCombo, 8)
		A.eq(v().runningScore, result.score, "at the end the live score is the score")
		A.eq(v().lastGrade, "Perfect", "the last decided span")
	end)

	t.it("live = replay: advancing between presses to any time before the next one decides every span alike", function()
		Prop.check(Tol.PROP_N, function(rng: TestRng.TestRng): { any }
			local material: DT.MaterialId = MATERIALS[rng:int(1, 2)]
			local tier: DT.TierId = if rng:int(1, 2) == 1 then "Normal" else "Hard"
			local P = patternOf(material, tier, rng:float(), rng:u32())
			local presses: { number } = {}
			for _, cy in ipairs(P.cycles) do
				if rng:int(1, 8) > 1 then
					table.insert(presses, math.max(0, cy.target + rng:int(-260, 260)))
				end
				if rng:int(1, 6) == 1 then
					table.insert(presses, math.max(0, cy.target + rng:int(-400, 400)))
				end
			end
			table.sort(presses)
			return { P = P, presses = presses, salt = rng:u32() }
		end, function(c: any)
			local P: Pattern = c.P
			local rng = TestRng.new(c.salt)
			local whole = replay(P, c.presses)
			local S = TimingStrike.newSession(P)
			local h = -100
			for _, tp in ipairs(c.presses) do
				-- the horizon never passes a record not yet pushed (D4): advance to at most this press's time
				while rng:int(1, 3) == 1 do
					h = math.min(tp, h + rng:int(0, 300))
					TimingStrike.advance(S, h)
					TimingStrike.view(S, h + rng:int(0, 120))
				end
				TimingStrike.push(S, tp)
				h = math.max(h, tp)
			end
			A.deepEq(TimingStrike.finish(S), whole, "live session = replay")
		end)
	end)

	t.it("TimingStrike = the S3 prototype's generate, replay and checks, bit for bit, on random configs and presses (D1)", function()
		Prop.check(Tol.PROP_N, function(rng: TestRng.TestRng): { any }
			local material: DT.MaterialId = MATERIALS[rng:int(1, 2)]
			local tier: DT.TierId = TIERS[rng:int(1, #TIERS)]
			local p = Params.resolve("TimingStrike", material, tier, Params.refFactors(rng:float()))
			local seed = rng:u32()
			local P = TimingStrike.generate(seed, p)
			-- human-like spreads, exact hits, early and late strays and repeats
			local sd = rng:pick({ 0, 0, 1, 4, 12, 45, 120 })
			local presses: { number } = {}
			for _, cy in ipairs(P.cycles) do
				if rng:int(1, 10) > 1 then
					table.insert(presses, math.max(0, cy.target + math.round(rng:normal(0, sd))))
				end
				if rng:int(1, 8) == 1 then
					table.insert(presses, rng:int(0, P.durationMs + 200))
				end
			end
			table.sort(presses)
			return { p = p, seed = seed, presses = presses }
		end, function(c: any)
			local P = TimingStrike.generate(c.seed, c.p)
			local Q = Proto.generate(c.seed, c.p)
			A.deepEq(P.cycles, Q.cycles, "cycles")
			A.deepEq({ P.M, P.W, P.core, P.durationMs, P.hash }, { Q.M, Q.W, Q.core, Q.durationMs, Q.hash },
				"M, W, core, durationMs, hash")
			local result, flags = replay(P, c.presses)
			local theirs = Proto.replay(Q, c.presses)
			A.eq(result.score, theirs.score, "score")
			A.deepEq(TimingStrike.judgeErrors(P, c.presses), theirs.errors, "judged errors")
			A.eq(result.breakdown.whiffs, theirs.whiffs, "whiffs")
			A.eq(result.breakdown.meanErrMs, theirs.meanErrMs, "meanErrMs")
			A.eq(result.breakdown.perfect, theirs.perfect, "perfect")
			local mapped: { FlagId } = {}
			for _, f in ipairs(theirs.flags) do
				table.insert(mapped, PROTO_FLAG[f])
			end
			A.deepEq(flags, mapped, "flags")
		end)
		-- the hash covers the pattern, not the scoring knobs (§6.4 rule 5)
		local p = table.clone(Params.resolve("TimingStrike", "Iron", "Normal", Params.refFactors(0)))
		local h = TimingStrike.generate(1, p).hash
		p.windowMs += 7
		A.eq(TimingStrike.generate(1, p).hash, h, "windowMs does not move the hash")
		p.beatMs += 1
		A.truthy(TimingStrike.generate(1, p).hash ~= h, "beatMs does")
		A.eq(Dump.canonical(TimingStrike.generate(7, p)), Dump.canonical(TimingStrike.generate(7, p)), "P-DET")
	end)
end)
