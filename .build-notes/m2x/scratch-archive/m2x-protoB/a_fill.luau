--!nocheck
-- (a) My own hidden fill: K from fixtures and a sweep of bases; F of every kind inside a host or flush with its faces or touching its rim from inside, in front of K or among it.
-- For each design: does K's kept row change? If not, are K's measure and ownership the same to the bit? If yes, does the truth flip too, and what does D do?
-- args: seed count
local process = require("@lune/process")
local L = require("./lib")
local T = L.T
local fmt = string.format
local Sampling, Shapes, Force = L.Sampling, L.Shapes, L.Force
local MassProps = require("./repo/src/shared/Physics/MassProps")
local EquipmentTypes = require("./repo/src/shared/Definitions/EquipmentTypes")
local seed = tonumber(process.args[1]) or 1
local count = tonumber(process.args[2]) or 200
math.randomseed(seed)
local rnd, rint = math.random, math.random
local function range(a, b) return a + (b - a) * rnd() end
T.SPACING, T.MAX_LINES = 0.002, 1000

local NAMES = { "F1", "F2", "F3", "F4", "F5", "C01", "C02 Arming (Iron)", "C04", "C05", "C06", "C07", "C08", "C09", "C10", "C11", "C12", "C13", "C14", "C15", "P1", "P2", "P3", "P4", "P5" }
local BASES = {}
for _, n in ipairs(NAMES) do
	local ok, parts = pcall(L.fixture, n)
	if ok then table.insert(BASES, { name = n, parts = parts }) end
end

