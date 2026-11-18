--!nocheck
-- Where the verdict's queries go on the worst designs: per part and in total. args: json index
local process = require("@lune/process")
local fs = require("@lune/fs")
local serde = require("@lune/serde")
local V = require("./v1")
local C = require("./count/Sampling")
local fmt = string.format
local COUNT = C.COUNT
local data = serde.decode("json", fs.readFile(process.args[1]))
local d = data[tonumber(process.args[2]) or 1]
local parts = V.renumber(V.copyParts(d.parts))
local P = V.prep(parts)
local real = V.Sampling.exposure(P)
COUNT.sd, COUNT.aabb = 0, 0
C.FORCE.verdictOnly = true
C.exposure(P)
C.FORCE.verdictOnly = nil
print(fmt("verdict: sd %d, aabb %d, cleaned %d", COUNT.sd, COUNT.aabb, #real.cleaned))
local ok, r = V.valid(parts)
print("valid", ok, "hSurf", r.budget.hSurf, "surfSamples", r.budget.surfSamples, "hVol", r.budget.hVol, "volSamples", r.budget.volSamples)
local shapes = {}
for i, p in ipairs(parts) do
	shapes[i] = fmt("%s %.2fx%.2fx%.3f", string.sub(p.shape, 1, 1), p.size[1], p.size[2], p.size[3])
end
print(table.concat(shapes, " | "))
-- a sample's cost: all parts' sample counts
local S = 0
for i, p in ipairs(P) do
	S += 0
end
