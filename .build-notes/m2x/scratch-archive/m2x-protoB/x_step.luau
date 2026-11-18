--!nocheck
-- V2: "the family whose lines agree better wins" by a step of 1e-5. 4 hairlines along a family's 4 lines in one column of patches: that family reads 1 and agrees to the bit; the
-- other crosses 4 hairlines, and a slit one hair wider past a patch's middle makes its lines disagree by more than LINES_AGREE. So one whole patch reads as showing, for nothing that shows.
local V = require("./v1")
local T = V.T
local fmt = string.format
local I = V.I

local function hilt()
	return {
		V.part("Pommel", "Ball", "Pommel", { 0, 0.30, 0 }, I, { 0.30, 0.30, 0.30 }),
		V.part("Grip", "Cylinder", "Grip", { 0, 0.88, 0 }, V.Z90, { 0.90, 0.16, 0.16 }),
		V.part("Guard", "Block", "Guard", { 0, 1.40, 0 }, I, { 1.10, 0.16, 0.30 }),
	}
end

local function design(W, L, t, c, na, nb, patchRows, e, step, withCore)
	local y = 1.45 + L / 2
	local parts = hilt()
	local z = t / 2 + c / 2
	if withCore then
		table.insert(parts, V.part("Core", "Block", "Guard", { 0, y, 0 }, I, { W, L, t }))
	end
	table.insert(parts, V.part("Back", "Block", "Blade", { 0, y, -z }, I, { W, L, c }))
	table.insert(parts, V.part("Tip", "Block", "Blade", { 0, y + L / 2 + 0.02, 0 }, I, { W + 0.08, 0.04, t + 2 * c }))
	table.insert(parts, V.part("Side", "Block", "Blade", { W / 2 + 0.02, y, 0 }, I, { 0.04, L, t + 2 * c }))
	table.insert(parts, V.part("Side", "Block", "Blade", { -W / 2 - 0.02, y, 0 }, I, { 0.04, L, t + 2 * c }))
	-- the 4 lines along Y of the first column of patches, in blade coordinates
	local hw = W / na / 2
	local cx = -W / 2 + hw
	local slits = { cx - 0.75 * hw, cx - 0.25 * hw, cx + 0.25 * hw, cx + 0.75 * hw }
	-- strips between them; the strip right of the last slit is split at the middle of a row, its lower piece standing `step` further off
	local edges = { -W / 2 }
	for _, s in ipairs(slits) do
		table.insert(edges, s - e)
		table.insert(edges, s + e)
	end
	table.insert(edges, W / 2)
	for i = 1, #edges - 2, 2 do
		local x0, x1 = edges[i], edges[i + 1]
		table.insert(parts, V.part("Strip", "Block", "Grip", { (x0 + x1) / 2, y, z }, I, { x1 - x0, L, c }))
	end
	local x0, x1 = edges[#edges - 1], edges[#edges]
	-- split points in the rows named
	local cuts = { y - L / 2 }
	local rowH = L / nb
	for _, r in ipairs(patchRows) do
		table.insert(cuts, y - L / 2 + (r - 0.5) * rowH)
	end
	table.insert(cuts, y + L / 2)
	for k = 1, #cuts - 1 do
		local off = if k % 2 == 1 then step else 0
		table.insert(parts, V.part("Piece", "Block", "Blade", { (x0 + off + x1) / 2, (cuts[k] + cuts[k + 1]) / 2, z }, I, { x1 - x0 - off, cuts[k + 1] - cuts[k], c }))
	end
	return parts
end

local function show(name, parts, noCore)
	V.renumber(parts)
	local ok, full = V.valid(V.copyParts(parts))
	local real, read = V.reads(parts)
	local shares = T.all(parts, 0.0005)
	local row, idx = {}, nil
	for i, p in ipairs(parts) do
		row[i] = shares[i] ~= false and shares[i] >= 0.02
		if p.label == "Core" then idx = i end
	end
	local Rv, Rt = V.emu(V.copyParts(parts)), V.emu(V.copyParts(parts), row)
	local w, tier = V.dDiff(Rv, Rt)
	print(fmt("%s: %d parts valid=%s | core true %.3f %% read %.3f %% %s | against truth's verdict |dD| %.4f%s", name, #parts, tostring(ok), shares[idx] * 100, read[idx] * 100, if real.kept[idx] then "kept" else "CLEANED", w, if tier then " TIER" else ""))
	print("   build " .. V.dline(Rv))
	print("   truth " .. V.dline(Rt))
	if noCore then
		V.renumber(noCore)
		local Ra = V.emu(V.copyParts(noCore))
		local w2, t2 = V.dDiff(Ra, Rv)
		print(fmt("   K alone %s, K + F against K |dD| %.4f%s", V.dline(Ra), w2, if t2 then " TIER" else ""))
	end
	if not ok then
		for _, e in ipairs(full.validation.errors) do print("   error", e.code, e.partId, e.slot) end
	end
end

local e = 0.000005
show("1 x 2, no step (the rule's own case)", design(1, 2, 0.02, 0.05, 3, 5, {}, e, 0, true))
show("1 x 2, a step of 1e-5 in 1 row", design(1, 2, 0.02, 0.05, 3, 5, { 3 }, e, 0.00001, true), design(1, 2, 0.02, 0.05, 3, 5, { 3 }, e, 0.00001, false))
show("1 x 2, a step of 1e-5 in 2 rows", design(1, 2, 0.02, 0.05, 3, 5, { 2, 4 }, e, 0.00001, true), design(1, 2, 0.02, 0.05, 3, 5, { 2, 4 }, e, 0.00001, false))
