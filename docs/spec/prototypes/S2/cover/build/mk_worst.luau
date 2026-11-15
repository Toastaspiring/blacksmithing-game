--!nocheck
-- The worst designs file for T-PERF-01 and S-PERF-01 (docs/spec/prototypes/S2/cover/worst_designs.luau): the slowest VALID
-- designs under VERDICT_WORK_MAX the time climbs found (their exact parts: the climbs' 17-digit literals), and designs over it,
-- which must come back TooComplex promptly (the judge's, prototype A's and B's climbs and worst_P's heaviest). Each canonical;
-- units without the cap (../snap), validity with it (../snapcap), the verdict's quiet ms (median of RUNS).
-- args: out runs climb1.json ...
local process = require("@lune/process")
local fs = require("@lune/fs")
local serde = require("@lune/serde")
local luau = require("@lune/luau")
local L = require("./lib")
local AnalyzeCap = require("../snapcap/src/shared/Physics/Analyze")
local fmt = string.format
local OUT = process.args[1]
local RUNS = tonumber(process.args[2]) or 15

local function canonical(parts)
	local r = L.Canonical.draft({ schema = 1, name = "worst", type = "Sword", parts = parts })
	assert(r.ok, tostring(r.code) .. " " .. tostring(r.path))
	return r.value.parts
end
local function timeOf(parts)
	local P = L.prep(parts)
	local e = L.SamplingV.exposure(P, nil)
	local ts = {}
	for r = 1, RUNS do
		local t0 = os.clock()
		L.SamplingV.exposure(P, nil)
		ts[r] = (os.clock() - t0) * 1000
	end
	return e.verdictWork, L.median(ts)
end

local valid, over = {}, {}
for a = 3, #process.args do
	local rows = serde.decode("json", fs.readFile(process.args[a]))
	for n, row in ipairs(rows) do
		local parts = luau.load("return { " .. row.lua .. " }")()
		parts = canonical(parts)
		local units, ms = timeOf(parts)
		local run = AnalyzeCap.run({ schema = 1, name = "worst", type = "Sword", parts = parts })
		if run.validation.ok then
			table.insert(valid, { name = fmt("%s #%d", string.match(process.args[a], "[^/\\]+$"), n), units = units, ms = ms, parts = parts })
		end
	end
end
table.sort(valid, function(x, y) return x.ms > y.ms end)
while #valid > 8 do table.remove(valid) end

local function addOver(list, prefix)
	for _, d in ipairs(list) do
		local parts = canonical(d.parts)
		local P = L.prep(parts)
		local units = L.SamplingV.exposure(P, nil).verdictWork
		if units > L.Balance.Geometry.VERDICT_WORK_MAX or units > 700000 then
			local run = AnalyzeCap.run({ schema = 1, name = "worst", type = "Sword", parts = parts })
			local codes = {}
			for _, e in ipairs(run.validation.errors) do table.insert(codes, e.code) end
			if table.find(codes, "TooComplex") then
				table.insert(over, { name = prefix .. d.name, units = units, parts = parts })
			end
		end
	end
end
addOver(L.judgeWorst(), "")
addOver(L.climbA(), "")
addOver(L.climbB(), "")
addOver(L.worstP(), "")

local out = { "--!strict",
	"-- docs/spec/prototypes/S2/cover/worst_designs.luau — evidence data (E-S2.12), not game code: the designs T-PERF-01 and",
	"-- S-PERF-01 run (§14.11). `valid`: the slowest canonical, valid designs under VERDICT_WORK_MAX that 4 climbs on the",
	"-- verdict's wall time found (18,000 evaluations), with their units and quiet Lune ms for the verdict alone. `tooComplex`:",
	"-- canonical designs past it (the judge's, prototype A's and B's climbs, worst_P.json's heaviest), which Analyze must answer",
	"-- TooComplex at once; units are what the verdict would spend without the cap. Luau literals, 17 significant digits.",
	"-- Written by build/mk_worst.luau.", "", "return {", "\tvalid = {" }
local function emit(list, withMs)
	for _, d in ipairs(list) do
		table.insert(out, "\t\t{")
		table.insert(out, fmt("\t\t\tname = %q,", d.name))
		table.insert(out, fmt("\t\t\tunits = %s,", L.num(d.units)))
		if withMs then table.insert(out, fmt("\t\t\tverdictMs = %.2f,", d.ms)) end
		table.insert(out, "\t\t\tparts = {")
		for _, p in ipairs(d.parts) do table.insert(out, "\t\t\t\t" .. L.partLiteral(p) .. ",") end
		table.insert(out, "\t\t\t},")
		table.insert(out, "\t\t},")
	end
end
emit(valid, true)
table.insert(out, "\t},")
table.insert(out, "\ttooComplex = {")
emit(over, false)
table.insert(out, "\t},")
table.insert(out, "}")
fs.writeFile(OUT, table.concat(out, "\n") .. "\n")
for _, d in ipairs(valid) do print(fmt("valid       %-24s %9.0f units %7.2f ms", d.name, d.units, d.ms)) end
for _, d in ipairs(over) do print(fmt("tooComplex  %-50s %10.0f units", string.sub(d.name, 1, 50), d.units)) end
