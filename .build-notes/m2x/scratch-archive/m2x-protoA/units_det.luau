--!nocheck
local S = require("./sets")
local Shapes = require("./repo/src/shared/Physics/Shapes")
local Sv = require("./v/newV_base/Sampling")
local fmt = string.format
local list = S.json("out/climb_4.json")
for k = 1, math.min(3, #list) do
	local d = list[k]
	local P = {}
	for i, p in ipairs(d.parts) do P[i] = Shapes.prepare(p, i) end
	local t = {}
	for r = 1, 3 do
		local units = 0
		Sv.exposure(P, function(n) units += n end)
		t[r] = units
	end
	print(fmt("design %d: units %.1f %.1f %.1f", k, t[1], t[2], t[3]))
end
local raw = require("@lune/serde").decode("json", require("@lune/fs").readFile("out/climb_4.json"))
for k = 1, math.min(3, #raw) do print("stored score", raw[k].score, raw[k].current) end
