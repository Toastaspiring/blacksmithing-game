--!nocheck
-- rodrim.luau's sweep, the most per (ρ, hx) and per m, and how many are kept
local process = require("@lune/process")
local L = require("./lib")
local fmt = string.format
local R, LEN = tonumber(process.args[1]) or 0.8, tonumber(process.args[2]) or 0.5
local C = { 0, 2, 0 }
local function rotXY(dx, dy)
	return L.axisAngle(0, 0, 1, math.deg(math.atan2(dy, dx)))
end
local function run(rho, hx, alpha, m)
	local a = math.rad(alpha)
	local rx, ry = math.sin(a), math.cos(a)
	local tx, ty = ry, -rx
	local y0 = math.sqrt((R - m) ^ 2 - hx * hx) - rho
	local parts = L.renumber({
		L.part("Guard", "Cylinder", C, L.Y90, { LEN, 2 * R, 2 * R }),
		L.part("Blade", "Cylinder", { C[1] + y0 * rx, C[2] + y0 * ry, C[3] }, rotXY(tx, ty), { 2 * hx, 2 * rho, 2 * rho }),
	})
	local P = L.prep(parts)
	if P[2].volume < L.Geo.MIN_PART_VOLUME then
		return nil
	end
	return L.readOf(P, 2, L.models(P))
end
for _, rho in ipairs({ 0.02, 0.03, 0.05, 0.1, 0.15 }) do
	for _, hx in ipairs({ 0.05, 0.1, 0.2, 0.3 }) do
		local line = {}
		for _, m in ipairs({ 2e-7, 1e-6, 1e-5, 3e-5, 1e-4, 2e-4, 5e-4, 1e-3 }) do
			local best, n, k = 0, 0, 0
			for j = 0, 32 do
				local r = run(rho, hx, 30 + j * 11.25 / 32, m)
				if r then
					n += 1
					best = math.max(best, r)
					if r >= 0.02 then
						k += 1
					end
				end
			end
			table.insert(line, if n == 0 then "  dust" else fmt("%5.2f%%/%2d", 100 * best, k))
		end
		print(fmt("ρ %.2f hx %.2f: m 2e-7 1e-6 1e-5 3e-5 1e-4 2e-4 5e-4 1e-3: %s", rho, hx, table.concat(line, " ")))
	end
end
