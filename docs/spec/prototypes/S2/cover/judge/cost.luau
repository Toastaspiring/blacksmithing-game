--!nocheck
-- M5 re-measured by the judge, alone on the machine: per design, Lune ms (os.clock, median of RUNS, the six variants
-- interleaved run by run in one process) for the verdict alone (v/<x>V: Sampling.exposure cut after the verdict) and the
-- whole exposure call (v/<x>), today's reading against A's and B's (baseline model), and each one's work units.
-- args: set [runs] [outfile]   set = fixtures | worstP | climbed | attacksJson | climbA | climbB | judge | file:<path>
local process = require("@lune/process")
local fs = require("@lune/fs")
local S = require("./jsets")
local Shapes = require("./repo/src/shared/Physics/Shapes")
local fmt = string.format

local V = {
	todayV = require("./v/todayV/Sampling"), today = require("./v/today/Sampling"),
	AV = require("./v/AV/Sampling"), A = require("./v/A/Sampling"),
	BV = require("./v/BV/Sampling"), B = require("./v/B/Sampling"),
}
local ORDER = { "todayV", "AV", "BV", "today", "A", "B" }

local which = process.args[1] or "fixtures"
local RUNS = tonumber(process.args[2] or "15") or 15
local outFile = process.args[3]

local designs = {}
local function add(list, filter)
	for _, d in ipairs(list) do
		if filter == nil or filter(d.name) then table.insert(designs, d) end
	end
end
if which == "fixtures" then
	add(S.repoF())
	add(S.protoFixtures(), function(n)
		local c = string.sub(n, 1, 1)
		return c == "C" or c == "F" or c == "A" or c == "X" or c == "P" or string.sub(n, 1, 7) == "base of"
	end)
elseif which == "worstP" then
	add(S.worstP())
elseif which == "climbed" then
	add(S.climbed())
elseif which == "attacksJson" then
	add(S.attacksJson())
elseif which == "climbA" then
	add(S.climbA())
elseif which == "climbB" then
	add(S.climbB())
elseif string.sub(which, 1, 5) == "file:" then
	local path = string.sub(which, 6)
	if string.sub(path, -6) == ".jsonl" then add(S.jsonl(path, "")) else add(S.json(path, "")) end
end

local function median(t)
	local c = table.clone(t)
	table.sort(c)
	local n = #c
	if n % 2 == 1 then return c[(n + 1) / 2] end
	return (c[n / 2] + c[n / 2 + 1]) / 2
end

local function prep(parts)
	local P = {}
	for i, p in ipairs(parts) do P[i] = Shapes.prepare(p, i) end
	return P
end

local rows = {}
print(fmt("%-44s %8s %8s %8s | %8s %8s %8s | %10s %10s %10s | %s", "design", "todayV", "AV", "BV", "today", "A", "B",
	"u todayV", "u AV", "u BV", "verdicts"))
for _, d in ipairs(designs) do
	local P = prep(d.parts)
	local units, kept = {}, {}
	for _, v in ipairs(ORDER) do
		local u = 0
		local ex = V[v].exposure(P, function(n) u += n end)
		units[v] = u
		local k = {}
		for i = 1, #P do k[i] = if ex.kept[i] then "1" else "0" end
		kept[v] = table.concat(k)
	end
	local ts = {}
	for _, v in ipairs(ORDER) do ts[v] = {} end
	for r = 1, RUNS do
		for _, v in ipairs(ORDER) do
			local t0 = os.clock()
			V[v].exposure(P, nil)
			ts[v][r] = (os.clock() - t0) * 1000
		end
	end
	local med = {}
	for _, v in ipairs(ORDER) do med[v] = median(ts[v]) end
	local same = if kept.todayV == kept.AV and kept.AV == kept.BV then "same" else fmt("today %s A %s B %s", kept.todayV, kept.AV, kept.BV)
	print(fmt("%-44s %8.2f %8.2f %8.2f | %8.2f %8.2f %8.2f | %10.0f %10.0f %10.0f | %s", string.sub(d.name, 1, 44), med.todayV,
		med.AV, med.BV, med.today, med.A, med.B, units.todayV, units.AV, units.BV, same))
	table.insert(rows, fmt('{"name":"%s","parts":%d,"ms":{"todayV":%.4f,"AV":%.4f,"BV":%.4f,"today":%.4f,"A":%.4f,"B":%.4f},"units":{"todayV":%.0f,"AV":%.0f,"BV":%.0f,"today":%.0f,"A":%.0f,"B":%.0f},"kept":{"today":"%s","A":"%s","B":"%s"}}',
		d.name, #P, med.todayV, med.AV, med.BV, med.today, med.A, med.B, units.todayV, units.AV, units.BV, units.today, units.A,
		units.B, kept.todayV, kept.AV, kept.BV))
end
if outFile then
	fs.writeFile(outFile, "[\n" .. table.concat(rows, ",\n") .. "\n]\n")
end
