--!nocheck
local L = require("./lib")
local Worst = require("./repo/docs/spec/prototypes/S2/cover/worst_designs")
local Attacks = require("./repo/tests/Physics/CoverAttacks")
for _, d in ipairs({ { "P1", L.fixture("P1") }, { "P4", L.fixture("P4") }, { "C09", L.fixture("C09") }, { "F3", L.repoFixture("F3") }, { "worst valid 1", L.copyParts(Worst.valid[1].parts) }, { "attack 3", L.copyParts(Attacks[3].parts) }, { "attack 15", L.copyParts(Attacks[15].parts) } }) do
	local e = L.Sampling.exposure(L.prep(L.renumber(d[2])))
	print(d[1], string.format("%.17g", e.verdictWork))
end
