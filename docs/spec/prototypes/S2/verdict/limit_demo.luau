--!nocheck
-- m2r5: what hidden parts can still reach under the recommended rule. Each row: K, K + H, the true shares (oracle), the verdicts, D per step (emulator). args: variant
local process = require("@lune/process")
local Sampling = require("./tree/src/shared/Physics/Sampling")
local Shapes = require("./tree/src/shared/Physics/Shapes")
local Emu = require("./proto/analyze_build")
local O = require("./oracle")
local L = require("./lib")
local V = require("./variants")
local Sets = require("./sets")
local fmt = string.format
local I = L.I
local RZ90 = { 0, 0, 0.70710678118654757, 0.70710678118654757 }

local variant = process.args[1] or "P"
V.apply(Sampling, variant)

local function dline(R)
	local t = {}
	for _, s in ipairs(R.steps) do
		table.insert(t, fmt("%s %.4f %s", string.sub(s.step, 1, 2), s.d, string.sub(s.tier, 1, 1)))
	end
	return table.concat(t, ", ")
end

local function view(parts, focus)
	L.renumber(parts)
	local P = L.prep(parts)
	local ex = Sampling.exposure(P)
	local shares = O.all(P)
	local R = Emu.run({ name = "x", parts = parts }, { measureInvalid = true, build = true })
	local t = {}
	for _, label in ipairs(focus) do
		for i, p in ipairs(parts) do
			if p.label == label then
				table.insert(t, fmt("%s true %.2f%% %s", label, (shares[i] or 0) * 100, if ex.kept[i] then "kept" else "CLEANED"))
			end
		end
	end
	return R, table.concat(t, ", "), #ex.cleaned
end

local function compare(name, K, H, focus)
	local a = L.copyParts(K)
	local b = L.copyParts(K)
	for _, h in ipairs(H) do
		table.insert(b, L.copyPart(h))
	end
	if not L.quickValid(a) or not L.quickValid(b) then
		print(name, "does not fit the rules")
		return
	end
	local Ra, ta = view(a, focus)
	local Rb, tb = view(b, focus)
	local worst, tier = 0, false
	for i, s in ipairs(Ra.steps) do
		worst = math.max(worst, math.abs(s.d - Rb.steps[i].d))
		tier = tier or s.tier ~= Rb.steps[i].tier
	end
	print(fmt("%s\n   K      %s | %s\n   K + H  %s | %s\n   |dD| %.4f%s", name, ta, dline(Ra), tb, dline(Rb), worst, if tier then " TIER" else ""))
end

local function hilt()
	return {
		{ id = 1, label = "Pommel", shape = "Ball", slot = "Pommel", material = "Iron", pos = { 0, 0.30, 0 }, rot = I, size = { 0.30, 0.30, 0.30 } },
		{ id = 2, label = "Grip", shape = "Cylinder", slot = "Grip", material = "Iron", pos = { 0, 0.88, 0 }, rot = RZ90, size = { 0.90, 0.16, 0.16 } },
		{ id = 3, label = "Guard", shape = "Block", slot = "Guard", material = "Iron", pos = { 0, 1.40, 0 }, rot = I, size = { 1.10, 0.16, 0.30 } },
	}
end

-- 1. a laminated blade whose core shows just over 2 %; H, a wider sheet in the same gap, shows under 2 % of itself and covers the core's rims: both are Enclosed
for _, def in ipairs({ { 1.2, 2.5, 0.05, 0.02, 0.90, 1.15 }, { 1.2, 2.5, 0.05, 0.02, 0.95, 1.18 }, { 1.2, 3.0, 0.03, 0.02, 0.90, 1.15 }, { 1.0, 2.5, 0.05, 0.02, 0.85, 1.02 } }) do
	local w, l, c, k, wc, wh = def[1], def[2], def[3], def[4], def[5], def[6]
	local y = 1.45 + l / 2
	local K = hilt()
	table.insert(K, { label = "CheekA", shape = "Block", slot = "Blade", material = "Iron", pos = { 0, y, k / 2 + c / 2 }, rot = I, size = { w, l, c } })
	table.insert(K, { label = "CheekB", shape = "Block", slot = "Blade", material = "Iron", pos = { 0, y, -(k / 2 + c / 2) }, rot = I, size = { w, l, c } })
	table.insert(K, { label = "Top", shape = "Block", slot = "Blade", material = "Iron", pos = { 0, 1.45 + l + 0.02, 0 }, rot = I, size = { w, 0.04, k + 2 * c } })
	table.insert(K, { label = "LamCore", shape = "Block", slot = "Blade", material = "Steel", pos = { 0, y, 0 }, rot = I, size = { wc, l, k } })
	local H = { { label = "Sheet", shape = "Block", slot = "Blade", material = "Iron", pos = { 0, y, 0 }, rot = I, size = { wh, l, k } } }
	compare(fmt("(1) laminate %.1f x %.1f, cheeks %.3f, core %.3f wide %.2f; H a sheet %.2f wide in the same gap", w, l, c, k, wc, wh), K, H, { "LamCore", "Sheet" })
end

