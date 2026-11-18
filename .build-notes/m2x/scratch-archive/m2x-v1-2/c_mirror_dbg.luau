--!nocheck
local process = require("@lune/process")
local fs = require("@lune/fs")
local serde = require("@lune/serde")
local L = require("./lib")
local AB = require("./arrbrute")
AB.init(L.Geo)
local fmt = string.format
local txt = fs.readFile(process.args[1])
for plane, idx, js in string.gmatch(txt, "MIRROR (%a) part (%d+) (%b[])") do
	local i = tonumber(idx)
	local parts = L.renumber(serde.decode("json", js))
	local im = {}
	for k, p in ipairs(parts) do im[k] = L.Mirror.reflect(L.copyPart(p), plane) end
	L.renumber(im)
	for _, d in ipairs({ { "original", parts }, { "image", im } }) do
		local P = L.prep(d[2])
		local models = L.models(P)
		local read = L.readOf(P, i, models)
		local aidx, ah = L.allHiders(P, i, models)
		local am = {}
		for k, j in ipairs(aidx) do am[k] = models[j] end
		local lo = AB.shown(models[i], am, ah, 1e-11) / models[i].total
		local hi = AB.shown(models[i], am, ah, -1e-11) / models[i].total
		print(fmt("%s %s part %d (%s %s): reads %.6f%%, bracket [%.6f%%, %.6f%%]", plane, d[1], i, P[i].shape, P[i].slot, 100 * read, 100 * lo, 100 * hi))
	end
	-- rank ties up to sign
	local P = L.prep(parts)
	local rank = L.Sampling.ranked(P)
	for j = 1, #P do
		if j ~= i then
			local a, b = P[i], P[j]
			if a.slot == b.slot and math.abs(a.volume - b.volume) < 1e-15 and a.cy == b.cy then
				print(fmt("   part %d ties part %d on slot, volume, cy (|cx| %.17g / %.17g, |cz| %.17g / %.17g)", i, j, math.abs(a.cx), math.abs(b.cx), math.abs(a.cz), math.abs(b.cz)))
			end
		end
	end
end
