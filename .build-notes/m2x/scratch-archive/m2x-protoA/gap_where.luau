--!nocheck
local S = require("./sets")
local Shapes = require("./repo/src/shared/Physics/Shapes")
local New = require("./v/newV_base/Sampling")
local fmt = string.format
local d
for _, x in ipairs(S.json("../m2r5-v1-1/out/d_hand.json")) do if string.find(x.name, "d 0.15 L 4.8", 1, true) then d = x end end
local P = {}
for i, p in ipairs(d.parts) do P[i] = Shapes.prepare(p, i) end
for run = 1, 3 do
	local last = os.clock()
	local calls, worst, where = 0, 0, ""
	local hist = { 0, 0, 0, 0, 0 }
	New.exposure(P, function(n)
		local now = os.clock()
		local g = (now - last) * 1000
		calls += 1
		if g > 0.35 then hist[1] += 1 end
		if g > 1 then hist[2] += 1 end
		if g > 5 then hist[3] += 1 end
		if g > worst then worst = g; where = debug.traceback("", 2) end
		last = now
	end)
	print(fmt("run %d: %d spend calls, gaps > 0.35 / 1 / 5 ms: %d / %d / %d, longest %.3f ms at:%s", run, calls, hist[1], hist[2], hist[3], worst, string.sub(where, 1, 400)))
end
