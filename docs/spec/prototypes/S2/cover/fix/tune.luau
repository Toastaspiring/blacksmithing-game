--!nocheck
-- V1's 24-Ball cluster (m2x-v1-1/tsets.luau) under the build: units (cap lifted) against dy, for d, ax given; the largest
-- valid one at or under the cap. args: d ax dy0 dy1 step
local process = require("@lune/process")
local L = require("./lab")
local fmt = string.format
local Free = L.H.plantedSampling({ VERDICT_WORK_MAX = math.huge })
local SLOTS = { "Pommel", "Pommel", "Grip", "Grip", "Guard", "Guard", "Guard", "Guard", "Guard", "Guard", "Guard", "Guard", "Blade", "Blade", "Blade", "Blade", "Blade", "Blade", "Blade", "Blade", "Blade", "Blade", "Blade", "Blade" }
local function cluster(d, dy, ax, y0)
	local parts = {}
	for i = 1, 24 do
		table.insert(parts, { id = i, slot = SLOTS[i], shape = "Ball", material = "Iron", pos = { ax * math.sin(i * 1.3), y0 + (i - 1) * dy, 0 }, rot = { 0, 0, 0, 1 }, size = { d, d, d } })
	end
	return parts
end
local d, ax = tonumber(process.args[1]), tonumber(process.args[2])
local dy0, dy1, step = tonumber(process.args[3]), tonumber(process.args[4]), tonumber(process.args[5])
local best, bestDy = 0, nil
local dy = dy0
while dy <= dy1 + 1e-12 do
	local parts = cluster(d, dy, ax, 0.3)
	local r = L.Canonical.draft({ schema = 1, name = "c", type = "Sword", parts = parts })
	local units = Free.exposure(L.prepared(r.value.parts)).verdictWork
	local valid = false
	if units <= L.Geo.VERDICT_WORK_MAX then
		valid = L.Analyze.run({ schema = 1, name = "c", type = "Sword", parts = r.value.parts }).validation.ok
		if valid and units > best then best, bestDy = units, dy end
	end
	print(fmt("d %.2f ax %.2f dy %.5f  %10.3f units %s", d, ax, dy, units, if units > L.Geo.VERDICT_WORK_MAX then "over" elseif valid then "valid" else "invalid"))
	dy += step
end
print(fmt("BEST d %.2f ax %.2f dy %s  %.3f units", d, ax, tostring(bestDy), best))
