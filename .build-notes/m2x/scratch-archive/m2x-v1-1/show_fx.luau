--!nocheck
local L = require("./lib")
for _, id in ipairs({ "F3", "F5" }) do
	for i, p in ipairs(L.repoFixture(id)) do
		print(id, i, p.slot, p.shape, p.material, table.concat(p.pos, ","), table.concat(p.rot, ","), table.concat(p.size, ","))
	end
end
local parts = L.fixture("C02")
for i, p in ipairs(parts) do
	print("C02", i, p.slot, p.shape, p.material, table.concat(p.pos, ","), table.concat(p.rot, ","), table.concat(p.size, ","))
end
