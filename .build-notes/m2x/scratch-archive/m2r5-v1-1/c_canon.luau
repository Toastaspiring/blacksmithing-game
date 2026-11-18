--!nocheck
-- The attack designs through Blueprint/Canonical: legal input, ids in order, and Analyze.run valid on what comes out.
local V = require("./v1")
local Canonical = require("./tree/src/shared/Blueprint/Canonical")
local Versions = require("./tree/src/shared/Definitions/Versions")
local Sets = require("./b_sets")
local fmt = string.format
local I = V.I
local S45 = 0.70710678118654757
local QP = { S45, 0, 0, S45 }
local function hilt()
	return {
		V.part("Pommel", "Ball", "Pommel", { 0, 0.30, 0 }, I, { 0.30, 0.30, 0.30 }),
		V.part("Grip", "Cylinder", "Grip", { 0, 0.88, 0 }, V.Z90, { 0.90, 0.16, 0.16 }),
		V.part("Guard", "Block", "Guard", { 0, 1.40, 0 }, I, { 1.10, 0.16, 0.30 }),
	}
end
local function apex(label, slot, ax, ay, az, b, h)
	local hx, hy, hz = b / 2, h / 2, b / 2
	return V.part(label, "CornerWedge", slot, { ax - hx, ay - hz, az - hy }, QP, { b, h, b })
end
local function cheeks(w, L, c, k, g, y, oneFace)
	local parts = hilt()
	local sw = (w - g) / 2
	local xc = g / 2 + sw / 2
	table.insert(parts, V.part("Strip", "Block", "Blade", { xc, y, k / 2 + c / 2 }, I, { sw, L, c }))
	table.insert(parts, V.part("Strip", "Block", "Blade", { -xc, y, k / 2 + c / 2 }, I, { sw, L, c }))
	if oneFace then
		table.insert(parts, V.part("Cheek", "Block", "Blade", { 0, y, -k / 2 - c / 2 }, I, { w, L, c }))
	else
		table.insert(parts, V.part("Strip", "Block", "Blade", { xc, y, -k / 2 - c / 2 }, I, { sw, L, c }))
		table.insert(parts, V.part("Strip", "Block", "Blade", { -xc, y, -k / 2 - c / 2 }, I, { sw, L, c }))
	end
	table.insert(parts, V.part("Tip", "Block", "Blade", { 0, 1.45 + L + 0.02, 0 }, I, { w + 0.08, 0.04, k + 2 * c }))
	table.insert(parts, V.part("Side", "Block", "Blade", { w / 2 + 0.02, y, 0 }, I, { 0.04, L, k + 2 * c }))
	table.insert(parts, V.part("Side", "Block", "Blade", { -w / 2 - 0.02, y, 0 }, I, { 0.04, L, k + 2 * c }))
	return parts
end
local function try(name, parts)
	V.renumber(parts)
	local draft = { schema = Versions.BLUEPRINT_SCHEMA, name = "attack", type = "Sword", parts = {} }
	for i, p in ipairs(parts) do
		draft.parts[i] = { id = p.id, slot = p.slot, shape = p.shape, material = p.material, pos = p.pos, rot = p.rot, size = p.size }
	end
	local res = Canonical.draft(draft)
	if not res.ok then
		print(name, "refused", res.code or "", res.path or "")
		return
	end
	local core = res.value or res.draft or res.core
	if not core then
		for k, v in res do print(k, v) end
		return
	end
	local isC = Canonical.isCanonical(core)
	local r = V.Analyze.run(core, {})
	print(fmt("%-28s canonical %s; Analyze.run valid %s, cleaned %d", name, tostring(isC), tostring(r.validation.ok), #r.cleaned))
end
do
	local L, c, k, g = 2.0, 0.05, 0.02, 0.00001
	local y = 1.45 + L / 2
	local KF = cheeks(1.0, L, c, k, g, y, false)
	table.insert(KF, V.part("Core", "Block", "Guard", { 0, y, 0 }, I, { 1.0, L, k }))
	try("hairline", KF)
end
do
	local L, c, k, g = 2.0, 0.05, 0.02, 0.08
	local y = 1.45 + L / 2
	local KF = cheeks(1.0, L, c, k, g, y, true)
	table.insert(KF, V.part("Core", "Block", "Guard", { 0, y, 0 }, I, { 1.0, L, k }))
	for _, yc in ipairs({ 1.65, 2.05, 2.45 }) do
		table.insert(KF, apex("Pin", "Guard", 0.0003, yc + 0.0003, k / 2 + 0.0125, 0.12, c + k + 0.0125 - 0.0005))
	end
	try("pins", KF)
end
do
	local base = V.fixture("F5")
	local h = base[4]
	local t = 0.02
	local sx, sy, sz = h.size[1], h.size[2], h.size[3]
	local cx, cy, cz = h.pos[1], h.pos[2], h.pos[3]
	local KF = {
		V.part("Skin", "Block", "Guard", { cx, cy, cz + sz / 2 - t / 2 }, I, { sx, sy, t }),
		V.part("Skin", "Block", "Guard", { cx, cy, cz - sz / 2 + t / 2 }, I, { sx, sy, t }),
		V.part("Skin", "Block", "Pommel", { cx + sx / 2 - t / 2, cy, cz }, I, { t, sy, sz }),
		V.part("Skin", "Block", "Pommel", { cx - sx / 2 + t / 2, cy, cz }, I, { t, sy, sz }),
	}
	for _, p in ipairs(base) do table.insert(KF, V.copyPart(p)) end
	try("F5 + skin", KF)
end
for _, d in ipairs(Sets.get("fuller")) do
	if d.name == "w0.2 L2.5 t0.04 c0.030 g0.02 at0.5 twin" then
		try("fuller", d.parts)
	end
end
