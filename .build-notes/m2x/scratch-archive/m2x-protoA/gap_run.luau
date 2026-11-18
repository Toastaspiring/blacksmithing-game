--!nocheck
-- §4.9 checkpoints with the new verdict: Analyze's cadence emulated on the whole exposure call (a checkpoint once the work
-- reaches CHECK_UNITS = 500 units), the longest time between two checkpoints and between two spend calls, per design, the
-- median over RUNS runs of each run's longest gap (Lune ms, os.clock; this machine runs ~2.2x slower than unloaded).
-- args: json-path [runs]
local process = require("@lune/process")
local S = require("./sets")
local Shapes = require("./repo/src/shared/Physics/Shapes")
local fmt = string.format
local New = require("./v/new_base/Sampling")
local Old = require("./v/old/Sampling")
local RUNS = tonumber(process.args[2] or "7")

local designs = {}
for _, d in ipairs(S.fixtures and {} or {}) do table.insert(designs, d) end
for _, d in ipairs(S.protoFixtures()) do
	if string.sub(d.name, 1, 3) == "P1 " or string.sub(d.name, 1, 3) == "P4 " or string.sub(d.name, 1, 3) == "C09" then table.insert(designs, d) end
end
for _, d in ipairs(S.json(process.args[1])) do table.insert(designs, d) end

local function median(t) table.sort(t) return t[math.ceil(#t / 2)] end
local function gaps(Sv, P)
	local units, last, lastSpend = 0, os.clock(), os.clock()
	local worst, worstSpend = 0, 0
	Sv.exposure(P, function(n)
		local now = os.clock()
		if now - lastSpend > worstSpend then worstSpend = now - lastSpend end
		lastSpend = now
		units += n
		if units >= 500 then
			units = 0
			if now - last > worst then worst = now - last end
			last = now
		end
	end)
	return worst * 1000, worstSpend * 1000
end
print(fmt("%-52s %s", "design", "longest gap between checkpoints / between spend calls, ms (median of " .. RUNS .. " runs): old | new"))
for _, d in ipairs(designs) do
	local P = {}
	for i, p in ipairs(d.parts) do P[i] = Shapes.prepare(p, i) end
	local og, os_, ng, ns = {}, {}, {}, {}
	for r = 1, RUNS do
		og[r], os_[r] = gaps(Old, P)
		ng[r], ns[r] = gaps(New, P)
	end
	print(fmt("%-52s old %.3f / %.3f | new %.3f / %.3f", string.sub(d.name, 1, 52), median(og), median(os_), median(ng), median(ns)))
end
