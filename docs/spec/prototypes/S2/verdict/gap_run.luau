--!nocheck
-- m2r5: the longest run between checkpoints through Analyze.run (T-PERF-01's bound is CHECKPOINT_GAP_LUNE_MS 0.35), median of ROUNDS of each run's longest, per variant.
-- args: rounds "V1 V2" json files...
local process = require("@lune/process")
local fs = require("@lune/fs")
local serde = require("@lune/serde")
local Analyze = require("./tree/src/shared/Physics/Analyze")
local Sampling = require("./tree/src/shared/Physics/Sampling")
local Fx = require("./proto/fixtures")
local V = require("./variants")
local fmt = string.format

local ROUNDS = tonumber(process.args[1]) or 15
local NAMES = string.split(process.args[2] or "A", " ")
local function median(t)
	table.sort(t)
	return t[(#t + 1) // 2]
end
local list = {}
for _, b in ipairs(Fx.calibration()) do
	if string.sub(b.name, 1, 3) == "C09" then table.insert(list, { "C09", b.parts }) end
end
for _, b in ipairs(Fx.perf()) do
	table.insert(list, { string.sub(b.name, 1, 2), b.parts })
end
for a = 3, #process.args do
	local data = serde.decode("json", fs.readFile(process.args[a]))
	for i, d in ipairs(data) do
		table.insert(list, { fmt("%s#%d", string.match(process.args[a], "[^/]*$"), i), d.parts })
	end
end
for _, it in ipairs(list) do
	local core = { schema = 1, name = "x", type = "Sword", parts = it[2] }
	local line = {}
	for _, v in ipairs(NAMES) do
		V.apply(Sampling, v)
		local tops = {}
		for r = 1, ROUNDS do
			local last = os.clock()
			local top = 0
			collectgarbage("collect")
			Analyze.run(core, { measureInvalid = true, checkpoint = function()
				local now = os.clock()
				if now - last > top then top = now - last end
				last = now
			end })
			tops[r] = top * 1000
		end
		table.insert(line, fmt("%s %.3f", v, median(tops)))
	end
	print(fmt("%-22s %s", string.sub(it[1], 1, 22), table.concat(line, " | ")))
end
