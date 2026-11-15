--!nocheck
-- fix-4: V2's e5v.luau (m2x-v2-4) on two named trees (TREES=base,now: the first as V2's base, the second its build). E5: round filler poking a hair out of a round part, in valid swords, built here: F5 with its pommel a Ball
-- 0.6 across at (0, 0.3, 0) and 4 Blade Balls r poking p out of it, along 4 directions of a set (V1's diagonals, or
-- seeded random ones in the pommel's upper half, which keep the sword in its hitbox). Per design: valid, the readings
-- (base, build), the truth, D on the build's verdict against D on the truth's row (the build's measure), the base's D.
--   lune run e5v -- <set: diagonal | random> [seed]
local process = require("@lune/process")
local V = require("./vlab")
local TN = string.split(process.env.TREES or "base,now", ",")
local B, N = V.tree(TN[1]), V.tree(TN[2])
local fmt = string.format
local set = process.args[1] or "diagonal"
local state = tonumber(process.args[2] or "1") * 7919 + 17
local function rand(): number
	state = (state * 1103515245 + 12345) % 2147483648
	return state / 2147483648
end

local R = 0.3
local PC = { 0, R, 0 }
local f5 = N.copy(N.Blueprints.core("F5").parts)
f5[1] = N.part("Pommel", "Ball", PC, nil, { 2 * R, 2 * R, 2 * R })

local sum = { designs = 0, valid = 0, flips = 0, flipsBase = 0, wrongKept = 0, worstRead = 0, lowRead = math.huge, worstD = 0 }
local function report(name, parts)
	parts = N.copy(parts)
	local ok = N.valid(parts)
	sum.designs += 1
	if not ok then
		print(name .. ": invalid")
		return
	end
	sum.valid += 1
	local Pb, Pn = B.prep(parts), N.prep(parts)
	local rb, kb = B.reads(Pb)
	local rn, kn = N.reads(Pn)
	local tn, row = N.truth(Pn)
	local cells = {}
	for i = #f5 + 1, #parts do
		local wrong = kn[i] ~= row[i]
		table.insert(cells, fmt("%s/%s/%s%s", V.pct(rb[i]), V.pct(rn[i]), V.pct(tn[i]), if wrong then "!" else ""))
		if kn[i] and not row[i] then
			sum.wrongKept += 1
			sum.worstRead = math.max(sum.worstRead, rn[i])
			sum.lowRead = math.min(sum.lowRead, rn[i])
		end
	end
	local Dn, Dt, Db = N.emu(parts), N.emu(parts, row), B.emu(parts)
	local w, tier = V.dDiff(Dn, Dt)
	local _, tierB = V.dDiff(Db, Dt)
	sum.worstD = math.max(sum.worstD, w)
	if tier then
		sum.flips += 1
	end
	if tierB then
		sum.flipsBase += 1
	end
	print(fmt("%s: base/build/truth %s | build %s | truth %s | base %s | |dD| %.4f%s", name, table.concat(cells, ", "), V.dline(Dn),
		V.dline(Dt), V.dline(Db), w, if tier then " TIER" else ""))
end

local dirsets = {}
if set == "diagonal" then
	dirsets = { V.dirs() }
else
	for _ = 1, 4 do
		local ds = {}
		while #ds < 4 do
			local x, y, z = 2 * rand() - 1, rand(), 2 * rand() - 1
			local l = math.sqrt(x * x + y * y + z * z)
			if l > 0.2 and l <= 1 and y / l > 0.35 then
				table.insert(ds, { x / l, y / l, z / l })
			end
		end
		table.insert(dirsets, ds)
	end
end
for si, ds in ipairs(dirsets) do
	for _, r in ipairs({ 0.06, 0.08, 0.1, 0.12, 0.15 }) do
		for _, p in ipairs({ 0.0001, 0.0005, 0.001, 0.002 }) do
			local parts = N.copy(f5)
			for _, d in ipairs(ds) do
				local k = R + p - r
				table.insert(parts, N.part("Blade", "Ball", { PC[1] + k * d[1], PC[2] + k * d[2], PC[3] + k * d[3] }, nil, { 2 * r, 2 * r, 2 * r }))
			end
			report(fmt("%s %d: 4 Blade Balls r %.2f poking %.4f out", set, si, r, p), parts)
		end
	end
end
print(fmt("%s: %d designs, %d valid; %d valid with a tier the truth's row does not have (the base %d); %d parts kept that truly show under 2 %% (read %.3f–%.3f%%); worst |dD| %.4f",
	set, sum.designs, sum.valid, sum.flips, sum.flipsBase, sum.wrongKept, 100 * sum.lowRead, 100 * sum.worstRead, sum.worstD))
