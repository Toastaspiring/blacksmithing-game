-- compare PT.nearest (segment scan) with a 2-stage version (nearest vertex, then its 2 segments): speed and results
local PT = require("./PrecisionTrace")
local Params = require("./Params")
local Blades = require("./Blades")
local Bots = require("./Bots")
local function nearest2(pat, cu, cv, sc)
	local arc, pu, pv = pat.arc, pat.pu, pat.pv
	local n = #arc
	local lo = math.clamp(math.floor((sc - PT.SEARCH) / PT.DS), 1, n - 1)
	local hi = math.clamp(math.ceil((sc + PT.SEARCH) / PT.DS) + 1, 1, n - 1) + 1
	local bj, bd = lo, math.huge
	for i = lo, hi do
		local du, dv = cu - pu[i], cv - pv[i]
		local d2 = du * du + dv * dv
		if d2 < bd then
			bd, bj = d2, i
		end
	end
	local best, bestS = math.huge, 0
	for i = math.max(lo, bj - 1), math.min(hi - 1, bj) do
		local au, av = pu[i], pv[i]
		local bu, bv = pu[i + 1] - au, pv[i + 1] - av
		local l2 = bu * bu + bv * bv
		local t = 0
		if l2 > 0 then
			t = math.clamp(((cu - au) * bu + (cv - av) * bv) / l2, 0, 1)
		end
		local du, dv = cu - (au + bu * t), cv - (av + bv * t)
		local d2 = du * du + dv * dv
		if d2 < best then
			best, bestS = d2, arc[i] + (arc[i + 1] - arc[i]) * t
		end
	end
	return math.sqrt(best), bestS
end
local p = Params.resolve("PrecisionTrace", "Iron", "Normal", Params.refFactors(0.1))
local b = Blades.flamberge
local src = PT.edgeToPanel(PT.sidesFromChains(b.chains, b.grip, b.axis), b.grip, b.axis, p.pacerSpeed)
local maxDiff, maxDs, cnt = 0, 0, 0
local t1, t2 = 0, 0
for seed = 1, 30 do
	local pat = PT.generate(seed, p, src)
	local smp = Bots.ptHuman(pat, Bots.PROFILES.Average, seed)
	for _, sm in smp do
		local u, v = sm.u / PT.Q, sm.v / PT.Q
		local sc = PT.pacerArc(pat, sm.t)
		local a = os.clock()
		local d1, s1 = PT.nearest(pat, u, v, sc)
		local m = os.clock()
		local d2, s2 = nearest2(pat, u, v, sc)
		local e = os.clock()
		t1 += m - a
		t2 += e - m
		maxDiff = math.max(maxDiff, math.abs(d1 - d2))
		if math.abs(d1 - d2) < 1e-12 then maxDs = math.max(maxDs, math.abs(s1 - s2)) end
		cnt += 1
	end
end
print(string.format("%d queries: segment scan %.3f ms total, 2-stage %.3f ms total; max |d1-d2| %.2e; max |s1-s2| (same d) %.2e", cnt, t1 * 1000, t2 * 1000, maxDiff, maxDs))
