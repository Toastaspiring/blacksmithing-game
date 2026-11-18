--!nocheck
-- checkpoint gaps under load: per design, each of 25 runs' longest gap; the minimum over runs (preemption only adds), the
-- median, and the units of the largest single report. lune run t_gapmin -- <file.json,...>
local process = require("@lune/process")
local fs = require("@lune/fs")
local serde = require("@lune/serde")
local L = require("./lib")
local Worst = require("./repo/docs/spec/prototypes/S2/cover/worst_designs")
local fmt = string.format
local designs = {}
for _, id in ipairs({ "F5" }) do table.insert(designs, { id, L.repoFixture(id) }) end
for _, pre in ipairs({ "C09", "P1", "P2", "P4" }) do
	local parts, name = L.fixture(pre)
	table.insert(designs, { string.sub(name, 1, 3), parts })
end
for _, d in ipairs(Worst.valid) do table.insert(designs, { d.name, L.copyParts(d.parts) }) end
for _, f in ipairs(string.split(process.args[1] or "", ",")) do
	if f ~= "" then table.insert(designs, { f, serde.decode("json", fs.readFile(f)) }) end
end
for _, d in ipairs(designs) do
	local parts = L.renumber(L.copyParts(d[2]))
	local core = { schema = 1, name = "x", type = "Sword", parts = parts }
	local mx = 0
	L.Sampling.exposure(L.prep(parts), function(n) if n > mx then mx = n end end)
	local gaps = {}
	for k = 1, 25 do
		local last, worst = os.clock(), 0
		L.Analyze.run(core, { checkpoint = function()
			local now = os.clock()
			if now - last > worst then worst = now - last end
			last = now
		end })
		table.insert(gaps, worst * 1000)
	end
	table.sort(gaps)
	print(fmt("%-44s largest report %7.1f units; longest gap per run: min %.3f, median %.3f ms", string.sub(d[1], 1, 44), mx, gaps[1], gaps[13]))
end
