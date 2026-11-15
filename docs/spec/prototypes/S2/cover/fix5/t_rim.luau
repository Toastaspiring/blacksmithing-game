--!nocheck
-- m2x-fix-5: Lune ns a call, median of 15 rounds: a cap circle's search (rim.luau's, 60 halvings), the two bounds of one
-- cap, the old bound of one cap, V1's verbatim search; and a unit's ns on this machine: the base's verdict (SamplingV) on
-- V1's cluster over its units. Every round runs each kind over the same 4,000 random tilted circles.
--   lune run t_rim -- [rounds]
local process = require("@lune/process")
local W = "C:/Users/louis/AppData/Local/Temp/claude/C--Users-louis-Documents-RANDOM-ROBLOX/93ae48b4-72b9-4dc1-aa5d-451af1abf9a0/scratchpad/m2x-fix-5"
local function req(p)
	return (require :: any)(p)
end
local TestRng = req(W .. "/base/tests/lib/TestRng")
local Shapes = req(W .. "/base/src/shared/Physics/Shapes")
local SV = req(W .. "/base/src/shared/Physics/SamplingV")
local Worst = req(W .. "/base/docs/spec/prototypes/S2/cover/worst_designs")
local R = require("./rim")
local fmt = string.format
local sqrt = math.sqrt
local ROUNDS = tonumber(process.args[1]) or 15
local rng = TestRng.new(5)
local N = 4000
local C = {}
local function unit(x, y, z)
	local l = sqrt(x * x + y * y + z * z)
	return x / l, y / l, z / l
end
for k = 1, N do
	local ux, uy, uz = unit(rng:normal(0, 1), rng:normal(0, 1), rng:normal(0, 1))
	local nx, ny, nz = unit(rng:normal(0, 1), rng:normal(0, 1), rng:normal(0, 1))
	local vx, vy, vz = unit(ny * 0.3 - nz * 0.7, nz * 0.1 - nx * 0.3, nx * 0.7 - ny * 0.1)
	local wx, wy, wz = ny * vz - nz * vy, nz * vx - nx * vz, nx * vy - ny * vx
	local mx, my, mz = rng:range(-1, 1), rng:range(-1, 1), rng:range(-1, 1)
	local t = mx * ux + my * uy + mz * uz
	C[k] = { mx - t * ux, my - t * uy, mz - t * uz, rng:range(0.01, 0.5), nx, ny, nz, ux, uy, uz, vx, vy, vz, wx, wy, wz, mx, my, mz }
end
local kinds = {
	search = function(c)
		return R.search(c[1], c[2], c[3], c[4], c[5], c[6], c[7], c[8], c[9], c[10], 1e-8)
	end,
	bounds = function(c)
		return R.bounds(c[1], c[2], c[3], c[4], c[11], c[12], c[13], c[14], c[15], c[16], c[8], c[9], c[10])
	end,
	old = function(c)
		return R.old(c[1], c[2], c[3], c[4])
	end,
	v1 = function(c)
		return R.v1(c[17], c[18], c[19], c[4], c[5], c[6], c[7], c[8], c[9], c[10])
	end,
	empty = function(c)
		return c[1]
	end,
}
local order = { "empty", "old", "bounds", "search", "v1" }
local times = {}
for _, k in ipairs(order) do
	times[k] = {}
end
local cluster = Worst.valid[1]
local P = {}
for i, p in ipairs(cluster.parts) do
	P[i] = Shapes.prepare(p, i)
end
local units = SV.exposure(P).verdictWork
local unitNs = {}
for _ = 1, ROUNDS do
	for _, k in ipairs(order) do
		local f = kinds[k]
		local t0 = os.clock()
		local s = 0
		for i = 1, N do
			s += f(C[i])
		end
		table.insert(times[k], (os.clock() - t0) / N * 1e9)
	end
	local t0 = os.clock()
	SV.exposure(P)
	table.insert(unitNs, (os.clock() - t0) / units * 1e9)
end
local function median(t)
	table.sort(t)
	return t[(#t + 1) // 2]
end
local e = median(times.empty)
for _, k in ipairs(order) do
	print(fmt("%-7s %8.1f ns a call (%8.1f past the loop's own)", k, median(times[k]), median(times[k]) - e))
end
print(fmt("the base's verdict on V1's cluster: %.1f units, %.2f ns a unit", units, median(unitNs)))