do
	local best, bestTier = nil, nil
	for _, w in ipairs({ 1.1, 1.2, 1.3, 1.4 }) do
		for _, l in ipairs({ 1.5, 2.0, 2.5, 3.0 }) do
			for _, c in ipairs({ 0.025, 0.03, 0.04, 0.05, 0.06, 0.08, 0.1 }) do
				for _, wc in ipairs({ 0.8, 0.85, 0.9, 0.95 }) do
					local k = 0.02
					local wh = w - 0.02
					local y = 1.45 + l / 2
					local K = hilt()
					table.insert(K, { label = "CheekA", shape = "Block", slot = "Blade", material = "Iron", pos = { 0, y, k / 2 + c / 2 }, rot = I, size = { w, l, c } })
					table.insert(K, { label = "CheekB", shape = "Block", slot = "Blade", material = "Iron", pos = { 0, y, -(k / 2 + c / 2) }, rot = I, size = { w, l, c } })
					table.insert(K, { label = "Top", shape = "Block", slot = "Blade", material = "Iron", pos = { 0, 1.45 + l + 0.02, 0 }, rot = I, size = { w, 0.04, k + 2 * c } })
					table.insert(K, { label = "LamCore", shape = "Block", slot = "Blade", material = "Steel", pos = { 0, y, 0 }, rot = I, size = { wc, l, k } })
					local b = L.copyParts(K)
					table.insert(b, { label = "Sheet", shape = "Block", slot = "Blade", material = "Iron", pos = { 0, y, 0 }, rot = I, size = { wh, l, k } })
					if L.quickValid(K) and L.quickValid(b) then
						L.renumber(K)
						L.renumber(b)
						local e0, e1 = Sampling.exposure(L.prep(K)), Sampling.exposure(L.prep(b))
						if e0.kept[#K] and not e1.kept[#K] and not e1.kept[#b] then
							local Ra = Emu.run({ name = "x", parts = K }, { measureInvalid = true, build = true })
							local Rb = Emu.run({ name = "x", parts = b }, { measureInvalid = true, build = true })
							local worst, tier = 0, false
							for i, st in ipairs(Ra.steps) do
								worst = math.max(worst, math.abs(st.d - Rb.steps[i].d))
								tier = tier or st.tier ~= Rb.steps[i].tier
							end
							local row = { w = w, l = l, c = c, wc = wc, worst = worst, a = dline(Ra), b = dline(Rb), tier = tier, K = K, H = b }
							if not best or worst > best.worst then best = row end
							if tier and (not bestTier or worst > bestTier.worst) then bestTier = row end
						end
					end
				end
			end
		end
	end
	for _, r in ipairs({ best or false, bestTier or false }) do
		if r then
			print(fmt("(1') sweep: cheeks %.1f x %.1f x %.3f, core %.2f wide, sheet %.2f wide: |dD| %.4f%s | K: %s | K + H: %s", r.w, r.l, r.c, r.wc, r.w - 0.02, r.worst, if r.tier then " TIER" else "", r.a, r.b))
			local Pb = L.prep(r.H)
			local sh = O.all(Pb)
			local Pk = L.prep(r.K)
			local sk = O.all(Pk)
			print(fmt("   true: core in K %.2f %%; in K + H core %.2f %%, sheet %.2f %%", sk[#r.K] * 100, sh[#r.K] * 100, sh[#r.H] * 100))
		end
	end
end

-- 2. a plate showing on a real sword; H, larger, buried, its rim just past the plate's, hides what the plate shows
local c05
for _, b in ipairs(Sets.bases()) do
	if b.tag == "C05" then c05 = b end
end
do
	local K = L.copyParts(c05.parts)
	-- X: a strip along the cleaver's +X rim, 0.02 thick, poking 0.003 past the blade
	table.insert(K, { label = "X", shape = "Block", slot = "Blade", material = "Iron", pos = { 0.75 + 0.003 - 0.1, 2.58, 0 }, rot = I, size = { 0.2, 1.6, 0.02 } })
	-- H: a sheet inside the blade, same thickness, its rim 0.001 past X's rim
	local H = { { label = "Sheet", shape = "Block", slot = "Blade", material = "Iron", pos = { 0.75 + 0.004 - 0.5, 2.58, 0 }, rot = I, size = { 1.0, 1.8, 0.02 } } }
	compare("(2) C05 + a strip poking 0.003 past the rim; H a sheet 1.0 x 1.8 x 0.02 inside the blade, rim 0.001 further", K, H, { "X", "Sheet" })
end

-- 3. hidden copies inside a part, near every sample: they reach nothing with no budget (with one they burn it)
do
	local c09
	for _, b in ipairs(Sets.bases()) do
		if b.tag == "C09" then c09 = b end
	end
	local K = L.copyParts(c09.parts)
	table.insert(K, { label = "X", shape = "Block", slot = "Blade", material = "Iron", pos = { -0.03, 2.6, 0 }, rot = I, size = { 0.12, 2, 0.05 } })
	local H = {}
	local slots = { "Guard", "Guard", "Guard", "Blade", "Blade", "Blade" }
	for j = 1, 5 do
		local g = 0.8 - 0.01 * j
		table.insert(H, { label = "Fill", shape = "Block", slot = slots[j], material = "Iron", pos = { 0, 2.6, 0 }, rot = I, size = { 0.12 * g, 2.4 * g, 0.06 * g } })
	end
	compare("(3) C09 + the verifier's plate 0.12 x 2 x 0.05, + 5 blocks hidden in the core", K, H, { "X" })
end

-- 4. a filler with a hair out: a false kept. A sheet inside the cleaver's blade with its rim 0.0005 past the blade's: true about 1 %, what does keeping it do?
do
	local K = L.copyParts(c05.parts)
	for _, p in ipairs({ 0.0005, 0.001, 0.002, 0.004 }) do
		local H = { { label = "Hair", shape = "Block", slot = "Blade", material = "Iron", pos = { 0.25 + p, 2.58, 0 }, rot = I, size = { 1.0, 2.0, 0.02 } } }
		compare(fmt("(4) C05 + a buried sheet 1.0 x 2.0 x 0.02, its rim %.4f past the blade's", p), K, H, { "Hair" })
	end
end
