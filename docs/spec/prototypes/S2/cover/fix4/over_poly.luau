--!nocheck
-- V1 (round 4): how far a round model's half-spaces moved out by their sag (n_i·x ≤ d_i + sag_i) stand past the true
-- surface, over all directions: the vertices of the moved-out polytope, by brute force over triples of half-spaces.
local L = require("./lab").tree(require("@lune/process").env.TREE or "now")
local fmt = string.format
local function check(shape, size, rot)
	local P = L.Shapes.prepare(L.part("Blade", shape, { 0, 0, 0 }, rot or L.I, size), 1)
	local m = L.Cover.model(P)
	local pl, sag = m.planes, m.sag
	local np = m.np
	local best, bestAt = -1, nil
	local bestBox = -1
	for a = 1, np do
		for b = a + 1, np do
			for c = b + 1, np do
				local A = { pl[4 * a - 3], pl[4 * a - 2], pl[4 * a - 1] }
				local B = { pl[4 * b - 3], pl[4 * b - 2], pl[4 * b - 1] }
				local C = { pl[4 * c - 3], pl[4 * c - 2], pl[4 * c - 1] }
				local da, db, dc = pl[4 * a] + sag[a], pl[4 * b] + sag[b], pl[4 * c] + sag[c]
				-- solve [A;B;C] x = (da, db, dc) by Cramer's rule
				local bxc = { B[2] * C[3] - B[3] * C[2], B[3] * C[1] - B[1] * C[3], B[1] * C[2] - B[2] * C[1] }
				local det = A[1] * bxc[1] + A[2] * bxc[2] + A[3] * bxc[3]
				if math.abs(det) > 1e-9 then
					local cxa = { C[2] * A[3] - C[3] * A[2], C[3] * A[1] - C[1] * A[3], C[1] * A[2] - C[2] * A[1] }
					local axb = { A[2] * B[3] - A[3] * B[2], A[3] * B[1] - A[1] * B[3], A[1] * B[2] - A[2] * B[1] }
					local x = { (da * bxc[1] + db * cxa[1] + dc * axb[1]) / det, (da * bxc[2] + db * cxa[2] + dc * axb[2]) / det,
						(da * bxc[3] + db * cxa[3] + dc * axb[3]) / det }
					local ok = true
					for i = 1, np do
						if pl[4 * i - 3] * x[1] + pl[4 * i - 2] * x[2] + pl[4 * i - 1] * x[3] > pl[4 * i] + sag[i] + 1e-9 then
							ok = false
							break
						end
					end
					if ok then
						local s = L.Shapes.sd(P, x[1], x[2], x[3])
						if s > best then
							best, bestAt = s, x
						end
						bestBox = math.max(bestBox, math.abs(x[1]) - P.maxx, math.abs(x[2]) - P.maxy, math.abs(x[3]) - P.maxz)
					end
				end
			end
		end
	end
	print(fmt("%s %s: moved-out polytope stands past the true surface by %.5f (= %.4f r) at (%.4f, %.4f, %.4f); past its box by %.5f (= %.4f r); model over %.5f",
		shape, table.concat(size, "x"), best, best / P.r, bestAt[1], bestAt[2], bestAt[3], bestBox, bestBox / P.r, m.over))
end
check("Ball", { 0.6, 0.6, 0.6 })
check("Ball", { 1, 1, 1 })
check("Cylinder", { 1, 0.6, 0.6 })
