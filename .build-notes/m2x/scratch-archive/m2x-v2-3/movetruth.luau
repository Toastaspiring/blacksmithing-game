--!nocheck
-- V2 round 3: the truth (VisibleOracle.share, the repo's) of every plausible part whose verdict the change moved, with the
-- repo's reading (H.reads, whole) and verdict.
--   lune run movetruth -- <moves.txt> <k> <n> <out>
local process = require("@lune/process")
local fs = require("@lune/fs")
local W = "C:/Users/louis/AppData/Local/Temp/claude/C--Users-louis-Documents-RANDOM-ROBLOX/93ae48b4-72b9-4dc1-aa5d-451af1abf9a0/scratchpad/m2x-v2-3"
local R = W .. "/repo"
local Shapes = require(R .. "/src/shared/Physics/Shapes")
local Sampling = require(R .. "/src/shared/Physics/Sampling")
local H = require(R .. "/tests/Physics/PhysicsHelpers")
local Oracle = require(R .. "/tests/Physics/VisibleOracle")
local PD = require(R .. "/tests/Physics/PlausibleDesigns")
local args = process.args
local k, n = tonumber(args[2]), tonumber(args[3])
local all = PD.all()
local lines = {}
local rowNo = 0
local cache = {}
for line in string.gmatch((string.gsub(fs.readFile(args[1]), "\r", "")), "[^\n]+") do
	rowNo += 1
	if (rowNo - 1) % n == k then
		local idx, name, part, was, now = string.match(line, "^(%d+)\t([^\t]+)\t(%d+)\t(%a)\t(%a)$")
		idx, part = tonumber(idx), tonumber(part)
		local d = all[idx]
		assert(d.name == name, "design " .. idx .. " is " .. d.name)
		local P = cache[idx]
		if not P then
			P = {}
			for i, p in ipairs(d.parts) do
				P[i] = Shapes.prepare(p, i)
			end
			cache = { [idx] = P }
		end
		local _, _, hider = Oracle.flags(P)
		local truth = Oracle.share(P, part, hider)
		local read = H.reads(P, part)
		local shape = P[part].code
		table.insert(lines, string.format("%d\t%s\t%d\t%s\t%s\t%.6f\t%.6f\t%s", idx, name, part, was, now, truth, read,
			({ "Block", "Wedge", "CornerWedge", "Cylinder", "Ball" })[shape] or tostring(shape)))
	end
end
fs.writeFile(args[4], table.concat(lines, "\n") .. "\n")
print(#lines .. " parts")
