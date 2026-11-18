--!nocheck
-- V2 round 3: the build's physics of the prototype's F and C fixtures (Analyze.run, measureInvalid), printed as E-S2.9's
-- physics table prints them, beside the emulator's edge and cutIndex, and the prototype's own row.
local W = "C:/Users/louis/AppData/Local/Temp/claude/C--Users-louis-Documents-RANDOM-ROBLOX/93ae48b4-72b9-4dc1-aa5d-451af1abf9a0/scratchpad/m2x-v2-3"
local R = W .. "/repo"
local Analyze = require(R .. "/src/shared/Physics/Analyze")
local Fx = require(W .. "/emuNow/proto/fixtures")
local Proto = require(W .. "/emuNow/proto/analyze")
local Emu = require(W .. "/emuNow/proto/analyze_build")
local fmt = string.format

local list = {}
for _, b in ipairs(Fx.golden()) do
	table.insert(list, b)
end
for _, b in ipairs(Fx.calibration()) do
	table.insert(list, b)
end
for _, b in ipairs(list) do
	local core = { schema = 1, name = b.name, type = "Sword", parts = b.parts }
	local a = Analyze.run(core, { measureInvalid = true })
	local p = a.physics
	local kept = #b.parts - #a.cleaned
	local e = Emu.run({ name = b.name, parts = b.parts }, { measureInvalid = true, build = true })
	local q = Proto.run({ name = b.name, parts = b.parts }, { measureInvalid = true })
	local edge = e.edge and e.edge.mainLength or (e.physics and e.physics.edgeLength) or -1
	local cut = e.physics and e.physics.cutIndex or -1
	print(fmt("%-44s %d (%d) | %.4f | %.5f | %.3f | %.3f | %.3f || emu edge %.3f cut %.2f || proto %.4f %.5f %.3f %.3f %.3f",
		b.name, #b.parts, kept, p.mass, p.volume, p.balance, p.reach, p.bladeLength, edge, cut,
		q.physics.mass, q.physics.volume, q.physics.balance, q.physics.reach, q.physics.bladeLength))
end
