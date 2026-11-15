--!nocheck
-- fix-4: V1's band designs (V2's e1v.luau, m2x-v2-4) on named trees: F5 with its pommel a Ball 0.6 across at (0, 0.3, 0)
-- and 4 Blade Blocks 0.1 × 0.2 × 0.1 along (1, ±1, ±1)/√3, outer faces 0.011 under the sphere, or 4 Blade Balls r 0.1,
-- 0.002 or 0.0002 under it; 4 Blocks in the band of F3's, C04's and C09's own pommels; a plate under a Cylinder r 0.3's
-- side. Per part the reading and verdict on each tree and the truth; D on each tree's verdict and on the truth's row.
--   lune run bands -- <tree> [<tree> ...]
local process = require("@lune/process")
local V = require("./vlab")
local Drep = require("./drep")
local fmt = string.format
local names = process.args
local N = V.tree(names[#names])
local DIRS = V.dirs()
local Fx = require(N.root .. "/docs/spec/prototypes/S2/v2/fixtures")

local R = 0.3
local f5 = N.copy(N.Blueprints.core("F5").parts)
f5[1] = N.part("Pommel", "Ball", { 0, R, 0 }, nil, { 2 * R, 2 * R, 2 * R })
Drep.report("F5 with its pommel a Ball 0.6 across", f5, 1, names)
for _, case in ipairs({ { "Block", 0.011 }, { "Ball", 0.002 }, { "Ball", 0.0002 } }) do
	local parts = N.copy(f5)
	for _, d in ipairs(DIRS) do
		local k = R - case[2] - 0.1
		if case[1] == "Block" then
			table.insert(parts, N.part("Blade", "Block", { k * d[1], R + k * d[2], k * d[3] },
				N.H.axisAngle(d[3], 0, -d[1], math.deg(math.acos(d[2]))), { 0.1, 0.2, 0.1 }))
		else
			table.insert(parts, N.part("Blade", "Ball", { k * d[1], R + k * d[2], k * d[3] }, nil, { 0.2, 0.2, 0.2 }))
		end
	end
	Drep.report(fmt("F5 + that pommel + 4 Blade %ss, %.4f under", case[1], case[2]), parts, #f5 + 1, names)
end

local function fixture(prefix)
	for _, list in ipairs({ Fx.calibration(), Fx.golden() }) do
		for _, b in ipairs(list) do
			if string.sub(b.name, 1, #prefix) == prefix then
				return N.copy(b.parts)
			end
		end
	end
	error(prefix)
end
for _, id in ipairs({ "F3", "C04", "C09" }) do
	local base = fixture(id)
	local bi = 0
	for i, p in ipairs(base) do
		if p.shape == "Ball" and bi == 0 then
			bi = i
		end
	end
	local ball = base[bi]
	local r = ball.size[1] / 2
	local e = 0.55 * 0.0572 * r
	local a = math.floor(math.sqrt(2 * ((r - 0.0005) ^ 2 - (r - e) ^ 2)) * 1000) / 1000
	local len = math.floor((2 * r - e - 0.03) * 1000) / 1000
	local parts = N.copy(base)
	for k = 1, 4 do
		local d = DIRS[k]
		local c = r - e - len / 2
		table.insert(parts, N.part("Blade", "Block", { ball.pos[1] + c * d[1], ball.pos[2] + c * d[2], ball.pos[3] + c * d[3] },
			N.H.axisAngle(d[3], 0, -d[1], math.deg(math.acos(d[2]))), { a, len, a }))
	end
	Drep.report(fmt("%s + 4 Blade Blocks %.3f × %.3f in its pommel (r %.3f), %.4f deep", id, a, len, r, e), parts, #base + 1, names)
end

for _, e in ipairs({ 0.0003, 0.0006, 0.001 }) do
	local r, a = 0.3, math.pi / 32
	local w = 2 * math.sqrt((r - 1e-4) ^ 2 - (r - e) ^ 2) * 0.95
	local k = r - e - 0.015
	local parts = N.copy({
		N.part("Grip", "Cylinder", { 0, 1, 0 }, nil, { 1.4, 2 * r, 2 * r }),
		N.part("Blade", "Block", { 0, 1 + k * math.cos(a), k * math.sin(a) }, N.H.axisAngle(1, 0, 0, math.deg(a)), { 1.2, 0.03, w }),
	})
	local cells = {}
	for _, n in ipairs(names) do
		local L = V.tree(n)
		table.insert(cells, n .. " " .. V.pct((L.reads(L.prep(parts)))[2]))
	end
	print(fmt("plate %.4f wide, %.4f under a Cylinder r 0.3's side: %s, truth %s", w, e, table.concat(cells, ", "), V.pct((N.truth(N.prep(parts), { [2] = true }))[2])))
end
