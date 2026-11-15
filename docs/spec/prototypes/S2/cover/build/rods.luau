--!nocheck
local L = require("./lib")
local Z90 = { 0, 0, 0.70710678118654757, 0.70710678118654757 }
local parts = {}
for i = 1, 24 do
	parts[i] = { id = i, shape = "Cylinder", slot = "Blade", material = "Iron", pos = { 0.004 * ((i - 1) % 8), 2.5 + 0.0001 * i, 0.01 * ((i - 1) // 8) }, rot = Z90, size = { 1.2, 0.02, 0.02 } }
end
local P = L.prep(parts)
local t0 = os.clock()
local e = L.SamplingV.exposure(P, nil)
print("units", e.verdictWork, "ms", (os.clock() - t0) * 1000)
local k = 0 for i = 1, 24 do if e.kept[i] then k += 1 end end
print("kept", k)
