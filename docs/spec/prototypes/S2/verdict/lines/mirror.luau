--!nocheck
-- The verdict on a design and on its mirror images. args: family shard nshards
local process = require("@lune/process")
local V = require("./v1")
local Sets = require("./b_sets")
local Mirror = require("./tree/src/shared/Blueprint/Mirror")
local Force = V.Force
local fmt = string.format
local family, shard, nshards = process.args[1], tonumber(process.args[2]), tonumber(process.args[3])
local list = Sets.get(family)
local tested, diffs, designsDiff = 0, 0, 0
local byShape = {}
local function prep(parts)
	local P = table.create(#parts)
	for i, p in ipairs(parts) do
		P[i] = V.Shapes.prepare(p, i)
	end
	return P
end
local function verdict(P)
	Force.FORCE.read, Force.FORCE.fullRead = {}, true
	local ex = Force.exposure(P)
	local read = Force.FORCE.read
	Force.FORCE.read, Force.FORCE.fullRead = nil, nil
	return ex.kept, read
end
for k, d in ipairs(list) do
	if (k - 1) % nshards == shard then
		V.renumber(d.parts)
		local a, ra = verdict(prep(d.parts))
		for _, plane in ipairs({ "X", "Z" }) do
			local m = table.create(#d.parts)
			for i, p in ipairs(d.parts) do
				m[i] = Mirror.reflect(p, plane)
				m[i].id = p.id
			end
			local b, rb = verdict(prep(m))
			tested += 1
			local any = false
			for i = 1, #d.parts do
				if a[i] ~= b[i] then
					diffs += 1
					any = true
					byShape[d.parts[i].shape] = (byShape[d.parts[i].shape] or 0) + 1
					print(fmt("DIFF %s %s part %d %s reads %.4f / %.4f (%s)", family, plane, i, d.parts[i].shape, ra[i] or -1, rb[i] or -1, d.name))
				end
			end
			if any then designsDiff += 1 end
		end
	end
end
local t = {}
for s, c in byShape do
	table.insert(t, s .. " " .. c)
end
print(fmt("SUMMARY %s %d: %d images, %d designs differ, %d parts differ: %s", family, shard, tested, designsDiff, diffs, table.concat(t, ", ")))
