--!nocheck
-- the largest single report Cover.shown and Cover.model make through spend, per design
local L = require("./lib")
local T = require("./tsets")
local Worst = require("./repo/docs/spec/prototypes/S2/cover/worst_designs")
local fmt = string.format
local designs = { { "P1", L.fixture("P1") }, { "P4", L.fixture("P4") }, { "C09", L.fixture("C09") }, { "worst valid 1", L.copyParts(Worst.valid[1].parts) }, { "worst valid 3", L.copyParts(Worst.valid[3].parts) }, { "cluster", T.cluster(0.54, 0.05803, 0.25, 0.3) }, { "tooComplex 2", L.copyParts(Worst.tooComplex[2].parts) } }
for _, d in ipairs(designs) do
	local biggest = 0
	L.Sampling.exposure(L.prep(L.renumber(d[2])), function(n) if n > biggest then biggest = n end end)
	print(fmt("%-14s largest single report %.1f units", d[1], biggest))
end
