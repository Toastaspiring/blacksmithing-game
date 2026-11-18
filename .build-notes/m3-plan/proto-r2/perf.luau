--!nocheck
-- m3-plan-r2: T-PERF-01's cases on the snapshot, in verdict/lines/d_cost.luau's way. Each round runs every design once,
-- forwards on odd rounds and backwards on even ones, collectgarbage("collect") before each timed run:
--   M2   the snapshot's Analyze.run (phases 1–5, measureInvalid = true), total ms
--   gap  a separate Analyze.run whose checkpoint records the longest stretch: start to first call, call to call, last
--        call to the end
--   M3   M3's share emulated: analyze_gap.luau (the emulator + one mark hook) in the measure's rank order, its T.edge +
--        T.factors, and the longest stretch between its checkpoints after the mark (the prototype's charges)
-- Medians over the rounds. Designs: F5, C02, C05, C09 (real designs, S-PERF-01's ceiling), P1–P5, P1–P3 + a floating Dust
-- speck (the 24th part replaced by a 0.05 Block at (0.7, 0.2, 0.2) in its slot, d_cost.luau's: Disconnected, measured
-- under measureInvalid) and + an attached one (the same Block at part 23's centre: valid, cleaned as Dust), and
-- docs/spec/prototypes/S2/cover/worst_designs.luau's valid and tooComplex designs (tooComplex: Analyze.run only).
--   lune run <abs>/proto/perf.luau -- [rounds] [only <prefix>]
local L = require("./lib")
local Gap = require("./analyze_gap")
local process = require("@lune/process")
local Analyze = require("../repo/src/shared/Physics/Analyze")
local Worst = require("../repo/docs/spec/prototypes/S2/cover/worst_designs")
local fmt = string.format

local ROUNDS = tonumber(process.args[1]) or 15
local only = if process.args[2] == "only" then process.args[3] else nil

local I = { 0, 0, 0, 1 }
local function copyParts(parts)
	local out = {}
	for i, p in ipairs(parts) do
		out[i] = { id = p.id, slot = p.slot, shape = p.shape, material = p.material, pos = table.clone(p.pos),
			rot = table.clone(p.rot), size = table.clone(p.size) }
	end
	return out
end
local function floating(parts)
	local s = copyParts(parts)
	s[#s] = { id = s[#s].id, slot = s[#s].slot, shape = "Block", material = "Iron", pos = { 0.7, 0.2, 0.2 }, rot = I,
		size = { 0.05, 0.05, 0.05 } }
	return s
end
local function attached(parts)
	local s = copyParts(parts)
	local host = s[#s - 1]
	s[#s] = { id = s[#s].id, slot = s[#s].slot, shape = "Block", material = "Iron", pos = table.clone(host.pos), rot = I,
		size = { 0.05, 0.05, 0.05 } }
	return s
end

local list = {}
local function add(name, parts, kind)
	if only == nil or string.sub(name, 1, #only) == only then
		table.insert(list, { name = name, parts = parts, kind = kind or "valid" })
	end
end
for _, id in ipairs({ "F5", "C02", "C05", "C09", "P1", "P2", "P3", "P4", "P5" }) do
	add(id, copyParts(L.find(id).parts))
end
for _, id in ipairs({ "P1", "P2", "P3" }) do
	add(id .. " + floating speck", floating(L.find(id).parts), "floating")
	add(id .. " + attached speck", attached(L.find(id).parts))
end
for k, d in ipairs(Worst.valid) do
	add(fmt("valid %d %s", k, string.sub(d.name, 1, 18)), copyParts(d.parts))
end
for k, d in ipairs(Worst.tooComplex) do
	add(fmt("past %d %s", k, string.sub(d.name, 1, 19)), copyParts(d.parts), "past")
end

local function median(t)
	if #t == 0 then
		return 0
	end
	local c = table.clone(t)
	table.sort(c)
	return c[(#c + 1) // 2]
end

local T = {}
for i, it in ipairs(list) do
	T[i] = { m2 = {}, gap = {}, m3 = {}, m3gap = {}, checks = 0 }
	it.core = { schema = 1, name = "x", type = "Sword", parts = it.parts }
	-- warm-up, and what the design is
	local R = Analyze.run(it.core, { measureInvalid = true })
	it.valid = R.validation.ok
	it.codes = {}
	for _, e in ipairs(R.validation.errors) do
		table.insert(it.codes, e.code)
	end
	it.cleaned = #R.cleaned
	if it.kind ~= "past" then
		it.rank = L.inRankOrder({ name = "x", parts = it.parts })
		Gap.run(it.rank, { build = true, measureInvalid = true })
	end
end

for r = 1, ROUNDS do
	local from, to, step = 1, #list, 1
	if r % 2 == 0 then
		from, to, step = #list, 1, -1
	end
	for i = from, to, step do
		local it = list[i]
		collectgarbage("collect")
		local t0 = os.clock()
		Analyze.run(it.core, { measureInvalid = true })
		table.insert(T[i].m2, (os.clock() - t0) * 1000)
		collectgarbage("collect")
		local top, n = 0, 0
		local last = os.clock()
		Analyze.run(it.core, { measureInvalid = true, checkpoint = function()
			local now = os.clock()
			if now - last > top then
				top = now - last
			end
			n += 1
			last = os.clock()
		end })
		local now = os.clock()
		if now - last > top then
			top = now - last
		end
		table.insert(T[i].gap, top * 1000)
		T[i].checks = n
		if it.kind ~= "past" then
			collectgarbage("collect")
			local mtop, armed = 0, false
			local mlast = os.clock()
			local R = Gap.run(it.rank, { build = true, measureInvalid = true, mark = function()
				armed = true
				mlast = os.clock()
			end, checkpoint = function()
				local tnow = os.clock()
				if armed and tnow - mlast > mtop then
					mtop = tnow - mlast
				end
				mlast = os.clock()
			end })
			local tend = os.clock()
			if armed and tend - mlast > mtop then
				mtop = tend - mlast
			end
			table.insert(T[i].m3, 1000 * ((R.T.edge or 0) + (R.T.factors or 0)))
			table.insert(T[i].m3gap, mtop * 1000)
		end
	end
end

print(fmt("%d rounds, medians (ms Lune 0.8.9)", ROUNDS))
print(fmt("%-34s %-26s %7s %7s %7s %7s %6s %6s %6s", "design", "validation", "M2", "M3", "M2+M3", "x2.6", "gapM2", "gapM3",
	"checks"))
for i, it in ipairs(list) do
	local m2, m3 = median(T[i].m2), median(T[i].m3)
	local what = if it.valid then fmt("valid, %d cleaned", it.cleaned) else table.concat(it.codes, ",")
	print(fmt("%-34s %-26s %7.2f %7.2f %7.2f %7.1f %6.3f %6.3f %6d", string.sub(it.name, 1, 34), string.sub(what, 1, 26), m2,
		m3, m2 + m3, (m2 + m3) * 2.6, median(T[i].gap), median(T[i].m3gap), T[i].checks))
end
