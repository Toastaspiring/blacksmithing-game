--!nocheck
-- V2: the three attack designs as canonical drafts: Canonical.draft accepts them, Analyze.run calls them valid; what the build reads, through the unmodified Analyze. Written to out/attacks.json.
local fs = require("@lune/fs")
local serde = require("@lune/serde")
local V = require("./v1")
local T = V.T
local Canonical = require("./repo/src/shared/Blueprint/Canonical")
local Analyze = require("./repo/src/shared/Physics/Analyze")
local fmt = string.format
local I = V.I
local Geo = require("./repo/src/shared/Definitions/Balance").Geometry

local function hilt(guardW)
	return {
		V.part("Pommel", "Ball", "Pommel", { 0, 0.30, 0 }, I, { 0.30, 0.30, 0.30 }),
		V.part("Grip", "Cylinder", "Grip", { 0, 0.88, 0 }, V.Z90, { 0.90, 0.16, 0.16 }),
		V.part("Guard", "Block", "Guard", { 0, 1.40, 0 }, I, { guardW, 0.16, 0.30 }),
	}
end
local function lines(w, n)
	local out = {}
	local hw = w / n / 2
	for k = 0, n - 1 do
		local c = (2 * k + 1) * hw
		for _, f in ipairs({ -0.75, -0.25, 0.25, 0.75 }) do
			table.insert(out, c + f * hw)
		end
	end
	return out
end
local function slotCycle()
	local left = { Blade = 12, Guard = 8, Grip = 6, Pommel = 4 }
	return function(parts)
		local count = { Blade = 0, Guard = 0, Grip = 0, Pommel = 0 }
		for _, p in ipairs(parts) do count[p.slot] += 1 end
		for _, s in ipairs({ "Blade", "Guard", "Grip", "Pommel" }) do
			if count[s] < left[s] then return s end
		end
		error("no slot")
	end
end
local function frame(W, L, t, c, withCore)
	local y = 1.45 + L / 2
	local parts = hilt(math.max(W + 0.1, 0.5))
	local z = t / 2 + c / 2
	if withCore then
		table.insert(parts, V.part("Core", "Block", "Guard", { 0, y, 0 }, I, { W, L, t }))
	end
	table.insert(parts, V.part("Back", "Block", "Blade", { 0, y, -z }, I, { W, L, c }))
	table.insert(parts, V.part("Tip", "Block", "Blade", { 0, y + L / 2 + 0.02, 0 }, I, { W + 0.08, 0.04, t + 2 * c }))
	table.insert(parts, V.part("Side", "Block", "Blade", { W / 2 + 0.02, y, 0 }, I, { 0.04, L, t + 2 * c }))
	table.insert(parts, V.part("Side", "Block", "Blade", { -W / 2 - 0.02, y, 0 }, I, { 0.04, L, t + 2 * c }))
	return parts, y, z
end
local function crossings(W, L, t, c, na, nb, xs, ys, e, withCore)
	local parts, y, z = frame(W, L, t, c, withCore)
	local slot = slotCycle()
	local cx = { -W / 2 }
	for _, x in ipairs(xs) do
		table.insert(cx, x - W / 2 - e)
		table.insert(cx, x - W / 2 + e)
	end
	table.insert(cx, W / 2)
	local cy = { y - L / 2 }
	for _, yy in ipairs(ys) do
		table.insert(cy, yy - L / 2 + y - e)
		table.insert(cy, yy - L / 2 + y + e)
	end
	table.insert(cy, y + L / 2)
	for i = 1, #cx, 2 do
		for j = 1, #cy, 2 do
			local x0, x1, y0, y1 = cx[i], cx[i + 1], cy[j], cy[j + 1]
			table.insert(parts, V.part("Tile", "Block", slot(parts), { (x0 + x1) / 2, (y0 + y1) / 2, z }, I, { x1 - x0, y1 - y0, c }))
		end
	end
	return parts
