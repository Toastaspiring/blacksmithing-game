--!nocheck
-- V2 round 3: every kept part of the plausible set (repo), VisibleOracle's coarse lattice; where it reads under 6 %, the
-- fine share. Prints the kept parts truly under 2.5 % and the lowest.   lune run keptlow -- <k> <n> <out>
local process = require("@lune/process")
local fs = require("@lune/fs")
local R = "C:/Users/louis/AppData/Local/Temp/claude/C--Users-louis-Documents-RANDOM-ROBLOX/93ae48b4-72b9-4dc1-aa5d-451af1abf9a0/scratchpad/m2x-v2-3/repo"
local Shapes = require(R .. "/src/shared/Physics/Shapes")
local Sampling = require(R .. "/src/shared/Physics/Sampling")
local Oracle = require(R .. "/tests/Physics/VisibleOracle")
local PD = require(R .. "/tests/Physics/PlausibleDesigns")
local k, n = tonumber(process.args[1]), tonumber(process.args[2])
local rows = {}
local lowest, lowestWhat, parts, fine = math.huge, "", 0, 0
for idx, d in ipairs(PD.all()) do
	if (idx - 1) % n == k then
		local P = {}
		for i, p in ipairs(d.parts) do
			P[i] = Shapes.prepare(p, i)
		end
		local e = Sampling.exposure(P)
		local _, _, hider = Oracle.flags(P)
		for i = 1, #P do
			if e.kept[i] then
				parts += 1
				local rough = Oracle.measure(P, i, hider, Oracle.COARSE_POINTS)
				if rough < 0.06 then
					fine += 1
					local truth = Oracle.share(P, i, hider)
					if truth < lowest then
						lowest, lowestWhat = truth, string.format("%s part %d (%s)", d.name, i, d.parts[i].shape)
					end
					if truth < 0.025 then
						table.insert(rows, string.format("%.17g\t%d\t%s\t%d\t%s", truth, idx, d.name, i, d.parts[i].shape))
					end
				end
			end
		end
	end
end
fs.writeFile(process.args[3], table.concat(rows, "\n") .. "\n")
print(string.format("slice %d/%d: %d kept parts, %d read fine; lowest kept %.6f %% (%s)", k, n, parts, fine, 100 * lowest, lowestWhat))
