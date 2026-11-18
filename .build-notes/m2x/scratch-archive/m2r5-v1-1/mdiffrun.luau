--!nocheck
-- A survivor against the build: what each reads per part, no early exit, on random and designed sets. args: mutant ids
local process = require("@lune/process")
local V = require("./v1")
local Sets = require("./b_sets")
local H = require("./tree/tests/Physics/PhysicsHelpers")
local TestRng = require("./tree/tests/lib/TestRng")
local Force = V.Force
local fmt = string.format

local designs = {}
do
	local rng = TestRng.new(123)
	for d = 1, 2500 do
		table.insert(designs, { "any" .. d, V.renumber(H.anyDesign(rng).parts) })
	end
	for _, f in ipairs({ "comb", "wall", "bead", "curvedGrip" }) do
		for _, d in ipairs(Sets.get(f)) do
			table.insert(designs, { f .. " " .. d.name, V.renumber(d.parts) })
		end
	end
	for _, f in ipairs({ "fuller", "oddPoke", "tiltPlate", "chamfer", "sunkRod", "thinPart" }) do
		local l = Sets.get(f)
		for k = 1, #l, 7 do
			table.insert(designs, { f .. " " .. l[k].name, V.renumber(l[k].parts) })
		end
	end
	for _, list in ipairs({ V.Fx.calibration(), V.Fx.golden(), V.Fx.perf() }) do
		for _, b in ipairs(list) do
			table.insert(designs, { b.name, V.renumber(V.copyParts(b.parts)) })
		end
	end
end
print(#designs, "designs")
local function readOf(M, P)
	M.FORCE.read, M.FORCE.fullRead = {}, true
	local ex = M.exposure(P)
	local r = M.FORCE.read
	M.FORCE.read, M.FORCE.fullRead = nil, nil
	return ex, r
end
local baseline = {}
for k, d in ipairs(designs) do
	local ex, r = readOf(Force, V.prep(d[2]))
	baseline[k] = { ex, r }
end
for a = 1, #process.args do
	local id = process.args[a]
	local M = require("./mdiff/m" .. id)
	local diff, flips, worst, firstName = 0, 0, 0, nil
	local worstName
	for k, d in ipairs(designs) do
		local ok, ex, r = pcall(readOf, M, V.prep(d[2]))
		if not ok then
			print("  error", id, d[1], ex)
			break
		end
		local b = baseline[k]
		local changed = false
		for i = 1, #d[2] do
			local ra, rb = b[2][i], r[i]
			if ra ~= rb then
				changed = true
				local dd = math.abs((ra or 0) - (rb or 0))
				if dd > worst then
					worst, worstName = dd, fmt("%s part %d (%s): %.5f -> %.5f", d[1], i, d[2][i].shape, ra or 0, rb or 0)
				end
			end
			if b[1].kept[i] ~= ex.kept[i] then
				flips += 1
			end
			if b[1].exposedKept[i] ~= ex.exposedKept[i] then changed = true end
		end
		if changed then diff += 1 end
	end
	print(fmt("m%s: %d designs differ, %d verdicts flip, the largest change of a reading %.5f %s", id, diff, flips, worst, worstName or ""))
end