end
local function windows(W, L, t, c, nx, ny, m)
	local parts, y, z = frame(W, L, t, c, true)
	parts[4].slot = "Blade" -- the core
	local slot = slotCycle()
	local lx = lines(W, nx)
	for i = 1, #lx, 2 do
		local a, b = lx[i] - W / 2 - m, lx[i + 1] - W / 2 + m
		table.insert(parts, V.part("RibX", "Block", slot(parts), { (a + b) / 2, y, z }, I, { b - a, L, c }))
	end
	local ly = lines(L, ny)
	for j = 1, #ly, 2 do
		local a, b = ly[j] - L / 2 - m + y, ly[j + 1] - L / 2 + m + y
		table.insert(parts, V.part("RibY", "Block", slot(parts), { 0, (a + b) / 2, z }, I, { W, b - a, c }))
	end
	return parts
end
local function step(W, L, t, c, na, nb, row, e, off)
	local parts, y, z = frame(W, L, t, c, true)
	local hw = W / na / 2
	local cx = -W / 2 + hw
	local slits = { cx - 0.75 * hw, cx - 0.25 * hw, cx + 0.25 * hw, cx + 0.75 * hw }
	local edges = { -W / 2 }
	for _, s in ipairs(slits) do
		table.insert(edges, s - e)
		table.insert(edges, s + e)
	end
	table.insert(edges, W / 2)
	local slot = slotCycle()
	for i = 1, #edges - 2, 2 do
		local x0, x1 = edges[i], edges[i + 1]
		table.insert(parts, V.part("Strip", "Block", slot(parts), { (x0 + x1) / 2, y, z }, I, { x1 - x0, L, c }))
	end
	local x0, x1 = edges[#edges - 1], edges[#edges]
	local cut = y - L / 2 + (row - 0.5) * (L / nb)
	table.insert(parts, V.part("Piece", "Block", slot(parts), { (x0 + off + x1) / 2, (y - L / 2 + cut) / 2, z }, I, { x1 - x0 - off, cut - (y - L / 2), c }))
	table.insert(parts, V.part("Piece", "Block", slot(parts), { (x0 + x1) / 2, (cut + y + L / 2) / 2, z }, I, { x1 - x0, y + L / 2 - cut, c }))
	return parts
end

local out = {}
local function show(name, parts, target)
	V.renumber(parts)
	local draft = { schema = 1, name = "attack", type = "Sword", parts = V.copyParts(parts) }
	for _, p in ipairs(draft.parts) do p.label = nil end
	local c = Canonical.draft(draft)
	if not c.ok then
		print(name, "NOT CANONICAL", c.code, c.path)
		return
	end
	local R = Analyze.run(c.value)
	local real, read = V.reads(parts)
	local shares = T.all(parts, 0.0005)
	local row = {}
	local idx
	for i, p in ipairs(parts) do
		row[i] = shares[i] ~= false and shares[i] >= 0.02
		if p.label == target then idx = i end
	end
	local Rv, Rt = V.emu(V.copyParts(parts)), V.emu(V.copyParts(parts), row)
	local w, tier, st = V.dDiff(Rv, Rt)
	print(fmt("%s: %d parts, canonical, Analyze.run valid=%s, cleaned %d | %s id %d: true %.3f %%, read %.3f %%, %s | |dD| %.4f%s", name, #parts, tostring(R.validation.ok), #R.cleaned, target, parts[idx].id, shares[idx] * 100, read[idx] * 100, if real.kept[idx] then "kept" else "CLEANED", w, if tier then " TIER" else ""))
	print("   build " .. V.dline(Rv) .. " | truth's verdict " .. V.dline(Rt))
	table.insert(out, { name = name, target = target, parts = c.value.parts })
end

do
	local W, L = 0.3, 2.6
	local lx, ly = lines(W, 1), lines(L, 9)
	show("crossings, blade 0.30 x 2.60, cheeks 0.03", crossings(W, L, 0.02, 0.03, 1, 9, { lx[2] }, { ly[2], ly[6] }, 0.000005, true), "Core")
	show("crossings, slits 0.001 wide", crossings(W, L, 0.02, 0.03, 1, 9, { lx[2] }, { ly[2], ly[6] }, 0.0005, true), "Core")
end
show("a step of 1e-5, blade 1 x 2, cheeks 0.05", step(1, 2, 0.02, 0.05, 3, 5, 3, 0.000005, 0.00001), "Core")
show("windows between the lines, blade 1 x 2, ribs 0.0005 past", windows(1, 2, 0.02, 0.03, 3, 5, 0.0005), "Core")
fs.writeFile("out/attacks.json", serde.encode("json", out, true))
