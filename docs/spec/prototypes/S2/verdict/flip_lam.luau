--!nocheck
-- V-A (c): a laminated blade. Two cheek plates with a thin core between them, core proud of (or recessed in) the cheeks' edges. When the
-- core is cleaned the cheeks' chords split at the gap, so Thinness and Volume move far more than the 2 % the core shows.
local process = require("@lune/process")
local Sampling = require("./tree/src/shared/Physics/Sampling")
local V = require("./variants")
local VARIANT = process.args[1] or "A"
V.apply(Sampling, VARIANT)
Sampling.CFG.verdictOnly = true
local Shapes = require("./tree/src/shared/Physics/Shapes")
local EmuReal = require("./proto/analyze_build")
local Emu = { run = function(a, b)
	Sampling.CFG.verdictOnly = false
	local R = EmuReal.run(a, b)
	Sampling.CFG.verdictOnly = true
	return R
end }
local L = require("./lib")
local fmt = string.format
local I = L.I
local RZ90 = { 0, 0, 0.70710678118654757, 0.70710678118654757 }

local function hilt()
	return {
		{ id = 1, label = "Pommel", shape = "Ball", slot = "Pommel", material = "Iron", pos = { 0, 0.30, 0 }, rot = I, size = { 0.30, 0.30, 0.30 } },
		{ id = 2, label = "Grip", shape = "Cylinder", slot = "Grip", material = "Iron", pos = { 0, 0.88, 0 }, rot = RZ90, size = { 0.90, 0.16, 0.16 } },
		{ id = 3, label = "Guard", shape = "Block", slot = "Guard", material = "Iron", pos = { 0, 1.40, 0 }, rot = I, size = { 1.10, 0.16, 0.30 } },
	}
end

-- cheeks at z = ±(k/2 + c/2), core between, proud by p at ±X; blade from y = 1.45 to 1.45 + l. topCap: a thin Blade plate over the top rim
local function blade(w, l, c, k, p, topCap)
	local y = 1.45 + l / 2
	local parts = {
		{ id = 4, label = "CheekA", shape = "Block", slot = "Blade", material = "Iron", pos = { 0, y, k / 2 + c / 2 }, rot = I, size = { w, l, c } },
		{ id = 5, label = "CheekB", shape = "Block", slot = "Blade", material = "Iron", pos = { 0, y, -(k / 2 + c / 2) }, rot = I, size = { w, l, c } },
	}
	if topCap then
		table.insert(parts, { id = 6, label = "Top", shape = "Block", slot = "Blade", material = "Iron", pos = { 0, 1.45 + l + 0.02, 0 }, rot = I, size = { w, 0.04, k + 2 * c } })
	end
	table.insert(parts, { id = 7, label = "Core", shape = "Block", slot = "Blade", material = "Steel", pos = { 0, y, 0 }, rot = I, size = { w + 2 * p, l, k } })
	return parts
end

local function fill(parts, n)
	-- enclosed in the cheeks (they are the large faces, so this raises the ladder fastest) and in the guard
	local out = {}
	local counts = L.slotCounts(parts)
	local a, b
	for _, p in ipairs(parts) do
		if p.label == "CheekA" then a = p elseif p.label == "CheekB" then b = p end
	end
	for j = 1, n do
		if #parts + #out >= 24 then break end
		local slot = L.freeSlot(counts, "Blade")
		if slot == nil then break end
		counts[slot] += 1
		local host = if j % 2 == 1 then a else b
		local f = 0.9 - 0.01 * j
		-- thin hosts: at least MIN_DIM thick and still strictly inside
		local q = L.shrunk(host, f, 100 + j, slot)
		q.size[3] = math.max(q.size[3], 0.02)
		table.insert(out, q)
	end
	return out
end

local function dline(R)
	local t = {}
	for _, s in ipairs(R.steps) do
		table.insert(t, fmt("%s %.4f %s", string.sub(s.step, 1, 2), s.d, string.sub(s.tier, 1, 1)))
	end
	return table.concat(t, ", ")
end

local rows = {}
local designs, flipCount = 0, 0
for _, w in ipairs({ 0.3, 0.4, 0.5, 0.6, 0.8, 1.0, 1.2 }) do
	for _, l in ipairs({ 2.0, 2.5, 3.0 }) do
		for _, c in ipairs({ 0.02, 0.025, 0.03, 0.04, 0.05 }) do
			for _, k in ipairs({ 0.02, 0.03, 0.04 }) do
				for _, p in ipairs({ -0.02, -0.01, 0, 0.003, 0.005, 0.0075, 0.01, 0.0125, 0.015, 0.02, 0.03 }) do
					for _, cap in ipairs({ false, true }) do
						local base = hilt()
						for _, q in ipairs(blade(w, l, c, k, p, cap)) do table.insert(base, q) end
						L.renumber(base)
						if L.quickValid(base) then
							designs += 1
							local coreIdx = #base
							local P0 = L.prep(base)
							local ex0 = Sampling.exposure(P0)
							local e0 = ex0.visibleArea[coreIdx] / P0[coreIdx].area
							for _, n in ipairs({ 1, 2, 3, 4, 6, 9, 12, 15 }) do
								local parts = L.copyParts(base)
								for _, q in ipairs(fill(base, n)) do table.insert(parts, q) end
								L.renumber(parts)
								if L.quickValid(parts) then
									local P1 = L.prep(parts)
									local ex1 = Sampling.exposure(P1)
									local allClean = true
									for i = #base + 1, #parts do
										if ex1.kept[i] then allClean = false end
									end
									local same = true
									for i = 1, #base - 1 do
										if ex1.kept[i] ~= ex0.kept[i] then same = false end
									end
									if allClean and same and ex1.kept[coreIdx] ~= ex0.kept[coreIdx] then
										flipCount += 1
										local R0 = Emu.run({ name = "a", parts = base }, { measureInvalid = true, build = true })
										local R1 = Emu.run({ name = "b", parts = parts }, { measureInvalid = true, build = true })
										local worst, tier = 0, false
										for si, st in ipairs(R0.steps) do
											worst = math.max(worst, math.abs(st.d - R1.steps[si].d))
											tier = tier or st.tier ~= R1.steps[si].tier
										end
										table.insert(rows, { w = w, l = l, c = c, k = k, p = p, cap = cap, n = #parts - #base, e0 = e0, e1 = ex1.visibleArea[coreIdx] / P1[coreIdx].area, h0 = ex0.hSurf, h1 = ex1.hSurf, worst = worst, tier = tier, a = dline(R0), b = dline(R1), kept0 = ex0.kept[coreIdx], valid = R0.valid and R1.valid })
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
table.sort(rows, function(a, b) return a.worst > b.worst end)
print(VARIANT, designs, "designs", flipCount, "flips")
local tiers = 0
for _, r in ipairs(rows) do if r.tier then tiers += 1 end end
print(VARIANT, "tier flips", tiers)
for i = 1, math.min(25, #rows) do
	local r = rows[i]
	print(fmt("w %.2f l %.1f cheek %.3f core %.3f proud %+.4f cap %s, +%2d hidden: core %s, e %.2f%% -> %.2f%%, hSurf %.3f -> %.3f, |dD| %.4f%s\n    %s\n -> %s", r.w, r.l, r.c, r.k, r.p, tostring(r.cap), r.n, if r.kept0 then "cleaned" else "kept", r.e0 * 100, r.e1 * 100, r.h0, r.h1, r.worst, if r.tier then " TIER" else "", r.a, r.b))
end
