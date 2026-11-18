--!nocheck
-- §5.5's table through the emulator on the build
local L = require("./lib")
for _, pre in ipairs({ "C01", "C02 Arming (Iron)", "C04", "C05", "C06", "C07", "C08", "C09", "C10", "C11", "C15" }) do
	local parts, name = L.fixture(pre)
	print(string.format("%-40s %s", name, L.dline(L.emu(L.copyParts(parts)))))
end
for _, id in ipairs({ "F1", "F2", "F3", "F4", "F5" }) do
	print(string.format("%-40s %s", id, L.dline(L.emu(L.repoFixture(id)))))
end
