--!nocheck
-- Cost, quiet. Rounds of alternating runs over the designs: the M2 path (Analyze.run, measureInvalid), the verdict alone, then M3's share (the prototype's edge and factors on the build's exposure). Medians.
-- Gaps: the longest run between checkpoints, per run, median over rounds, and where the longest of all ended. args: rounds [json...]
local process = require("@lune/process")
local fs = require("@lune/fs")
local serde = require("@lune/serde")
local V = require("./v1")
local Analyze = V.Analyze
local Force = V.Force
local Emu = V.Emu
local Fx = V.Fx
local Vd = require("./plain/Sampling")
local fmt = string.format
local I = V.I

local ROUNDS = tonumber(process.args[1]) or 15

local function median(t)
	local c = table.clone(t)
	table.sort(c)
	return c[(#c + 1) // 2]
end

local list = {}
local function add(name, parts)
	table.insert(list, { name = name, parts = V.renumber(V.copyParts(parts)) })
end
local function speck(parts)
	local s = V.copyParts(parts)
	if #s >= 24 then
		s[#s] = { id = 900, slot = s[#s].slot, shape = "Block", material = "Iron", pos = { 0.7, 0.2, 0.2 }, rot = I, size = { 0.05, 0.05, 0.05 } }
	else
		table.insert(s, { id = 900, slot = "Pommel", shape = "Block", material = "Iron", pos = { 0.7, 0.2, 0.2 }, rot = I, size = { 0.05, 0.05, 0.05 } })
	end
	return s
end
add("F5", (V.fixture("F5")))
add("C02", (V.fixture("C02 Arming (Iron)")))
add("C05", (V.fixture("C05")))
add("C09", (V.fixture("C09")))
add("C10", (V.fixture("C10")))
for _, n in ipairs({ "P1", "P2", "P3", "P4", "P5" }) do
	add(n, (V.fixture(n)))
end
for _, n in ipairs({ "P1", "P2", "P3" }) do
	add(n .. " + speck", speck((V.fixture(n))))
end
for a = 2, #process.args do
	local data = serde.decode("json", fs.readFile(process.args[a]))
	local stem = string.match(process.args[a], "[^/]*$")
	for i, d in ipairs(data) do
		add(fmt("%s#%d", string.sub(stem, 1, 12), i), d.parts)
	end
end

local T = table.create(#list)
for i = 1, #list do
	T[i] = { m2 = {}, verdict = {}, m3 = {}, gap = {} }
end
local topGap, topWhere, topName = 0, "", ""
for r = 1, ROUNDS do
	-- alternating: forwards, then backwards
	local from, to, step = 1, #list, 1
	if r % 2 == 0 then
		from, to, step = #list, 1, -1
	end
	for i = from, to, step do
		local it = list[i]
		local core = { schema = 1, name = "x", type = "Sword", parts = it.parts }
		collectgarbage("collect")
		local t0 = os.clock()
		Analyze.run(core, { measureInvalid = true })
		table.insert(T[i].m2, (os.clock() - t0) * 1000)
		-- gaps: a separate run, the clock inside the checkpoint
		collectgarbage("collect")
		local last = os.clock()
		local top = 0
		Analyze.run(core, { measureInvalid = true, checkpoint = function()
			local now = os.clock()
			local g = now - last
			if g > top then
				top = g
				if g > topGap then
					topGap, topName = g, it.name
					topWhere = debug.traceback("", 1)
				end
			end
			last = os.clock()
		end })
		table.insert(T[i].gap, top * 1000)
		local P = V.prep(it.parts)
		collectgarbage("collect")
		t0 = os.clock()
		Vd.FORCE.verdictOnly = true
		Vd.exposure(P)
		Vd.FORCE.verdictOnly = nil
		table.insert(T[i].verdict, (os.clock() - t0) * 1000)
		if r <= 7 then
			collectgarbage("collect")
			local R = Emu.run({ name = "x", parts = it.parts }, { measureInvalid = true, build = true })
			table.insert(T[i].m3, 1000 * ((R.T.edge or 0) + (R.T.factors or 0)))
		end
	end
end
print(fmt("%d rounds", ROUNDS))
print(fmt("%-22s %8s %8s %8s %8s %8s %9s", "design", "verdict", "M2", "M3", "M2+M3", "Studio", "gap"))
local rows = {}
for i, it in ipairs(list) do
	local a, b, c, g = median(T[i].verdict), median(T[i].m2), median(T[i].m3), median(T[i].gap)
	print(fmt("%-22s %8.2f %8.2f %8.2f %8.2f %8.1f %9.3f", string.sub(it.name, 1, 22), a, b, c, b + c, (b + c) * 2.6, g))
	table.insert(rows, { name = it.name, verdict = a, m2 = b, m3 = c, gap = g })
end
print(fmt("the longest gap of all: %.3f ms on %s, ending at:\n%s", topGap * 1000, topName, topWhere))
fs.writeFile("out/d_cost_last.json", serde.encode("json", rows))
