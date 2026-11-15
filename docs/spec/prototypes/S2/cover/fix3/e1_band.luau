--!nocheck
-- m2x-fix-3 E1: V1's sag-band designs on the base and the build: F5 with its pommel a Ball 0.6 across holding 4 Blade
-- Blocks against its true surface or 4 Blade Balls r 0.1; the fixtures' own pommels with 4 such Blocks; a plate inside a
-- Cylinder under its side. Reading, truth, D (each tree's emulator; the truth's row through the build's).
local Lab = require("./lab")
local B, N = Lab.tree("base"), Lab.tree("now")
local fmt = string.format
local S3 = 1 / math.sqrt(3)
local DIRS = { { S3, S3, S3 }, { S3, -S3, S3 }, { S3, S3, -S3 }, { S3, -S3, -S3 } }

local function report(name, parts, first)
	print(name)
	local valid, codes = N.valid(N.copyParts(parts))
	print("  valid: " .. tostring(valid) .. " " .. codes)
	local Pb, Pn = B.prep(parts), N.prep(parts)
	local rb, rn = B.readAll(Pb), N.readAll(Pn)
	local tn = N.truthAll(Pn)
	local kb, kn = B.Sampling.exposure(Pb).kept, N.Sampling.exposure(Pn).kept
	for i = first, #parts do
		print(fmt("  part %2d %-8s: base %s (%s), build %s (%s), truth %s", i, parts[i].shape, B.pct(rb[i]), kb[i] and "kept" or "cleaned",
			N.pct(rn[i]), kn[i] and "kept" or "cleaned", N.pct(tn[i])))
	end
	local Db, Dn, Dt = B.emu(B.copyParts(parts)), N.emu(N.copyParts(parts)), N.emu(N.copyParts(parts), N.truthRow(tn))
	print("  D base:  " .. N.dline(Db))
	print("  D build: " .. N.dline(Dn))
	print("  D truth: " .. N.dline(Dt))
	local w, tier = N.dDiff(Dn, Dt)
	print(fmt("  build against the truth's row: |dD| %.4f, tier %s", w, tostring(tier)))
end

local function blockAlong(L, c, d, rOuter, len, a, slot)
	local rot = L.axisAngle(d[3], 0, -d[1], math.deg(math.acos(d[2])))
	local k = rOuter - len / 2
	return L.part(slot, "Block", { c[1] + k * d[1], c[2] + k * d[2], c[3] + k * d[3] }, rot, { a, len, a })
end

-- V1's test design: F5, its pommel a Ball 0.6 across at (0, 0.3, 0)
local R = 0.3
local f5 = N.repoFixture("F5")
f5[1] = N.part("Pommel", "Ball", { 0, R, 0 }, N.I, { 2 * R, 2 * R, 2 * R })
for _, kind in ipairs({ "Block", "Ball" }) do
	local parts = N.copyParts(f5)
	for _, d in ipairs(DIRS) do
		if kind == "Block" then
			local k = R - 0.011 - 0.1
			table.insert(parts, N.part("Blade", "Block", { k * d[1], R + k * d[2], k * d[3] }, N.axisAngle(d[3], 0, -d[1], math.deg(math.acos(d[2]))), { 0.1, 0.2, 0.1 }))
		else
			local k = R - 0.002 - 0.1
			table.insert(parts, N.part("Blade", "Ball", { k * d[1], R + k * d[2], k * d[3] }, N.I, { 0.2, 0.2, 0.2 }))
		end
	end
	report("F5, pommel Ball 0.6, + 4 Blade " .. kind .. "s in its band", N.renumber(parts), #f5 + 1)
end

-- the fixtures' own pommels (F3, C04, C09): 4 Blade Blocks in the band along (1, ±1, ±1)/√3
for _, fx in ipairs({ { "F3", true }, { "C04", false }, { "C09", false } }) do
	local base = if fx[2] then N.repoFixture(fx[1]) else (N.fixture(fx[1]))
	local bi = 0
	for i, p in ipairs(base) do
		if p.shape == "Ball" and bi == 0 then
			bi = i
		end
	end
	local ball = base[bi]
	local r = math.min(ball.size[1], ball.size[2], ball.size[3]) / 2
	local e = 0.55 * 0.0572 * r
	local a = math.floor(math.sqrt(2 * ((r - 0.0005) ^ 2 - (r - e) ^ 2)) * 1000) / 1000
	local len = math.floor((2 * r - e - 0.03) * 1000) / 1000
	local parts = N.copyParts(base)
	for k = 1, 4 do
		table.insert(parts, blockAlong(N, ball.pos, DIRS[k], r - e, len, a, "Blade"))
	end
	report(fmt("%s + 4 Blade Blocks %.3f x %.3f in its Ball %d (r %.3f), outer faces %.4f deep", fx[1], a, len, bi, r, e), N.renumber(parts), #base + 1)
end

-- a plate inside a Cylinder r 0.3 along X, its outer face e under the side facet 1's middle
for _, e in ipairs({ 0.0003, 0.0006, 0.001 }) do
	local r = 0.3
	local a = math.pi / 32
	local d = { 0, math.cos(a), math.sin(a) }
	local w = 2 * math.sqrt(math.max(0, (r - 1e-4) ^ 2 - (r - e) ^ 2)) * 0.95
	local t = 0.03
	local k = r - e - t / 2
	local parts = {
		N.part("Grip", "Cylinder", { 0, 1, 0 }, N.I, { 1.4, 2 * r, 2 * r }),
		N.part("Blade", "Block", { 0, 1 + k * d[2], k * d[3] }, N.axisAngle(1, 0, 0, math.deg(a)), { 1.2, t, math.max(w, 0.02) }),
	}
	N.renumber(parts)
	local Pb, Pn = B.prep(parts), N.prep(parts)
	print(fmt("plate %.4f wide in a Cylinder r 0.3, depth %.4f: base %s, build %s, truth %s", w, e, B.pct((B.readOf(Pb, 2))),
		N.pct((N.readOf(Pn, 2))), N.pct(N.truth(Pn, 2))))
end
