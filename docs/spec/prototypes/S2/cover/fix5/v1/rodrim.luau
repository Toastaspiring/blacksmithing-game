--!nocheck
-- V1 (m2x, round 5): round filler wholly inside ONE round part, a hair under its true surface, read on the model (§17.2:
-- "Filler wholly inside a Ball or a Cylinder, against its true surface, reads nothing"). A disk Q (a Cylinder r R along Z,
-- LEN long) and a rod P (r ρ, half length hx) across Q's axis, tangent to its rim: its axis square to the radius at angle
-- α from +Y, its cap rims' farthest points m inside Q's side (so every point of P lies at least m inside Q: the truth
-- reads 0). Rule A's bound for a Cylinder in a Cylinder (caps' centres' distance from the axis + ρ) stands above P's true
-- farthest point, and a facet's hull stands 0.0048 ρ past P's surface: does the build still hide P?
--   lune run rodrim -- [R] [len]
local process = require("@lune/process")
local L = require("./lib")
local fmt = string.format
local R, LEN = tonumber(process.args[1]) or 0.8, tonumber(process.args[2]) or 0.5
local C = { 0, 2, 0 }

-- the quaternion turning local +X onto (dx, dy, 0)
local function rotXY(dx, dy)
	return L.axisAngle(0, 0, 1, math.deg(math.atan2(dy, dx)))
end

local function run(rho, hx, alpha, m, verbose)
	-- the radius direction at alpha from +Y toward +X, the rod along the tangent
	local a = math.rad(alpha)
	local rx, ry = math.sin(a), math.cos(a)
	local tx, ty = ry, -rx
	-- centre at distance y0 from the axis: the cap rim's farthest point sqrt(hx² + (y0 + ρ)²) = R − m
	local y0 = math.sqrt((R - m) ^ 2 - hx * hx) - rho
	local parts = L.renumber({
		L.part("Guard", "Cylinder", C, L.Y90, { LEN, 2 * R, 2 * R }),
		L.part("Blade", "Cylinder", { C[1] + y0 * rx, C[2] + y0 * ry, C[3] }, rotXY(tx, ty), { 2 * hx, 2 * rho, 2 * rho }),
	})
	local P = L.prep(parts)
	if P[2].volume < L.Geo.MIN_PART_VOLUME then
		return 0, -1, parts
	end
	local read = L.readOf(P, 2, L.models(P))
	local truth = -1
	if verbose then
		local _, _, hider = L.Oracle.flags(P)
		truth = L.Oracle.share(P, 2, hider)
	end
	return read, truth, parts
end

local worst, wpar = 0, nil
local kept, total = 0, 0
for _, rho in ipairs({ 0.02, 0.03, 0.05, 0.1 }) do
	for _, hx in ipairs({ 0.05, 0.1, 0.2, 0.3 }) do
		for k = 0, 16 do
			local alpha = 30 + k * 11.25 / 16
			for _, m in ipairs({ 2e-7, 1e-6, 1e-5, 3e-5, 1e-4, 2e-4, 5e-4 }) do
				local read = run(rho, hx, alpha, m)
				total += 1
				if read >= 0.02 then
					kept += 1
				end
				if read > worst then
					worst, wpar = read, { rho, hx, alpha, m }
				end
			end
		end
	end
end
if wpar == nil then -- m2x-fix-5: every rod reads 0
	print(fmt("R %.2f: %d rods wholly inside the disk (truly 0), %d read 2 %% or more (kept); none reads above 0", R, total, kept))
	return
end
print(fmt("R %.2f: %d rods wholly inside the disk (truly 0), %d read 2 %% or more (kept); the most %.3f%% (ρ %.2f, hx %.2f, α %.3f°, m %.0e)",
	R, total, kept, 100 * worst, wpar[1], wpar[2], wpar[3], wpar[4]))
local read, truth, parts = run(wpar[1], wpar[2], wpar[3], wpar[4], true)
print(fmt("   that rod: reads %.3f%%, truth %.3f%%", 100 * read, 100 * truth))
print("   " .. require("@lune/serde").encode("json", parts))
