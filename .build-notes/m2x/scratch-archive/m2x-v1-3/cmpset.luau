--!nocheck
-- V1 (m2x, round 3): two trees' verdicts on a design set, and the truth of every part whose verdict differs.
--   lune run cmpset -- <set> <shard> <nshards> <treeA> <treeB> <out>
-- set: plausible | attacks | fixtures; trees: folders beside this script holding src/shared/Physics/SamplingV.luau
local process = require("@lune/process")
local fs = require("@lune/fs")
local fmt = string.format
local args = process.args
local set, shard, nshards, ta, tb, outPath = args[1], tonumber(args[2]), tonumber(args[3]), args[4], args[5], args[6]
local function req(p)
	return (require :: any)(p)
end
local SA = req("./" .. ta .. "/src/shared/Physics/SamplingV")
local SB = req("./" .. tb .. "/src/shared/Physics/SamplingV")
local ShA = req("./" .. ta .. "/src/shared/Physics/Shapes")
local ShB = req("./" .. tb .. "/src/shared/Physics/Shapes")
local Oracle = req("./repo/tests/Physics/VisibleOracle")
local Shapes = req("./repo/src/shared/Physics/Shapes")

local function clean(parts)
	local o = {}
	for i, p in ipairs(parts) do
		o[i] = { id = i, shape = p.shape, slot = p.slot or "Blade", material = p.material or "Iron",
			pos = { p.pos[1], p.pos[2], p.pos[3] }, rot = { p.rot[1], p.rot[2], p.rot[3], p.rot[4] },
			size = { p.size[1], p.size[2], p.size[3] } }
	end
	return o
end

local designs = {}
if set == "plausible" then
	for _, d in ipairs(req("./repo/tests/Physics/PlausibleDesigns").all()) do
		table.insert(designs, { name = d.name, parts = clean(d.parts) })
	end
elseif set == "attacks" then
	for _, d in ipairs(req("./repo/tests/Physics/CoverAttacks")) do
		table.insert(designs, { name = d.name, parts = clean(d.parts) })
	end
elseif set == "fixtures" then
	local Fx = req("./repo/docs/spec/prototypes/S2/v2/fixtures")
	for _, list in ipairs({ Fx.calibration(), Fx.golden(), Fx.perf(), Fx.regression() }) do
		for _, b in ipairs(list) do
			if b.parts then
				table.insert(designs, { name = b.name, parts = clean(b.parts) })
			end
		end
	end
else
	error("set?")
end

local lines = {}
local n, moved, cappedDiff = 0, 0, 0
for k = shard, #designs, nshards do
	local d = designs[k]
	local PA, PB = {}, {}
	for i, p in ipairs(d.parts) do
		PA[i] = ShA.prepare(p, i)
		PB[i] = ShB.prepare(p, i)
	end
	local ra = SA.exposure(PA)
	local rb = SB.exposure(PB)
	n += 1
	if ra.capped ~= rb.capped then
		cappedDiff += 1
		table.insert(lines, fmt("CAPPED\t%s\t%s\t%s", d.name, tostring(ra.capped), tostring(rb.capped)))
	elseif not ra.capped then
		local _, _, hider = nil, nil, nil
		for i = 1, #d.parts do
			if ra.kept[i] ~= rb.kept[i] then
				if hider == nil then
					_, _, hider = Oracle.flags(PA)
				end
				local t = if hider[i] then Oracle.share(PA, i, hider) else -1
				moved += 1
				table.insert(lines, fmt("MOVE\t%s\t%d\t%s\t%s\t%s\t%s\t%.5f", d.name, i, d.parts[i].shape, d.parts[i].slot,
					tostring(ra.kept[i]), tostring(rb.kept[i]), t))
			end
		end
	end
end
table.insert(lines, fmt("DONE\t%d designs\t%d moved parts\t%d capped differ", n, moved, cappedDiff))
fs.writeFile(outPath, table.concat(lines, "\n") .. "\n")
print(lines[#lines])
