--!nocheck
-- Where a design's verdict units come from, by the line of Cover that charges them (an instrumented copy: every
-- `pending +=` and the model's `m.work +=` also add to a counter of their own), with the verdict's Lune ms (median of RUNS).
-- args: jsonfile [count] [runs]   (a climb's output, or any { parts } list); or "real:<name>"
local process = require("@lune/process")
local fs = require("@lune/fs")
local luau = require("@lune/luau")
local serde = require("@lune/serde")
local L = require("./lib")
local fmt = string.format

local src = fs.readFile(L.SCR .. "m2x-build/snap/src/shared/Physics/Cover.luau")
local C = {}
local names = {}
local k = 0
src = string.gsub(src, "pending %+= ([^\n]+)", function(expr)
	k += 1
	names[k] = expr
	return "do local __u = " .. expr .. "; pending += __u; __C[" .. k .. "] += __u end"
end)
src = string.gsub(src, "m%.work %+= ([^\n]+)", function(expr)
	k += 1
	names[k] = "model: " .. expr
	return "do local __u = " .. expr .. "; m.work += __u; __C[" .. k .. "] += __u end"
end)
for i = 1, k do C[i] = 0 end
local mods = { ["../Definitions/Balance"] = L.Balance, ["./Shapes"] = L.Shapes }
local CoverI = luau.load(src, { debugName = "CoverI", environment = { require = function(n) return mods[n] end, math = math, table = table, string = string, __C = C } })()
local samplingSrc = fs.readFile(L.SCR .. "m2x-build/snap/src/shared/Physics/SamplingV.luau")
local smods = { ["../Definitions/Balance"] = L.Balance, ["../Definitions/Limits"] = require("../snap/src/shared/Definitions/Limits"), ["./Cover"] = CoverI, ["./Shapes"] = L.Shapes }
local SV = luau.load(samplingSrc, { debugName = "SamplingVI", environment = { require = function(n) return smods[n] end, math = math, table = table, string = string } })()

local arg1 = process.args[1]
local COUNT = tonumber(process.args[2] or "3") or 3
local RUNS = tonumber(process.args[3] or "11") or 11
local list
if string.sub(arg1, 1, 5) == "real:" then
	list = {}
	for _, d in ipairs(L.realFixtures()) do
		if string.find(d.name, string.sub(arg1, 6), 1, true) then table.insert(list, d) end
	end
else
	list = serde.decode("json", fs.readFile(arg1))
end
for n = 1, math.min(COUNT, #list) do
	local d = list[n]
	local P = L.prep(d.parts)
	for i = 1, k do C[i] = 0 end
	local e = SV.exposure(P, nil)
	local counts = table.clone(C)
	local ts = {}
	for r = 1, RUNS do
		local t0 = os.clock()
		L.SamplingV.exposure(P, nil)
		ts[r] = (os.clock() - t0) * 1000
	end
	local shapes = {}
	for _, p in ipairs(d.parts) do shapes[p.shape] = (shapes[p.shape] or 0) + 1 end
	local sh = {}
	for s, c in pairs(shapes) do table.insert(sh, s .. " " .. c) end
	table.sort(sh)
	print(fmt("== %s: %.0f units, %.3f ms, %.1f ns/unit [%s]", d.name or ("#" .. n), e.verdictWork, L.median(ts), L.median(ts) * 1e6 / e.verdictWork, table.concat(sh, ", ")))
	for i = 1, k do
		if counts[i] > 0 then
			print(fmt("   %5.1f%% %10.0f  %s", 100 * counts[i] / e.verdictWork, counts[i], string.sub(names[i], 1, 80)))
		end
	end
end
