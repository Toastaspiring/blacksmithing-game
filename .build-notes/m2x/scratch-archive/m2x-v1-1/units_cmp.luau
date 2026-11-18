--!nocheck
-- units and verdicts of a variant against the build: P1–P5, the worst valid designs, the tooComplex ones
local L = require("./lib")
local Worst = require("./repo/docs/spec/prototypes/S2/cover/worst_designs")
local fmt = string.format
local designs = {}
for _, b in ipairs(L.Fx.perf()) do table.insert(designs, { name = b.name, parts = L.copyParts(b.parts) }) end
for k, d in ipairs(Worst.valid) do table.insert(designs, { name = "worst valid " .. k, parts = L.copyParts(d.parts) }) end
for k, d in ipairs(Worst.tooComplex) do if k <= 3 then table.insert(designs, { name = "tooComplex " .. k, parts = L.copyParts(d.parts) }) end end
for _, d in ipairs(designs) do
	local P = L.prep(L.renumber(d.parts))
	local t0 = os.clock()
	local e = L.Sampling.exposure(P)
	local ms = (os.clock() - t0) * 1000
	print(fmt("%-40s units %10.1f capped %-5s cleaned %2d  %.1f ms", string.sub(d.name, 1, 40), e.verdictWork, tostring(e.capped), #e.cleaned, ms))
end
