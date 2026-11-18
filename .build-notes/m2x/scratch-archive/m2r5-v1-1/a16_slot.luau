--!nocheck
-- An exact copy in another slot, with a lower id: the same solid, kept under the copy's slot. And the same thing with no copy at all: the slot alone.
local V = require("./v1")
local fmt = string.format
for _, def in ipairs({ { "F3", 6 }, { "C08", 4 }, { "C05", 4 }, { "C06", 5 } }) do
	local base = V.fixture(def[1])
	local Ra = V.emu(V.copyParts(base))
	local KF = V.copyParts(base)
	local c = V.copyPart(base[def[2]])
	c.slot = "Guard"
	table.insert(KF, 1, c)
	local ok1 = V.valid(KF)
	local Rb = V.emu(KF)
	local KS = V.copyParts(base)
	KS[def[2]].slot = "Guard"
	local ok2 = V.valid(KS)
	local Rc = V.emu(KS)
	print(fmt("%s: K %s\n   + a copy of the main blade in Guard, lower id (valid %s): %s\n   the main blade labelled Guard, no copy (valid %s): %s", def[1], V.dline(Ra), tostring(ok1), V.dline(Rb), tostring(ok2), V.dline(Rc)))
end
