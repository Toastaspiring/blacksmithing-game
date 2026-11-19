--!strict
-- T-PERF-01 Physics/Analyze's cost (SPEC §4.9, §14.11, §16.32; E-S2.8, E-S2.12; the M3 plan's [8.4] and [9]), Lune.
-- Cases: the F, C and X fixtures; X08's cost cases (aliases of P2, P1 and P5, P1 once under both names), P3, P4; P1–P3
-- with a Dust speck, floating (measureInvalid) or attached; worst_designs.luau's slowest valid designs under
-- VERDICT_WORK_MAX and its TooComplex designs past it (tests/fixtures/Cost.TPERF).
-- Method (the plan's perf.luau, M2's d_cost.luau): a warm-up run per case, then PERF_RUNS rounds, odd ones forward
-- through the cases and even ones backward; per case and round a timed run, and a run whose checkpoint times its
-- longest stretch (run start to the first checkpoint, checkpoint to checkpoint, the last to the run's end), each after
-- a full collection, as §4.9's figures were taken. A case's numbers are its medians.
-- Asserted (§14.11): every total ≤ ANALYSIS_LUNE_MAX_MS, TooComplex's answer included; the longest stretch ≤
-- CHECKPOINT_GAP_LUNE_MS on the F, C and X fixtures. Reported, printed: P1–P5's, the specks' and the worst designs'
-- stretches against that bound (a collection can pass it there, §4.9), and P1's and the worst valid designs' totals
-- against 29 ms, §4.9's 75 ms Studio ceiling ÷ 2.6. Run it alone (--filter Physics/Perf) on a quiet machine: other load
-- reaches the stretches and the totals first, and a larger heap the stretches (the full suite runs it in path order,
-- after 635 of its 772 cases); a failure under load is re-run alone before it counts, and under this machine's ordinary
-- load (7–61 % busy) the slowest valid design sits at the 60 ms guard (SPEC §14.11).

local luau = require("@lune/luau")
local Test = require("../lib/Test")
local A = require("../lib/Assert")
local Tol = require("../lib/Tol")
local Blueprints = require("../fixtures/Blueprints")
local Calibration = require("../fixtures/Calibration")
local Cost = require("../fixtures/Cost")
local Regression = require("../fixtures/Regression")
local Analyze = require("../../src/shared/Physics/Analyze")

local STUDIO_CEILING_MS = 75 -- §4.9: real designs in Studio, gated by S-PERF-01
local STUDIO_PER_LUNE = 2.6 -- §4.9's assumption, which S-PERF-01 measures

-- A full collection. luau-lsp's standard platform declares no collectgarbage, so it runs from a chunk of its own.
local collect: () -> () = luau.load('collectgarbage("collect")', { debugName = "T-PERF-01 collect" })

type Case = { name: string, core: any, measureInvalid: boolean, group: string }
type Timing = { name: string, group: string, total: number, gap: number }

-- group: "fixture" (the F, C and X fixtures, the stretch asserted), "cost" (P1–P5 and the specks), "valid" and
-- "tooComplex" (worst_designs.luau)
local function cases(): { Case }
	local out: { Case } = {}
	for _, id in Blueprints.order do
		table.insert(out, { name = id, core = Blueprints.get(id).core, measureInvalid = false, group = "fixture" })
	end
	for _, set in { Calibration.list, Regression.list } do
		for _, f in set do
			table.insert(out, { name = f.id, core = f.core, measureInvalid = false, group = "fixture" })
		end
	end
	for _, c in Cost.TPERF do
		local group = if string.sub(c.name, 1, 11) == "worst valid" then "valid"
			elseif string.sub(c.name, 1, 10) == "TooComplex" then "tooComplex"
			else "cost"
		table.insert(out, { name = c.name, core = c.core, measureInvalid = c.measureInvalid, group = group })
	end
	return out
end

local function median(values: { number }): number
	local sorted = table.clone(values)
	table.sort(sorted)
	return sorted[(#sorted + 1) // 2]
end

-- One run's longest stretch between checkpoints, ms; the checkpoint's own bookkeeping left out.
local function longestStretch(c: Case): number
	local longest = 0
	local last = os.clock()
	Analyze.run(c.core, { measureInvalid = c.measureInvalid, checkpoint = function()
		longest = math.max(longest, os.clock() - last)
		last = os.clock()
	end })
	return math.max(longest, os.clock() - last) * 1000
end

local function measure(list: { Case }): { Timing }
	local totals: { { number } } = {}
	local gaps: { { number } } = {}
	for k, c in list do
		local warm = Analyze.run(c.core, { measureInvalid = c.measureInvalid })
		if c.group == "tooComplex" then
			local errors = warm.validation.errors
			A.eq(errors[#errors].code, "TooComplex", c.name)
		end
		totals[k], gaps[k] = {}, {}
	end
	for round = 1, Tol.PERF_RUNS do
		local forward = round % 2 == 1
		for step = 1, #list do
			local k = if forward then step else #list + 1 - step
			local c = list[k]
			collect()
			local t0 = os.clock()
			Analyze.run(c.core, { measureInvalid = c.measureInvalid })
			table.insert(totals[k], (os.clock() - t0) * 1000)
			collect()
			table.insert(gaps[k], longestStretch(c))
		end
	end
	local out: { Timing } = {}
	for k, c in list do
		out[k] = { name = c.name, group = c.group, total = median(totals[k]), gap = median(gaps[k]) }
	end
	return out
end

-- "lo–hi ms (the case at hi)" over a group's timings.
local function span(timings: { Timing }, group: string, field: string): string
	local lo, hi, at = math.huge, -math.huge, ""
	for _, t in timings do
		if t.group == group then
			local v = (t :: any)[field]
			lo = math.min(lo, v)
			if v > hi then
				hi, at = v, t.name
			end
		end
	end
	return string.format("%.3f–%.3f (%s)", lo, hi, at)
end

return Test.suite("Physics/Perf", function(t)
	t.slow("T-PERF-01 Analyze.run, median of PERF_RUNS: every total ≤ ANALYSIS_LUNE_MAX_MS; the stretches ≤ "
		.. "CHECKPOINT_GAP_LUNE_MS on the F, C and X fixtures, reported on the rest", function()
		local timings = measure(cases())
		local over: { string } = {}
		local p1, studio = 0, STUDIO_CEILING_MS / STUDIO_PER_LUNE
		local overStudio, valid = 0, 0
		for _, m in timings do
			A.truthy(m.total <= Tol.ANALYSIS_LUNE_MAX_MS, string.format("%s: %.2f ms", m.name, m.total))
			if m.group == "fixture" then
				local what = string.format("%s: longest stretch %.3f ms", m.name, m.gap)
				A.truthy(m.gap <= Tol.CHECKPOINT_GAP_LUNE_MS, what)
			elseif m.gap > Tol.CHECKPOINT_GAP_LUNE_MS then
				table.insert(over, string.format("%s %.3f", m.name, m.gap))
			end
			if m.name == "P1 (X08b)" then
				p1 = m.total
			elseif m.group == "valid" then
				valid += 1
				overStudio += if m.total > studio then 1 else 0
			end
		end
		print(string.format("  T-PERF-01 median of %d runs, ms Lune; the F, C and X fixtures: total %s, longest "
			.. "stretch %s", Tol.PERF_RUNS, span(timings, "fixture", "total"), span(timings, "fixture", "gap")))
		print(string.format("  T-PERF-01 reported against %.2f ms (the stretch): P1–P5 and the specks %s, the worst "
			.. "valid designs %s, past the cap %s; past it: %s", Tol.CHECKPOINT_GAP_LUNE_MS,
			span(timings, "cost", "gap"), span(timings, "valid", "gap"), span(timings, "tooComplex", "gap"),
			if #over > 0 then table.concat(over, ", ") else "none"))
		print(string.format("  T-PERF-01 reported against %.1f ms (75 ÷ 2.6): P1 %.2f; the worst valid designs %s, %d "
			.. "of %d past it; P1–P5 and the specks %s; TooComplex answered in %s", studio, p1,
			span(timings, "valid", "total"), overStudio, valid, span(timings, "cost", "total"),
			span(timings, "tooComplex", "total")))
	end)
end)
