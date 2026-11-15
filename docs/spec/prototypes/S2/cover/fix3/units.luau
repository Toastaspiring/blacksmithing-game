--!nocheck
-- m2x-fix-3: the verdict's units of the pinned designs and worst_designs.luau, on the base and the build
local Lab = require("./lab")
local fmt = string.format
local W = Lab.SCR .. "/m2x-fix-3/"
local trees = { Lab.tree("base"), Lab.tree(W .. "var_AB"), Lab.tree(W .. "var_ABA"), Lab.tree("now") }
local N = trees[4]
local Worst = (require :: any)(N.root .. "/docs/spec/prototypes/S2/cover/worst_designs")
local Attacks = (require :: any)(N.root .. "/tests/Physics/CoverAttacks")
local H = (require :: any)(N.root .. "/tests/Physics/PhysicsHelpers")
local designs = { { "P1", H.p1().parts }, { "C09", H.ornate().parts }, { "F3", N.Blueprints.core("F3").parts },
	{ "F5", N.Blueprints.core("F5").parts }, { "attack 3 " .. Attacks[3].name, Attacks[3].parts }, { "attack 15 " .. Attacks[15].name, Attacks[15].parts } }
for _, perf in ipairs(N.Fx.perf()) do
	if perf.parts then
		table.insert(designs, { string.sub(perf.name, 1, 2), perf.parts })
	end
end
for _, d in ipairs(Worst.valid) do
	table.insert(designs, { "valid " .. d.name, d.parts, d.units })
end
for _, d in ipairs(Worst.tooComplex) do
	table.insert(designs, { "tooComplex " .. d.name, d.parts, d.units })
end
for _, d in ipairs(designs) do
	local row = {}
	for t, T in ipairs(trees) do
		local e = T.Sampling.exposure(T.prep(d[2]))
		row[t] = fmt("%12.3f%s", e.verdictWork, if e.capped then "C" else " ")
	end
	print(fmt("%-44s %s %s %s %s", string.sub(d[1], 1, 44), row[1], row[2], row[3], row[4]))
end
