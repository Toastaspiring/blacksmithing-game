--!strict
local n = 0
for line in string.gmatch("a\nb\n\nc", "[^\n]*") do n += 1 end
print("gmatch matches for 4 lines:", n, " string.split:", #string.split("a\nb\n\nc", "\n"))
local P = require("../repo/src/shared/Physics/ProtoShapes")
local TestRng = require("../repo/tests/lib/TestRng")
local rng = TestRng.new(5)
for _, shape in { "Block", "Wedge", "CornerWedge", "Cylinder", "Ball" } do
	local part = { slot = "", shape = shape, material = "", pos = { 0, 0, 0 }, rot = { 0, 0, 0, 1 }, size = { 0.6, 0.9, 0.4 } }
	if shape == "Ball" then part.size = { 0.5, 0.5, 0.5 } end
	local hx, hy, hz = part.size[1] / 2, part.size[2] / 2, part.size[3] / 2
	local N, inside, sx, sy, sz = 400000, 0, 0, 0, 0
	for _ = 1, N do
		local x, y, z = rng:range(-hx, hx), rng:range(-hy, hy), rng:range(-hz, hz)
		if P.insideLocal(shape, hx, hy, hz, x, y, z) then inside += 1; sx += x; sy += y; sz += z end
	end
	local vMC = inside / N * 8 * hx * hy * hz
	local c = P.localCentroid(part)
	print(string.format("%-11s V exact %.5f MC %.5f | centroid exact (%.4f, %.4f, %.4f) MC (%.4f, %.4f, %.4f)",
		shape, P.analyticVolume(part), vMC, c[1], c[2], c[3], sx / inside, sy / inside, sz / inside))
end
