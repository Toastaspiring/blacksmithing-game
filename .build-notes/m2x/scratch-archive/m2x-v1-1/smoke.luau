--!nocheck
local L = require("./lib")
for _, id in ipairs({ "F1", "F2", "F3", "F4", "F5" }) do
	local parts = L.repoFixture(id)
	local R = L.emu(parts)
	local P = L.prep(parts)
	local e = L.Sampling.exposure(P)
	print(id, #parts, L.dline(R), "units", e.verdictWork, "cleaned", #e.cleaned, "canon", L.canonical(L.copyParts(parts)))
end
local parts = L.fixture("C09")
print("C09", L.dline(L.emu(parts)))
