--!nocheck
-- m2x-fix-5: the Ball circle's price as the verifiers' climbs found it, reproduced on the build: each climb's top part
-- (exact literals from their logs: V2's mybrute.luau price/price2, out/price_03.txt, price2_03.txt, price_other_r.txt; V1's
-- pokeball.luau, out/pokeball_*.txt) against its Ball alone (a Ball r R at (0, 2, 0) in the Pommel, the part in the
-- Blade): Sampling's verdict, the part's reading, and the truth (VisibleOracle on 400,000 points).
--   lune run ballprice -- [tree root]
local process = require("@lune/process")
local W = "C:/Users/louis/AppData/Local/Temp/claude/C--Users-louis-Documents-RANDOM-ROBLOX/93ae48b4-72b9-4dc1-aa5d-451af1abf9a0/scratchpad/m2x-fix-5"
local root = process.args[1] or "C:/Users/louis/Documents/RANDOM/ROBLOX/Blacksmithing Game"
local function req(p)
	return (require :: any)(root .. "/" .. p)
end
local Shapes = req("src/shared/Physics/Shapes")
local Sampling = req("src/shared/Physics/Sampling")
local Cover = req("src/shared/Physics/Cover")
local Oracle = req("tests/Physics/VisibleOracle")
local fmt = string.format

local cases = {
	{ "V2 price R 0.3 seed 42", 0.3, "Block", { 0.20778034860254257, 1.8425578791016439, 0.061472998279941876 },
		{ 0.51606779855103435, -0.09609294124329168, -0.46862904089058421, 0.71051178454398167 },
		{ 0.036508539493374161, 0.059156176690495769, 0.093266196882164976 } },
	{ "V2 price R 0.3 seed 41", 0.3, "Block", { 0.012987149554672759, 2.2380479600926235, -0.11647859269687337 },
		{ 0.40201361236010308, 0.8157966171381702, -0.013744265912893891, 0.41553824143827539 },
		{ 0.060910671041887673, 0.034508149955565046, 0.096289830979670865 } },
	{ "V2 price2 R 0.3 Block", 0.3, "Block", { -0.23721534618403176, 1.8931284491438161, 0.038682714961424239 },
		{ -0.77983758009639315, -0.50903166595678795, -0.0074894998369440134, 0.36425817645572639 },
		{ 0.078805858559862316, 0.026050901791738097, 0.10079398803588263 } },
	{ "V2 price2 R 0.3 Wedge", 0.3, "Wedge", { 0.22725364721919941, 1.923311098641078, -0.029162703607990986 },
		{ 0.17268380983475107, -0.67442660130205478, 0.010258807876812914, 0.71779092926705446 },
		{ 0.068809383560149776, 0.1384970730364205, 0.046785487417480072 } },
	{ "V2 price2 R 0.3 CornerWedge", 0.3, "CornerWedge", { 0.20732856203443528, 2.0171528903810017, 0.13235824078751304 },
		{ 0.4583819220445145, -0.34979419428430547, 0.39959296097433716, 0.71263981135460841 },
		{ 0.067481947687470095, 0.093022574486313889, 0.099069213186836758 } },
	{ "V2 price R 0.2 seed 43", 0.2, "Block", { -0.037878075850569411, 1.9261104828215443, -0.14128449283635244 },
		{ -0.5994279992710857, -0.034923769880061864, 0.7995771610573652, 0.011948535586930511 },
		{ 0.056845867968749353, 0.048474783037574111, 0.073611714233737094 } },
	{ "V2 price R 1 seed 43", 1, "Block", { -0.5773876471012781, 2.776277997046269, -0.11090826989534236 },
		{ 0.09166445317835914, 0.61031316157789872, 0.57352837860221095, 0.53868420411797979 },
		{ 0.036135439258713049, 0.04973246141111351, 0.11180907574351671 } },
	{ "V2 price R 3 seed 43", 3, "Block", { -2.4197521751677757, 2.9310754181332479, -1.4629664102640483 },
		{ -0.21296106373271886, 0.91703670310199215, 0.073046564439388992, 0.3291739204755747 },
		{ 0.050836745026814109, 0.028139734724989381, 0.14101357303651063 } },
	{ "V1 pokeball R 0.3 s2", 0.3, "CornerWedge", { 0.08418442572811075, 2.134589939576445, 0.14347482002586803 },
		{ -0.21938947037765114, 0.6543882339134626, -0.3557057683634665, 0.6301727588177618 },
		{ 0.18432830005884168, 0.06788605639130012, 0.05169890236109495 } },
	{ "V1 pokeball R 0.2 s4", 0.2, "Wedge", { 0.05815108269819935, 1.9890180074802586, -0.05813814789058841 },
		{ 0.6440344683297796, 0.6232770520797973, 0.16696252722001115, 0.4109365333700604 },
		{ 0.03336679876782, 0.054942996669560665, 0.23329601246863602 } },
	{ "V1 pokeball R 3 s7", 3, "CornerWedge", { 1.2642816854907282, 4.273684662047819, 1.491952985956012 },
		{ 0.05107723353521342, 0.7864113473293551, -0.2548986384981817, 0.5603347152352698 },
		{ 0.14044393274001776, 0.21163415836930624, 0.02061274381135844 } },
}
for _, c in ipairs(cases) do
	local R = c[2]
	local parts = {
		{ id = 1, shape = "Ball", slot = "Pommel", material = "Iron", pos = { 0, 2, 0 }, rot = { 0, 0, 0, 1 }, size = { 2 * R, 2 * R, 2 * R } },
		{ id = 2, shape = c[3], slot = "Blade", material = "Iron", pos = c[4], rot = c[5], size = c[6] },
	}
	local P = { Shapes.prepare(parts[1], 1), Shapes.prepare(parts[2], 2) }
	local m1, m2 = Cover.model(P[1]), Cover.model(P[2])
	local reads = Cover.shown(m2, { m1 }, { true }, math.huge, math.huge) / m2.total
	local kept = Sampling.exposure(P).kept[2]
	local _, _, hider = Oracle.flags(P)
	local truth = Oracle.measure(P, 2, hider, 400000)
	print(fmt("%-30s %-11s %.4f × %.4f × %.4f (%.6f stud³): reads %.4f %%, %s; truly %.4f %%", c[1], c[3], c[6][1], c[6][2], c[6][3],
		P[2].volume, 100 * reads, if kept then "kept" else "cleaned", 100 * truth))
end
