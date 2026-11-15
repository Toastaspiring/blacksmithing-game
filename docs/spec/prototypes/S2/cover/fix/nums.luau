--!nocheck
local L = require("./lab")
local Cage = require("./cage")
local fmt = string.format
local parts = Cage.sword()
local core = { schema = 1, name = "cage", type = "Sword", parts = parts }
print("canonical", L.Canonical.isCanonical(core))
local run = L.Analyze.run(core)
local codes = {}
for _, e in ipairs(run.validation.errors) do table.insert(codes, e.code) end
print("valid", run.validation.ok, table.concat(codes, ","))
local P = L.prepared(parts)
local share = L.H.reads(P, 5)
local e = L.Sampling.exposure(P)
print(fmt("ball reads %.6f %%, kept %s, units %.3f", 100 * share, tostring(e.kept[5]), e.verdictWork))
local _, _, hider = L.Oracle.flags(P)
print(fmt("truth %.4f %%", 100 * L.Oracle.share(P, 5, hider)))
local cl = {}
for _, c in ipairs(e.cleaned) do table.insert(cl, c.partId .. ":" .. c.reason) end
print("cleaned", table.concat(cl, " "))
-- with the Ball as Pommel
local p2 = Cage.sword(nil, nil, nil, "Pommel")
local P2 = L.prepared(p2)
print(fmt("as Pommel: reads %.6f %%, kept %s", 100 * L.H.reads(P2, 5), tostring(L.Sampling.exposure(P2).kept[5])))
