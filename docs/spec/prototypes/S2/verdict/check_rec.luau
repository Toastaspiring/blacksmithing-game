--!nocheck
-- m2r5: the recommended file against the parametric variant P, on every set: the same kept row, the same reading, the same measure.
local Param = require("./tree/src/shared/Physics/Sampling")
local Rec = require("./rec/src/shared/Physics/Sampling")
local Shapes = require("./tree/src/shared/Physics/Shapes")
local Sets = require("./sets")
local V = require("./variants")
local fmt = string.format
V.apply(Param, "P")
local bad, n, parts = 0, 0, 0
for _, name in ipairs({ "fixtures", "poke", "fuzz", "plausible" }) do
	local list = Sets.get(name)
	for k, d in ipairs(list) do
		local P = table.create(#d.parts)
		for i, p in ipairs(d.parts) do P[i] = Shapes.prepare(p, i) end
		local a, b = Param.exposure(P), Rec.exposure(P)
		n += 1
		for i = 1, #P do
			parts += 1
			if a.kept[i] ~= b.kept[i] or a.visibleArea[i] ~= b.visibleArea[i] or a.exposedKept[i] ~= b.exposedKept[i] then
				bad += 1
				if bad <= 20 then print("DIFF", d.name, i, a.kept[i], b.kept[i], a.visibleArea[i], b.visibleArea[i], a.exposedKept[i], b.exposedKept[i]) end
			end
			for j = 1, #P do
				if a.contact[i][j] ~= b.contact[i][j] then
					bad += 1
				end
			end
		end
		if a.hKept ~= b.hKept or a.surfSamples ~= b.surfSamples or a.subSampled ~= b.subSampled then
			bad += 1
			if bad <= 20 then print("DIFF budget", d.name) end
		end
	end
	print(name, "so far", n, "designs", parts, "parts", bad, "differences")
end
print(fmt("rec vs P: %d designs, %d parts, %d differences", n, parts, bad))
