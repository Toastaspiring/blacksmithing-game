--!nocheck
local L = require("./lib")
print(table.concat(L.Blueprints.order, " "))
print()
local parts = L.repoFixture("F5")
for i, p in ipairs(parts) do
	print(i, p.slot, p.shape, p.material, table.concat(p.pos, ","), table.concat(p.rot, ","), table.concat(p.size, ","))
end
local R = L.emu(L.copyParts(parts))
print(L.dline(R))
