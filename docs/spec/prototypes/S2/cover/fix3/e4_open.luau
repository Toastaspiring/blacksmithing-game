--!nocheck
-- m2x-fix-3 E4: what is still open against round hiders, in valid swords, against the truth and through the emulator.
--   (a) round fillers wholly inside a round hider, e from its true surface (fixAB (ii)'s hull is loose by its own sag)
--   (b) a flat filler straddling a round hider and another part (its band piece buried by (i))
--   (c) a round filler straddling a round hider and another part (a Ball half in the pommel, half in the grip)
--   (d) a round filler inside the union of two round hiders (two pommel Balls; a pommel Ball and a grip Cylinder)
--   lune run e4_open -- <a | b | c | d>
local Lab = require("./lab")
local process = require("@lune/process")
local B, N = Lab.tree("base"), Lab.tree("now")
local fmt = string.format
local which = process.args[1] or "a"

local function norm(d)
	local l = math.sqrt(d[1] * d[1] + d[2] * d[2] + d[3] * d[3])
	return { d[1] / l, d[2] / l, d[3] / l }
end
local function rotTo(d)
	local ax, az = d[3], -d[1]
	if math.abs(ax) + math.abs(az) < 1e-12 then
		return if d[2] > 0 then N.I else N.axisAngle(1, 0, 0, 180)
	end
	return N.axisAngle(ax, 0, az, math.deg(math.acos(d[2])))
end

local summary = { designs = 0, flips = 0, wrongKept = 0, worstD = 0 }
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
			table.insert(line, fmt("%s %s/%s/%s%s", parts[i].shape, B.pct(rb[i]), N.pct(rn[i]), N.pct(tn[i]),
				if kn[i] ~= (tn[i] >= 0.02) then "!" else ""))
			if kn[i] and tn[i] < 0.02 then
				summary.wrongKept += 1
			end
		end
	end
	local dpart = ""
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

-- F5 with its pommel a Ball 0.6 across at (0, 0.3, 0): the grip Block 0.16 x 0.9 stands on it from y 0.3
local R = 0.3
local PC = { 0, R, 0 }
local function f5big()
	local f5 = N.repoFixture("F5")
	f5[1] = N.part("Pommel", "Ball", PC, N.I, { 2 * R, 2 * R, 2 * R })
	return f5
end
local S3 = 1 / math.sqrt(3)
local DIRS = { { S3, S3, S3 }, { S3, -S3, S3 }, { S3, S3, -S3 }, { S3, -S3, -S3 } }

if which == "a" then
	for _, r in ipairs({ 0.03, 0.04, 0.06, 0.1, 0.15 }) do
		for _, e in ipairs({ 0.0002, 0.0005, 0.001, 0.002, 0.004 }) do
			local parts = f5big()
			for _, d in ipairs(DIRS) do
				local k = R - e - r
				table.insert(parts, N.part("Blade", "Ball", { PC[1] + k * d[1], PC[2] + k * d[2], PC[3] + k * d[3] }, N.I, { 2 * r, 2 * r, 2 * r }))
			end
			report(fmt("(a) F5 + 4 Blade Balls r %.2f in its pommel R 0.3, e %.4f", r, e), parts, 6)
		end
	end
	-- short Blade rods in the pommel, their far rim e from the sphere
	for _, r in ipairs({ 0.03, 0.06 }) do
		for _, e in ipairs({ 0.0002, 0.0005, 0.001, 0.002 }) do
			local parts = f5big()
			local hx = r
			for _, d in ipairs(DIRS) do
				local k = R - e - math.sqrt(r * r + hx * hx)
				table.insert(parts, N.part("Blade", "Cylinder", { PC[1] + k * d[1], PC[2] + k * d[2], PC[3] + k * d[3] }, rotTo(d), { 2 * hx, 2 * r, 2 * r }))
			end
			report(fmt("(a) F5 + 4 Blade rods r %.2f x %.2f in its pommel R 0.3, e %.4f", r, 2 * hx, e), parts, 6)
		end
	end
	-- F3's grip, a Cylinder r 0.065 along Y, with a Blade rod inside it e from its side (parallel), or a Ball
	for _, r in ipairs({ 0.02, 0.03, 0.045 }) do
		for _, e in ipairs({ 0.0002, 0.0005, 0.001, 0.002 }) do
			for _, kind in ipairs({ "Cylinder", "Ball" }) do
				local parts = N.repoFixture("F3")
				local k = 0.065 - e - r
				for _, a in ipairs({ 30, 150 }) do
					local x, z = k * math.cos(math.rad(a)), k * math.sin(math.rad(a))
					if kind == "Cylinder" then
						table.insert(parts, N.part("Blade", "Cylinder", { x, 0.75, z }, N.Z90, { 0.6, 2 * r, 2 * r }))
					else
						table.insert(parts, N.part("Blade", "Ball", { x, 0.75, z }, N.I, { 2 * r, 2 * r, 2 * r }))
					end
				end
				report(fmt("(a) F3 + 2 Blade %ss r %.3f in its grip r 0.065, e %.4f", kind, r, e), parts, 8)
			end
		end
	end
elseif which == "b" or which == "c" then
	-- along d toward the grip's rim (x 0.08 at the pommel's top), the filler's outer side e under the sphere: half under the
	-- grip, half in the pommel's band
	for _, tx in ipairs({ 0.06, 0.08, 0.1 }) do
		local d = norm({ tx, 0.28, 0 })
		for _, e in ipairs({ 0.0002, 0.0005, 0.001, 0.002, 0.004 }) do
			local parts = f5big()
			if which == "b" then
				for _, a in ipairs({ 0.04, 0.08 }) do
					local len = 0.1
					local k = R - e - len / 2
					local dd = if a == 0.04 then d else { -d[1], d[2], d[3] }
					table.insert(parts, N.part("Blade", "Block", { PC[1] + k * dd[1], PC[2] + k * dd[2], PC[3] + k * dd[3] }, rotTo(dd), { a, len, a }))
				end
				report(fmt("(b) F5 + 2 Blade Blocks 0.04 / 0.08 wide straddling the pommel's band and the grip, toward x %.2f, e %.4f", tx, e), parts, 6)
			else
				for _, r in ipairs({ 0.03, 0.05 }) do
					local k = R - e - r
					local dd = if r == 0.03 then d else { -d[1], d[2], d[3] }
					table.insert(parts, N.part("Blade", "Ball", { PC[1] + k * dd[1], PC[2] + k * dd[2], PC[3] + k * dd[3] }, N.I, { 2 * r, 2 * r, 2 * r }))
				end
				report(fmt("(c) F5 + 2 Blade Balls r 0.03 / 0.05 straddling the pommel's band and the grip, toward x %.2f, e %.4f", tx, e), parts, 6)
			end
		end
	end
