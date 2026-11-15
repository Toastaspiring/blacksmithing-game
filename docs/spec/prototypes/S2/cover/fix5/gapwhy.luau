--!nocheck
-- m2x-fix-5: what runs in a design's longest stretch between checkpoints. Analyze.run on the gaps tree (the build, its
-- checkpoint told the units since the last and the report that crossed CHECK_UNITS, −1 at a phase), RUNS runs; per run
-- every stretch (from the end of one checkpoint's bookkeeping to the next checkpoint, so that the bookkeeping is not in
-- it): its ms, units, the report that ended it, where the checkpoint was called from, and the heap (collectgarbage
-- "count") at both ends. Then the median run's longest stretch and the ten longest of all runs, and the same with a full
-- collection at every checkpoint (outside the stretches) when `collect` is given.
--   lune run gapwhy -- <design name in worst_designs (valid or tooComplex) | fixture prefix> [runs] [collect]
local process = require("@lune/process")
local W = "C:/Users/louis/AppData/Local/Temp/claude/C--Users-louis-Documents-RANDOM-ROBLOX/93ae48b4-72b9-4dc1-aa5d-451af1abf9a0/scratchpad/m2x-fix-5"
local function req(p)
	return (require :: any)(p)
end
local Analyze = req(W .. "/gaps/src/shared/Physics/Analyze")
local Worst = req(W .. "/gaps/docs/spec/prototypes/S2/cover/worst_designs")
local Fx = req(W .. "/gaps/docs/spec/prototypes/S2/v2/fixtures")
local B = req(W .. "/gaps/tests/fixtures/Blueprints")
local fmt = string.format
local name = process.args[1] or "tclimb_4.json #1"
local RUNS = tonumber(process.args[2]) or 15
local COLLECT = process.args[3] == "collect"

local parts
for _, list in ipairs({ Worst.valid, Worst.tooComplex }) do
	for _, d in ipairs(list) do
		if d.name == name then
			parts = d.parts
		end
	end
end
if not parts then
	for _, list in ipairs({ Fx.calibration(), Fx.regression(), Fx.perf() }) do
		for _, b in ipairs(list) do
			local bb = b.fixture or b
			if bb.parts and string.sub(bb.name, 1, #name) == name then
				parts = bb.parts
			end
		end
	end
end
if not parts then
	parts = B.core(name).parts
end
local core = { schema = 1, name = "g", type = "Sword", parts = parts }

local function where()
	-- the frames above Analyze's spend or phase: which loop reported
	local out = {}
	for level = 3, 9 do
		local src, line, fn = debug.info(level, "sln")
		if src == nil then
			break
		end
		local f = string.match(src, "Physics[/\\](%w+)%.luau")
		if f then
			table.insert(out, f .. ":" .. tostring(line) .. (if fn and fn ~= "" then "(" .. fn .. ")" else ""))
		end
	end
	return table.concat(out, " < ")
end

local runs = {}
for run = 1, RUNS do
	local stretches = {}
	local lastEnd, lastWhere, lastHeap = os.clock(), "start", collectgarbage("count")
	local t0 = os.clock()
	Analyze.run(core, { measureInvalid = true, checkpoint = function(u, n)
		local now = os.clock()
		local heap = collectgarbage("count")
		local w = where()
		table.insert(stretches, { ms = (now - lastEnd) * 1000, units = u or 0, report = n or 0, from = lastWhere, to = w,
			heap0 = lastHeap, heap1 = heap })
		if COLLECT then
			collectgarbage("collect")
		end
		lastWhere, lastHeap = w, collectgarbage("count")
		lastEnd = os.clock()
	end })
	local now = os.clock()
	table.insert(stretches, { ms = (now - lastEnd) * 1000, units = 0, report = 0, from = lastWhere, to = "end",
		heap0 = lastHeap, heap1 = collectgarbage("count") })
	local longest = 1
	for i, s in ipairs(stretches) do
		if s.ms > stretches[longest].ms then
			longest = i
		end
	end
	table.insert(runs, { total = (now - t0) * 1000, stretches = stretches, longest = longest, worst = stretches[longest].ms })
end
table.sort(runs, function(a, b)
	return a.worst < b.worst
end)
local med = runs[(#runs + 1) // 2]
local s = med.stretches[med.longest]
local ms = {}
for _, x in ipairs(med.stretches) do
	table.insert(ms, x.ms)
end
table.sort(ms)
print(fmt("%s (%s): %d runs; the median run's longest stretch %.3f ms (runs' longest %.3f–%.3f); that run %d stretches, median %.3f ms, its run %.2f ms",
	name, if COLLECT then "a full collection at every checkpoint" else "plain", RUNS, s.ms, runs[1].worst, runs[#runs].worst, #med.stretches,
	ms[(#ms + 1) // 2], med.total))
print(fmt("   stretch %d: %.0f units (the report ending it %s), heap %.0f → %.0f KB (%s)", med.longest, s.units,
	if s.report < 0 then "a phase" else fmt("%.1f", s.report), s.heap0, s.heap1, if s.heap1 < s.heap0 then "a collection ran in it" else "no drop"))
print("   from " .. s.from)
print("   to   " .. s.to)
-- every run's stretches past 0.25 ms: where, units, whether the heap dropped
local all = {}
for _, r in ipairs(runs) do
	for _, x in ipairs(r.stretches) do
		table.insert(all, x)
	end
end
table.sort(all, function(a, b)
	return a.ms > b.ms
end)
local drops, n = 0, 0
for _, x in ipairs(all) do
	if x.ms > 0.25 then
		n += 1
		if x.heap1 < x.heap0 then
			drops += 1
		end
	end
end
print(fmt("   stretches past 0.25 ms over all runs: %d, of which the heap dropped in %d", n, drops))
for i = 1, math.min(10, #all) do
	local x = all[i]
	print(fmt("   %.3f ms %6.0f u (%s) heap %.0f → %.0f  %s  →  %s", x.ms, x.units, if x.report < 0 then "phase" else fmt("%.1f", x.report),
		x.heap0, x.heap1, x.from, x.to))
end
