--!nocheck
local serde = require("@lune/serde")
local fs = require("@lune/fs")
local Analyze = require("./repo/src/shared/Physics/Analyze")
local Canonical = require("./repo/src/shared/Blueprint/Canonical")
local Shapes = require("./repo/src/shared/Physics/Shapes")
local Sv = require("./v/newV_base/Sampling")
local raw = serde.decode("json", fs.readFile("out/climb_4.json"))
local parts = raw[1].parts
local before = serde.encode("json", parts)
local function units()
	local P = {}
	for i, p in ipairs(parts) do P[i] = Shapes.prepare(p, i) end
	local u = 0
	Sv.exposure(P, function(n) u += n end)
	return u
end
print("units", units())
local core = { schema = 1, name = "climb", type = "Sword", parts = parts }
Analyze.quick(core, { connectivity = true })
print("after quick, same parts:", serde.encode("json", parts) == before, "units", units())
Canonical.isCanonical(core)
print("after isCanonical, same parts:", serde.encode("json", parts) == before, "units", units())
-- the stored rows: is the parts list shared between keep entries (aliasing)?
for k = 1, #raw do print(k, raw[k].score) end
