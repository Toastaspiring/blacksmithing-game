--!nocheck
-- fix-4: V1's poke_sweep.luau (m2x-v1-4) on named trees: Blocks a × len × a poking p out of a Ball r along directions
-- near the moved-out polytope's highest vertices, and at the pole; per tree, how many that truly show 2 % or more are
-- cleaned, the largest such true share, and the farthest out still read 0. The truth once (VisibleOracle).
--   lune run poke -- <r> <tree> [<tree> ...]
local process = require("@lune/process")
local V = require("./vlab")
local fmt = string.format
local R = tonumber(process.args[1]) or 0.3
local names = {}
for i = 2, #process.args do
	table.insert(names, process.args[i])
end
local T = {}
for i, n in ipairs(names) do
	T[i] = V.tree(n)
end
local N = T[#T]

local function unit(x, y, z)
	local l = math.sqrt(x * x + y * y + z * z)
	return { x / l, y / l, z / l }
end
local function rotTo(d)
	local ax, az = d[3], -d[1]
	if math.abs(ax) + math.abs(az) < 1e-12 then
		return if d[2] > 0 then { 0, 0, 0, 1 } else N.H.axisAngle(1, 0, 0, 180)
	end
	return N.H.axisAngle(ax, 0, az, math.deg(math.acos(d[2])))
end

local C = { 0, 1, 0 }
local DIRS = {
	{ "pole", { 0, 1, 0 } },
	{ "vertex", unit(0.1353, 0.1353, -0.2484) },
	{ "vertex'", unit(0.2484, 0.1353, 0.1353) },
	{ "near vertex", unit(0.15, 0.13, -0.245) },
}
local count = 0
local stat = {}
for i = 1, #T do
	stat[i] = { wrong = 0, worst = 0, worstWhat = "", deepest = 0, deepestWhat = "", keptLow = 0 }
end
for _, dd in ipairs(DIRS) do
	local d = dd[2]
	for _, a in ipairs({ 0.03, 0.04, 0.05, 0.06, 0.07, 0.08, 0.1 }) do
		for _, len in ipairs({ 0.1, 0.2 }) do
			if a * a * len >= 0.0002 then
				for _, frac in ipairs({ 0.002, 0.005, 0.01, 0.015, 0.02, 0.026, 0.03, 0.035, 0.04, 0.045 }) do
					local p = frac * R
					local k = R + p - len / 2
					local parts = N.copy({
						N.part("Pommel", "Ball", C, nil, { 2 * R, 2 * R, 2 * R }),
						N.part("Blade", "Block", { C[1] + k * d[1], C[2] + k * d[2], C[3] + k * d[3] }, rotTo(d), { a, len, a }),
					})
					count += 1
					local truth = nil
					for i, L in ipairs(T) do
						local P = L.prep(parts)
						local read = L.H.reads(P, 2)
						if truth == nil then
							local _, _, hider = N.Oracle.flags(N.prep(parts))
							truth = N.Oracle.share(N.prep(parts), 2, hider)
						end
						local s = stat[i]
						if read < 0.02 and truth >= 0.02 then
							s.wrong += 1
							if truth > s.worst then
								s.worst, s.worstWhat = truth, fmt("%s, Block %.2f × %.2f × %.2f, %.5f out (%.3f r): reads %.3f%%, truth %.3f%%", dd[1], a, len, a, p, frac, 100 * read, 100 * truth)
							end
							if read < 1e-6 and frac > s.deepest then
								s.deepest, s.deepestWhat = frac, fmt("%s, Block %.2f × %.2f × %.2f, %.5f out: reads %.4f%%, truth %.3f%%", dd[1], a, len, a, p, 100 * read, 100 * truth)
							end
						elseif read >= 0.02 and truth < 0.02 then
							s.keptLow += 1
						end
					end
				end
			end
		end
	end
end
for i, n in ipairs(names) do
	local s = stat[i]
	print(fmt("%s, Ball r %.2f: %d Blocks poked out, %d cleaned that truly show 2 %% or more, %d kept that truly show under 2 %%", n, R, count, s.wrong, s.keptLow))
	print("  the largest true share cleaned: " .. s.worstWhat)
	print(fmt("  the farthest out still read 0: %.3f r: %s", s.deepest, s.deepestWhat))
end
