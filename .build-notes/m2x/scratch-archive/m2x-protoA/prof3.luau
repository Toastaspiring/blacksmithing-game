--!nocheck
local S = require("./sets")
local L = require("./lib")
local C = require("./v/coverprof/Cover")
local fmt = string.format
local list = {}
local c3 = S.json("out/climb_3.json")
table.insert(list, c3[1])
for _, d in ipairs(S.json("../m2r5-v1-1/out/d_hand.json")) do if string.find(d.name, "d 0.15 L 4.8", 1, true) then table.insert(list, d) end end
for _, d in ipairs(S.protoFixtures()) do if string.sub(d.name, 1, 3) == "P1 " or string.sub(d.name, 1, 3) == "P4 " then table.insert(list, d) end end
for _, d in ipairs(list) do
	local P = L.prep(d.parts)
	for k in pairs(C.PROF) do C.PROF[k] = 0 end
	local t0 = os.clock()
	local share, kept, tests = L.newShares(P, C.model, C)
	local ms = (os.clock() - t0) * 1000
	local t = 0
	for i = 1, #P do t += tests[i] end
	local p = C.PROF
	print(fmt("%-40s full read %.0f ms, tests %d = pretest %d (%.0f%%) + clip %d (%.0f%%) + within %d + apart %d (%.0f%%) + split %d (%.0f%%) | pairs %d, subtractions %d, mean list %.1f, max list %d",
		string.sub(d.name, 1, 40), ms, t, p.pre, 100 * p.pre / t, p.clip, 100 * p.clip / t, p.within, p.apart, 100 * p.apart / t, p.sub, 100 * p.sub / t, p.pairs, p.subtracts, p.polys / math.max(1, p.subtracts), p.maxlist))
end
