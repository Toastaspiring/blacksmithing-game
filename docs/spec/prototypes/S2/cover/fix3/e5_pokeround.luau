--!nocheck
-- m2x-fix-3 E5: a round filler that pokes out of a round hider by p (the truth: its cap, about p / 2r of a Ball), in valid
-- swords: F5 with its pommel a Ball 0.6 across holding 4 Blade Balls along (1, ±1, ±1)/√3 or the axes; F3's grip
-- Cylinder r 0.065 holding 2 Blade rods or Balls. The reading (base, build), the truth, D against the truth's row.
--   lune run e5_pokeround -- <balls | grip>
local Lab = require("./lab")
local process = require("@lune/process")
local B = Lab.tree("base")
local N = Lab.tree(if process.args[2] then Lab.SCR .. "/m2x-fix-3/" .. process.args[2] else "now")
local fmt = string.format
local which = process.args[1] or "balls"

local summary = { designs = 0, flips = 0, wrongKept = 0, worstD = 0, worstRead = 0 }
local function report(name, parts, first)
	N.renumber(parts)
	local valid, codes = N.valid(N.copyParts(parts))
	local Pb, Pn = B.prep(parts), N.prep(parts)
	local rb, rn = B.readAll(Pb), N.readAll(Pn)
	local tn = N.truthAll(Pn)
	local kn = N.Sampling.exposure(Pn).kept
	local line = {}
	for i = first, #parts do
		if rn[i] ~= false then
			table.insert(line, fmt("%s/%s/%s%s", B.pct(rb[i]), N.pct(rn[i]), N.pct(tn[i]), if kn[i] ~= (tn[i] >= 0.02) then "!" else ""))
			if kn[i] and tn[i] < 0.02 then
				summary.wrongKept += 1
				summary.worstRead = math.max(summary.worstRead, rn[i])
			end
		end
	end
	local dpart
	if valid then
		local Dn, Dt = N.emu(N.copyParts(parts)), N.emu(N.copyParts(parts), N.truthRow(tn))
		local w, tier = N.dDiff(Dn, Dt)
		summary.worstD = math.max(summary.worstD, w)
		if tier then
			summary.flips += 1
		end
		dpart = fmt(" | build %s | truth %s | |dD| %.4f%s", N.dline(Dn), N.dline(Dt), w, if tier then " TIER" else "")
	else
		dpart = " | invalid " .. codes
	end
	summary.designs += 1
	print(fmt("%s: base/build/truth %s%s", name, table.concat(line, ", "), dpart))
end

local function norm(d)
	local l = math.sqrt(d[1] * d[1] + d[2] * d[2] + d[3] * d[3])
	return { d[1] / l, d[2] / l, d[3] / l }
end
local S3 = 1 / math.sqrt(3)
local SETS = {
	diagonal = { { S3, S3, S3 }, { S3, -S3, S3 }, { S3, S3, -S3 }, { S3, -S3, -S3 } },
	axes = { { 1, 0, 0 }, { -1, 0, 0 }, { 0, 0, 1 }, { 0, -1, 0 } },
	odd = { norm({ 1, 2, 3 }), norm({ -2, -1, 1 }), norm({ 3, -1, -2 }), norm({ -1, 1, -3 }) },
}

if which == "balls" then
	local R = 0.3
	local PC = { 0, R, 0 }
	for _, set in ipairs({ "diagonal", "axes", "odd" }) do
		for _, r in ipairs({ 0.06, 0.1, 0.15 }) do
			for _, p in ipairs({ 0.0001, 0.0003, 0.001, 0.002, 0.004 }) do
				local parts = N.repoFixture("F5")
				parts[1] = N.part("Pommel", "Ball", PC, N.I, { 2 * R, 2 * R, 2 * R })
				for _, d in ipairs(SETS[set]) do
					local k = R + p - r
					table.insert(parts, N.part("Blade", "Ball", { PC[1] + k * d[1], PC[2] + k * d[2], PC[3] + k * d[3] }, N.I, { 2 * r, 2 * r, 2 * r }))
				end
				report(fmt("F5 + 4 Blade Balls r %.2f poking %.4f out of its pommel R 0.3 (%s)", r, p, set), parts, 6)
			end
		end
	end
else
	for _, r in ipairs({ 0.03, 0.045 }) do
		for _, p in ipairs({ 0.0001, 0.0003, 0.001, 0.002 }) do
			for _, kind in ipairs({ "Cylinder", "Ball" }) do
				local parts = N.repoFixture("F3")
				local k = 0.065 + p - r
				for _, a in ipairs({ 30, 150 }) do
					local x, z = k * math.cos(math.rad(a)), k * math.sin(math.rad(a))
					if kind == "Cylinder" then
						table.insert(parts, N.part("Blade", "Cylinder", { x, 0.75, z }, N.Z90, { 0.6, 2 * r, 2 * r }))
					else
						table.insert(parts, N.part("Blade", "Ball", { x, 0.75, z }, N.I, { 2 * r, 2 * r, 2 * r }))
					end
				end
				report(fmt("F3 + 2 Blade %ss r %.3f poking %.4f out of its grip r 0.065", kind, r, p), parts, 8)
			end
		end
	end
end
print(fmt("%s: %d designs, %d with a tier the truth's row does not have, %d parts kept that truly show under 2 %% (read up to %.3f%%), worst |dD| %.4f",
	which, summary.designs, summary.flips, summary.wrongKept, 100 * summary.worstRead, summary.worstD))
