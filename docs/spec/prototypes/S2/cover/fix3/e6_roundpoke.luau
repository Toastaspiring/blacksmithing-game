--!nocheck
-- m2x-fix-3 E6: a round part poking out of a round hider by p, alone (the truth: its cap past the hider's surface, with the
-- probe): the base's reading, the build's, the truth. Errors either way across 2 %: kept that truly shows under 2 % (the
-- band's over-reading), cleaned that truly shows 2 % or more (the price of the buried piece moved out).
--   lune run e6_roundpoke -- <ballInBall | cylInBall | ballInCyl | cylInCyl> [<variant folder for the base column>]
local Lab = require("./lab")
local process = require("@lune/process")
local B, N = Lab.tree(if process.args[2] then Lab.SCR .. "/m2x-fix-3/" .. process.args[2] else "base"), Lab.tree(if process.args[3] then Lab.SCR .. "/m2x-fix-3/" .. process.args[3] else "now")
local fmt = string.format
local family = process.args[1] or "ballInBall"
local G = 0.02

local function norm(d)
	local l = math.sqrt(d[1] * d[1] + d[2] * d[2] + d[3] * d[3])
	return { d[1] / l, d[2] / l, d[3] / l }
end
local DIRS = { { "pole", { 0, 1, 0 } }, { "octant", norm({ 1, 1, 1 }) }, { "between", norm({ 1, 3, 1 }) }, { "odd", norm({ 1, 2, 3 }) } }
local POKES = { 0.0002, 0.0005, 0.001, 0.002, 0.004, 0.008, 0.016, 0.03 }

local count, s = 0, { baseWrongKept = 0, buildWrongKept = 0, baseWrongCleaned = 0, buildWrongCleaned = 0 }
local worstPrice, worstKept = nil, nil
local function try(what, parts)
	N.renumber(parts)
	local Pn, Pb = N.prep(parts), B.prep(parts)
	if Pn[2].volume < N.Geo.MIN_PART_VOLUME then
		return
	end
	local rn, rb = N.readOf(Pn, 2), B.readOf(Pb, 2)
	local t = N.truth(Pn, 2)
	count += 1
	local flags = ""
	if rb >= G and t < G then
		s.baseWrongKept += 1
		flags ..= " baseKEPT"
	end
	if rn >= G and t < G then
		s.buildWrongKept += 1
		flags ..= " KEPT"
		if worstKept == nil or rn > worstKept[1] then
			worstKept = { rn, what, t }
		end
	end
	if rb < G and t >= G then
		s.baseWrongCleaned += 1
		flags ..= " baseCLEANED"
	end
	if rn < G and t >= G then
		s.buildWrongCleaned += 1
		flags ..= " CLEANED"
		if worstPrice == nil or t > worstPrice[1] then
			worstPrice = { t, what, rn }
		end
	end
	print(fmt("%-66s truth %7.3f%%  base %7.3f%%  build %7.3f%%%s", what, 100 * t, 100 * rb, 100 * rn, flags))
end

-- the turn taking local +X (a Cylinder's axis) to d
local function axisTo(d)
	local ax, az = d[3], -d[1]
	local up = if math.abs(ax) + math.abs(az) < 1e-12 then N.I else N.axisAngle(ax, 0, az, math.deg(math.acos(d[2])))
	return N.Quat.hemisphere(N.Quat.normalize(N.Quat.mul(up, N.Z90)))
end

local C = { 0, 2, 0 }
for _, R in ipairs({ 0.15, 0.3, 0.8 }) do
	for _, f in ipairs({ 0.15, 0.25, 0.4, 0.6 }) do
		local r = f * R
		for _, p in ipairs(POKES) do
			for di, dir in ipairs(DIRS) do
				local d = dir[2]
				if family == "ballInBall" then
					local k = R + p - r
					try(fmt("Ball r %.3f out of Ball R %.2f by %.4f, %s", r, R, p, dir[1]), {
						N.part("Pommel", "Ball", C, N.I, { 2 * R, 2 * R, 2 * R }),
						N.part("Blade", "Ball", { C[1] + k * d[1], C[2] + k * d[2], C[3] + k * d[3] }, N.axisAngle(1, 2, 3, 17 * di), { 2 * r, 2 * r, 2 * r }),
					})
				elseif family == "cylInBall" then
					-- a rod along d, its end cap p out of the sphere at its centre
					local hx = r
					local k = R + p - hx
					try(fmt("Cyl r %.3f x %.3f out of Ball R %.2f by %.4f, %s", r, 2 * hx, R, p, dir[1]), {
						N.part("Pommel", "Ball", C, N.I, { 2 * R, 2 * R, 2 * R }),
						N.part("Blade", "Cylinder", { C[1] + k * d[1], C[2] + k * d[2], C[3] + k * d[3] }, axisTo(d), { 2 * hx, 2 * r, 2 * r }),
					})
				else
					-- the hider a Cylinder along X, R, length 4 R; the part through its side at angle a from Y
					local a = ({ 0, 5.625, 2.8, 30 })[di]
					local dd = { 0, math.cos(math.rad(a)), math.sin(math.rad(a)) }
					local k = R + p - r
					local hider = N.part("Grip", "Cylinder", C, N.I, { 4 * R, 2 * R, 2 * R })
					if family == "ballInCyl" then
						try(fmt("Ball r %.3f out of Cyl R %.2f by %.4f, at %.1f°", r, R, p, a), {
							hider,
							N.part("Blade", "Ball", { C[1] + 0.3 * R, C[2] + k * dd[2], C[3] + k * dd[3] }, N.I, { 2 * r, 2 * r, 2 * r }),
						})
					else
						-- a rod parallel to the hider's axis, its side p out
						try(fmt("Cyl r %.3f out of Cyl R %.2f by %.4f, at %.1f°", r, R, p, a), {
							hider,
							N.part("Blade", "Cylinder", { C[1], C[2] + k * dd[2], C[3] + k * dd[3] }, N.I, { 2 * R, 2 * r, 2 * r }),
						})
					end
				end
			end
		end
	end
end
print(fmt("%s: %d designs; kept that truly show under 2 %%: base %d, build %d%s; cleaned that truly show 2 %% or more: base %d, build %d%s",
	family, count, s.baseWrongKept, s.buildWrongKept,
	if worstKept then fmt(" (the build's most: %s, read %.3f%%, truly %.3f%%)", worstKept[2], 100 * worstKept[1], 100 * worstKept[3]) else "",
	s.baseWrongCleaned, s.buildWrongCleaned,
	if worstPrice then fmt(" (the build's most: %s, truly %.3f%%, read %.3f%%)", worstPrice[2], 100 * worstPrice[1], 100 * worstPrice[3]) else ""))
