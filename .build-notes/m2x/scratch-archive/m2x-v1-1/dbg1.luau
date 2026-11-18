--!nocheck
local L = require("./lib")
local MB = require("./mybrute")
MB.init(L.Geo)
local Cover = L.Cover
local function P(shape, pos, rot, size) return L.part("Blade", shape, pos, rot, size) end
local parts = {
	P("Ball", {0.23786114109680051,0.17894511069171132,-0.16216906970366834}, {0,0,0,1}, {0.54352666090708224,0.54352666090708224,0.54352666090708224}),
	P("Block", {-0.058902189356740631,-0.024877387152194508,-0.16216906970366834}, {0,0,0,1}, {0.050000000000000003,0.13588166521927056,0.55261934308258609}),
	P("Block", {0.53462447155034165,0.11100427807707605,-0.16216906970366834}, {0,0,0,1}, {0.050000000000000003,0.13588166521927056,0.50651151072491651}),
	P("Block", {0.5246245715503417,0.24688594330634661,-0.16216906970366834}, {0,0,0,1}, {0.029999999999999999,0.13588166521927056,0.55234765702943078}),
	P("Block", {-0.048902189356740622,0.38276760853561714,-0.16216906970366834}, {0,0,0,1}, {0.029999999999999999,0.13588166521927056,0.5205256419176163}),
	P("Block", {0.10197947337002994,0.17894511069171132,0.12459416074987278}, {0,0,0,1}, {0.27176332545354109,0.55089041377544656,0.029999999999999999}),
	P("Block", {0.37374280882357103,0.17894511069171132,-0.45893250015720949}, {0,0,0,1}, {0.27176332545354109,0.5814388075481316,0.050000000000000003}),
}
L.renumber(parts)
local Pp = L.prep(parts)
local m = Cover.model(Pp[1])
local function oneFacet(m, f)
	local b = 6 * (f - 1)
	return { part = m.part, round = m.round, n = 1, poly = { m.poly[f] }, nx = { m.nx[f] }, ny = { m.ny[f] }, nz = { m.nz[f] },
		area = { m.area[f] }, box = { m.box[b + 1], m.box[b + 2], m.box[b + 3], m.box[b + 4], m.box[b + 5], m.box[b + 6] },
		total = m.area[f], np = 0, planes = {}, sag = { if m.round then m.sag[f] else 0 }, inner = 0, work = 0 }
end
for k = 2, #parts do
	local q = Cover.model(Pp[k])
	for _, f in ipairs({ 2, 3 }) do
		local c = Cover.shown(oneFacet(m, f), { q }, { false }, math.huge, math.huge)
		local b = MB.facetShown(m, f, { q }, { false })
		print(string.format("hider %d facet %d: cover %.9g brute %.9g  (area %.9g) facet normal (%.4f %.4f %.4f) sag %.5f", k, f, c, b, m.area[f], m.nx[f], m.ny[f], m.nz[f], m.sag[f]))
	end
end
-- the ball's box vs hider boxes
local B = Pp[1]
print(string.format("ball box x %.5f..%.5f y %.5f..%.5f z %.5f..%.5f", B.minx, B.maxx, B.miny, B.maxy, B.minz, B.maxz))
for k = 2, #parts do
	local Q = Pp[k]
	print(string.format("hider %d box x %.5f..%.5f y %.5f..%.5f z %.5f..%.5f", k, Q.minx, Q.maxx, Q.miny, Q.maxy, Q.minz, Q.maxz))
end
local f = 3
local b6 = 6 * (f - 1)
print(string.format("facet %d box x %.5f..%.5f y %.5f..%.5f z %.5f..%.5f", f, m.box[b6+1], m.box[b6+4], m.box[b6+2], m.box[b6+5], m.box[b6+3], m.box[b6+6]))
