--!nocheck
local L = require("./lib")
local names = {}
for _, list in ipairs({ L.Fx.calibration(), L.Fx.regression(), L.Fx.perf(), L.Fx.golden() }) do
	for _, b in ipairs(list) do table.insert(names, tostring(b.name) .. (b.parts and "" or "(no parts)")) end
end
print(table.concat(names, " | "))
local parts = L.fixture("X01")
for i, p in ipairs(parts) do print(i, p.slot, p.shape, table.concat(p.pos, ","), table.concat(p.size, ","), table.concat(p.rot, ",")) end
