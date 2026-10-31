local Shapes = require("./shapes")
local Gjk = require("./gjk")
local Swords = require("./swords")
local seed = 987654
local function rnd() seed = (seed * 1103515245 + 12345) % 2147483648; return seed / 2147483648 end
local shapes = { "Block", "Wedge", "CornerWedge", "Cylinder", "Ball" }
local function mk(id, sh, pos, q, size) return Shapes.prepare(Shapes.sanitizePart(Swords.part(id, sh, "Blade", "Iron", pos, q, size)), 1) end
local function bruteDist(A, B)
	local xs, ys, zs = Shapes.volumeSamples(A, 0.02, 3, 60, 40000)
	for k = 1, #xs do if Shapes.sd(B, xs[k], ys[k], zs[k]) <= 0 then return 0 end end
	xs, ys, zs = Shapes.volumeSamples(B, 0.02, 3, 60, 40000)
	for k = 1, #xs do if Shapes.sd(A, xs[k], ys[k], zs[k]) <= 0 then return 0 end end
	local SA = Shapes.surfaceSamples(A, 0.004, 600)
	local SB = Shapes.surfaceSamples(B, 0.004, 600)
	local ca, cb = {}, {}
	for k = 1, SA.n do if Shapes.sd(B, SA.x[k], SA.y[k], SA.z[k]) <= 0.03 then table.insert(ca, k) end end
	for k = 1, SB.n do if Shapes.sd(A, SB.x[k], SB.y[k], SB.z[k]) <= 0.03 then table.insert(cb, k) end end
	local best = math.huge
	for _, i in ipairs(ca) do
		for _, j in ipairs(cb) do
			local dx, dy, dz = SA.x[i] - SB.x[j], SA.y[i] - SB.y[j], SA.z[i] - SB.z[j]
			local d = dx*dx + dy*dy + dz*dz
			if d < best then best = d end
		end
	end
	return math.sqrt(best), #ca, #cb
end
local agree, dis, band, its, maxIt = 0, 0, 0, 0, 0
local N = 300
for trial = 1, N do
	local shA, shB = shapes[1 + math.floor(rnd() * 5)], shapes[1 + math.floor(rnd() * 5)]
	local qA = Swords.qAxis(rnd() - 0.5, rnd() - 0.5, rnd() - 0.5, rnd() * 360)
	local qB = Swords.qAxis(rnd() - 0.5, rnd() - 0.5, rnd() - 0.5, rnd() * 360)
	local sA = { 0.08 + rnd() * 0.4, 0.08 + rnd() * 0.4, 0.08 + rnd() * 0.4 }
	local sB = { 0.08 + rnd() * 0.4, 0.08 + rnd() * 0.4, 0.08 + rnd() * 0.4 }
	local A = mk("A", shA, { 0, 1, 0 }, qA, sA)
	local dx, dy, dz = rnd() - 0.5, rnd() - 0.5, rnd() - 0.5
	local n = math.sqrt(dx*dx+dy*dy+dz*dz); dx, dy, dz = dx/n, dy/n, dz/n
	local target = rnd() * 0.03
	local lo, hi, B = 0, 1.5, nil
	for _ = 1, 32 do
		local mid = (lo + hi) / 2
		B = mk("B", shB, { mid * dx, 1 + mid * dy, mid * dz }, qB, sB)
		local _, d = Gjk.within(A, B, 0)
		if d < target then lo = mid else hi = mid end
	end
	local ok, d, it = Gjk.within(A, B, 0.01)
	its += it; maxIt = math.max(maxIt, it)
	local bd = bruteDist(A, B)
	if bd < 0.006 or bd > 0.014 then
		if (bd <= 0.01) == ok then agree += 1 else dis += 1; print(string.format("MISMATCH %s/%s gjk=%s d=%.4f brute=%.4f", shA, shB, tostring(ok), d, bd)) end
	else band += 1 end
end
print(string.format("pairs=%d agree=%d disagree=%d band=%d meanIters=%.2f maxIters=%d", N, agree, dis, band, its / N, maxIt))
