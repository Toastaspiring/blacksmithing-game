--!nocheck
-- exactness on the repo fixtures, the emulator's fixtures and the attack designs
local L = require("./lib")
local E = require("./exactlib")
local Attacks = require("./repo/tests/Physics/CoverAttacks")
local fmt = string.format
local t0 = os.clock()
local tot = { checked = 0, ties = 0, past = 0, bad = 0 }
local function run(name, parts)
	local P = L.prep(parts)
	local r = E.check(P)
	tot.checked += r.checked
	tot.ties += r.ties
	tot.past += r.past
	tot.bad += #r.bad
	if #r.bad > 0 or r.nonfinite > 0 then
		print(fmt("%s: checked %d ties %d past %d BAD %d nonfinite %d", name, r.checked, r.ties, r.past, #r.bad, r.nonfinite))
		for _, b in ipairs(r.bad) do
			print(fmt("   part %d (%s) facet %d: cover %.17g outside [%.17g, %.17g] (miss %.3g of the part)", b.part, b.shape, b.facet, b.c, b.lo, b.hi, b.miss / b.total))
		end
	end
end
for _, id in ipairs(L.Blueprints.order) do
	run(id, L.repoFixture(id))
end
for _, list in ipairs({ L.Fx.calibration(), L.Fx.regression(), L.Fx.perf(), L.Fx.adversarial(), L.Fx.validation() }) do
	for _, b in ipairs(list) do
		local f = b.fixture or b
		if f.parts then
			run(tostring(f.name), L.copyParts(f.parts))
		end
	end
end
for _, d in ipairs(Attacks) do
	run(d.name or "attack", L.copyParts(d.parts))
end
print(fmt("fixtures + attacks: checked %d parts, ties %d, past the cell limit %d, outside the bracket %d (%.1f s)", tot.checked, tot.ties, tot.past, tot.bad, os.clock() - t0))
