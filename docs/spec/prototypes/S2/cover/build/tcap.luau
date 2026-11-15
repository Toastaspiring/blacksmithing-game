--!nocheck
-- How soon a design past VERDICT_WORK_MAX comes back (worst_designs.luau's `tooComplex`, the build: ../snapcap): the
-- exposure's units, its first run with preparation (as Cover.spec (f) had it before it took the best of 3), the exposure
-- alone (best and median of RUNS) and Analyze.run (median of RUNS), Lune ms. args: runs
local process = require("@lune/process")
local Shapes = require("../snapcap/src/shared/Physics/Shapes")
local Sampling = require("../snapcap/src/shared/Physics/Sampling")
local Analyze = require("../snapcap/src/shared/Physics/Analyze")
local Worst = require("../snapcap/docs/spec/prototypes/S2/cover/worst_designs")
local RUNS = tonumber(process.args[1]) or 15
local fmt = string.format

local function prepared(parts)
	local out = table.create(#parts)
	for i, p in ipairs(parts) do out[i] = Shapes.prepare(p, i) end
	return out
end
local function median(ts)
	table.sort(ts)
	return ts[(#ts + 1) // 2]
end

print(fmt("%-52s %9s %7s %7s %7s %8s  %s", "design", "units", "first", "best", "median", "analyze", "last code"))
local lo, hi = math.huge, 0
for _, d in ipairs(Worst.tooComplex) do
	local t0 = os.clock()
	local e = Sampling.exposure(prepared(d.parts))
	local first = (os.clock() - t0) * 1000
	local P = prepared(d.parts)
	local ts, as = {}, {}
	for r = 1, RUNS do
		local t1 = os.clock()
		Sampling.exposure(P)
		ts[r] = (os.clock() - t1) * 1000
	end
	local core = { schema = 1, name = "worst", type = "Sword", parts = d.parts }
	local run
	for r = 1, RUNS do
		local t2 = os.clock()
		run = Analyze.run(core, { measureInvalid = true })
		as[r] = (os.clock() - t2) * 1000
	end
	local best = math.min(table.unpack(ts))
	local am = median(as)
	lo, hi = math.min(lo, am), math.max(hi, am)
	assert(e.capped and run.physics == nil)
	print(fmt("%-52s %9.0f %7.2f %7.2f %7.2f %8.2f  %s", string.sub(d.name, 1, 52), e.verdictWork, first, best, median(ts), am,
		run.validation.errors[#run.validation.errors].code))
end
print(fmt("Analyze.run, median of %d: %.2f to %.2f ms", RUNS, lo, hi))
