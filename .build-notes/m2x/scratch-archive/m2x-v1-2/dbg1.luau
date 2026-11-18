--!nocheck
local L = require("./lib")
local AB = require("./arrbrute")
AB.init(L.Geo)
local fmt = string.format
local n = 0
for _, list in ipairs({ L.Fx.calibration(), L.Fx.regression(), L.Fx.perf() }) do
	for _, b in ipairs(list) do
		n += 1
		if n < 5 then print(b.name, b.parts and #b.parts) end
	end
end
print("fx designs", n)
local Attacks = require("./repo/tests/Physics/CoverAttacks")
print("attacks", #Attacks, Attacks[1].name, #Attacks[1].parts)
-- one design: C09 read vs brute
local parts = L.fixture("C09")
local P = L.prep(parts)
local models = L.models(P)
for i = 1, #P do
	if models[i] then
		local idx, higher = L.hidersOf(P, i, models)
		local hm = {}
		for k, j in ipairs(idx) do hm[k] = models[j] end
		local aidx, ah = L.allHiders(P, i, models)
		local am = {}
		for k, j in ipairs(aidx) do am[k] = models[j] end
		local c = L.Cover.shown(models[i], hm, higher, math.huge, math.huge)
		local b, cells = AB.shown(models[i], am, ah, 0)
		print(fmt("%2d %-12s %-8s cover %.15f brute %.15f diff %.2e cells %d hiders %d/%d", i, P[i].shape, P[i].slot, c / models[i].total, b / models[i].total, (c - b) / models[i].total, cells, #idx, #aidx))
	end
end
