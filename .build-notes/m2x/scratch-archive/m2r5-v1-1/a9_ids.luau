--!nocheck
-- C09 + 0.03 on the blade: nothing added, nothing moved, the ids alone.
local V = require("./v1")
local fmt = string.format
local function longer(dl)
	local base = V.fixture("C09")
	for _, i in ipairs({ 12, 13, 14, 15, 16 }) do
		base[i].size = if i == 12 then { base[i].size[1], base[i].size[2] + dl, base[i].size[3] } else { base[i].size[1] + dl, base[i].size[2], base[i].size[3] }
		base[i].pos = { base[i].pos[1], base[i].pos[2] + dl / 2, base[i].pos[3] }
	end
	for _, i in ipairs({ 17, 18 }) do
		base[i].pos = { base[i].pos[1], base[i].pos[2] + dl, base[i].pos[3] }
	end
	return base
end
local base = longer(0.03)
print("as built:", V.dline(V.emu(V.copyParts(base))))
for _, j in ipairs({ 13, 14, 15, 16 }) do
	local p = V.copyParts(base)
	local q = table.remove(p, j)
	table.insert(p, 1, q)
	local ok = V.valid(p)
	print(fmt("part %d first (valid %s): %s", j, tostring(ok), V.dline(V.emu(p))))
end
-- what lifting the budget gives
local P = V.prep(base)
print("cleaned", #V.Sampling.exposure(P).cleaned)
