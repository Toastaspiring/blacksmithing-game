--!nocheck
-- The swaps of cand and near change no bit: what the verdict reads, sample by sample in sum, with and without them, no early exit; and the checkpoint units.
local V = require("./v1")
local NoSwap = require("./noswap/Sampling")
local Force = V.Force
local Sets = require("./b_sets")
local H = require("./tree/tests/Physics/PhysicsHelpers")
local TestRng = require("./tree/tests/lib/TestRng")
local fmt = string.format
local function readOf(M, P)
	M.FORCE.read, M.FORCE.fullRead = {}, true
	local units = 0
	local ex = M.exposure(P, function(n) units += n end)
	local read = M.FORCE.read
	M.FORCE.read, M.FORCE.fullRead = nil, nil
	return ex, read, units
end
local function same(parts, what)
	local P = V.prep(parts)
	local a, ra, ua = readOf(Force, P)
	local P2 = V.prep(parts)
	local b, rb, ub = readOf(NoSwap, P2)
	for i = 1, #parts do
		if a.kept[i] ~= b.kept[i] or ra[i] ~= rb[i] or a.exposedKept[i] ~= b.exposedKept[i] then
			print("DIFF", what, i, ra[i], rb[i])
			return false
		end
	end
	if ua ~= ub then
		print("UNITS", what, ua, ub)
		return false
	end
	return true
end
local n, bad = 0, 0
local rng = TestRng.new(99)
for d = 1, 1500 do
	local design = H.anyDesign(rng)
	n += 1
	if not same(V.renumber(design.parts), "any " .. d) then bad += 1 end
end
print(fmt("anyDesign: %d designs, %d differ", n, bad))
for _, f in ipairs({ "comb", "wall", "bead", "curvedGrip" }) do
	local l = Sets.get(f)
	local b2 = 0
	for _, d in ipairs(l) do
		if not same(V.renumber(d.parts), d.name) then b2 += 1 end
	end
	print(f, #l, "designs", b2, "differ")
end
local Fx = V.Fx
local b3, n3 = 0, 0
for _, list in ipairs({ Fx.calibration(), Fx.golden(), Fx.perf() }) do
	for _, b in ipairs(list) do
		n3 += 1
		if not same(V.copyParts(b.parts), b.name) then b3 += 1 end
	end
end
print("fixtures", n3, b3, "differ")
