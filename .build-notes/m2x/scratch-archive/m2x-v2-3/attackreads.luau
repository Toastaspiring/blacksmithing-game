--!nocheck
local R = "C:/Users/louis/AppData/Local/Temp/claude/C--Users-louis-Documents-RANDOM-ROBLOX/93ae48b4-72b9-4dc1-aa5d-451af1abf9a0/scratchpad/m2x-v2-3/repo"
local H = require(R .. "/tests/Physics/PhysicsHelpers")
local Attacks = require(R .. "/tests/Physics/CoverAttacks")
local Sampling = require(R .. "/src/shared/Physics/Sampling")
local worst = 0
for _, d in ipairs(Attacks) do
	local P = H.prepared({ parts = d.parts })
	local r = H.reads(P, d.target)
	local kept = Sampling.exposure(P).kept[d.target]
	worst = math.max(worst, d.truth - r)
	print(string.format("%-55s read %7.3f %% truth %7.3f %% kept %-5s (truth's %s)", string.sub(d.name, 1, 55), 100 * r, 100 * d.truth, tostring(kept), tostring(d.kept)))
end
print(string.format("the largest reading under the truth: %.2f points", 100 * worst))
