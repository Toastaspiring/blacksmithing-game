--!nocheck
-- m2x-fix-3 E2: a round part wholly inside a round hider, its surface e from the hider's true surface (the truth: 0 %),
-- over radii, depths and directions: the build's reading (the hull rule's looseness), the base's. The largest reading per
-- family, and every reading ≥ 1 %.
--   lune run e2_inside -- <family: ballInBall | cylInBall | ballInCyl | cylInCyl>
local Lab = require("./lab")
local process = require("@lune/process")
local B, N = Lab.tree("base"), Lab.tree("now")
local fmt = string.format
local family = process.args[1] or "ballInBall"

local function norm(d)
	local l = math.sqrt(d[1] * d[1] + d[2] * d[2] + d[3] * d[3])
	return { d[1] / l, d[2] / l, d[3] / l }
end
local DIRS = { norm({ 1, 1, 1 }), norm({ 1, 0, 0 }), norm({ 0, 1, 0 }), norm({ 1, 1, 0 }), norm({ 2, 1, 1 }), norm({ 1, 2, 3 }),
	norm({ 0.3, -1, 0.7 }), norm({ 3, 1, 0.2 }), norm({ 1, 1, 0.5 }), norm({ 1, 0.25, 0 }) }
local DEPTHS = { 0.0002, 0.0005, 0.001, 0.002, 0.003, 0.005, 0.008, 0.012, 0.02 }

local worst, worstWhat, count, over1 = 0, "", 0, 0
local baseWorst = 0
local baseWorstWhat, baseFlat = "", 0
local function try(what, parts)
	N.renumber(parts)
	local Pn, Pb = N.prep(parts), B.prep(parts)
	if Pn[2].volume < N.Geo.MIN_PART_VOLUME then
		return
	end
	-- wholly inside: the truth reads 0
	local rn = N.readOf(Pn, 2)
	local rb = B.readOf(Pb, 2)
	count += 1
	if rb > baseWorst then baseWorstWhat = what end
	baseWorst = math.max(baseWorst, rb)
	if string.find(what, "tilt 0.0", 1, true) then baseFlat = math.max(baseFlat, rb) end
	if rn > worst then
		worst, worstWhat = rn, what
	end
	if rn >= 0.01 then
		over1 += 1
		print(fmt("  %-70s build %6.3f%%  base %6.3f%%  truth %6.3f%%", what, 100 * rn, 100 * rb, 100 * N.truth(Pn, 2)))
	end
end

local C = { 0, 2, 0 }
if family == "ballInBall" or family == "cylInBall" then
	for _, R in ipairs({ 0.1, 0.2, 0.3, 1, 3 }) do
		for _, f in ipairs({ 0.1, 0.2, 0.33, 0.5, 0.8 }) do
			local r = f * R
			for _, e in ipairs(DEPTHS) do
				for di, d in ipairs(DIRS) do
					local k = R - e - r
					local pos = { C[1] + k * d[1], C[2] + k * d[2], C[3] + k * d[3] }
					if family == "ballInBall" then
						try(fmt("Ball r %.3f in Ball R %.2f, e %.4f, dir %d", r, R, e, di), {
							N.part("Pommel", "Ball", C, N.I, { 2 * R, 2 * R, 2 * R }),
							N.part("Blade", "Ball", pos, N.axisAngle(1, 2, 3, 17 * di), { 2 * r, 2 * r, 2 * r }),
						})
					else
						-- a short Cylinder whose axis lies across d, its far rim e from the sphere: centre at R − e − √(r² + hx²)
						for _, hx in ipairs({ 0.2 * r, r }) do
							local reach = math.sqrt(r * r + hx * hx)
							local kk = R - e - reach
							if kk > 0 then
								local p2 = { C[1] + kk * d[1], C[2] + kk * d[2], C[3] + kk * d[3] }
								try(fmt("Cyl r %.3f hx %.3f in Ball R %.2f, e %.4f, dir %d", r, hx, R, e, di), {
									N.part("Pommel", "Ball", C, N.I, { 2 * R, 2 * R, 2 * R }),
									N.part("Blade", "Cylinder", p2, N.axisAngle(d[2], -d[1] + 0.3, 0.2, 90), { 2 * hx, 2 * r, 2 * r }),
								})
							end
						end
					end
				end
			end
		end
	end
else
	-- a Cylinder hider along X, R, length 2.4; the part's surface e from its side, at angle a round the axis
	for _, R in ipairs({ 0.1, 0.2, 0.3, 0.8, 3 }) do
		for _, f in ipairs({ 0.1, 0.2, 0.33, 0.5, 0.8 }) do
			local r = f * R
			for _, e in ipairs(DEPTHS) do
				for ai, a in ipairs({ 0, 1.5, 3, 5.625, 8, 11.25, 30, 45, 77 }) do
					local d = { 0, math.cos(math.rad(a)), math.sin(math.rad(a)) }
					if family == "ballInCyl" then
						local k = R - e - r
						try(fmt("Ball r %.3f in Cyl R %.2f, e %.4f, angle %.3f", r, R, e, a), {
							N.part("Grip", "Cylinder", C, N.I, { 2.4, 2 * R, 2 * R }),
							N.part("Blade", "Ball", { C[1] + 0.1, C[2] + k * d[2], C[3] + k * d[3] }, N.axisAngle(1, 2, 3, ai * 13), { 2 * r, 2 * r, 2 * r }),
						})
					else
						-- a thinner Cylinder along X too (a rod in a rod), its side e from the hider's side
						for ti, tilt in ipairs({ 0, 0.5 }) do
							local t = math.rad(tilt)
							local k = R - e - r / math.cos(t) - 0.5 * math.sin(t)
							try(fmt("Cyl r %.3f in Cyl R %.2f, e %.4f, angle %.3f, tilt %.1f", r, R, e, a, tilt), {
								N.part("Grip", "Cylinder", C, N.I, { 2.4, 2 * R, 2 * R }),
								N.part("Blade", "Cylinder", { C[1], C[2] + k * d[2], C[3] + k * d[3] }, N.axisAngle(0, -d[3], d[2], tilt),
									{ 1.0, 2 * r, 2 * r }),
							})
						end
					end
				end
			end
		end
	end
end
print(fmt("%s: %d designs, the build reads up to %.3f%% (%s), 1 %% or more on %d; the base up to %.3f%%", family, count,
	100 * worst, worstWhat, over1, 100 * baseWorst))
print(fmt("the base's most: %s; untilted only %.3f%%", baseWorstWhat, 100 * baseFlat))
