--!nocheck
-- The conservative probe's price: Balls in cages whose model reading (the hide test, no box filter: mybrute) is under 2 %
-- while the truth shows more. Search r, g, b; truth by VisibleOracle on the candidates.
local process = require("@lune/process")
local L = require("./lib")
local MB = require("./mybrute")
local mk = require("./cagelib")
MB.init(L.Geo)
local Cover = L.Cover
local fmt = string.format
local seed = tonumber(process.args[1]) or 1
local N = tonumber(process.args[2]) or 600
math.randomseed(seed)
local best = { 0 }
local cand = 0
for t = 1, N do
	local RS = { 0.1, 0.15, 0.2, 0.25, 0.28, 0.29 }
	if process.args[3] == "big" then RS = { 0.2, 0.25, 0.28, 0.29 } end
	local r = RS[math.random(1, #RS)]
	local g = -0.004 + 0.02 * math.random()
	local b = r * (0.15 + 0.42 * math.random())
	local parts = mk.cage(L, r, g, b)
	local P = L.prep(parts)
	local models = {}
	for i = 1, #P do models[i] = Cover.model(P[i]) end
	local idx, higher = {}, {}
	local rk, ord = L.Sampling.ranked(P)
	for k = 1, #ord do
		local q = ord[k]
		if q.index ~= 1 then table.insert(idx, q.index); table.insert(higher, k < rk[1]) end
	end
	local hm = {}
	for k, j in ipairs(idx) do hm[k] = models[j] end
	local m = models[1]
	local bsum = 0
	for f = 1, m.n do bsum += MB.facetShown(m, f, hm, higher) end
	local ht = bsum / m.total
	if ht < 0.02 and ht > 0.002 then
		cand += 1
		local _, _, h = L.Oracle.flags(P)
		local truth = L.Oracle.share(P, 1, h)
		if truth > best[1] then best = { truth, r, g, b, ht } end
	end
end
print(fmt("seed %d: %d cages, %d read 0.2–2 %% on the model; the highest truth among them %.3f%% (r %.2f g %.5f b %.4f, model %.3f%%)", seed, N, cand, 100 * best[1], best[2] or 0, best[3] or 0, best[4] or 0, 100 * (best[5] or 0)))
