--!nocheck
-- m2x-fix-5: V1's rodtilt.luau rods (its draws, seed by seed) and rodrim.luau's tangent rods and pucks, on the build,
-- the always-exact rule and the tree before: per rod its exact farthest point out of the host (along its axis the
-- support, across it each cap circle's farthest point by the 50-digit-checked search, m⊥ by its parts), rule A's
-- decision on the build and on the always-exact rule (both ranks), the caps the build's bounds leave open, and the
-- reading of the build and of the tree before (whole, against the host alone).
--   lune run rods5 -- tilt <seed> <count>     V1's rodtilt draws
--   lune run rods5 -- rim <R> <len>           V1's rodrim sweep (ρ 0.02–0.1, hx 0.05–0.3, α 30–41.25°, m 2e-7–5e-4)
local process = require("@lune/process")
local W = "C:/Users/louis/AppData/Local/Temp/claude/C--Users-louis-Documents-RANDOM-ROBLOX/93ae48b4-72b9-4dc1-aa5d-451af1abf9a0/scratchpad/m2x-fix-5"
local function req(p)
	return (require :: any)(p)
end
local Shapes = req(W .. "/hook/src/shared/Physics/Shapes")
local Sampling = req(W .. "/hook/src/shared/Physics/Sampling")
local Build = req(W .. "/hook/src/shared/Physics/Cover")
local Exact = req(W .. "/exact/src/shared/Physics/Cover")
local Old = req(W .. "/base/src/shared/Physics/Cover")
local OShapes = req(W .. "/base/src/shared/Physics/Shapes")
local Quat = req(W .. "/hook/src/shared/Blueprint/Quat")
local TestRng = req(W .. "/hook/tests/lib/TestRng")
local Geo = req(W .. "/hook/src/shared/Definitions/Balance").Geometry
local R5 = require("./rim")
local fmt = string.format
local sqrt, abs, max = math.sqrt, math.abs, math.max
local mode = process.args[1] or "tilt"

local I = { 0, 0, 0, 1 }
local S45 = 0.70710678118654757
local Z90, Y90 = { 0, 0, S45, S45 }, { 0, S45, 0, S45 }
local function axisAngle(ax, ay, az, deg)
	local h = math.rad(deg) / 2
	local n = math.sqrt(ax * ax + ay * ay + az * az)
	return Quat.hemisphere(Quat.normalize({ ax / n * math.sin(h), ay / n * math.sin(h), az / n * math.sin(h), math.cos(h) }))
end
local function part(slot, shape, pos, rot, size)
	return { id = 0, label = shape, shape = shape, slot = slot, material = "Iron", pos = { pos[1], pos[2], pos[3] }, rot = rot or I,
		size = { size[1], size[2], size[3] } }
end

-- the exact largest signed distance of Cylinder P's solid from Cylinder Q's (max of along and across)
local function exactS(P, Q)
	local ux, uy, uz = Q.ux, Q.uy, Q.uz
	local dx, dy, dz = P.cx - Q.cx, P.cy - Q.cy, P.cz - Q.cz
	local sx, sy, sz = P.uy * uz - P.uz * uy, P.uz * ux - P.ux * uz, P.ux * uy - P.uy * ux
	local along = abs(dx * ux + dy * uy + dz * uz) + P.hx * abs(P.ux * ux + P.uy * uy + P.uz * uz)
		+ P.r * sqrt(sx * sx + sy * sy + sz * sz) - Q.hx
	local across = 0
	for s = -1, 1, 2 do
		local mx, my, mz = dx + s * P.hx * P.ux, dy + s * P.hx * P.uy, dz + s * P.hx * P.uz
		local t = mx * ux + my * uy + mz * uz
		mx, my, mz = mx - t * ux, my - t * uy, mz - t * uz
		across = max(across, R5.search(mx, my, mz, P.r, P.ux, P.uy, P.uz, ux, uy, uz, 1e-8))
	end
	return max(along, across - Q.r)
end

-- the reading of part 2 against part 1 alone, whole, on a tree's Cover (Q ranks higher: the larger)
local function read(Cv, Sh, parts)
	local P1, P2 = Sh.prepare(parts[1], 1), Sh.prepare(parts[2], 2)
	local m1, m2 = Cv.model(P1), Cv.model(P2)
	local shown, used = Cv.shown(m2, { m1 }, { true }, math.huge, math.huge)
	return shown / m2.total, used
end

local c = { rods = 0, inside = 0, keptB = 0, keptO = 0, open = 0, caps = 0, differ = 0, worstB = 0, worstO = 0, out = 0,
	outKept = 0 }
local function one(parts, label)
	local P = { Shapes.prepare(parts[1], 1), Shapes.prepare(parts[2], 2) }
	if P[2].volume < Geo.MIN_PART_VOLUME then
		return
	end
	c.rods += 1
	local s = exactS(P[2], P[1])
	for _, higher in ipairs({ true, false }) do
		local a, ua = Build._lies(P[2], P[1], higher)
		local b = Exact._lies(P[2], P[1], higher)
		if a ~= b then
			c.differ += 1
			print(fmt("DIFFER %s (higher %s): build %s, exact %s, s %.3e", label, tostring(higher), tostring(a), tostring(b), s))
		end
		if ua > 0.5 then
			c.open += 1
			c.caps += (ua - 0.5) / 28
		end
	end
	local rb, ro = read(Build, Shapes, parts), read(Old, OShapes, parts)
	if s <= Geo.EPS_GEOM then
		c.inside += 1
		if rb >= 0.02 then
			c.keptB += 1
		end
		if ro >= 0.02 then
			c.keptO += 1
		end
		c.worstB, c.worstO = max(c.worstB, rb), max(c.worstO, ro)
	else
		c.out += 1
		if rb >= 0.02 then
			c.outKept += 1
		end
	end
end

if mode == "tilt" then
	-- V1's rodtilt.luau, its draws in its order (seed, count), the rod put by bisection on 720 points of each cap rim
	local rng = TestRng.new(tonumber(process.args[2]) or 1)
	local COUNT = tonumber(process.args[3]) or 500
	local function farthestTrue(P, Q)
		local best = -math.huge
		for s = -1, 1, 2 do
			for k = 0, 719 do
				local t = 2 * math.pi * k / 720
				local cc, si = math.cos(t), math.sin(t)
				local x = P.cx + s * P.hx * P.ux + P.r * (cc * P.vx + si * P.wx)
				local y = P.cy + s * P.hx * P.uy + P.r * (cc * P.vy + si * P.wy)
				local z = P.cz + s * P.hx * P.uz + P.r * (cc * P.vz + si * P.wz)
				best = math.max(best, Shapes.sd(Q, x, y, z))
			end
		end
		return best
	end
	for _ = 1, COUNT do
		local R = rng:pick({ 0.1, 0.2, 0.3, 0.5, 0.8 })
		local LEN = rng:pick({ 0.3, 0.5, 1.0, 2.0 * R })
		local axis = rng:pick({ "Z", "Y" })
		local Qrot = if axis == "Z" then Y90 else Z90
		local C = { 0, 2, 0 }
		local rho = math.max(0.02, R * rng:range(0.05, 0.4))
		local hx = math.max(0.01, R * rng:range(0.05, 0.6))
		local theta = rng:pick({ 2, 5, 15, 30, 45, 60, 75, 89, 90, rng:range(0, 90) })
		local m = rng:pick({ 2e-7, 1e-6, 1e-5, 3e-5, 1e-4, 3e-4, 1e-3 })
		local u = if axis == "Z" then { 0, 0, 1 } else { 0, 1, 0 }
		local beta = rng:range(0, 2 * math.pi)
		local e1 = { 1, 0, 0 }
		local e2 = { u[2] * e1[3] - u[3] * e1[2], u[3] * e1[1] - u[1] * e1[3], u[1] * e1[2] - u[2] * e1[1] }
		local w = { math.cos(beta) * e1[1] + math.sin(beta) * e2[1], math.cos(beta) * e1[2] + math.sin(beta) * e2[2], math.cos(beta) * e1[3] + math.sin(beta) * e2[3] }
		local t = { u[2] * w[3] - u[3] * w[2], u[3] * w[1] - u[1] * w[3], u[1] * w[2] - u[2] * w[1] }
		local towardT = rng:float() < 0.6
		local b = if towardT then t else w
		local th = math.rad(theta)
		local a = { math.cos(th) * u[1] + math.sin(th) * b[1], math.cos(th) * u[2] + math.sin(th) * b[2], math.cos(th) * u[3] + math.sin(th) * b[3] }
		local ax, ay, az = 0, -a[3], a[2]
		local s = math.sqrt(ay * ay + az * az)
		local q = if s < 1e-12 then I else axisAngle(ax, ay, az, math.deg(math.atan2(s, a[1])))
		q = Quat.hemisphere(Quat.normalize(Quat.mul(q, axisAngle(1, 0, 0, rng:range(0, 180)))))
		local along = rng:range(-0.5, 0.5) * math.max(0, LEN / 2 - hx)
		local Q = part("Guard", "Cylinder", C, Qrot, { LEN, 2 * R, 2 * R })
		local QP = Shapes.prepare(Q, 1)
		local function at(k)
			return part("Blade", "Cylinder", { C[1] + along * u[1] + k * w[1], C[2] + along * u[2] + k * w[2], C[3] + along * u[3] + k * w[3] }, q,
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
			one({ Q, at(lo) }, fmt("tilt %.1f° m %.0e", theta, m))
		end
	end
else
	-- V1's rodrim.luau: rods and pucks across a disk's axis, tangent to its rim, cap rims m under its side; then the same
	-- turned 2–90° about the radius (no longer tangent: the bounds leave caps open)
	local R, LEN = tonumber(process.args[2]) or 0.8, tonumber(process.args[3]) or 0.5
	local C = { 0, 2, 0 }
	for _, turn in ipairs({ 0, 2, 10, 45, 90 }) do
		for _, rho in ipairs({ 0.02, 0.03, 0.05, 0.1 }) do
			for _, hx in ipairs({ 0.05, 0.1, 0.2, 0.3 }) do
				for k = 0, 16 do
					local alpha = 30 + k * 11.25 / 16
					for _, m in ipairs({ 2e-7, 1e-6, 1e-5, 3e-5, 1e-4, 2e-4, 5e-4 }) do
						local al = math.rad(alpha)
						local rx, ry = math.sin(al), math.cos(al)
						local tx, ty = ry, -rx
						-- the rod along the tangent, then turned `turn`° about the radius toward the disk's axis: its farthest point
						-- put m under the side by bisection on its distance from the axis (exact search, the 50-digit-checked one)
						local q = Quat.hemisphere(Quat.normalize(Quat.mul(axisAngle(rx, ry, 0, turn), axisAngle(0, 0, 1, math.deg(math.atan2(ty, tx))))))
						local Q = part("Guard", "Cylinder", C, Y90, { LEN, 2 * R, 2 * R })
						local QP = Shapes.prepare(Q, 1)
						local function at(y0)
							return part("Blade", "Cylinder", { C[1] + y0 * rx, C[2] + y0 * ry, C[3] }, q, { 2 * hx, 2 * rho, 2 * rho })
						end
						local lo, hi = 0, R
						for _ = 1, 80 do
							local mid = (lo + hi) / 2
							if exactS(Shapes.prepare(at(mid), 2), QP) < -m then
								lo = mid
							else
								hi = mid
							end
						end
						if exactS(Shapes.prepare(at(lo), 2), QP) < -m * 0.999 then
							one({ Q, at(lo) }, fmt("turn %d° ρ %.2f hx %.2f α %.3f m %.0e", turn, rho, hx, alpha, m))
						end
					end
				end
			end
		end
	end
end
print(fmt("%s %s: %d rods; %d wholly inside (exact s ≤ EPS_GEOM): the build keeps %d (the most %.3f%%), the tree before %d (the most %.3f%%); %d poke out more than EPS_GEOM, the build keeps %d of them; the bounds left %d tests open (%d caps searched) of %d (both ranks); %d decisions differ from the always-exact rule",
	mode, table.concat(process.args, " ", 2), c.rods, c.inside, c.keptB, 100 * c.worstB, c.keptO, 100 * c.worstO, c.out, c.outKept,
	c.open, c.caps, 2 * c.rods, c.differ))
