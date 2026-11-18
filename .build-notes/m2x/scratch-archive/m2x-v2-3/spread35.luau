--!nocheck
-- V2 round 3: the 35 plausible designs the spread moves, every step's D through the M3 emulator on the original build
-- (emuBase, m2x-fix-1/base) and the repo (emuNow).
local fs = require("@lune/fs")
local W = "C:/Users/louis/AppData/Local/Temp/claude/C--Users-louis-Documents-RANDOM-ROBLOX/93ae48b4-72b9-4dc1-aa5d-451af1abf9a0/scratchpad/m2x-v2-3"
local PD = require(W .. "/repo/tests/Physics/PlausibleDesigns")
local Now = require(W .. "/emuNow/proto/analyze_build")
local Base = require(W .. "/emuBase/proto/analyze_build")
local fmt = string.format
local want = {}
for line in string.gmatch((string.gsub(fs.readFile(W .. "/out/spread35.txt"), "\r", "")), "[^\n]+") do
	want[line] = true
end
local worst, worstName, flips, n = 0, "", 0, 0
for _, d in ipairs(PD.all()) do
	if want[d.name] then
		n += 1
		local a = Base.run({ name = d.name, parts = d.parts }, { measureInvalid = true, build = true })
		local b = Now.run({ name = d.name, parts = d.parts }, { measureInvalid = true, build = true })
		for s = 1, #a.steps do
			local dd = math.abs(a.steps[s].d - b.steps[s].d)
			if dd > worst then
				worst, worstName = dd, d.name .. " " .. a.steps[s].step
			end
			if a.steps[s].tier ~= b.steps[s].tier then
				flips += 1
			end
		end
	end
end
print(fmt("%d designs: tier flips %d, worst |dD| %.4f (%s)", n, flips, worst, worstName))