else
	-- two pommel Balls R2 0.15 at x ±0.1, y 0.3 (they meet in a circle of radius 0.1118 at x = 0); a Blade Ball on the crease
	for _, r in ipairs({ 0.03, 0.05 }) do
		for _, e in ipairs({ 0.0002, 0.0005, 0.001, 0.002, 0.004 }) do
			local parts = N.repoFixture("F5")
			parts[1] = N.part("Pommel", "Ball", { -0.1, 0.17, 0 }, N.I, { 0.3, 0.3, 0.3 })
			table.insert(parts, N.part("Pommel", "Ball", { 0.1, 0.17, 0 }, N.I, { 0.3, 0.3, 0.3 }))
			local s = 0.1118033988749895 - e - r
			for _, dir in ipairs({ { 0, -1 }, { 0.6, -0.8 }, { -0.6, -0.8 } }) do
				table.insert(parts, N.part("Blade", "Ball", { 0, 0.17 + s * dir[2], s * dir[1] }, N.I, { 2 * r, 2 * r, 2 * r }))
			end
			report(fmt("(d) F5 + 2 pommel Balls r 0.15 + 3 Blade Balls r %.2f on their crease, e %.4f", r, e), parts, 7)
		end
	end
	-- F3's pommel Ball r 0.14 at y 0.16 and its grip Cylinder r 0.065 from y 0.3: a Blade Ball in the corner where they meet
	for _, r in ipairs({ 0.02, 0.03 }) do
		for _, e in ipairs({ 0.0002, 0.0005, 0.001, 0.002 }) do
			local parts = N.repoFixture("F3")
			-- the grip's side x = 0.065 meets the sphere at y = 0.16 + √(0.14² − 0.065²)
			local yMeet = 0.16 + math.sqrt(0.14 * 0.14 - 0.065 * 0.065)
			for _, a in ipairs({ 0, 120, 240 }) do
				local c, sn = math.cos(math.rad(a)), math.sin(math.rad(a))
				local x = 0.065 - e - r
				table.insert(parts, N.part("Blade", "Ball", { x * c, yMeet, x * sn }, N.I, { 2 * r, 2 * r, 2 * r }))
			end
			report(fmt("(d) F3 + 3 Blade Balls r %.2f where its pommel Ball meets its grip Cylinder, e %.4f", r, e), parts, 8)
		end
	end
end
print(fmt("%s: %d designs, %d with a tier the truth's row does not have, %d parts kept that truly show under 2 %%, worst |dD| %.4f",
	which, summary.designs, summary.flips, summary.wrongKept, summary.worstD))
