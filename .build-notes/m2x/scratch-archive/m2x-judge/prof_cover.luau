--!nocheck
-- Where A's verdict spends time that its units do not count: per design, units, ms (median of 7), and the counters of
-- proto/CoverI.luau (pair box tests, list scans in subtract, measure vertices). args: file [canon]
local process = require("@lune/process")
local L = require("./jlib")
local S = require("./jsets")
local CoverI = require("./proto/CoverI")
local fmt = string.format
local opts = if process.args[2] == "base" then nil else { canon = true }
local list = {}
for a = 1, #process.args do
	local x = process.args[a]
	if x == "fixtures" then for _, d in ipairs(S.fixtures()) do if string.sub(d.name, 1, 1) == "P" or string.sub(d.name, 1, 3) == "C09" then table.insert(list, d) end end
	elseif x == "climbA" then for _, d in ipairs(S.climbA()) do table.insert(list, d) end
	elseif x == "climbB" then for _, d in ipairs(S.climbB()) do table.insert(list, d) end
	elseif x == "worstP" then for _, d in ipairs(S.worstP()) do table.insert(list, d) end
	elseif string.sub(x, 1, 5) == "file:" then for _, d in ipairs(S.json(string.sub(x, 6), "")) do table.insert(list, d) end end
end
local function verdict(P, flags, spend)
	local rank, byRank, isCopy, dust, hider = table.unpack(flags)
	local models = {}
	for i = 1, #P do if hider[i] then models[i] = CoverI.model(P[i], opts); spend(4 * models[i].n) end end
	for i = 1, #P do
		if hider[i] then
			local idx, higher = L.cands(P, i, rank, byRank, hider)
			local hm = {}
			for k, j in ipairs(idx) do hm[k] = models[j] end
			CoverI.shown(models[i], hm, higher, 0.02 * models[i].total, spend)
		end
	end
end
print(fmt("%-40s %9s %8s %7s | %9s %9s %10s %9s %9s %7s", "design", "units", "ms", "ns/u", "pairBox", "pairPass", "scan", "measureV", "subtract", "maxList"))
for _, d in ipairs(list) do
	local P = L.prep(d.parts)
	local flags = { L.flags(P) }
	for k in pairs(CoverI.C) do CoverI.C[k] = 0 end
	local units = 0
	verdict(P, flags, function(n) units += n end)
	local C = table.clone(CoverI.C)
	local ts = {}
	for r = 1, 7 do
		local t0 = os.clock()
		verdict(P, flags, function() end)
		ts[r] = (os.clock() - t0) * 1000
	end
	table.sort(ts)
	print(fmt("%-40s %9.0f %8.2f %7.1f | %9d %9d %10d %9d %9d %7d", string.sub(d.name, 1, 40), units, ts[4], ts[4] / units * 1e6,
		C.pairBox, C.pairPass, C.scan, C.measureV, C.subtracts, C.maxList))
end
