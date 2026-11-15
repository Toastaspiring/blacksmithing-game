--!nocheck
-- D before (V1's emu, the tree before this round) and now (./emu), through the emulator, on the plausible designs listed
-- (indices, one a line) whose shard is ours. args: list shard nshards out
local process = require("@lune/process")
local fs = require("@lune/fs")
local L = require("./lab")
local Now = require("./emulab")
local Before = (require :: any)("C:/Users/louis/AppData/Local/Temp/claude/C--Users-louis-Documents-RANDOM-ROBLOX/93ae48b4-72b9-4dc1-aa5d-451af1abf9a0/scratchpad/m2x-v1-1/emu/proto/analyze_build")
local fmt = string.format
local LIST, shard, nshards, OUT = process.args[1], tonumber(process.args[2]), tonumber(process.args[3]), process.args[4]
local PD = ((require :: any)(L.ROOT .. "/tests/Physics/PlausibleDesigns")).all()
local function before(parts)
	local copy = {}
	for i, p in ipairs(parts) do
		copy[i] = { id = i, slot = p.slot or "Blade", shape = p.shape, material = p.material or "Iron", pos = { p.pos[1], p.pos[2], p.pos[3] },
			rot = { p.rot[1], p.rot[2], p.rot[3], p.rot[4] }, size = { p.size[1], p.size[2], p.size[3] } }
	end
	return Before.run({ name = "x", parts = copy }, { measureInvalid = true, build = true })
end
local lines, n = {}, 0
for line in string.gmatch(fs.readFile(LIST), "[^\n]+") do
	n += 1
	if (n - 1) % nshards == shard then
		local k = tonumber(line)
		local d = PD[k]
		local a, b = before(d.parts), Now.run(d.parts)
		local dd, t, s = Now.diff(a, b)
		table.insert(lines, fmt("%d\t%s\t%.6f\t%s\t%s\t%s\t%s", k, d.name, dd, s, tostring(t), Now.dline(a), Now.dline(b)))
	end
end
fs.writeFile(OUT, table.concat(lines, "\n") .. "\n")
