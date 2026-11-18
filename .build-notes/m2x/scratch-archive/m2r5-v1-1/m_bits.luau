--!nocheck
-- nosearch against the build: readings, no early exit
local V = require("./v1")
local H = require("./tree/tests/Physics/PhysicsHelpers")
local TestRng = require("./tree/tests/lib/TestRng")
local Sets = require("./b_sets")
local Force = V.Force
local Alt = require("./alt-nosearch/force/Sampling")
local fmt = string.format
local function readOf(M, P)
	M.FORCE.read, M.FORCE.fullRead = {}, true
	local ex = M.exposure(P)
	local r = M.FORCE.read
	M.FORCE.read, M.FORCE.fullRead = nil, nil
	return ex, r
end
local diff, flips, n, worst = 0, 0, 0, 0
local where
local function one(name, parts)
	n += 1
	V.renumber(parts)
	local a, ra = readOf(Force, V.prep(parts))
	local b, rb = readOf(Alt, V.prep(parts))
	local changed = false
	for i = 1, #parts do
		if ra[i] ~= rb[i] then
			changed = true
			local d = math.abs((ra[i] or 0) - (rb[i] or 0))
			if d > worst then worst, where = d, fmt("%s part %d %s %.5f -> %.5f", name, i, parts[i].shape, ra[i] or 0, rb[i] or 0) end
		end
		if a.kept[i] ~= b.kept[i] then flips += 1 end
	end
	if changed then diff += 1 end
end
local rng = TestRng.new(321)
for d = 1, 1500 do one("any" .. d, H.anyDesign(rng).parts) end
for _, f in ipairs({ "comb", "wall", "bead", "curvedGrip" }) do
	for _, d in ipairs(Sets.get(f)) do one(f .. " " .. d.name, d.parts) end
end
local l = Sets.get("fuller")
for k = 1, #l, 5 do one("fuller " .. l[k].name, l[k].parts) end
for _, list in ipairs({ V.Fx.calibration(), V.Fx.golden(), V.Fx.perf() }) do
	for _, b in ipairs(list) do one(b.name, V.copyParts(b.parts)) end
end
print(fmt("%d designs: %d read otherwise, %d verdicts flip, worst %.5f %s", n, diff, flips, worst, where or ""))
