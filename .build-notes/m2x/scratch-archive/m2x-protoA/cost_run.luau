--!nocheck
-- M5: per design, Lune ms (os.clock, median of RUNS) of the verdict alone and of the whole exposure call, old reading
-- (base/) against the new (Physics/Cover, 3 models), in one process; work units through spend for each.
-- args: set [runs] [outfile]   set = fixtures | worst | climbed | all | jsonl:<path>
local process = require("@lune/process")
local fs = require("@lune/fs")
local serde = require("@lune/serde")
local S = require("./sets")
local Shapes = require("./repo/src/shared/Physics/Shapes")
local fmt = string.format

local V = {
	old = { full = require("./v/old/Sampling"), verdict = require("./v/oldV/Sampling") },
	base = { full = require("./v/new_base/Sampling"), verdict = require("./v/newV_base/Sampling") },
	canon = { full = require("./v/new_canon/Sampling"), verdict = require("./v/newV_canon/Sampling") },
	fine = { full = require("./v/new_fine/Sampling"), verdict = require("./v/newV_fine/Sampling") },
}
local ORDER = { "old", "base", "canon", "fine" }
if process.env.VARIANTS then
	ORDER = {}
	for v in string.gmatch(process.env.VARIANTS, "[^,]+") do table.insert(ORDER, v) end
end

local which = process.args[1] or "fixtures"
local RUNS = tonumber(process.args[2] or "15")
local outFile = process.args[3]

local designs = {}
local function add(list, filter)
	for _, d in ipairs(list) do
		if filter == nil or filter(d.name) then table.insert(designs, d) end
	end
end
if which == "fixtures" or which == "all" then
	add(S.repoF())
	add(S.protoFixtures(), function(n)
		local c = string.sub(n, 1, 1)
		return c == "C" or c == "F" or c == "A" or c == "X" or c == "P" or string.sub(n, 1, 7) == "base of"
	end)
end
if which == "worst" or which == "all" then add(S.worstP()) end
if which == "climbed" or which == "all" then add(S.climbed()); add(S.attacksJson()) end
if string.sub(which, 1, 6) == "jsonl:" then add(S.jsonl(string.sub(which, 7))) end
if string.sub(which, 1, 5) == "json:" then add(S.json(string.sub(which, 6))) end
if string.sub(which, 1, 6) == "climb:" then
	-- the best design of each climb seed: climb:<seed>,<seed>...
	for sd in string.gmatch(string.sub(which, 7), "[^,]+") do
		local list = S.json("out/climb_" .. sd .. ".json", "climb seed " .. sd .. " #")
		table.insert(designs, list[1])
	end
end

local function median(t)
	table.sort(t)
	local n = #t
	if n % 2 == 1 then return t[(n + 1) / 2] end
	return (t[n / 2] + t[n / 2 + 1]) / 2
end

local function prep(parts)
	local P = {}
	for i, p in ipairs(parts) do P[i] = Shapes.prepare(p, i) end
	return P
end

local function timeIt(fn, P, runs)
	local units = 0
	local spend = function(n) units += n end
	fn(P, spend) -- warm
	local u0 = units
	units = 0
	local ts = {}
	for r = 1, runs do
		local t0 = os.clock()
		fn(P, nil)
		ts[r] = (os.clock() - t0) * 1000
	end
	return median(ts), u0
end

local rows = {}
print(fmt("%-58s verdict ms: %s | exposure ms: same | verdict units: same | kept: same", "design (ms Lune, median of " .. RUNS .. ")", table.concat(ORDER, " ")))
for _, d in ipairs(designs) do
	local P = prep(d.parts)
	local row = { name = d.name, n = #P, verdict = {}, full = {}, units = {}, unitsFull = {}, kept = {} }
	for _, k in ipairs(ORDER) do
		local v = V[k]
		row.verdict[k], row.units[k] = timeIt(v.verdict.exposure, P, RUNS)
		row.full[k], row.unitsFull[k] = timeIt(v.full.exposure, P, RUNS)
		local e = v.verdict.exposure(P)
		local c = 0
		for i = 1, #P do if e.kept[i] then c += 1 end end
		row.kept[k] = c
	end
	table.insert(rows, row)
	local a, b, c, k = {}, {}, {}, {}
	for _, v in ipairs(ORDER) do
		table.insert(a, fmt("%7.2f", row.verdict[v])); table.insert(b, fmt("%7.2f", row.full[v])); table.insert(c, fmt("%8.0f", row.units[v])); table.insert(k, tostring(row.kept[v]))
	end
	print(fmt("%-58s %s | %s | %s | %s", string.sub(d.name, 1, 58), table.concat(a, " "), table.concat(b, " "), table.concat(c, " "), table.concat(k, " ")))
end
if outFile then fs.writeFile(outFile, serde.encode("json", rows)) end
