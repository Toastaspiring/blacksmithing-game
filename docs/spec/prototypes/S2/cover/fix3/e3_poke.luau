--!nocheck
-- m2x-fix-3 E3: the buried piece on a round hider's half-spaces moved out (fixAB (i))'s price. A Block whose top face stands
-- e past a round hider's true surface, the rest of it inside: a Ball's pole (its moved half-spaces' tip, 0.0260 r out), the
-- middle of an octant (where they touch the sphere) and between, a Cylinder side across a 32-gon vertex (sec(π/32) − 1 =
-- 0.0048 r out) and across a side's middle; radii up to MAX_DIM / 2. The truth, the base's reading, the build's; the price
-- is a Block the build cleans that truly shows 2 % or more.
--   lune run e3_poke -- <ball | cylinder>
local Lab = require("./lab")
local process = require("@lune/process")
local B, N = Lab.tree("base"), Lab.tree("now")
local fmt = string.format
local which = process.args[1] or "ball"

local function norm(d)
	local l = math.sqrt(d[1] * d[1] + d[2] * d[2] + d[3] * d[3])
	return { d[1] / l, d[2] / l, d[3] / l }
end

-- the turn taking local +Y to d
local function rotTo(d)
	local ax, az = d[3], -d[1]
	if math.abs(ax) + math.abs(az) < 1e-12 then
		return if d[2] > 0 then N.I else N.axisAngle(1, 0, 0, 180)
	end
	return N.axisAngle(ax, 0, az, math.deg(math.acos(d[2])))
end

local rows, price, moved, worstPrice = 0, 0, 0, nil
local function try(what, parts, over)
	N.renumber(parts)
	local Pn, Pb = N.prep(parts), B.prep(parts)
	if Pn[2].volume < N.Geo.MIN_PART_VOLUME then
		return
	end
	local rn, rb = N.readOf(Pn, 2), B.readOf(Pb, 2)
	local truth = N.truth(Pn, 2)
	rows += 1
	local G = 0.02
	local flag = ""
	if (rn >= G) ~= (rb >= G) then
		moved += 1
		flag = flag .. "  MOVED"
	end
	if rn < G and truth >= G then
		price += 1
		flag = flag .. "  PRICE"
		if worstPrice == nil or truth > worstPrice[1] then
			worstPrice = { truth, what, rn }
		end
	end
	print(fmt("%-72s truth %7.3f%%  base %7.3f%%  build %7.3f%%%s", what, 100 * truth, 100 * rb, 100 * rn, flag))
end

if which == "ball" then
	for _, R in ipairs({ 0.05, 0.1, 0.2, 0.3, 0.6, 1.2, 3 }) do
		local over = 0.026 * R
		for _, dir in ipairs({ { "pole", { 0, 1, 0 } }, { "octant", norm({ 1, 1, 1 }) }, { "between", norm({ 1, 3, 1 }) } }) do
			local d = dir[2]
			for _, a in ipairs({ 0.02, 0.04, 0.1, 0.25 * R }) do
				if a >= 0.02 and a <= 0.6 * R then
					for _, f in ipairs({ 0.05, 0.1, 0.25, 0.5, 0.75, 1, 1.25 }) do
						local e = f * over
						local len = math.max(0.02, math.min(0.2, R))
						local k = R + e - len / 2
						local C = { 0, 2, 0 }
						local parts = {
							N.part("Pommel", "Ball", C, N.I, { 2 * R, 2 * R, 2 * R }),
							N.part("Blade", "Block", { C[1] + k * d[1], C[2] + k * d[2], C[3] + k * d[3] }, rotTo(d), { a, len, a }),
						}
						try(fmt("Ball r %.2f, %-7s Block %.3f x %.3f, top %.2f over (%.5f) out", R, dir[1], a, len, f, e), parts, over)
					end
				end
			end
		end
	end
else
	for _, R in ipairs({ 0.05, 0.1, 0.2, 0.3, 0.8, 1.5, 3 }) do
		local over = 0.0048 * R
		-- the Cylinder along X; its 32-gon starts from world Y: vertices at angles k·11.25° from Y toward Z, sides' middles between
		for _, dir in ipairs({ { "vertex", 0 }, { "middle", 5.625 }, { "between", 2.8 } }) do
			local ang = math.rad(dir[2])
			local d = { 0, math.cos(ang), math.sin(ang) }
			for _, a in ipairs({ 0.02, 0.04, 0.1 }) do
				if a <= 0.6 * R then
					for _, f in ipairs({ 0.05, 0.1, 0.25, 0.5, 0.75, 1, 1.25 }) do
						local e = f * over
						local len = math.max(0.02, math.min(0.2, R))
						local k = R + e - len / 2
						local C = { 0, 2, 0 }
						local parts = {
							N.part("Grip", "Cylinder", C, N.I, { 1.2, 2 * R, 2 * R }),
							N.part("Blade", "Block", { C[1], C[2] + k * d[2], C[3] + k * d[3] }, rotTo(d), { a, len, a }),
						}
						try(fmt("Cylinder r %.2f, %-7s Block %.3f x %.3f, top %.2f over (%.6f) out", R, dir[1], a, len, f, e), parts, over)
					end
				end
			end
		end
	end
end
print(fmt("%s: %d designs, verdict moved against the base on %d, cleaned by the build while truly ≥ 2 %% on %d%s", which, rows,
	moved, price, if worstPrice then fmt(" (the most: %s, truly %.3f%%, read %.3f%%)", worstPrice[2], 100 * worstPrice[1], 100 * worstPrice[3]) else ""))
