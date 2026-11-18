--!nocheck
local S = require("./sets")
local L = require("./lib")
local C = require("./v/coverprof/Cover")
local fmt = string.format
local function run(name)
	local d
	for _, x in ipairs(S.climbed()) do if string.find(x.name, name, 1, true) then d = x break end end
	local P = L.prep(d.parts)
	for k in pairs(C.PROF) do C.PROF[k] = 0 end
	local share, kept, tests = L.newShares(P, C.model, C)
	local t = 0 for i = 1, #P do t += tests[i] end
	local p = C.PROF
	print(fmt("%s: tests %d = proj %d + clip %d + sub %d | pairs %d pieces %d whole %d subtracted %d mean act %.1f mean list %.1f max list %d splits %d",
		d.name, t, p.proj, p.clip, p.sub, p.pairs, p.pieces, p.whole, p.subtracted, p.actsum / math.max(1, p.subtracted), p.listsum / math.max(1, p.subtracted), p.maxlist, p.splits))
end
run("rods d 0.15 L 4.8")
run("d_climb_3 #4")
run("climb_w10_4")
