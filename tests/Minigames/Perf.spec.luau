--!strict
-- T-PERF-02 the minigames' server cost (SPEC §10.5, §14.11, §16.32; E-S3.5; M4's plan [6.8] with L6, the handoff's
-- slice 10), Lune: Minigames.judge at each family's record cap, and prepare for Sharpening.
-- Cases: judge on HoldZone Steel/Hard x = 1 (18 s) with 1,024 alternating records and on TimingStrike Steel/Hard x = 1
-- with 512 presses (decode's caps), and on the trace at Minigames.recordCap(spec) (L6) on worst.luau's 256-point source
-- at the length bound (Iron/Normal x = 0, 8.55 u; 29,560 ms, so 1,479 records) spread over travel, grinding on the
-- pacer (reviewer V1's hostile.luau, part 2); prepare (the edge hand-off plus generate) on X08's edges (Analyze.run of
-- Cost.X08's X08a, X08b and X08c, outside the timed part), Cost.X08_EDGE and a 256-point chain at the length bound, at
-- Iron/Normal x = 0 and Steel/Hard x = 1. Each input is checked by its counts (records, presses, points, E shrinks);
-- the X08 edges are S2's output, reported and not pinned (M4's D5, D6).
-- Method T-PERF-01's: a warm-up run per case, then PERF_RUNS rounds, odd ones forward through the cases and even ones
-- backward, each timed run after a full collection; a case's number is its median.
-- Asserted (§14.11): judge ≤ REPLAY_BUDGET_MS, prepare ≤ PT_GENERATE_BUDGET_MS. Reported, printed: the honest trace
-- (one sample per 20 ms from GO) beside the spread one, which costs about 2 % more (the cap bounds the count, not the
-- cost); decode alone of a 2,048-sample trace (decode's cap), which judge refuses as TooMany after decode; the hand-off
-- and generate apart; HoldZone's and TimingStrike's generate; and every median × 2.6 against §10.5's 7 ms in Studio.
-- Run it alone (--filter Minigames/Perf) on a quiet machine, the CPU load beside the medians: other load reaches the
-- medians, and a failure under load is re-run alone before it counts (§14.11's rule for T-PERF-01).

local luau = require("@lune/luau")
local Test = require("../lib/Test")
local A = require("../lib/Assert")
local Tol = require("../lib/Tol")
local Cost = require("../fixtures/Cost")
local Edges = require("../fixtures/Edges")
local H = require("./MinigamesHelpers")
local MF = require("../../src/shared/Definitions/MinigameFamilies")
local Network = require("../../src/shared/Definitions/Network")
local DT = require("../../src/shared/Definitions/Types")
local Versions = require("../../src/shared/Definitions/Versions")
local Minigames = require("../../src/shared/Minigames/Minigames")
local Params = require("../../src/shared/Minigames/Params")
local PrecisionTrace = require("../../src/shared/Minigames/PrecisionTrace")
local Timeline = require("../../src/shared/Minigames/Timeline")
local Types = require("../../src/shared/Minigames/Types")
local Analyze = require("../../src/shared/Physics/Analyze")

type StepSpec = Types.StepSpec
type HoldRecord = Types.HoldRecord
type TraceRecord = Types.TraceRecord
type MinigameResult = Types.MinigameResult
type Config = { material: DT.MaterialId, tier: DT.TierId, x: number }

local PT = PrecisionTrace
local QF = PT.PT_FIXED_POINT
local STUDIO_TARGET_MS = 7 -- §10.5: judge and prepare each ≤ 7 ms in Studio
local STUDIO_PER_LUNE = 2.6 -- §4.9's assumption, which S-PERF-01 measures
local SEED = 10 -- every step's seed: hostile.luau's, and PrecisionTrace.spec's on the worst source
local IRON_NORMAL: Config = { material = "Iron", tier = "Normal", x = 0 }
local STEEL_HARD: Config = { material = "Steel", tier = "Hard", x = 1 }

-- A full collection. luau-lsp's standard platform declares no collectgarbage, so it runs from a chunk of its own.
local collect: () -> () = luau.load('collectgarbage("collect")', { debugName = "T-PERF-02 collect" })

-- group: "judge" and "prepare" (asserted); "honest", "decode", "hand-off", "generate" and "family generate" (reported)
type Timed = { name: string, group: string, run: () -> any }

local function median(values: { number }): number
	local sorted = table.clone(values)
	table.sort(sorted)
	return sorted[(#sorted + 1) // 2]
end

-- T-PERF-01's method over timed calls: a warm-up run each (its result returned, for the checks), then PERF_RUNS rounds,
-- odd ones forward and even ones backward, a full collection before each timed run. Returns the medians (ms) and the
-- warm-up results.
local function measure(list: { Timed }): ({ number }, { any })
	local warm: { any } = {}
	local times: { { number } } = {}
	for k, c in list do
		warm[k] = c.run()
		times[k] = {}
	end
	for round = 1, Tol.PERF_RUNS do
		local forward = round % 2 == 1
		for step = 1, #list do
			local k = if forward then step else #list + 1 - step
			collect()
			local t0 = os.clock()
			list[k].run()
			table.insert(times[k], (os.clock() - t0) * 1000)
		end
	end
	local medians: { number } = {}
	for k in list do
		medians[k] = median(times[k])
	end
	return medians, warm
end

local function label(c: Config): string
	return string.format("%s/%s x = %g", c.material, c.tier, c.x)
end

-- printed to `dp` decimals: within half a unit of the last printed digit
local function printed(actual: number, expected: number, dp: number, what: string)
	local unit = 1
	for _ = 1, dp do
		unit /= 10
	end
	A.near(actual, expected, unit / 2 * (1 + 1e-9) + 1e-12, what)
end

-- "lo–hi (the case at hi)" over a group's medians × 2.6, ms; the cases past 7 ms are added to `past`
local function studio(list: { Timed }, medians: { number }, group: string, past: { string }): string
	local lo, hi, at = math.huge, -math.huge, ""
	for k, c in list do
		if c.group == group then
			local v = medians[k] * STUDIO_PER_LUNE
			lo = math.min(lo, v)
			if v > hi then
				hi, at = v, c.name
			end
			if v > STUDIO_TARGET_MS then
				table.insert(past, string.format("%s %s %.2f", group, c.name, v))
			end
		end
	end
	return string.format("%.2f–%.2f (%s)", lo, hi, at)
end

-- worst.luau's source, as PrecisionTrace.spec builds it: a sine across the usable panel, 256 points, the largest
-- amplitude (in 0.001 steps) whose length fits the hand-off's bound at these params; with that length
local function lengthBoundSource(p: { [string]: number }): ({ number }, number)
	local maxLen = PT.PT_LEN_MARGIN * PT.PT_TRAVEL_MAX_MS / 1000 * p.pacerSpeed
	local best: { number }, bestLen = {}, 0
	for a10 = 1, 380 do
		local amp = a10 / 1000
		local us: { number }, vs: { number } = {}, {}
		local len = 0
		for i = 0, 255 do
			us[i + 1] = 0.15 + 2.7 * i / 255
			vs[i + 1] = 0.5 + amp * math.sin(2 * math.pi * 10 * i / 255)
			if i > 0 then
				local du, dv = us[i + 1] - us[i], vs[i + 1] - vs[i]
				len += math.sqrt(du * du + dv * dv)
			end
		end
		if len <= maxLen then
			best, bestLen = {}, len
			for i = 1, 256 do
				table.insert(best, math.round(us[i] * QF))
				table.insert(best, math.round(vs[i] * QF))
			end
		end
	end
	return best, bestLen
end

-- the trace step at Iron/Normal x = 0 on that source: the StepSpec prepare would make for it (prepare takes an edge,
-- so it is built as hostile.luau builds it, and start checks it), its pattern and the source's length
local function traceStep(): (StepSpec, PrecisionTrace.Pattern, number)
	local family: DT.FamilyId = "PrecisionTrace"
	local c = IRON_NORMAL
	local p = table.freeze(Params.resolve(family, c.material, c.tier, Params.refFactors(c.x)))
	local source, len = lengthBoundSource(p)
	local P = PT.generate(SEED, p, source)
	local spec: StepSpec = table.freeze({
		family = family,
		seed = SEED,
		params = p,
		source = table.freeze(source),
		durationMs = P.durationMs,
		countdownMs = Network.COUNTDOWN_MS,
		patternHash = P.hash,
		balanceVersion = Versions.BALANCE_VERSION,
	})
	return spec, P, len
end

-- a sample on the pacer at t, grinding, quantized as Input records it
local function onPacerAt(P: PrecisionTrace.Pattern, t: number): TraceRecord
	local u, v = H.fixed(PT.pointAt(P, PT.pacerArc(P, t)))
	return { t = t, u = u, v = v, grind = true }
end

-- X08's edges as S2 hands them to Sharpening: Analyze.run of each X08 fixture, outside the timed part
local function x08Edges(): { Edges.Edge }
	local out: { Edges.Edge } = {}
	for _, alias in { "X08a", "X08b", "X08c" } do
		local id = Cost.X08[alias]
		local edge = Analyze.run(Cost.core(id) :: any).edge
		A.truthy(edge ~= nil, alias .. ": Analyze.run hands over an edge")
		local e = edge :: Analyze.EdgeProfile
		table.insert(out, { name = string.format("%s (%s)", alias, id), chains = e.chains, gripPoint = e.gripPoint,
			gripAxis = e.gripAxis })
	end
	return out
end

-- a 256-point chain at the length bound: a sine of 0.331 stud and 10 periods along 4.4 studs from y 1.48, the grip
-- upright at (0, 0.88) as the reference blades' (M4's fix round 1, wavehand.luau: at Iron/Normal x = 0 the largest
-- amplitude in 0.001 steps that keeps every point, 7 E shrinks and no Douglas–Peucker; 0.332 stud needs a pass)
local function lengthBoundChain(): Edges.Edge
	local pts: { { number } } = {}
	local length = 0
	for i = 0, 255 do
		local pt = { 0.331 * math.sin(2 * math.pi * 10 * i / 255), 1.48 + 4.4 * i / 255 }
		if i > 0 then
			local du, dv = pt[1] - pts[i][1], pt[2] - pts[i][2]
			length += math.sqrt(du * du + dv * dv)
		end
		table.insert(pts, pt)
	end
	return { name = "the length-bound chain", chains = { { points = pts, length = length } },
		gripPoint = { 0, 0.88, 0 }, gripAxis = { 0, 1 } }
end

-- how the hand-off fitted an edge: "7 → 7 points", its E shrinks and Douglas–Peucker attempts when it made any, its
-- length against the bound; or why there is no source, so that generate plays the fallback
local function fitted(e: Edges.Edge, source: { number }?, info: PrecisionTrace.EdgeInfo): string
	local from = #e.chains[1].points
	if source == nil then
		return string.format("%d points → no source (%s): the fallback", from, tostring(info.reason))
	end
	local how = string.format("%d → %d points", from, #source // 2)
	if (info.eSteps :: number) > 0 then
		how ..= string.format(", %d E shrinks", info.eSteps :: number)
	end
	if (info.steps :: number) > 0 then
		how ..= string.format(", %d Douglas–Peucker attempts", info.steps :: number)
	end
	return how .. string.format(", %.2f of %.2f u", info.len :: number, info.maxLen :: number)
end

return Test.suite("Minigames/Perf", function(t)
	t.slow("T-PERF-02 judge at each family's cap, median of PERF_RUNS: HoldZone's 1,024 records, TimingStrike's 512 "
		.. "presses and the trace's 1,479 samples spread over travel ≤ REPLAY_BUDGET_MS", function()
		-- HoldZone, decode's cap: 512 strokes, a down every 35 ms from GO held 15 ms (cost2.luau's stroke, 36 / 15 ms)
		local hzSpec, hzP = H.prepared("HoldZone", STEEL_HARD.material, STEEL_HARD.tier, STEEL_HARD.x, SEED)
		local strokes: { HoldRecord } = {}
		for k = 0, MF.MAX_RECORDS[hzSpec.family] // 2 - 1 do
			table.insert(strokes, { t = 35 * k, down = true })
			table.insert(strokes, { t = 35 * k + 15, down = false })
		end
		A.eq(hzSpec.durationMs, 18000, "HoldZone Steel/Hard x = 1: 18 s")
		A.eq(#strokes, 1024, "HoldZone: 1,024 alternating records")
		A.eq(Minigames.recordCap(hzSpec), #strokes, "HoldZone: the cap")
		-- TimingStrike, decode's cap: 512 presses spread over the step, press i at floor(i · durationMs / 511)
		local tsSpec, tsP = H.prepared("TimingStrike", STEEL_HARD.material, STEEL_HARD.tier, STEEL_HARD.x, SEED)
		local presses: { number } = {}
		local n = MF.MAX_RECORDS[tsSpec.family]
		for i = 0, n - 1 do
			table.insert(presses, math.floor(i * tsSpec.durationMs / (n - 1)))
		end
		A.eq(#presses, 512, "TimingStrike: 512 presses")
		A.eq(Minigames.recordCap(tsSpec), #presses, "TimingStrike: the cap")
		-- the trace at L6's cap on the length-bound source
		local spec, P, len = traceStep()
		local cap = Minigames.recordCap(spec)
		A.eq(#(spec.source :: { number }) // 2, 256, "the source: 256 points")
		printed(len, 8.54, 2, "the source's length")
		printed(PT.PT_LEN_MARGIN * PT.PT_TRAVEL_MAX_MS / 1000 * spec.params.pacerSpeed, 8.55, 2, "the length bound")
		A.eq(spec.durationMs, 29560, "the pattern: 29,560 ms")
		A.eq(cap, math.floor(29560 / PT.PT_EVAL_MS) + 1, "the trace's cap")
		A.eq(cap, 1479)
		local again = Minigames.start(spec)
		A.eq(again and again.hash, spec.patternHash, "start rebuilds the pattern from the spec")
		-- spread over travel: sample i = 0 … cap − 1 at leadInMs + floor(i · travelMs / (cap − 1)), on the pacer
		local spread: { TraceRecord } = {}
		for i = 0, cap - 1 do
			table.insert(spread, onPacerAt(P, P.leadInMs + math.floor(i * P.travelMs / (cap - 1))))
		end
		A.eq(#spread, 1479, "spread: 1,479 records")
		A.deepEq({ spread[1].t, spread[cap].t } :: { any }, { P.leadInMs, P.leadInMs + P.travelMs } :: { any },
			"spread: from the pacer's start to its end")
		-- the honest timeline: one sample per 20 ms from GO
		local honest = H.onPacer(P, PT.PT_EVAL_MS)
		A.eq(#honest, cap, "honest: one sample per due time, 1,479")
		-- decode's cap: 2,048 grinding samples on the pacer, one per 14 ms from GO (to 28,658 ms)
		local full: { TraceRecord } = {}
		for i = 0, MF.MAX_RECORDS[spec.family] - 1 do
			table.insert(full, onPacerAt(P, 14 * i))
		end
		A.eq(#full, 2048, "decode's cap: 2,048 samples")
		local hzBuf, tsBuf = Minigames.encode(hzSpec, strokes), Minigames.encode(tsSpec, presses)
		local spreadBuf, honestBuf = Minigames.encode(spec, spread), Minigames.encode(spec, honest)
		local fullBuf = Minigames.encode(spec, full)
		local refused = Minigames.judge(spec, P, fullBuf, 0)
		A.eq(refused.status, "Invalid", "2,048 samples")
		A.eq(refused.invalidReason, "TooMany", "2,048 samples: judge's cap")

		local list: { Timed } = {
			{ name = "HoldZone", group = "judge", run = function()
				return Minigames.judge(hzSpec, hzP, hzBuf, 0)
			end },
			{ name = "TimingStrike", group = "judge", run = function()
				return Minigames.judge(tsSpec, tsP, tsBuf, 0)
			end },
			{ name = "the trace spread over travel", group = "judge", run = function()
				return Minigames.judge(spec, P, spreadBuf, 0)
			end },
			{ name = "the trace honest", group = "honest", run = function()
				return Minigames.judge(spec, P, honestBuf, 0)
			end },
			{ name = "decode alone of 2,048 samples", group = "decode", run = function()
				return Timeline.decode(fullBuf, "PrecisionTrace", spec.durationMs)
			end },
		}
		local m, warm = measure(list)
		for k = 1, 4 do
			A.eq((warm[k] :: MinigameResult).status, "Ok", list[k].name .. ": replayed whole")
		end
		A.eq(#(warm[5] :: { TraceRecord }), 2048, "decode accepts the 2,048 samples: judge's cap refuses them after it")
		for k, c in list do
			if c.group == "judge" then
				A.truthy(m[k] <= Tol.REPLAY_BUDGET_MS, string.format("judge, %s: %.3f ms", c.name, m[k]))
			end
		end
		print(string.format("  T-PERF-02 judge, median of %d runs, ms Lune (≤ %g): HoldZone Steel/Hard x = 1 "
			.. "(%d ms), %d alternating records %.3f; TimingStrike Steel/Hard x = 1 (%d ms), %d presses %.3f; the "
			.. "trace Iron/Normal x = 0 (%d ms), %d samples spread over travel %.3f", Tol.PERF_RUNS,
			Tol.REPLAY_BUDGET_MS, hzSpec.durationMs, #strokes, m[1], tsSpec.durationMs, #presses, m[2], spec.durationMs,
			#spread, m[3]))
		print(string.format("  T-PERF-02 reported: the honest trace (%d samples, one per 20 ms from GO) %.3f, "
			.. "spread ÷ honest ×%.3f; decode alone of %d samples %.3f, refused by judge (TooMany)", #honest, m[4],
			m[3] / m[4], #full, m[5]))
		local each: { string } = {}
		local past: { string } = {}
		for k, c in list do
			local v = m[k] * STUDIO_PER_LUNE
			table.insert(each, string.format("%s %.2f", c.name, v))
			if v > STUDIO_TARGET_MS then
				table.insert(past, c.name)
			end
		end
		print(string.format("  T-PERF-02 reported against %g ms (§10.5; Studio ≈ Lune × %g): %s; past it: %s",
			STUDIO_TARGET_MS, STUDIO_PER_LUNE, table.concat(each, ", "),
			if #past > 0 then table.concat(past, ", ") else "none"))
	end)

	t.slow("T-PERF-02 prepare for Sharpening (the hand-off + generate), median of PERF_RUNS: X08's edges, "
		.. "Cost.X08_EDGE and the length-bound chain ≤ PT_GENERATE_BUDGET_MS", function()
		local edges = x08Edges()
		local zigzag = Cost.X08_EDGE
		table.insert(edges, { name = "Cost.X08_EDGE (the zigzag)", chains = zigzag.chains, gripPoint = zigzag.gripPoint,
			gripAxis = zigzag.gripAxis })
		local chain = lengthBoundChain()
		A.eq(#chain.chains[1].points, 256, "the chain: 256 points")
		table.insert(edges, chain)
		-- per edge and config, in this order: prepare, the hand-off, generate on the hand-off's source
		local list: { Timed } = {}
		local fits: { string } = {}
		for _, e in edges do
			for _, c in { IRON_NORMAL, STEEL_HARD } do
				local p = Params.resolve("PrecisionTrace", c.material, c.tier, Params.refFactors(c.x))
				local sides = PT.sidesFromChains(e.chains, e.gripPoint, e.gripAxis)
				local source, info = PT.edgeToPanelInfo(sides, e.gripPoint, e.gripAxis, p.pacerSpeed)
				if e == chain then
					A.deepEq({ if source then #source // 2 else 0, info.steps } :: { any }, { 256, 0 } :: { any },
						"the chain at " .. label(c) .. ": every point kept, no Douglas–Peucker")
					if c == IRON_NORMAL then
						A.eq(info.eSteps, 7, "the chain at Iron/Normal x = 0: 7 E shrinks")
						A.truthy((info.len :: number) <= (info.maxLen :: number), "within the bound")
						printed(info.len :: number, 8.53, 2, "its length")
						printed(info.maxLen :: number, 8.55, 2, "the length bound")
					end
				end
				table.insert(fits, fitted(e, source, info))
				local input = H.inputFor("PrecisionTrace", c.material, c.tier, c.x, SEED, e)
				local at = e.name .. " " .. label(c)
				table.insert(list, { name = at, group = "prepare", run = function()
					return Minigames.prepare(input)
				end })
				table.insert(list, { name = at, group = "hand-off", run = function()
					local g, axis = e.gripPoint, e.gripAxis
					return PT.edgeToPanel(PT.sidesFromChains(e.chains, g, axis), g, axis, p.pacerSpeed)
				end })
				table.insert(list, { name = at, group = "generate", run = function()
					return PT.generate(SEED, p, source)
				end })
			end
		end
		local prepared = #list
		for _, family: DT.FamilyId in { "HoldZone", "TimingStrike" } :: { DT.FamilyId } do
			local F = Minigames.get(family)
			for _, c in { IRON_NORMAL, STEEL_HARD } do
				local p = Params.resolve(family, c.material, c.tier, Params.refFactors(c.x))
				table.insert(list, { name = family .. " " .. label(c), group = "family generate", run = function()
					return F.generate(SEED, p, nil)
				end })
			end
		end
		local m, warm = measure(list)
		for k, c in list do
			if c.group == "prepare" then
				local P = warm[k + 2] :: PrecisionTrace.Pattern
				A.eq((warm[k] :: StepSpec).patternHash, P.hash, c.name .. ": prepare plays the hand-off's source")
				A.truthy(m[k] <= Tol.PT_GENERATE_BUDGET_MS, string.format("prepare, %s: %.3f ms", c.name, m[k]))
			end
		end
		local s = STUDIO_PER_LUNE
		print(string.format("  T-PERF-02 prepare for Sharpening = the hand-off + generate, median of %d runs, ms Lune "
			.. "(≤ %g), and × %g:", Tol.PERF_RUNS, Tol.PT_GENERATE_BUDGET_MS, s))
		for k = 1, prepared, 6 do
			local at: { string } = {}
			for j, c in { IRON_NORMAL, STEEL_HARD } do
				local i = k + 3 * (j - 1)
				table.insert(at, string.format("%s %.3f = %.3f + %.3f, × %g %.2f = %.2f + %.2f (%s)", label(c), m[i],
					m[i + 1], m[i + 2], s, m[i] * s, m[i + 1] * s, m[i + 2] * s, fits[(i + 2) // 3]))
			end
			print(string.format("  T-PERF-02   %s: %s", edges[(k + 5) // 6].name, table.concat(at, "; ")))
		end
		local others: { string } = {}
		for k = prepared + 1, #list do
			table.insert(others, string.format("%s %.3f, × %g %.2f", list[k].name, m[k], s, m[k] * s))
		end
		print("  T-PERF-02 reported, generate: " .. table.concat(others, "; "))
		local past: { string } = {}
		print(string.format("  T-PERF-02 reported against %g ms (§10.5; Studio ≈ Lune × %g): prepare %s, the hand-off "
			.. "%s, generate %s, HoldZone and TimingStrike generate %s; past it: %s", STUDIO_TARGET_MS, s,
			studio(list, m, "prepare", past), studio(list, m, "hand-off", past), studio(list, m, "generate", past),
			studio(list, m, "family generate", past), if #past > 0 then table.concat(past, ", ") else "none"))
	end)
end)
