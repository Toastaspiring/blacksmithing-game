--!nocheck
local S = require("./sets")
local L = require("./lib")
local Full = require("./v/cover/Cover")
local Lite = require("./v/coverlite/Cover")
local fmt = string.format
local list = {}
table.insert(list, S.json("out/climb_3.json")[1])
table.insert(list, S.json("out/climb_2.json")[1])
for _, d in ipairs(S.json("../m2r5-v1-1/out/d_hand.json")) do if string.find(d.name, "d 0.15 L 4.8", 1, true) then table.insert(list, d) end end
for _, d in ipairs(S.worstP()) do if string.find(d.name, "climbL_2#1", 1, true) then table.insert(list, d) end end
for _, d in ipairs(S.protoFixtures()) do if string.sub(d.name, 1, 3) == "P1 " or string.sub(d.name, 1, 3) == "P4 " or string.sub(d.name, 1, 3) == "C09" then table.insert(list, d) end end
local maxd = 0
for _, d in ipairs(list) do
	local P = L.prep(d.parts)
	local res = {}
	for _, v in ipairs({ { "full", Full }, { "lite", Lite } }) do
		local best = math.huge
		local share, tests
		for r = 1, 3 do
			local t0 = os.clock()
			share, _, tests = L.newShares(P, v[2].model, v[2])
			best = math.min(best, (os.clock() - t0) * 1000)
		end
		local t = 0
		for i = 1, #P do t += tests[i] end
		res[v[1]] = { ms = best, tests = t, share = share }
	end
	for i = 1, #P do
		if res.full.share[i] then maxd = math.max(maxd, math.abs(res.full.share[i] - res.lite.share[i])) end
	end
	print(fmt("%-34s full read (no early stop), best of 3: SAT on both polygons %8.1f ms %9d tests | piece lines only %8.1f ms %9d tests", string.sub(d.name or "climb", 1, 34), res.full.ms, res.full.tests, res.lite.ms, res.lite.tests))
end
print(fmt("largest |share difference| between the two: %.3e", maxd))
