--!nocheck
local process = require("@lune/process")
local L = require("./jlib")
local T = require("./tangles")
local fmt = string.format
local seed, k, ip = tonumber(process.args[1]), tonumber(process.args[2]), tonumber(process.args[3])
local d = T.corpus(seed, k, 3, 14)[k]
local P = L.prep(d.parts)
for i, p in ipairs(d.parts) do
	print(fmt("%d %s pos (%.9g, %.9g, %.9g) rot (%.6g %.6g %.6g %.6g) size (%.9g %.9g %.9g) vol %.6g", i, p.shape, p.pos[1], p.pos[2], p.pos[3], p.rot[1], p.rot[2], p.rot[3], p.rot[4], p.size[1], p.size[2], p.size[3], P[i].volume))
end
local flags = { L.flags(P) }
print("ranks", table.concat(flags[1], ","), "copy", table.concat((function() local t = {} for i = 1, #P do t[i] = tostring(flags[3][i]) end return t end)(), ","))
local A, Am = L.readA(P, nil, flags)
local B, Bm = L.readB(P, 32, 4, false, flags)
local Jb, Jm = L.JBrute.readAll(P, flags, L.cands, nil, nil)
local idx = L.cands(P, ip, flags[1], flags[2], flags[5])
print("cands of", ip, table.concat(idx, ","))
-- per facet: A needs per-facet: run A.shown on a one-facet model? use full and compare totals per facet via B and J
for f = 1, #B[ip].per do
	print(fmt("facet %d: B %.12g J %.12g  diff %.3g  area J %.6g", f, B[ip].per[f], Jb[ip].per[f], B[ip].per[f] - Jb[ip].per[f], Jm[ip].area[f]))
end
print(fmt("totals A %.12g B %.12g J %.12g", A[ip].shown, B[ip].shown, Jb[ip].shown))
local f = tonumber(process.args[4] or "0")
if f > 0 then
	local rank, byRank, isCopy, dust, hider = table.unpack(flags)
	local idx2, higher = L.cands(P, ip, rank, byRank, hider)
	local hm = {}
	for kk, j in ipairs(idx2) do hm[kk] = Jm[j] end
	for _, n in ipairs({ 100, 400, 1000 }) do
		local s, t = L.JBrute.facetLattice(Jm[ip], f, hm, higher, n)
		print(fmt("lattice n %d: facet %d shown %.9g of %.9g", n, f, s, t))
	end
end
