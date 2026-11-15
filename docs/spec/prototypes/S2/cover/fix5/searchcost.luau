--!nocheck
-- m2x-fix-5: what the searches cost against what they are charged. A disk (a Cylinder r 0.8 along Z, 0.5 long) and 23 rods
-- r ρ, 2·hx long, along its rim's tangent turned `turn`° about the radius toward the disk's axis, their farthest points
-- m under its side (m < 0: out of it), at 11.25° steps: every rod's test against the disk leaves its caps open. The
-- verdict alone (SamplingV), median of 15, every design once a round on each tree in turn; its units, the caps searched
-- (the build's _lies), ns a unit.
--   lune run searchcost -- [rounds]
local process = require("@lune/process")
local W = "C:/Users/louis/AppData/Local/Temp/claude/C--Users-louis-Documents-RANDOM-ROBLOX/93ae48b4-72b9-4dc1-aa5d-451af1abf9a0/scratchpad/m2x-fix-5"
local function req(p)
	return (require :: any)(p)
end
local R5 = require("./rim")
local fmt = string.format
local sqrt, abs, max = math.sqrt, math.abs, math.max
local ROUNDS = tonumber(process.args[1]) or 15
local trees = {}
for _, name in ipairs({ "hook", "base" }) do
	table.insert(trees, { name = name, Shapes = req(W .. "/" .. name .. "/src/shared/Physics/Shapes"),
		V = req(W .. "/" .. name .. "/src/shared/Physics/SamplingV"), Cover = req(W .. "/" .. name .. "/src/shared/Physics/Cover") })
end
local Quat = req(W .. "/hook/src/shared/Blueprint/Quat")
local Shapes = trees[1].Shapes
local I = { 0, 0, 0, 1 }
local S45 = 0.70710678118654757
local Y90 = { 0, S45, 0, S45 }
local function axisAngle(ax, ay, az, deg)
	local h = math.rad(deg) / 2
	local n = math.sqrt(ax * ax + ay * ay + az * az)
	return Quat.hemisphere(Quat.normalize({ ax / n * math.sin(h), ay / n * math.sin(h), az / n * math.sin(h), math.cos(h) }))
end
local function part(slot, shape, pos, rot, size)
	return { id = 0, label = shape, shape = shape, slot = slot, material = "Iron", pos = { pos[1], pos[2], pos[3] }, rot = rot or I,
		size = { size[1], size[2], size[3] } }
end
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
-- radial rods: along the radius, tilted `tilt`° out of the disk's plane (asin(ρ/x) puts the bounds furthest apart), their
-- farthest points m under the side
local function radial(rho, hx, tilt, m)
	local R, LEN, C = 0.8, 0.5, { 0, 2, 0 }
	local parts = { part("Guard", "Cylinder", C, Y90, { LEN, 2 * R, 2 * R }) }
	local Q = Shapes.prepare(parts[1], 1)
	for j = 0, 22 do
		local al = math.rad(j * 360 / 23)
		local rx, ry = math.sin(al), math.cos(al)
		local nx, ny, nz = rx * math.cos(math.rad(tilt)), ry * math.cos(math.rad(tilt)), math.sin(math.rad(tilt))
		-- local X onto n
		local ax, ay, az = 0, -nz, ny
		local s = math.sqrt(ay * ay + az * az)
		local q = Quat.hemisphere(Quat.normalize({ ax / s * math.sin(math.atan2(s, nx) / 2), ay / s * math.sin(math.atan2(s, nx) / 2),
			az / s * math.sin(math.atan2(s, nx) / 2), math.cos(math.atan2(s, nx) / 2) }))
		local function at(y0)
			return part("Blade", "Cylinder", { C[1] + y0 * rx, C[2] + y0 * ry, C[3] }, q, { 2 * hx, 2 * rho, 2 * rho })
		end
		local lo, hi = 0, R
		for _ = 1, 80 do
			local mid = (lo + hi) / 2
			if exactS(Shapes.prepare(at(mid), 2), Q) < -m then
				lo = mid
			else
				hi = mid
			end
		end
		table.insert(parts, at(lo))
	end
	for i, p in ipairs(parts) do
		p.id = i
	end
	return parts
end
local function design(rho, hx, turn, m)
	local R, LEN, C = 0.8, 0.5, { 0, 2, 0 }
	local parts = { part("Guard", "Cylinder", C, Y90, { LEN, 2 * R, 2 * R }) }
	local Q = Shapes.prepare(parts[1], 1)
	for j = 0, 22 do
		local al = math.rad(j * 360 / 23)
		local rx, ry = math.sin(al), math.cos(al)
		local q = Quat.hemisphere(Quat.normalize(Quat.mul(axisAngle(rx, ry, 0, turn), axisAngle(0, 0, 1, math.deg(math.atan2(-rx, ry))))))
		local function at(y0)
			return part("Blade", "Cylinder", { C[1] + y0 * rx, C[2] + y0 * ry, C[3] }, q, { 2 * hx, 2 * rho, 2 * rho })
		end
		local lo, hi = 0, R
		for _ = 1, 80 do
			local mid = (lo + hi) / 2
			if exactS(Shapes.prepare(at(mid), 2), Q) < -m then
				lo = mid
			else
				hi = mid
			end
		end
		table.insert(parts, at(lo))
	end
	for i, p in ipairs(parts) do
		p.id = i
	end
	return parts
end
local designs = {
	{ "23 rods 1e-4 inside, turned 10°", design(0.03, 0.1, 10, 1e-4) },
	{ "23 rods 1e-4 inside, turned 45°", design(0.05, 0.1, 45, 1e-4) },
	{ "23 rods 1e-6 out, turned 10°", design(0.03, 0.1, 10, -1e-6) },
	{ "23 pucks 1e-4 inside, turned 30°", design(0.1, 0.05, 30, 1e-4) },
	{ "23 radial rods 1e-4 inside, 4° up", radial(0.05, 0.1, math.deg(math.asin(0.05 / 0.65)), 1e-4) },
	{ "23 radial rods 1e-6 out, 4° up", radial(0.05, 0.1, math.deg(math.asin(0.05 / 0.65)), -1e-6) },
	{ "23 radial rods 2e-7 inside, 4° up", radial(0.05, 0.1, math.deg(math.asin(0.05 / 0.65)), 2e-7) },
}
local data = {}
for k, d in ipairs(designs) do
	data[k] = {}
	for t, T in ipairs(trees) do
		local P = {}
		for i, p in ipairs(d[2]) do
			P[i] = T.Shapes.prepare(p, i)
		end
		local e = T.V.exposure(P)
		local kept = 0
		for i = 1, #P do
			if e.kept[i] then
				kept += 1
			end
		end
		local caps = 0
		if T.Cover._lies then
			for i = 2, #P do
				for _, higher in ipairs({ true }) do
					local _, u = T.Cover._lies(P[i], P[1], higher)
					caps += (u - 0.5) / 28
				end
			end
		end
		data[k][t] = { P = P, units = e.verdictWork, kept = kept, caps = caps, v = {} }
	end
end
for _ = 1, ROUNDS do
	for k in ipairs(designs) do
		for t, T in ipairs(trees) do
			local x = data[k][t]
			local t0 = os.clock()
			T.V.exposure(x.P)
			table.insert(x.v, (os.clock() - t0) * 1000)
		end
	end
end
local function median(list)
	table.sort(list)
	return list[(#list + 1) // 2]
end
for k, d in ipairs(designs) do
	local row = { fmt("%-34s", d[1]) }
	for t, T in ipairs(trees) do
		local x = data[k][t]
		local ms = median(x.v)
		table.insert(row, fmt("%s %9.1f u, %2d kept, %2d caps searched (rods against the disk), verdict %6.3f ms, %5.1f ns a unit", T.name,
			x.units, x.kept, x.caps, ms, ms * 1e6 / x.units))
	end
	print(table.concat(row, " | "))
end
