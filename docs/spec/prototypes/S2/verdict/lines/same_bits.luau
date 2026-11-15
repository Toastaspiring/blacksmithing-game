--!nocheck
-- The shortcuts change no reading: each removed, against the build, on any designs and the slit families. args: variant step
local process = require("@lune/process")
local V = require("./v1")
local Sets = require("./b_sets")
local H = require("./tree/tests/Physics/PhysicsHelpers")
local TestRng = require("./tree/tests/lib/TestRng")
local Force = V.Force
local Var = require("./var_" .. process.args[1] .. "/Sampling")
local step = tonumber(process.args[2]) or 10
local fmt = string.format
local function readOf(M, P)
	M.FORCE.read, M.FORCE.fullRead = {}, true
	local ex = M.exposure(P)
	local read = M.FORCE.read
	M.FORCE.read, M.FORCE.fullRead = nil, nil
	return ex, read
end
local parts, bits, big, designs = 0, 0, 0, 0
local worst = 0
local function same(list, what)
	V.renumber(list)
	local a, ra = readOf(Force, V.prep(list))
	local b, rb = readOf(Var, V.prep(list))
	designs += 1
	for i = 1, #list do
		parts += 1
		if a.kept[i] ~= b.kept[i] then
			print("VERDICT", what, i)
			big += 1
		end
		if ra[i] and rb[i] and ra[i] ~= rb[i] then
			bits += 1
			local d = math.abs(ra[i] - rb[i])
			if d > worst then worst = d end
		end
	end
end
local rng = TestRng.new(4711)
for d = 1, 1500 do
	same(H.anyDesign(rng).parts, "any " .. d)
end
for _, fam in ipairs({ "comb", "wall", "fuller", "chamfer", "oddPoke", "tiltPlate", "plausible" }) do
	for k, d in ipairs(Sets.get(fam)) do
		if k % step == 0 then
			same(d.parts, d.name)
		end
	end
end
print(fmt("%s: %d designs, %d parts, %d verdicts differ, %d readings differ in a bit, the largest by %.3g", process.args[1], designs, parts, big, bits, worst))
