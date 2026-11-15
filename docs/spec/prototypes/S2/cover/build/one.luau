--!nocheck
-- Time a few named designs of a set alone: verdict (SamplingV) and units. args: set namePattern [runs]
local process = require("@lune/process")
local L = require("./lib")
local fmt = string.format
local which, pat, RUNS = process.args[1], process.args[2], tonumber(process.args[3] or "15") or 15
local list = if which == "plausible" then L.plausible() elseif which == "real" then L.realFixtures() elseif which == "hostile" then L.worstP() else L.json(which, "")
local found = {}
for _, d in ipairs(list) do
	if string.find(d.name, pat, 1, true) then table.insert(found, d) end
	if #found >= 6 then break end
end
list = nil
for _, d in ipairs(found) do
	local P = L.prep(d.parts)
	local e = L.SamplingV.exposure(P, nil)
	local ts = {}
	for r = 1, RUNS do
		local t0 = os.clock()
		L.SamplingV.exposure(P, nil)
		ts[r] = (os.clock() - t0) * 1000
	end
	print(fmt("%-60s %9.0f units %8.3f ms (min %.3f)", string.sub(d.name, 1, 60), e.verdictWork, L.median(ts), math.min(table.unpack(ts))))
end
