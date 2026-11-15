--!nocheck
-- fix-4: designs of a set by name (plausible, corpus or fixtures, as bc.luau lists them), and parts of each: the reading
-- and verdict on each named tree, the truth (VisibleOracle, fine lattice: Oracle.share), and D on each tree's verdict and
-- the truth's row (the last tree's measure), for the valid ones.
--   lune run moved -- <set> <names file: one "design<TAB>part,part" a line> <tree> [<tree> ...]
local process = require("@lune/process")
local fs = require("@lune/fs")
local serde = require("@lune/serde")
local V = require("./vlab")
local Drep = require("./drep")
local S = "C:/Users/louis/AppData/Local/Temp/claude/C--Users-louis-Documents-RANDOM-ROBLOX/93ae48b4-72b9-4dc1-aa5d-451af1abf9a0/scratchpad"
local REPO = S .. "/m2x-r4-base/repo"
local fmt = string.format
local set, file = process.args[1], process.args[2]
local names = {}
for i = 3, #process.args do
	table.insert(names, process.args[i])
end
local want = {}
for line in string.gmatch(fs.readFile(file), "[^\n]+") do
	local name, parts = string.match(line, "^(.-)\t(.*)$")
	local idx = {}
	for x in string.gmatch(parts, "%d+") do
		table.insert(idx, tonumber(x))
	end
	want[name] = idx
end
local designs = {}
if set == "plausible" then
	for _, d in ipairs((require :: any)(REPO .. "/tests/Physics/PlausibleDesigns").all()) do
		designs[d.name] = d.parts
	end
elseif set == "corpus" then
	for line in string.gmatch(fs.readFile(S .. "/m2x-protoA/out/corpus_all.jsonl"), "[^\n]+") do
		local d = serde.decode("json", line)
		designs[d.name] = d.parts
	end
end
local N = V.tree(names[#names])
local sum = { parts = 0, toward = 0, away = 0, flipsBefore = 0, flipsAfter = 0 }
for name, idx in pairs(want) do
	local parts = designs[name]
	assert(parts, name)
	local first = math.huge
	for _, i in ipairs(idx) do
		first = math.min(first, i)
	end
	local out = Drep.report(name, parts, 1, names, true)
	for _, i in ipairs(idx) do
		local cells = {}
		for t = 1, #names do
			table.insert(cells, fmt("%s %s %s", names[t], V.pct(out.reads[t][i]), if out.kept[t][i] then "K" else "E"))
		end
		local before, after = out.kept[1][i], out.kept[#names][i]
		local verdict = ""
		if before ~= after then
			sum.parts += 1
			if after == out.row[i] then
				sum.toward += 1
				verdict = " toward the truth"
			else
				sum.away += 1
				verdict = " AWAY from the truth"
			end
		end
		print(fmt("%s part %d %s: %s; truth %s %s%s", name, i, parts[i].shape, table.concat(cells, ", "), V.pct(out.truth[i]), if out.row[i] then "K" else "E", verdict))
	end
	if out.valid then
		local dl = {}
		for t = 1, #names do
			table.insert(dl, fmt("%s %s (|dD| %.4f%s)", names[t], V.dline(out.D[t]), out.dd[t], if out.flips[t] then " TIER" else ""))
		end
		print("  D " .. table.concat(dl, "; ") .. "; truth " .. V.dline(out.Dt))
		if out.flips[1] then
			sum.flipsBefore += 1
		end
		if out.flips[#names] then
			sum.flipsAfter += 1
		end
	else
		print("  invalid")
	end
end
print(fmt("%d part verdicts move: %d toward the truth, %d away; designs with a tier the truth's row does not have: %d before, %d after",
	sum.parts, sum.toward, sum.away, sum.flipsBefore, sum.flipsAfter))
