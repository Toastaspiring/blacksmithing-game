--!nocheck
-- m2r5: the oracle over a shard of a set. args: set shard nshards
local process = require("@lune/process")
local fs = require("@lune/fs")
local serde = require("@lune/serde")
local Sets = require("./sets")
local Shapes = require("./tree/src/shared/Physics/Shapes")
local O = require("./oracle")

local setName, shard, nshards = process.args[1], tonumber(process.args[2]), tonumber(process.args[3])
local list = Sets.get(setName)
local out = {}
local t0 = os.clock()
local points = 0
for k, d in ipairs(list) do
	if (k - 1) % nshards == shard then
		local P = table.create(#d.parts)
		for i, p in ipairs(d.parts) do
			P[i] = Shapes.prepare(p, i)
		end
		local shares = O.all(P)
		table.insert(out, { k, shares })
	end
end
fs.writeDir("out/truth")
fs.writeFile(string.format("out/truth/%s.%d.json", setName, shard), serde.encode("json", out))
print(setName, shard, #out, "designs", string.format("%.1f s", os.clock() - t0))
