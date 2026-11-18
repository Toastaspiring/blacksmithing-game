--!nocheck
-- V2 round 3: Lune ms, median of RUNS rounds (every design once a round): the whole exposure and Analyze.run on the repo,
-- for F5, C05, C09, P1, P4, V1's cluster, the slowest climbed design by Analyze.run and 3 designs past the cap.
local process = require("@lune/process")
local W = "C:/Users/louis/AppData/Local/Temp/claude/C--Users-louis-Documents-RANDOM-ROBLOX/93ae48b4-72b9-4dc1-aa5d-451af1abf9a0/scratchpad/m2x-v2-3"
local R = W .. "/repo"
local Shapes = require(R .. "/src/shared/Physics/Shapes")
local Sampling = require(R .. "/src/shared/Physics/Sampling")
local Analyze = require(R .. "/src/shared/Physics/Analyze")
local B = require(R .. "/tests/fixtures/Blueprints")
local Worst = require(R .. "/docs/spec/prototypes/S2/cover/worst_designs")
local Fx = require(W .. "/emuNow/proto/fixtures")
local fmt = string.format
local RUNS = tonumber(process.args[1]) or 15
local function find(prefix)
	for _, list in ipairs({ Fx.calibration(), Fx.perf() }) do
		for _, b in ipairs(list) do
			if string.sub(b.name, 1, #prefix) == prefix then
				return b.parts
			end
		end
	end
	error(prefix)
end
local designs = { { "F5", B.core("F5").parts }, { "C05", find("C05") }, { "C09", find("C09") }, { "P1", find("P1") }, { "P4", find("P4") } }
for _, d in ipairs(Worst.valid) do
	if d.name == "tclimb_3.json #6" or string.sub(d.name, 1, 10) == "V1 cluster" or d.name == "tclimb_2.json #4" then
		table.insert(designs, { d.name, d.parts })
	end
end
for k = 1, 3 do
	table.insert(designs, { "past " .. Worst.tooComplex[k].name, Worst.tooComplex[k].parts, true })
end
local data = {}
for k, d in ipairs(designs) do
	local P = {}
	for i, p in ipairs(d[2]) do
		P[i] = Shapes.prepare(p, i)
	end
	data[k] = { P = P, core = { schema = 1, name = "t", type = "Sword", parts = d[2] }, e = {}, a = {} }
end
for _ = 1, RUNS do
	for k, d in ipairs(designs) do
		local x = data[k]
		if not d[3] then
			local t0 = os.clock()
			Sampling.exposure(x.P)
			table.insert(x.e, (os.clock() - t0) * 1000)
		end
		local t1 = os.clock()
		Analyze.run(x.core)
		table.insert(x.a, (os.clock() - t1) * 1000)
	end
end
local function median(t)
	if #t == 0 then
		return 0
	end
	table.sort(t)
	return t[(#t + 1) // 2]
end
for k, d in ipairs(designs) do
	print(fmt("%-42s exposure %6.2f  Analyze.run %6.2f", string.sub(d[1], 1, 42), median(data[k].e), median(data[k].a)))
end
