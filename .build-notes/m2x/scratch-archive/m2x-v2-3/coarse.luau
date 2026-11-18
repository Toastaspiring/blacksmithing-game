--!nocheck
-- V2 round 3: VisibleOracle's coarse lattice (COARSE_POINTS) on the listed parts, beside their fine share.
local process = require("@lune/process")
local fs = require("@lune/fs")
local R = "C:/Users/louis/AppData/Local/Temp/claude/C--Users-louis-Documents-RANDOM-ROBLOX/93ae48b4-72b9-4dc1-aa5d-451af1abf9a0/scratchpad/m2x-v2-3/repo"
local Shapes = require(R .. "/src/shared/Physics/Shapes")
local Oracle = require(R .. "/tests/Physics/VisibleOracle")
local PD = require(R .. "/tests/Physics/PlausibleDesigns")
local all = PD.all()
local low, n = 0, 0
local out = {}
for line in string.gmatch((string.gsub(fs.readFile(process.args[1]), "\r", "")), "[^\n]+") do
	local idx, name, part = string.match(line, "^(%d+)\t([^\t]+)\t(%d+)")
	idx, part = tonumber(idx), tonumber(part)
	local d = all[idx]
	local P = {}
	for i, p in ipairs(d.parts) do
		P[i] = Shapes.prepare(p, i)
	end
	local _, _, hider = Oracle.flags(P)
	local rough = Oracle.measure(P, part, hider, Oracle.COARSE_POINTS)
	n += 1
	if rough <= 0.01 then
		low += 1
	end
	table.insert(out, string.format("%.5f\t%s", rough, line))
end
fs.writeFile(process.args[2], table.concat(out, "\n") .. "\n")
print(n .. " parts; coarse <= 1 %: " .. low)
