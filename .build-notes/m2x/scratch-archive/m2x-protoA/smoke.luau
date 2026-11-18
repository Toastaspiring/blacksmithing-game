--!nocheck
-- Smoke test of Physics/Cover in the copy: models, isolated parts, simple covers with closed forms.
local Shapes = require("./repo/src/shared/Physics/Shapes")
local Cover = require("./repo/src/shared/Physics/Cover")
local Sampling = require("./repo/src/shared/Physics/Sampling")
local fmt = string.format

local I = { 0, 0, 0, 1 }
local function part(id, shape, pos, rot, size, slot)
	return { id = id, slot = slot or "Blade", shape = shape, material = "Iron", pos = pos, rot = rot or I, size = size }
end
local function prep(list)
	local P = {}
	for i, p in ipairs(list) do P[i] = Shapes.prepare(p, i) end
	return P
end

-- models
for _, sh in ipairs({ "Block", "Wedge", "CornerWedge", "Cylinder", "Ball" }) do
	local P = Shapes.prepare(part(1, sh, { 0, 1, 0 }, { 0.1, 0.2, 0.3, 0.927 }, { 0.6, 0.5, 0.4 }), 1)
	-- normalize quat first
	local m = Cover.model(P)
	-- check closedness: sum of area * normal = 0
	local sx, sy, sz = 0, 0, 0
	local outward = true
	for f = 1, m.n do
		sx += m.area[f] * m.nx[f]; sy += m.area[f] * m.ny[f]; sz += m.area[f] * m.nz[f]
		local poly = m.poly[f]
		local cx, cy, cz = 0, 0, 0
		for i = 1, #poly, 3 do cx += poly[i]; cy += poly[i + 1]; cz += poly[i + 2] end
		local n = #poly / 3
		cx, cy, cz = cx / n, cy / n, cz / n
		if (cx - P.gx) * m.nx[f] + (cy - P.gy) * m.ny[f] + (cz - P.gz) * m.nz[f] <= 0 then outward = false end
	end
	-- every vertex inside every plane
	local worst = -math.huge
	for f = 1, m.n do
		local poly = m.poly[f]
		for i = 1, #poly, 3 do
			for k = 1, m.np do
				local pl = m.planes
				local s = pl[4 * k - 3] * poly[i] + pl[4 * k - 2] * poly[i + 1] + pl[4 * k - 1] * poly[i + 2] - pl[4 * k]
				if s > worst then worst = s end
			end
		end
	end
	print(fmt("%-12s facets %3d planes %3d area %.6f analytic %.6f ratio %.5f  closure %.1e outward %s maxPlaneViolation %.1e", sh, m.n, m.np, m.total, P.area, m.total / P.area, math.sqrt(sx * sx + sy * sy + sz * sz), tostring(outward), worst))
end

local function verdict(list, label)
	local P = prep(list)
	local e = Sampling.exposure(P)
	local t = {}
	for i = 1, #P do t[i] = if e.kept[i] then "kept" else "CLEANED" end
	print(label, table.concat(t, " "))
	return e, P
end

verdict({ part(1, "Block", { 0, 1, 0 }, I, { 1, 1, 1 }) }, "lone block:")
verdict({ part(1, "Block", { 0, 1, 0 }, I, { 1, 1, 1 }), part(2, "Block", { 0, 1, 0 }, I, { 0.5, 0.5, 0.5 }) }, "block in block:")
verdict({ part(1, "Ball", { 0, 1, 0 }, I, { 1, 1, 1 }), part(2, "Cylinder", { 0, 1, 0 }, I, { 0.5, 0.5, 0.5 }) }, "cyl in ball:")

-- direct shown readings: a 1x1x1 block p with a slab lid covering its top face exactly and a strip
local function shownOf(list, i)
	local P = prep(list)
	local rank, byRank = Sampling.ranked(P)
	local models = {}
	for k = 1, #P do models[k] = Cover.model(P[k]) end
	local cand, higher = {}, {}
	for r = 1, #P do
		local q = byRank[r]
		if q.index ~= i then table.insert(cand, models[q.index]); table.insert(higher, r < rank[i]) end
	end
	local s, tests = Cover.shown(models[i], cand, higher, math.huge, nil, true)
	return s, models[i].total, tests
end
-- p: 1x1x1 at origin y=1 (top at 1.5). lid: 2x0.2x2 on top (covers top face) -> top face hidden: shows 5 faces = 5
print("lid on top", shownOf({ part(1, "Block", { 0, 1, 0 }, I, { 1, 1, 1 }), part(2, "Block", { 0, 1.6, 0 }, I, { 2, 0.2, 2 }) }, 1))
-- lid with a gap 0.011 (< HIDE_OFFSET): still hidden by probe
print("lid 0.011 above", shownOf({ part(1, "Block", { 0, 1, 0 }, I, { 1, 1, 1 }), part(2, "Block", { 0, 1.611, 0 }, I, { 2, 0.2, 2 }) }, 1))
-- lid 0.013 above: not hidden
print("lid 0.013 above", shownOf({ part(1, "Block", { 0, 1, 0 }, I, { 1, 1, 1 }), part(2, "Block", { 0, 1.613, 0 }, I, { 2, 0.2, 2 }) }, 1))
-- two lids leaving a slit of 0.001 on the top face: shows 5 + 0.001*1 = 5.001 (+ eps effects)
print("slit 0.001", shownOf({ part(1, "Block", { 0, 1, 0 }, I, { 1, 1, 1 }),
	part(2, "Block", { -0.5005 - 0.25, 1.6, 0 }, I, { 1.5, 0.2, 2 }), part(3, "Block", { 0.5005 + 0.25, 1.6, 0 }, I, { 1.5, 0.2, 2 }) }, 1))
-- a hairline 1e-5
print("slit 1e-5", shownOf({ part(1, "Block", { 0, 1, 0 }, I, { 1, 1, 1 }),
	part(2, "Block", { -0.500005 - 0.25, 1.6, 0 }, I, { 1.5, 0.2, 2 }), part(3, "Block", { 0.500005 + 0.25, 1.6, 0 }, I, { 1.5, 0.2, 2 }) }, 1))
-- coincident: a twin block of same size but different slot... use a block flush beside: 1x1x1 beside at x=1: the face x=0.5 coincident
print("flush beside (other larger)", shownOf({ part(1, "Block", { 0, 1, 0 }, I, { 1, 1, 1 }), part(2, "Block", { 1.0, 1, 0 }, I, { 1, 1.2, 1.2 }) }, 1))
print("flush beside (other smaller, lower rank)", shownOf({ part(1, "Block", { 0, 1, 0 }, I, { 1, 1, 1 }), part(2, "Block", { 0.9, 1, 0 }, I, { 0.8, 0.8, 0.8 }) }, 1))
-- 4 lids leaving a window 0.1 x 0.1 in the middle of the top face: 5 + 0.01
print("window 0.1", shownOf({ part(1, "Block", { 0, 1, 0 }, I, { 1, 1, 1 }),
	part(2, "Block", { -0.55, 1.6, 0 }, I, { 1.0, 0.2, 2 }), part(3, "Block", { 0.55, 1.6, 0 }, I, { 1.0, 0.2, 2 }),
	part(4, "Block", { 0, 1.6, -0.55 }, I, { 0.1, 0.2, 1.0 }), part(5, "Block", { 0, 1.6, 0.55 }, I, { 0.1, 0.2, 1.0 }) }, 1))
