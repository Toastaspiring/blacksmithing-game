--!nocheck
-- V2 round 3 (from round 2's): P1's cleaned list against a high-resolution reading: per part, the build's verdict and exact reading on its model
-- (Cover against Sampling's hiders, whole), and VisibleOracle's share on `total` points.
--   lune run p1truth -- <total>
local process = require("@lune/process")
local W = "C:/Users/louis/AppData/Local/Temp/claude/C--Users-louis-Documents-RANDOM-ROBLOX/93ae48b4-72b9-4dc1-aa5d-451af1abf9a0/scratchpad/m2x-v2-3"
local R = W .. "/repo"
local Shapes = require(R .. "/src/shared/Physics/Shapes")
local Sampling = require(R .. "/src/shared/Physics/Sampling")
local Cover = require(R .. "/src/shared/Physics/Cover")
local H = require(R .. "/tests/Physics/PhysicsHelpers")
local Oracle = require(R .. "/tests/Physics/VisibleOracle")
local Fx = require(R .. "/docs/spec/prototypes/S2/v2/fixtures")
local fmt = string.format
local total = tonumber(process.args[1]) or 400000
local only = tonumber(process.args[2])
local P1
for _, b in ipairs(Fx.perf()) do
	if string.sub(b.name, 1, 2) == "P1" then
		P1 = b
	end
end
local parts = {}
for i, p in ipairs(P1.parts) do
	parts[i] = Shapes.prepare({ id = i, slot = p.slot, shape = p.shape, material = p.material, pos = p.pos, rot = p.rot, size = p.size }, i)
end
local e = Sampling.exposure(parts)
local _, _, hider = Oracle.flags(parts)
local wrong = 0
for i = 1, #parts do
	if only == nil or only == i then
		local read = H.reads(parts, i)
		local truth = Oracle.measure(parts, i, hider, total)
		local tk = truth >= 0.02
		if tk ~= e.kept[i] then
			wrong += 1
		end
		print(fmt("part %2d %-7s kept %-5s read %7.4f %%  truth %7.4f %% (%d points)%s", i, parts[i].slot, tostring(e.kept[i]), 100 * read,
			100 * truth, total, if tk ~= e.kept[i] then "  WRONG" else ""))
	end
end
print("verdicts that differ from the truth: " .. wrong)
