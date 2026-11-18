--!nocheck
-- m3-plan-r2: where M3's longest stretches between checkpoints end, through analyze_gap.luau (the emulator, the
-- prototype's charges) in the measure's rank order. For each design, over n runs: the longest stretch after the mark,
-- the emulator line its checkpoint was called from (the tick's caller), and the median over runs of the longest stretch
-- per such line. Designs by name: fixture ids, or "valid <k>" for worst_designs.luau's valid list.
--   lune run <abs>/proto/m3gap.luau -- <runs> <design> [<design> ...]
local L = require("./lib")
local Gap = require("./analyze_gap")
local process = require("@lune/process")
local Worst = require("../repo/docs/spec/prototypes/S2/cover/worst_designs")
local fmt = string.format

local RUNS = tonumber(process.args[1]) or 9
local function partsOf(name)
	local k = string.match(name, "^valid(%d+)$")
	if k then
		return Worst.valid[tonumber(k)].parts
	end
	return L.find(name).parts
end
local function median(t)
	local c = table.clone(t)
	table.sort(c)
	return c[(#c + 1) // 2]
end

for a = 2, #process.args do
	local name = process.args[a]
	local b = L.inRankOrder({ name = name, parts = partsOf(name) })
	Gap.run(b, { build = true, measureInvalid = true })
	local byLine = {}
	for _ = 1, RUNS do
		collectgarbage("collect")
		local armed, last = false, os.clock()
		local top = {}
		local function note(where, g)
			if g > (top[where] or 0) then
				top[where] = g
			end
		end
		local function caller()
			-- level 1 this function, 2 the checkpoint, 3 tick or phase, 4 the loop that charged
			local _, line3 = debug.info(3, "sl")
			local _, line4 = debug.info(4, "sl")
			local n4 = debug.info(4, "n")
			return fmt("%s:%d<%d", n4 or "?", line4 or 0, line3 or 0)
		end
		Gap.run(b, { build = true, measureInvalid = true, mark = function()
			armed = true
			last = os.clock()
		end, checkpoint = function()
			local now = os.clock()
			if armed then
				note(caller(), now - last)
			end
			last = os.clock()
		end })
		note("end of run", os.clock() - last)
		for where, g in pairs(top) do
			byLine[where] = byLine[where] or {}
			table.insert(byLine[where], g * 1000)
		end
	end
	local rows = {}
	for where, list in pairs(byLine) do
		table.insert(rows, { where = where, med = median(list), max = math.max(table.unpack(list)) })
	end
	table.sort(rows, function(x, y)
		return x.med > y.med
	end)
	print(fmt("%s (%d runs): longest stretch after the mark, by the line that charged it (median / max ms)", name, RUNS))
	for k = 1, math.min(6, #rows) do
		print(fmt("    %-34s %.3f / %.3f", rows[k].where, rows[k].med, rows[k].max))
	end
end
