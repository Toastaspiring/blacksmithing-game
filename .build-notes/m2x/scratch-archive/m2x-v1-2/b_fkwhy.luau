--!nocheck
-- why the model over-reads the caged Ball: its reading, the same per-facet shown fractions weighted by each facet's spherical
-- patch (Van Oosterom–Strackee solid angle), and the truth
local fs = require("@lune/fs")
local serde = require("@lune/serde")
local L = require("./lib")
local E = require("./exactlib")
local fmt = string.format
local txt = fs.readFile("out/cages_61b.log") .. fs.readFile("out/cages_62b.log")
for line in string.gmatch(txt, "FALSEKEPT [^\n]*") do
	local parts = L.renumber(serde.decode("json", string.match(line, "(%b[])")))
	local P = L.prep(parts)
	local models = L.models(P)
	local m = models[1]
	local idx, higher = L.hidersOf(P, 1, models)
	local hm = {}
	for k, j in ipairs(idx) do hm[k] = models[j] end
	local c = { P[1].cx, P[1].cy, P[1].cz }
	local r = P[1].r
	local shownModel, weighted, sphere = 0, 0, 0
	local byRing = {}
	for f = 1, m.n do
		local s = L.Cover.shown(E.oneFacet(m, f), hm, higher, math.huge, math.huge)
		local p = m.poly[f]
		local v = {}
		for k = 0, 2 do
			local x, y, z = p[3 * k + 1] - c[1], p[3 * k + 2] - c[2], p[3 * k + 3] - c[3]
			local l = math.sqrt(x * x + y * y + z * z)
			v[k + 1] = { x / l, y / l, z / l }
		end
		local a, b, cc = v[1], v[2], v[3]
		local triple = a[1] * (b[2] * cc[3] - b[3] * cc[2]) - a[2] * (b[1] * cc[3] - b[3] * cc[1]) + a[3] * (b[1] * cc[2] - b[2] * cc[1])
		local dab = a[1] * b[1] + a[2] * b[2] + a[3] * b[3]
		local dbc = b[1] * cc[1] + b[2] * cc[2] + b[3] * cc[3]
		local dca = cc[1] * a[1] + cc[2] * a[2] + cc[3] * a[3]
		local omega = 2 * math.atan2(math.abs(triple), 1 + dab + dbc + dca)
		local patch = omega * r * r
		shownModel += s
		weighted += s / m.area[f] * patch
		sphere += patch
	end
	local _, _, hider = L.Oracle.flags(P)
	local truth = L.Oracle.measure(P, 1, hider, 400000)
	print(fmt("r %.2f: model reads %.4f%%; per facet weighted by its sphere patch %.4f%% (patches sum to %.6f of 4πr²); truth %.4f%%",
		r, 100 * shownModel / m.total, 100 * weighted / sphere, sphere / (4 * math.pi * r * r), 100 * truth))
end
