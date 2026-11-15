--!nocheck
-- m2x-fix-3: a Wedge (sx, sy, sz) and the same solid as (sx, sz, sy) half turned about its local (0, 1, −1): Shapes' volumes,
-- the world vertices, the rank; and the other shapes' writings of one solid (a Block's 24, a Cylinder's radius, a Ball's)
local Lab = require("./lab")
local N = Lab.tree("now")
local B = Lab.tree("base")
local fmt = string.format
local S = 0.70710678118654757
local half = { 0, S, -S, 0 } -- a half turn about (0, 1, −1)/√2
local function wedges(T, size, rot)
	local a = T.part("Blade", "Wedge", { 0, 1, 0 }, rot, size)
	local b = T.part("Guard", "Wedge", { 0, 1, 0 }, T.Quat.hemisphere(T.Quat.normalize(T.Quat.mul(rot, half))), { size[1], size[3], size[2] })
	return a, b
end
-- the candidates of Verdict.spec's Block (0.0231, 0.37, 0.0388) and a few
for _, size in ipairs({ { 0.37, 0.0231, 0.0388 }, { 0.37, 0.0388, 0.0231 }, { 0.3, 0.07, 0.035 }, { 0.035, 0.3, 0.07 }, { 0.12, 0.09, 0.05 } }) do
	local a, b = wedges(N, size, N.I)
	local Pa, Pb = N.Shapes.prepare(a, 1), N.Shapes.prepare(b, 2)
	local same = true
	local va, vb = {}, {}
	for k = 1, #Pa.wverts, 3 do
		table.insert(va, fmt("%.17g,%.17g,%.17g", Pa.wverts[k], Pa.wverts[k + 1], Pa.wverts[k + 2]))
		table.insert(vb, fmt("%.17g,%.17g,%.17g", Pb.wverts[k], Pb.wverts[k + 1], Pb.wverts[k + 2]))
	end
	table.sort(va)
	table.sort(vb)
	for k = 1, #va do
		same = same and va[k] == vb[k]
	end
	local _, ob = B.Sampling.ranked(B.prep({ a, b }))
	local _, on = N.Sampling.ranked(N.prep({ a, b }))
	print(fmt("Wedge %s: volumes %.17g / %.17g (%s), vertex sets %s; first in the rank: base part %d, build part %d", table.concat(size, " x "),
		Pa.volume, Pb.volume, if Pa.volume == Pb.volume then "equal" elseif Pa.volume < Pb.volume then "the copy larger" else "the copy smaller",
		if same then "bit-identical" else "differ", ob[1].index, on[1].index))
end
-- how often over random sizes
local rng = 12345
local function rand()
	rng = (rng * 1103515245 + 12345) % 2147483648
	return rng / 2147483648
end
local larger, smaller = 0, 0
for _ = 1, 10000 do
	local size = { 0.02 + 2 * rand(), 0.02 + 2 * rand(), 0.02 + 2 * rand() }
	local a, b = wedges(N, size, N.I)
	local va, vb = N.Shapes.prepare(a, 1).volume, N.Shapes.prepare(b, 2).volume
	if vb > va then
		larger += 1
	elseif vb < va then
		smaller += 1
	end
end
print(fmt("10,000 random Wedges: the other writing's Shapes volume larger %d, smaller %d", larger, smaller))
