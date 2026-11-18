local S = require("./sets")
local function n(name, l) print(name, #l) end
local pf = S.protoFixtures()
n("protoFixtures", pf)
local t = {}
for _, d in ipairs(pf) do table.insert(t, d.name) end
print(table.concat(t, " | "))
n("repoF", S.repoF()); n("worstP", S.worstP()); n("climbed", S.climbed()); n("attacksJson", S.attacksJson()); n("bFamilies", S.bFamilies())