local MAX = { Blade = 12, Guard = 8, Grip = 6, Pommel = 4 }
local function freeSlot(parts)
	local c = { Blade = 0, Guard = 0, Grip = 0, Pommel = 0 }
	for _, p in ipairs(parts) do c[p.slot] += 1 end
	local order = { "Pommel", "Grip", "Guard", "Blade" }
	-- a random slot with room
	local list = {}
	for _, s in ipairs(order) do if c[s] < MAX[s] then table.insert(list, s) end end
	if #list == 0 then return nil end
	return list[rint(1, #list)]
end

local function randomQuat()
	return L.axisAngle(range(-1, 1), range(-1, 1), range(-1, 1) + 1e-3, range(0, 360))
end

local KINDS = { "inner", "flushFace", "flushEdge", "copy", "dust", "innerTurned", "thinSheet", "poke", "poke", "poke", "poke" }
local function filler(parts)
	local slot = freeSlot(parts)
	if not slot then return nil end
	local host
	for _ = 1, 20 do
		host = parts[rint(1, #parts)]
		if host.shape == "Block" then break end
	end
	local kind = KINDS[rint(1, #KINDS)]
	local P = Shapes.prepare(host, 1)
	if kind == "copy" then
		local c = L.copyPart(host)
		-- a copy in a slot that comes after its original's by name, or the same
		c.slot = host.slot
		local cnt = 0
		for _, p in ipairs(parts) do if p.slot == c.slot then cnt += 1 end end
		if cnt >= MAX[c.slot] then return nil end
		return c, kind
	elseif kind == "dust" then
		local d = range(0.02, 0.0575)
		return L.part("F", ({ "Block", "Ball", "Wedge", "Cylinder" })[rint(1, 4)], slot, { range(-0.7, 0.7), range(0.1, 4.9), range(-0.25, 0.25) }, randomQuat(), { d, d, d }), kind
	end
	if host.shape ~= "Block" then
		-- a smaller copy about its centroid, inside whatever its shape
		local f = range(0.1, 0.9)
		return L.part("F", host.shape, slot, { P.gx + f * (host.pos[1] - P.gx), P.gy + f * (host.pos[2] - P.gy), P.gz + f * (host.pos[3] - P.gz) }, host.rot, { host.size[1] * f, host.size[2] * f, host.size[3] * f }), "innerShape"
	end
	local sx, sy, sz = host.size[1], host.size[2], host.size[3]
	-- local box inside the host: [lo, hi] per axis
	local function box(lox, hix, loy, hiy, loz, hiz)
		local cx, cy, cz = (lox + hix) / 2, (loy + hiy) / 2, (loz + hiz) / 2
		local x, y, z = Shapes.toWorld(P, cx, cy, cz)
		return L.part("F", "Block", slot, { x, y, z }, host.rot, { hix - lox, hiy - loy, hiz - loz })
	end
	local hx, hy, hz = sx / 2, sy / 2, sz / 2
	local function sub(h, f)
		-- a sub-interval of [-h, h] of relative length f
		local len = 2 * h * f
		local lo = range(-h, h - len)
		return lo, lo + len
	end
	if kind == "inner" then
		local a, b = sub(hx, range(0.3, 0.95))
		local c, d = sub(hy, range(0.3, 0.95))
		local e, f = sub(hz, range(0.3, 0.95))
		if b - a < 0.02 or d - c < 0.02 or f - e < 0.02 then return nil end
		return box(a + 1e-4, b - 1e-4, c + 1e-4, d - 1e-4, e + 1e-4, f - 1e-4), kind
	elseif kind == "flushFace" then
		-- flush with one face of the host, wholly inside
		local a, b = sub(hx, range(0.3, 1))
		local c, d = sub(hy, range(0.3, 1))
		local t = math.max(0.02, 2 * hz * range(0.2, 0.9))
		if t > 2 * hz or b - a < 0.02 or d - c < 0.02 then return nil end
		if rnd() < 0.5 then return box(a, b, c, d, hz - t, hz), kind end
		return box(a, b, c, d, -hz, -hz + t), kind
	elseif kind == "flushEdge" then
		-- flush along an edge: touches the visible rim from inside on 2 faces
		local a, b = sub(hx, range(0.2, 1))
		local tz = math.max(0.02, 2 * hz * range(0.2, 0.9))
		local ty = math.max(0.02, 2 * hy * range(0.05, 0.3))
		if tz > 2 * hz or ty > 2 * hy or b - a < 0.02 then return nil end
		return box(a, b, hy - ty, hy, hz - tz, hz), kind
	elseif kind == "poke" then
		-- a sheet that fills the host's face and pokes a little past 1 to 4 of its rims, by up to 0.02, at a random depth
		local t = math.max(0.02, 2 * hz * range(0.1, 0.8))
		if t > 2 * hz then return nil end
		local z0 = range(-hz, hz - t)
		local p = { 0, 0, 0, 0 }
		for i = 1, 4 do
			if rnd() < 0.5 then p[i] = 10 ^ range(-5, math.log10(0.02)) else p[i] = -1e-4 end
		end
		return box(-hx - p[1], hx + p[2], -hy - p[3], hy + p[4], z0, z0 + t), kind
	elseif kind == "innerTurned" then
		local d = math.min(sx, sy, sz) * range(0.15, 0.4)
		if d < 0.02 then return nil end
		return L.part("F", ({ "Block", "Wedge", "CornerWedge", "Cylinder", "Ball" })[rint(1, 5)], slot, { host.pos[1], host.pos[2], host.pos[3] }, randomQuat(), { d, d, d }), kind
	else -- thinSheet: a thin sheet wholly inside, the size of the host's face
		if 2 * hz < 0.024 then return nil end
		return box(-hx + 1e-4, hx - 1e-4, -hy + 1e-4, hy - 1e-4, -0.01 + range(-1, 1) * (hz - 0.0101), 0.01 + 0), kind
	end
end

local function bitsSame(a, b, n)
	for i = 1, n do
		if a.kept[i] ~= b.kept[i] or a.exposedKept[i] ~= b.exposedKept[i] then return false, "exposed" end
		for j = 1, n do
			if a.contact[i][j] ~= b.contact[i][j] then return false, "contact" end
		end
	end
	return a.hSurf == b.hSurf and a.surfSamples == b.surfSamples and a.subSampled == b.subSampled, "budget"
end

local stats = { designs = 0, sameRow = 0, rowChanged = 0, truthAgrees = 0, measureDiff = 0, ownDiff = 0, kinds = {} }
local worst = {}
local TYPE = EquipmentTypes.get("Sword")
local rankOf = {}
for _, s in ipairs(TYPE.slots) do rankOf[s.id] = s.rank end

for d = 1, count do
	local base = BASES[rint(1, #BASES)]
	local K = L.renumber(L.copyParts(base.parts))
	local nk = #K
	local exK = Sampling.exposure(L.prep(K))
	local keptK = exK.kept
	local fills = {}
	local trial = L.copyParts(K)
	local room = 24 - nk
	local want = rint(1, math.max(1, math.min(room, 8)))
	local kindNames = {}
	for _ = 1, want do
		if #trial >= 24 then break end
		local f, kind = filler(trial)
		if f then
			table.insert(trial, f)
			table.insert(fills, f)
			table.insert(kindNames, kind)
		end
	end
	if #fills > 0 then
		stats.designs += 1
		-- ids: K first, fill after, then the same with the fill in front (lower ids): the same design by the rank
		L.renumber(trial)
		local exF = Sampling.exposure(L.prep(trial))
		local front = {}
		for i = nk + 1, #trial do table.insert(front, L.copyPart(trial[i])) end
		for i = 1, nk do table.insert(front, L.copyPart(trial[i])) end
		L.renumber(front)
		local exFront = Sampling.exposure(L.prep(front))
		-- the verdicts by solid, in both orders: in rank order, so that exact copies (which fall to the index) line up
		local orderOK = true
		do
			local Pa, Pb = L.prep(trial), L.prep(front)
			local _, oa = Sampling.ranked(Pa)
			local _, ob = Sampling.ranked(Pb)
			for r = 1, #trial do
				local ia, ib = oa[r].index, ob[r].index
				if exF.kept[ia] ~= exFront.kept[ib] or exF.exposedKept[ia] ~= exFront.exposedKept[ib] then
					orderOK = false
				end
			end
		end
		if not orderOK then
			print("ORDER DIFFERS", base.name, table.concat(kindNames, ","))
			stats.orderDiff = (stats.orderDiff or 0) + 1
		end
		local changed = false
		for i = 1, nk do
			if exF.kept[i] ~= keptK[i] then changed = true end
		end
		local anyFillKept = false
		for i = nk + 1, #trial do
			if exF.kept[i] then anyFillKept = true end
		end
		if not changed and not anyFillKept then
			stats.sameRow += 1
			local same, why = bitsSame(exF, exK, nk)
			if not same then
				stats.measureDiff += 1
				print("MEASURE DIFFERS", base.name, why, table.concat(kindNames, ","))
			end
			-- ownership of K
			local keptF = exF.kept
			local ownK = MassProps.ownership(L.prep(K), keptK, rankOf)
			local ownF = MassProps.ownership(L.prep(trial), keptF, rankOf)
			for i = 1, nk do
				if ownK.ownedVolume[i] ~= ownF.ownedVolume[i] then
					stats.ownDiff += 1
					print("OWNERSHIP DIFFERS", base.name, i, ownK.ownedVolume[i], ownF.ownedVolume[i], table.concat(kindNames, ","))
					break
				end
			end
		elseif changed then
			stats.rowChanged += 1
			-- the truth on both
			local sK = T.all(K)
			local sF = T.all(trial)
			local tFlip = false
			local parts = {}
			for i = 1, nk do
				local tk = sK[i] ~= false and sK[i] >= 0.02
				local tf = sF[i] ~= false and sF[i] >= 0.02
				if tk ~= tf then tFlip = true end
				if exF.kept[i] ~= keptK[i] then
					table.insert(parts, fmt("%s#%d(%s) true %.2f -> %.2f, kept %s -> %s", tostring(K[i].label), i, K[i].shape, (sK[i] or 0) * 100, (sF[i] or 0) * 100, tostring(keptK[i]), tostring(exF.kept[i])))
				end
			end
			if tFlip then stats.truthAgrees += 1 end
			local Ra, Rb = L.emu(L.copyParts(K)), L.emu(L.copyParts(trial))
			local w, tier, step = L.dDiff(Ra, Rb)
			table.insert(worst, { w = w, tier = tier, text = fmt("%s + %s: %s; |dD| %.4f %s%s; truth flips: %s", base.name, table.concat(kindNames, ","), table.concat(parts, "; "), w, step, if tier then " TIER" else "", tostring(tFlip)) })
		else
			stats.fillKept = (stats.fillKept or 0) + 1
		end
	end
end
table.sort(worst, function(a, b) return a.w > b.w end)
print(fmt("seed %d: designs %d, nothing of K changes %d (measure differs %d, ownership differs %d), a fill part kept with K's row unchanged %d, K's row changed %d (truth flips too %d), order differs %d",
	seed, stats.designs, stats.sameRow, stats.measureDiff, stats.ownDiff, stats.fillKept or 0, stats.rowChanged, stats.truthAgrees, stats.orderDiff or 0))
for i = 1, math.min(12, #worst) do print(worst[i].text) end
