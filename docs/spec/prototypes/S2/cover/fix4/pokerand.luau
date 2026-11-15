--!nocheck
-- fix-4: the circle's price, beyond V1's radial pokes: Blocks of random size (0.03–0.3) and turn whose farthest corner
-- stands p out of a Ball r's true sphere (p from 0.0001 r to 0.006 r, about the 32-gon's over through the centre), in a
-- random direction: their faces that cross the sphere near its centre plane are buried up to the 32-gon's over. Per
-- tree, how many that truly show 2 % or more are cleaned (and the largest such true share), how many truly under 2 % are
-- kept; the truth (VisibleOracle) on the last tree.
--   lune run pokerand -- <r> <count> <seed> <tree> [<tree> ...]
local process = require("@lune/process")
local V = require("./vlab")
local fmt = string.format
local R, COUNT, SEED = tonumber(process.args[1]), tonumber(process.args[2]), tonumber(process.args[3])
local names = {}
for i = 4, #process.args do
	table.insert(names, process.args[i])
end
local T = {}
for i, n in ipairs(names) do
	T[i] = V.tree(n)
end
local N = T[#T]
local TestRng = require(N.root .. "/tests/lib/TestRng")
local rng = TestRng.new(SEED)
local C = { 0, 1, 0 }
local stat = {}
for i = 1, #T do
	stat[i] = { wrong = 0, worst = 0, what = "", keptLow = 0 }
end
local truthRuns, tried = 0, 0
for n = 1, COUNT do
	local s = { rng:range(0.03, 0.3), rng:range(0.03, 0.3), rng:range(0.03, 0.3) }
	if s[1] * s[2] * s[3] >= 0.0002 then
		tried += 1
		local q = N.H.randomQuat(rng)
		local x, y, z = rng:normal(0, 1), rng:normal(0, 1), rng:normal(0, 1)
		local l = math.sqrt(x * x + y * y + z * z)
		local d = { x / l, y / l, z / l }
		local p = R * rng:range(0.0001, 0.006)
		-- the centre along d where the farthest corner stands R + p from C (bisection; the farthest is a corner)
		local P0 = N.Shapes.prepare(N.part("Blade", "Block", { 0, 0, 0 }, q, s), 1)
		local function far(k)
			local best = 0
			for j = 1, #P0.wverts, 3 do
				local vx, vy, vz = P0.wverts[j] + k * d[1], P0.wverts[j + 1] + k * d[2], P0.wverts[j + 2] + k * d[3]
				best = math.max(best, vx * vx + vy * vy + vz * vz)
			end
			return math.sqrt(best)
		end
		local lo, hi = 0, R + 1
		for _ = 1, 80 do
			local k = (lo + hi) / 2
			if far(k) <= R + p then
				lo = k
			else
				hi = k
			end
		end
		local parts = N.copy({
			N.part("Pommel", "Ball", C, nil, { 2 * R, 2 * R, 2 * R }),
			N.part("Blade", "Block", { C[1] + lo * d[1], C[2] + lo * d[2], C[3] + lo * d[3] }, q, s),
		})
		local reads = {}
		local close = true
		for i, L in ipairs(T) do
			reads[i] = L.H.reads(L.prep(parts), 2)
		end
		if close then
			truthRuns += 1
			local P = N.prep(parts)
			local _, _, hider = N.Oracle.flags(P)
			local truth = N.Oracle.share(P, 2, hider)
			for i = 1, #T do
				local st = stat[i]
				if reads[i] < 0.02 and truth >= 0.02 then
					st.wrong += 1
					if truth > st.worst then
						st.worst, st.what = truth, fmt("#%d Block %.3f × %.3f × %.3f, its corner %.5f out (%.4f r): reads %.3f%%, truth %.3f%%", n, s[1], s[2], s[3], p, p / R, 100 * reads[i], 100 * truth)
					end
				elseif reads[i] >= 0.02 and truth < 0.02 then
					st.keptLow += 1
				end
			end
		end
	end
end
for i, n in ipairs(names) do
	local st = stat[i]
	print(fmt("%s, Ball r %.2f, seed %d: %d Blocks, %d read near 2 %% and checked against the truth; %d cleaned that truly show 2 %% or more, %d kept truly under 2 %%",
		n, R, SEED, tried, truthRuns, st.wrong, st.keptLow))
	if st.wrong > 0 then
		print("  the largest true share cleaned: " .. st.what)
	end
end
