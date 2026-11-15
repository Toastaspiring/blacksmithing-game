--!nocheck
-- V1 (m2x, round 5): Cylinders wholly inside one Cylinder at every tilt. Host Q: r R along Z (LEN long) or along Y; a rod
-- P (r ρ, 2·hx long) turned θ off Q's axis, spun about Q's axis by β, its farthest true point m under Q's surface (by
-- bisection on its offset from Q's axis along a random radial direction, the farthest point from Q's true solid taken on
-- 720 points of each cap rim). The truth reads 0 for every one; how many does the build keep, and the most it reads.
--   lune run rodtilt -- <seed> <count> [tree: repo|fix]
local process = require("@lune/process")
local L = require("./lib")
local TestRng = require("./repo/tests/lib/TestRng")
local fmt = string.format
local rng = TestRng.new(tonumber(process.args[1]) or 1)
local COUNT = tonumber(process.args[2]) or 500
local Cover = L.Cover
if process.args[3] == "fix" then
	Cover = require("./fixA/src/shared/Physics/Cover")
end
local Shapes = L.Shapes

-- the farthest true point of P's solid from Q's: the cap rims (a Cylinder's farthest points from a convex solid lie on them)
local function farthestTrue(P, Q)
	local best = -math.huge
	for s = -1, 1, 2 do
		for k = 0, 719 do
			local t = 2 * math.pi * k / 720
			local c, si = math.cos(t), math.sin(t)
			local x = P.cx + s * P.hx * P.ux + P.r * (c * P.vx + si * P.wx)
			local y = P.cy + s * P.hx * P.uy + P.r * (c * P.vy + si * P.wy)
			local z = P.cz + s * P.hx * P.uz + P.r * (c * P.vz + si * P.wz)
			best = math.max(best, Shapes.sd(Q, x, y, z))
		end
	end
	return best
end

local function readOf(P, i)
	local models = {}
	for j = 1, #P do
		models[j] = Cover.model(P[j])
	end
	local rank, order = L.Sampling.ranked(P)
	local hm, higher = {}, {}
	for r = 1, #order do
		local j = order[r].index
		if j ~= i then
			table.insert(hm, models[j])
			table.insert(higher, r < rank[i])
		end
	end
	local shown = Cover.shown(models[i], hm, higher, math.huge, math.huge)
	return shown / models[i].total
end

local byTilt = {}
local keptN, total, worst, wpar = 0, 0, 0, nil
for _ = 1, COUNT do
	local R = rng:pick({ 0.1, 0.2, 0.3, 0.5, 0.8 })
	local LEN = rng:pick({ 0.3, 0.5, 1.0, 2.0 * R })
	local axis = rng:pick({ "Z", "Y" })
	local Qrot = if axis == "Z" then L.Y90 else L.Z90 -- local X onto world Z (Y90) or world Y (Z90)
	local C = { 0, 2, 0 }
	local rho = math.max(0.02, R * rng:range(0.05, 0.4))
	local hx = math.max(0.01, R * rng:range(0.05, 0.6))
	local theta = rng:pick({ 2, 5, 15, 30, 45, 60, 75, 89, 90, rng:range(0, 90) })
	local m = rng:pick({ 2e-7, 1e-6, 1e-5, 3e-5, 1e-4, 3e-4, 1e-3 })
	-- Q's axis u, a radial direction w square to it, and P's axis turned θ from u toward w × u (along the rim) or w
	local u = if axis == "Z" then { 0, 0, 1 } else { 0, 1, 0 }
	local beta = rng:range(0, 2 * math.pi)
	local e1 = if axis == "Z" then { 1, 0, 0 } else { 1, 0, 0 }
	local e2 = { u[2] * e1[3] - u[3] * e1[2], u[3] * e1[1] - u[1] * e1[3], u[1] * e1[2] - u[2] * e1[1] }
	local w = { math.cos(beta) * e1[1] + math.sin(beta) * e2[1], math.cos(beta) * e1[2] + math.sin(beta) * e2[2], math.cos(beta) * e1[3] + math.sin(beta) * e2[3] }
	local t = { u[2] * w[3] - u[3] * w[2], u[3] * w[1] - u[1] * w[3], u[1] * w[2] - u[2] * w[1] }
	local towardT = rng:float() < 0.6
	local b = if towardT then t else w
	local th = math.rad(theta)
	local a = { math.cos(th) * u[1] + math.sin(th) * b[1], math.cos(th) * u[2] + math.sin(th) * b[2], math.cos(th) * u[3] + math.sin(th) * b[3] }
	-- the rod's quaternion: local X onto a, spun at random
	local ax, ay, az = 0, -a[3], a[2]
	local s = math.sqrt(ay * ay + az * az)
	local q = if s < 1e-12 then L.I else L.axisAngle(ax, ay, az, math.deg(math.atan2(s, a[1])))
	q = L.Quat.hemisphere(L.Quat.normalize(L.Quat.mul(q, L.axisAngle(1, 0, 0, rng:range(0, 180)))))
	local along = rng:range(-0.5, 0.5) * math.max(0, LEN / 2 - hx)
	local Q = L.part("Guard", "Cylinder", C, Qrot, { LEN, 2 * R, 2 * R })
	local QP = Shapes.prepare(Q, 1)
	-- bisection on the offset k along w for farthestTrue = −m
	local function at(k)
		return L.part("Blade", "Cylinder", { C[1] + along * u[1] + k * w[1], C[2] + along * u[2] + k * w[2], C[3] + along * u[3] + k * w[3] }, q,
			{ 2 * hx, 2 * rho, 2 * rho })
	end
	local lo, hi = 0, R
	if farthestTrue(Shapes.prepare(at(0), 2), QP) < -m then
		for _ = 1, 60 do
			local mid = (lo + hi) / 2
			if farthestTrue(Shapes.prepare(at(mid), 2), QP) < -m then
				lo = mid
			else
				hi = mid
			end
		end
		local parts = L.renumber({ Q, at(lo) })
		local P = L.prep(parts)
		if P[2].volume >= L.Geo.MIN_PART_VOLUME then
			local r = readOf(P, 2)
			total += 1
			local key = fmt("%2d", math.floor(theta / 15 + 0.5) * 15)
			byTilt[key] = byTilt[key] or { n = 0, kept = 0, worst = 0 }
			byTilt[key].n += 1
			if r >= 0.02 then
				keptN += 1
				byTilt[key].kept += 1
			end
			byTilt[key].worst = math.max(byTilt[key].worst, r)
			if r > worst then
				worst, wpar = r, parts
			end
		end
	end
end
local keys = {}
for k in byTilt do
	table.insert(keys, k)
end
table.sort(keys)
for _, k in ipairs(keys) do
	local v = byTilt[k]
	print(fmt("tilt ~%s°: %4d rods, %3d kept, the most %.3f%%", k, v.n, v.kept, 100 * v.worst))
end
print(fmt("%d rods wholly inside one Cylinder (truly 0): %d kept, the most %.3f%%", total, keptN, 100 * worst))
if wpar then
	print(require("@lune/serde").encode("json", wpar))
end
