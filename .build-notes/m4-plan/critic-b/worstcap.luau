--!strict
-- M4 plan critic B: T-PERF-02's PrecisionTrace case, honest maximum (1 sample / 20 ms, 1,479 samples, as worst.luau)
-- against the decode cap (MAX_RECORDS 2,048 grinding samples, every 14 ms), on the S3 prototype; medians of 15
-- alternating rounds, a collection before each timed run.
local PT = require("./PrecisionTrace")
local Params = require("./Params")
local Timeline = require("./Timeline")
local p = Params.resolve("PrecisionTrace", "Iron", "Normal", Params.refFactors(0))
local maxLen = PT.LEN_MARGIN * PT.TRAVEL_MAX_MS / 1000 * p.pacerSpeed
local best
for a10 = 1, 380 do
	local amp = a10 / 1000
	local us, vs = {}, {}
	for i = 0, 255 do
		table.insert(us, 0.15 + 2.7 * i / 255)
		table.insert(vs, 0.5 + amp * math.sin(2 * math.pi * 10 * i / 255)) -- allow-transcendental: test path only
	end
	if PT.polyLen(us, vs) <= maxLen then
		best = { us = us, vs = vs }
	end
end
local src = {}
for i = 1, #best.us do
	table.insert(src, math.round(best.us[i] * PT.Q))
	table.insert(src, math.round(best.vs[i] * PT.Q))
end
local pat = PT.generate(1, p, src)
local function samplesEvery(step: number, cap: number)
	local out = {}
	local t = 0
	while t <= pat.durationMs and #out < cap do
		local u, v = PT.pointAt(pat, PT.pacerArc(pat, t))
		table.insert(out, { t = t, u = math.round(u * PT.Q + 41), v = math.round(v * PT.Q - 23), grind = true })
		t += step
	end
	return out
end
local honest = samplesEvery(20, 2048)
local cap = samplesEvery(14, 2048)
local bH = Timeline.encode("PrecisionTrace", pat.durationMs, pat.hash, honest)
local bC = Timeline.encode("PrecisionTrace", pat.durationMs, pat.hash, cap)
local collect = (require("@lune/luau") :: any).load('collectgarbage("collect")')
local function judge(b: buffer)
	local rec = Timeline.decode(b, "PrecisionTrace", pat.durationMs)
	return PT.replay(pat, rec)
end
judge(bH)
judge(bC)
local th, tc = {}, {}
for round = 1, 15 do
	local order = if round % 2 == 1 then { bH, bC } else { bC, bH }
	for _, b in order do
		collect()
		local t0 = os.clock()
		judge(b)
		local dt = (os.clock() - t0) * 1000
		if b == bH then table.insert(th, dt) else table.insert(tc, dt) end
	end
end
table.sort(th)
table.sort(tc)
print(string.format("path pts %d, travel %d ms; decode + replay + checks median: honest %d samples %.2f ms; decode cap %d samples %.2f ms (x%.2f)",
	#pat.pu, pat.travelMs, #honest, th[8], #cap, tc[8], tc[8] / th[8]))
