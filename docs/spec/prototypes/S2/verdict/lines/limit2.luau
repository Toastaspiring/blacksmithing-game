--!nocheck
-- §17.2's limit rows, on the rule as built: K, K + H, true shares, what each reads, the verdicts, D per step. And the label row, the id orders of C09, and a mirror image's |dD|.
local V = require("./v1")
local T = V.T
local fmt = string.format
local I = V.I

local function view(parts, focus)
	V.renumber(parts)
	local real, read = V.reads(parts)
	local shares = T.all(parts, 0.0005)
	local t = {}
	for _, label in ipairs(focus) do
		for i, p in ipairs(parts) do
			if p.label == label then
				table.insert(t, fmt("%s true %.2f %% read %.2f %% %s", label, (shares[i] or 0) * 100, (read[i] or 0) * 100, if real.kept[i] then "kept" else "CLEANED"))
			end
		end
	end
	return V.emu(V.copyParts(parts)), table.concat(t, ", ")
end
local function compare(name, K, H, focus)
	local b = V.copyParts(K)
	for _, h in ipairs(H) do
		table.insert(b, V.copyPart(h))
	end
	local Ra, ta = view(V.copyParts(K), focus)
	local Rb, tb = view(b, focus)
	local w, tier = V.dDiff(Ra, Rb)
	print(fmt("%s\n   K      %s | %s\n   K + H  %s | %s\n   |dD| %.4f%s", name, ta, V.dline(Ra), tb, V.dline(Rb), w, if tier then " TIER" else ""))
end
local function hilt()
	return {
		V.part("Pommel", "Ball", "Pommel", { 0, 0.30, 0 }, I, { 0.30, 0.30, 0.30 }),
		V.part("Grip", "Cylinder", "Grip", { 0, 0.88, 0 }, V.Z90, { 0.90, 0.16, 0.16 }),
		V.part("Guard", "Block", "Guard", { 0, 1.40, 0 }, I, { 1.10, 0.16, 0.30 }),
	}
end
do
	for _, def in ipairs({ { 1.1, 2.0, 0.06, 0.95, 1.08 }, { 1.2, 2.5, 0.05, 0.90, 1.15 } }) do
		local w, l, c, wc, wh = def[1], def[2], def[3], def[4], def[5]
		local k = 0.02
		local y = 1.45 + l / 2
		local K = hilt()
		table.insert(K, V.part("CheekA", "Block", "Blade", { 0, y, k / 2 + c / 2 }, I, { w, l, c }))
		table.insert(K, V.part("CheekB", "Block", "Blade", { 0, y, -(k / 2 + c / 2) }, I, { w, l, c }))
		table.insert(K, V.part("Top", "Block", "Blade", { 0, 1.45 + l + 0.02, 0 }, I, { w, 0.04, k + 2 * c }))
		table.insert(K, V.part("LamCore", "Block", "Blade", { 0, y, 0 }, I, { wc, l, k }, "Steel"))
		compare(fmt("(1) laminate %.1f x %.1f x %.2f, core %.2f; H a sheet %.2f in the same gap", w, l, c, wc, wh), K, { V.part("Sheet", "Block", "Blade", { 0, y, 0 }, I, { wh, l, k }) }, { "LamCore", "Sheet" })
	end
end
do
	local K = V.fixture("C05")
	table.insert(K, V.part("X", "Block", "Blade", { 0.75 + 0.003 - 0.1, 2.58, 0 }, I, { 0.2, 1.6, 0.02 }))
	compare("(2) C05 + a strip poking 0.003 past the rim; H a sheet 1.0 x 1.8 x 0.02, rim 0.001 further", K, { V.part("Sheet", "Block", "Blade", { 0.75 + 0.004 - 0.5, 2.58, 0 }, I, { 1.0, 1.8, 0.02 }) }, { "X", "Sheet" })
end
do
	local K = V.fixture("C09")
	table.insert(K, V.part("X", "Block", "Blade", { -0.03, 2.6, 0 }, I, { 0.12, 2, 0.05 }))
	local H = {}
	local slots = { "Guard", "Guard", "Guard", "Blade", "Blade", "Blade" }
	for j = 1, 5 do
		local g = 0.8 - 0.01 * j
		table.insert(H, V.part("Fill", "Block", slots[j], { 0, 2.6, 0 }, I, { 0.12 * g, 2.4 * g, 0.06 * g }))
	end
	compare("(3) C09 + a plate 0.12 x 2 x 0.05, + 5 blocks hidden in the core", K, H, { "X" })
end
do
	local K = V.fixture("C05")
	for _, p in ipairs({ 0.0005, 0.001, 0.002, 0.004, 0.006, 0.008 }) do
		compare(fmt("(4) C05 + a buried sheet 1.0 x 2.0 x 0.02, rim %.4f past the blade's", p), K, { V.part("Hair", "Block", "Blade", { 0.25 + p, 2.58, 0 }, I, { 1.0, 2.0, 0.02 }) }, { "Hair" })
	end
end
-- the labels
for _, def in ipairs({ { "F3", 6, "Guard" }, { "C08", 4, "Guard" }, { "F5", 4, "Pommel" }, { "F4", 4, "Guard" } }) do
	local base = V.fixture(def[1])
	local l = V.copyParts(base)
	l[def[2]].slot = def[3]
	local Ra, Rb = V.emu(V.copyParts(base)), V.emu(l)
	local w, tier = V.dDiff(Ra, Rb)
	print(fmt("label %s part %d in %s: |dD| %.4f%s %s -> %s", def[1], def[2], def[3], w, if tier then " TIER" else "", V.dline(Ra), V.dline(Rb)))
end
-- a copy into an earlier slot: a part of the Guard, its copy in the Blade
do
	local base = V.fixture("F3")
	local gi
	for i, p in ipairs(base) do
		if p.slot == "Guard" then gi = i break end
	end
	local c = V.copyParts(base)
	local copy = V.copyPart(base[gi])
	copy.slot = "Blade"
	table.insert(c, copy)
	local l = V.copyParts(base)
	l[gi].slot = "Blade"
	local Ra, Rb, Rc = V.emu(V.copyParts(base)), V.emu(c), V.emu(l)
	print(fmt("F3: a copy of guard part %d in the Blade: %s; relabelled: %s; base %s", gi, V.dline(Rb), V.dline(Rc), V.dline(Ra)))
end
