--!nocheck
-- m2r5: cost. Analyze.run (the M2 path) per variant, alternating inside each round, median of ROUNDS; M3's share = the prototype's edge + factor times on the build's
-- exposure, median of 5, as the verifier computed it. The verdict's own stats per design under the first variant.
-- args: rounds "V1 V2 ..." [json files of extra designs...]
local process = require("@lune/process")
local fs = require("@lune/fs")
local serde = require("@lune/serde")
local Analyze = require("./tree/src/shared/Physics/Analyze")
local RepoAnalyze = require("./repo/src/shared/Physics/Analyze")
local Sampling = require("./tree/src/shared/Physics/Sampling")
local Emu = require("./proto/analyze_build")
local L = require("./lib")
local Fx = require("./proto/fixtures")
local V = require("./variants")
local fmt = string.format
local I = L.I

local ROUNDS = tonumber(process.args[1]) or 15
local NAMES = string.split(process.args[2] or "A", " ")

local function median(list)
	local t = table.clone(list)
	table.sort(t)
	return t[(#t + 1) // 2]
end

local list = {}
local function withSpeck(short, parts)
	local speck = L.copyParts(parts)
	if #speck >= 24 then
		speck[#speck] = { id = 900, slot = speck[#speck].slot, shape = "Block", material = "Iron", pos = { 0.7, 0.2, 0.2 }, rot = I, size = { 0.05, 0.05, 0.05 } }
	else
		table.insert(speck, { id = 900, slot = "Pommel", shape = "Block", material = "Iron", pos = { 0.7, 0.2, 0.2 }, rot = I, size = { 0.05, 0.05, 0.05 } })
	end
	table.insert(list, { short .. " + speck", speck })
end
for _, b in ipairs(Fx.golden()) do
	if string.sub(b.name, 1, 2) == "F5" then
		table.insert(list, { "F5", b.parts })
	end
end
for _, b in ipairs(Fx.calibration()) do
	local tag = string.sub(b.name, 1, 3)
	if b.name == "C02 Arming (Iron)" or tag == "C05" or tag == "C09" or tag == "C10" then
		table.insert(list, { tag, b.parts })
	end
end
for _, b in ipairs(Fx.perf()) do
	local short = string.sub(b.name, 1, 2)
	table.insert(list, { short, b.parts })
	if short == "P1" or short == "P2" or short == "P3" then
		withSpeck(short, b.parts)
	end
end
for a = 3, #process.args do
	local data = serde.decode("json", fs.readFile(process.args[a]))
	for i, d in ipairs(data) do
		table.insert(list, { fmt("%s#%d", string.match(process.args[a], "[^/]*$"), i), d.parts })
	end
end

local out = {}
for _, it in ipairs(list) do
	local name, parts = it[1], it[2]
	local core = { schema = 1, name = "x", type = "Sword", parts = parts }
	local times = {}
	for _, v in ipairs(NAMES) do times[v] = {} end
	for r = 1, ROUNDS do
		for k = 0, #NAMES - 1 do
			local v = NAMES[(k + r - 1) % #NAMES + 1]
			local mod = Analyze
			if v == "R" then
				mod = RepoAnalyze
			else
				V.apply(Sampling, v)
			end
			collectgarbage("collect")
			local t0 = os.clock()
			mod.run(core, { measureInvalid = true })
			table.insert(times[v], (os.clock() - t0) * 1000)
		end
	end
	local row = {}
	for _, v in ipairs(NAMES) do
		local m3 = {}
		if v == "R" then
			V.apply(Sampling, "A")
			-- the repo's kept row, on the emulator's measure: close enough for M3's share (edge and factors read kept, areas)
		else
			V.apply(Sampling, v)
		end
		for r = 1, 5 do
			collectgarbage("collect")
			local R = Emu.run({ name = "x", parts = parts }, { measureInvalid = true, build = true })
			m3[r] = 1000 * ((R.T.edge or 0) + (R.T.factors or 0))
		end
		local a, b = median(times[v]), median(m3)
		table.insert(row, { v = v, m2 = a, m3 = b, sum = a + b, studio = (a + b) * 2.6 })
	end
	local line = {}
	for _, c in ipairs(row) do
		table.insert(line, fmt("%s %5.2f+%5.2f=%5.2f", c.v, c.m2, c.m3, c.sum))
	end
	print(fmt("%-22s %s", string.sub(name, 1, 22), table.concat(line, " | ")))
	table.insert(out, { name = name, row = row })
end
if process.env.COST_OUT then
	fs.writeFile(process.env.COST_OUT, serde.encode("json", out))
end
