--!nocheck
local L = require("./lib")
local E = require("./exactlib")
local r, w, e = 0.3, 0.06, 0.0005
local parts = {
	L.part("Blade", "Block", { 0, -0.01, 0 }, L.I, { 0.16, 0.02, 0.16 }),
	L.part("Blade", "Block", { 0, -0.07, 0 }, L.I, { 0.5, 0.1, 0.5 }),
}
for sx = -1, 1, 2 do
	table.insert(parts, L.part("Guard", "Block", { sx * (0.08 + 0.005 + 0.01), -0.01, 0 }, L.I, { 0.02, 0.02, 0.2 }))
	table.insert(parts, L.part("Guard", "Block", { 0, -0.01, sx * (0.08 + 0.005 + 0.01) }, L.I, { 0.2, 0.02, 0.02 }))
end
local t, y = 0.02, 0.005 + 0.01
local a = (0.16 - w) / 2
table.insert(parts, L.part("Guard", "Block", { -(w / 2 + a / 2), y, 0 }, L.I, { a, t, 0.16 }))
table.insert(parts, L.part("Guard", "Block", { (w / 2 + a / 2), y, 0 }, L.I, { a, t, 0.16 }))
table.insert(parts, L.part("Guard", "Block", { 0, y, -(w / 2 + a / 2) }, L.I, { w, t, a }))
table.insert(parts, L.part("Guard", "Block", { 0, y, (w / 2 + a / 2) }, L.I, { w, t, a }))
table.insert(parts, L.part("Pommel", "Ball", { 0, 0.012 + e + r, 0 }, L.I, { 2 * r, 2 * r, 2 * r }))
L.renumber(parts)
local P = L.prep(parts)
local models = L.models(P)
local m = models[1]
local idx, higher = L.hidersOf(P, 1, models)
local hm = {}
for k, j in ipairs(idx) do hm[k] = models[j] end
print("hiders", table.concat(idx, ","))
for f = 1, m.n do
	local s = L.Cover.shown(E.oneFacet(m, f), hm, higher, math.huge, math.huge)
	print(string.format("facet %d normal (%.0f %.0f %.0f) area %.5f shown %.5f", f, m.nx[f], m.ny[f], m.nz[f], m.area[f], s))
end
for i = 1, #P do print(i, P[i].slot, P[i].shape, P[i].minx, P[i].maxx, P[i].miny, P[i].maxy, P[i].minz, P[i].maxz) end
