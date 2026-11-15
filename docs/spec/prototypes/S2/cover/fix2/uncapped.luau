--!nocheck
-- fix-2 (V2's uncapped.luau on the repo): the units a design past the cap would spend with the cap lifted (A28,
-- worst_designs.luau's tooComplex), and how far past the cap each stops with it; run from the repo root
local R = "C:/Users/louis/Documents/RANDOM/ROBLOX/Blacksmithing Game"
local H = require(R .. "/tests/Physics/PhysicsHelpers")
local Adv = require(R .. "/tests/fixtures/Adversarial")
local Canonical = require(R .. "/src/shared/Blueprint/Canonical")
local Sampling = require(R .. "/src/shared/Physics/Sampling")
local Worst = require(R .. "/docs/spec/prototypes/S2/cover/worst_designs")
local Lifted = H.plantedSampling({ VERDICT_WORK_MAX = math.huge })
local fmt = string.format
local function units(parts)
	return Lifted.exposure(H.prepared({ parts = parts })).verdictWork
end
local a28 = Canonical.draft(Adv.variant("A28").draft()).value.parts
print(fmt("A28: %.3f units; with the cap %.3f", units(a28), Sampling.exposure(H.prepared({ parts = a28 })).verdictWork))
local lo, hi, past = math.huge, 0, 0
for _, d in ipairs(Worst.tooComplex) do
	local u = units(d.parts)
	lo, hi = math.min(lo, u), math.max(hi, u)
	past = math.max(past, Sampling.exposure(H.prepared({ parts = d.parts })).verdictWork - 700000)
end
print(fmt("tooComplex: %.0f – %.0f units uncapped; with the cap each stops at most %.3f past it", lo, hi, past))
