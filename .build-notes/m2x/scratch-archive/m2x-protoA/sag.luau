-- sagitta of the octahedral grid ball model (unit sphere) per n, and of the N-gon
for _, n in ipairs({ 2, 3, 4, 5, 6, 8, 10, 12, 16, 20, 24 }) do
	local worst = 0
	local area = 0
	local function v(i, j, k) local l = math.sqrt(i * i + j * j + k * k) return { i / l, j / l, k / l } end
	local function tri(a, b, c)
		local A, B, C = v(a[1], a[2], a[3]), v(b[1], b[2], b[3]), v(c[1], c[2], c[3])
		local ux, uy, uz = B[1] - A[1], B[2] - A[2], B[3] - A[3]
		local wx, wy, wz = C[1] - A[1], C[2] - A[2], C[3] - A[3]
		local cx, cy, cz = uy * wz - uz * wy, uz * wx - ux * wz, ux * wy - uy * wx
		local l = math.sqrt(cx * cx + cy * cy + cz * cz)
		local d = math.abs((cx * A[1] + cy * A[2] + cz * A[3]) / l)
		worst = math.max(worst, 1 - d)
		area += l / 2
	end
	for t = 0, n - 1 do
		local top, low = n - t, n - t - 1
		for j = 0, t do
			tri({ top, j, t - j }, { low, j + 1, t - j }, { low, j, t - j + 1 })
			if j < t then tri({ top, j, t - j }, { top, j + 1, t - j - 1 }, { low, j + 1, t - j }) end
		end
	end
	print(string.format("ball n %2d facets %5d sagitta/r %.6f area ratio %.5f  r for sag 0.002: %.3f", n, 8 * n * n, worst, 8 * area / (4 * math.pi), 0.002 / worst))
end
for _, N in ipairs({ 32, 64, 128, 256 }) do
	local s = 1 - math.cos(math.pi / N)
	print(string.format("cyl N %3d sagitta/r %.7f  r for sag 0.002: %.3f", N, s, 0.002 / s))
end
