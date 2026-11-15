--!nocheck
-- V-A (c): directed search for kept-set flips on the calibration swords. X: a block inside a host, poking out of one face by t.
-- F: blocks inside the largest hosts, away from X's protruding end, as many as the slots allow. A flip: X's verdict differs between K + X
-- and K + X + F while all of F is cleaned. Effect: D (emulated) of the two designs.
-- args: seed, fixture filter (prefix or "all")
local process = require("@lune/process")
local Sampling = require("./tree/src/shared/Physics/Sampling")
local Shapes = require("./tree/src/shared/Physics/Shapes")
local Emu = require("./proto/analyze_build")
local L = require("./lib")
local fmt = string.format

local seed = tonumber(process.args[1]) or 1
local filter = process.args[2] or "all"
local V = require("./variants")
local VARIANT = process.args[3] or "A"
V.apply(Sampling, VARIANT)
Sampling.CFG.verdictOnly = true
local realEmu = Emu.run
local function emuRun(a, b)
	Sampling.CFG.verdictOnly = false
	local R = realEmu(a, b)
	Sampling.CFG.verdictOnly = true
	return R
end
local rng = L.rng(seed)
local I = L.I

local function fixturesToTry()
	local out = {}
	for _, b in ipairs(L.fixtures()) do
		local tag = string.sub(b.name, 1, 1)
		if (tag == "C" or tag == "F") and (filter == "all" or string.sub(b.name, 1, #filter) == filter) then
			table.insert(out, b)
		end
	end
	return out
end

-- X: same frame as host, half extents = fractions of the host's, centre moved along local axis `ax` (1..3) sign `s` so that it pokes t
local function makeX(host, frac, ax, s, t, slot, id)
	local size = { host.size[1] * frac[1], host.size[2] * frac[2], host.size[3] * frac[3] }
	size[1] = math.max(size[1], 0.02)
	size[2] = math.max(size[2], 0.02)
	size[3] = math.max(size[3], 0.02)
	local off = { 0, 0, 0 }
	off[ax] = s * (host.size[ax] / 2 - size[ax] / 2 + t)
	local P = Shapes.prepare(host, 1)
	local x = host.pos[1] + off[1] * P.ux + off[2] * P.vx + off[3] * P.wx
	local y = host.pos[2] + off[1] * P.uy + off[2] * P.vy + off[3] * P.wy
	local z = host.pos[3] + off[1] * P.uz + off[2] * P.vz + off[3] * P.wz
	return { id = id, label = "X", slot = slot, shape = "Block", material = "Iron", pos = { x, y, z }, rot = { host.rot[1], host.rot[2], host.rot[3], host.rot[4] }, size = size }
end

-- filler inside the largest Block hosts, big ones first: raises the ladder's estimate fast. Keeps off the poke by shrinking about the host's centroid.
local function makeFiller(parts, n)
	-- the budget's channel: hidden copies of X inside X, each a little smaller: near every sample of X, they hide nothing of it
	local X
	for _, p in ipairs(parts) do
		if p.label == "X" then X = p end
	end
	local counts = L.slotCounts(parts)
	local out = {}
	for k = 1, n do
		if #parts + #out >= 24 then break end
		local slot = L.freeSlot(counts, "Blade")
		if slot == nil then break end
		local f = 0.985 - 0.012 * k
		local q = L.shrunk(X, f, 100 + k, slot)
		if q.size[1] < 0.02 or q.size[2] < 0.02 or q.size[3] < 0.02 then break end
		counts[slot] += 1
		table.insert(out, q)
	end
	return out
end

local function exposureOf(parts)
	local P = L.prep(parts)
	return Sampling.exposure(P), P
end

local found = {}
local tested, flipsTotal, xTried, windows = 0, 0, 0, 0
local FILL_COUNTS = { 1, 2, 3, 4, 6, 9, 12, 15, 18, 23 }
local FRACS = {
	{ 0.3, 0.97, 0.3 }, { 0.5, 0.97, 0.5 }, { 0.8, 0.97, 0.5 }, { 0.3, 0.8, 0.3 }, { 0.5, 0.5, 0.5 }, { 0.8, 0.8, 0.8 }, { 0.95, 0.95, 0.5 }, { 0.5, 0.95, 0.95 }, { 0.95, 0.5, 0.95 },
	{ 0.1, 0.97, 0.3 }, { 0.3, 0.97, 0.1 }, { 0.97, 0.97, 0.3 },
}

local function designOf(K, X, n)
	local base = L.copyParts(K)
	table.insert(base, X)
	if n == 0 then
		return base, 0
	end
	local F = makeFiller(base, n)
	if F == nil then
		return base, 0
	end
	for _, f in ipairs(F) do
		table.insert(base, f)
	end
	return base, #F
end

-- the poke at which X's verdict changes, for a given filler count (nil when it does not change on [0, 0.3] or the design breaks a rule)
local function crossing(K, host, frac, ax, s, n)
	local function keptAt(t)
		local X = makeX(host, frac, ax, s, t, host.slot, 50)
		local parts = designOf(K, X, n)
		if not L.quickValid(parts) then
			return nil
		end
		tested += 1
		local ex = exposureOf(parts)
		return ex.kept[#K + 1]
	end
	local lo, hi = 0, 0.3
	local a, b = keptAt(lo), keptAt(hi)
	if a == nil then return nil end
	while b == nil and hi > 0.01 do
		hi /= 2
		b = keptAt(hi)
	end
	if b == nil or a == b then return nil end
	for _ = 1, 13 do
		local mid = (lo + hi) / 2
		local c = keptAt(mid)
		if c == nil then return nil end
		if c == a then lo = mid else hi = mid end
	end
	return (lo + hi) / 2, a
end

for _, b in ipairs(fixturesToTry()) do
	local K = L.copyParts(b.parts)
	L.renumber(K)
	for hi, host in ipairs(K) do
		if host.shape == "Block" and #K < 24 then
			for _, frac in ipairs(FRACS) do
				for ax = 1, 3 do
					for s = -1, 1, 2 do
						xTried += 1
						local t0 = crossing(K, host, frac, ax, s, 0)
						local nMax = 24 - #K - 1
						local t1 = if t0 then crossing(K, host, frac, ax, s, nMax) else nil
						if t0 and t1 and math.abs(t0 - t1) > 2e-4 then
							windows += 1
							-- the middle of the window, and the smallest filler count that flips it
							local t = (t0 + t1) / 2
							local X = makeX(host, frac, ax, s, t, host.slot, 50)
							local base = designOf(K, X, 0)
							local ex0, P0 = exposureOf(base)
							local xi = #K + 1
							local e0 = ex0.visibleArea[xi] / P0[xi].area
							for _, n in ipairs(FILL_COUNTS) do
								if n <= nMax then
									local filled, nf = designOf(K, X, n)
									local ex1, P1 = exposureOf(filled)
									local allClean = true
									for i = #base + 1, #filled do
										if ex1.kept[i] then allClean = false end
									end
									local same = true
									for i = 1, #K do
										if ex1.kept[i] ~= ex0.kept[i] then same = false end
									end
									if allClean and same and ex1.kept[xi] ~= ex0.kept[xi] then
										flipsTotal += 1
										local e1 = ex1.visibleArea[xi] / P1[xi].area
										local R0 = emuRun({ name = "a", parts = base }, { measureInvalid = true, build = true })
										local R1 = emuRun({ name = "b", parts = filled }, { measureInvalid = true, build = true })
										local line = {}
										local worst, tierFlip = 0, false
										for si, st in ipairs(R0.steps or {}) do
											local o = R1.steps[si]
											local dd = o.d - st.d
											if math.abs(dd) > worst then worst = math.abs(dd) end
											if st.tier ~= o.tier then tierFlip = true end
											table.insert(line, fmt("%s %.4f->%.4f", string.sub(st.step, 1, 2), st.d, o.d))
										end
										table.insert(found, { name = string.sub(b.name, 1, 3), host = host.label, frac = frac, ax = ax, s = s, t = t, t0 = t0, t1 = t1, n = nf, e0 = e0, e1 = e1, h0 = ex0.hSurf, h1 = ex1.hSurf, hk = ex1.hKept, worst = worst, tier = tierFlip, line = table.concat(line, " "), kept0 = ex0.kept[xi], valid = R0.valid and R1.valid })
										break
									end
								end
							end
						end
					end
				end
			end
		end
	end
end
table.sort(found, function(a, c) return a.worst > c.worst end)
print(fmt("%s %s: %d X placements, %d designs tested, %d with a window, %d flips", VARIANT, filter, xTried, tested, windows, flipsTotal))
local tiers = 0
for _, f in ipairs(found) do if f.tier then tiers += 1 end end
print(fmt("%s %s: tier flips: %d", VARIANT, filter, tiers))
for i = 1, math.min(40, #found) do
	local f = found[i]
	print(fmt("%s host %-9s X frac (%.2f %.2f %.2f) axis %d%s poke %.4f (window %.4f..%.4f), +%2d filler: %s X, e %.2f%% -> %.2f%%, hSurf %.3f -> %.3f (hKept %.3f), |dD| %.4f%s %s %s", f.name, f.host, f.frac[1], f.frac[2], f.frac[3], f.ax, if f.s > 0 then "+" else "-", f.t, f.t0, f.t1, f.n, if f.kept0 then "cleans" else "keeps", f.e0 * 100, f.e1 * 100, f.h0, f.h1, f.hk, f.worst, if f.tier then " TIER" else "", f.line, if f.valid then "" else "(invalid)"))
end
