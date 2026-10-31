--!strict
-- worst-case PrecisionTrace: a source exactly at the length bound (0.95 * 30 s * pacerSpeed), slowest pacer,
-- 1 sample per 20 ms over the full duration (the honest maximum, durationMs/20 + 1 records)
local PT = require("./PrecisionTrace")
local Params = require("./Params")
local p = Params.resolve("PrecisionTrace", "Iron", "Normal", Params.refFactors(0))
local maxLen = PT.LEN_MARGIN * PT.TRAVEL_MAX_MS / 1000 * p.pacerSpeed
-- sine path across the usable panel, amplitude chosen so the length is ~maxLen, 256 points
local best
for a10 = 1, 380 do
	local amp = a10 / 1000
	local us, vs = {}, {}
	for i = 0, 255 do
		local u = 0.15 + 2.7 * i / 255
		table.insert(us, u)
		table.insert(vs, 0.5 + amp * math.sin(2 * math.pi * 10 * i / 255))
	end
	local L = PT.polyLen(us, vs)
	if L <= maxLen then
		best = { us = us, vs = vs, L = L, amp = amp }
	end
end
local src = {}
for i = 1, #best.us do
	table.insert(src, math.round(best.us[i] * PT.Q))
	table.insert(src, math.round(best.vs[i] * PT.Q))
end
local function ms(f: () -> ()): number
	local t = os.clock()
	f()
	return (os.clock() - t) * 1000
end
local pat
local g = 0
for s = 1, 10 do
	g = math.max(g, ms(function() pat = PT.generate(s, p, src) end))
end
local samples = {}
local t = 0
while t <= pat.durationMs do
	local u, v = PT.pointAt(pat, PT.pacerArc(pat, t))
	table.insert(samples, { t = t, u = math.round(u * PT.Q + 41), v = math.round(v * PT.Q - 23), grind = true })
	t += 20
end
local r = 0
for _ = 1, 10 do
	r = math.max(r, ms(function() PT.replay(pat, samples) end))
end
print(string.format("maxLen %.3f srcL %.3f amp %.3f -> path pts %d L %.3f travel %d ms (clamped %s) duration %d ms; samples %d; generate max %.2f ms; replay+checks max %.2f ms",
	maxLen, best.L, best.amp, #pat.pu, pat.L, pat.travelMs, tostring(pat.clampedTravel), pat.durationMs, #samples, g, r))
