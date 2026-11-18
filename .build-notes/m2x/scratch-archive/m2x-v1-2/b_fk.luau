--!nocheck
-- the false-kept caged Balls: a finer truth, the hide test on the model (arrbrute, every part a hider), and D in a sword
local fs = require("@lune/fs")
local serde = require("@lune/serde")
local L = require("./lib")
local AB = require("./arrbrute")
AB.init(L.Geo)
local fmt = string.format
for _, f in ipairs({ "out/cages_61b.log", "out/cages_62b.log" }) do
	local txt = fs.readFile(f)
	for line in string.gmatch(txt, "FALSEKEPT [^\n]*") do
		local js = string.match(line, "(%b[])")
		local parts = L.renumber(serde.decode("json", js))
		local P = L.prep(parts)
		local models = L.models(P)
		local read = L.readOf(P, 1, models)
		local aidx, ah = L.allHiders(P, 1, models)
		local am = {}
		for k, j in ipairs(aidx) do am[k] = models[j] end
		local ht = AB.shown(models[1], am, ah, 0) / models[1].total
		local _, _, hider = L.Oracle.flags(P)
		local t40 = L.Oracle.measure(P, 1, hider, 40000)
		local t400 = L.Oracle.measure(P, 1, hider, 400000)
		local t2m = L.Oracle.measure(P, 1, hider, 2000000)
		print(fmt("r %.3f: reads %.4f%% (hide test on the model %.4f%%), truth %.4f%% / %.4f%% / %.4f%% (40k / 400k / 2M points)", P[1].r, 100 * read, 100 * ht, 100 * t40, 100 * t400, 100 * t2m))
	end
end
