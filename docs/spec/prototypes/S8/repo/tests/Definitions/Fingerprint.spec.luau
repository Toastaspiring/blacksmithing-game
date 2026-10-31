--!strict
-- Balance fingerprint: any change to Definitions/Balance without a BALANCE_VERSION bump fails.
local Test = require("../lib/Test")
local A = require("../lib/Assert")
local Dump = require("../lib/Dump")
local Golden = require("../lib/Golden")
local Balance = require("../../src/shared/Definitions/Balance")

return Test.suite("Definitions/Fingerprint", function(t)
	t.it("FNV-1a matches the reference vectors", function()
		A.eq(Dump.fnv1a32(""), 0x811C9DC5)
		A.eq(Dump.fnv1a32("a"), 0xE40C292C)
		A.eq(Dump.fnv1a32("foobar"), 0xBF9CF968)
	end)

	t.it("Balance data is frozen", function()
		A.truthy(table.isfrozen(Balance))
		A.throws(function()
			(Balance :: any).BALANCE_VERSION = 99
		end)
	end)

	t.it("balance fingerprint matches the blessed {version, hash}", function()
		local text = Dump.canonical(Balance)
		local current = { version = Balance.BALANCE_VERSION, fnv1a32 = Dump.fnv1a32(text), bytes = #text }
		local blessed = Golden.read("balance_fingerprint")
		-- Guard runs in --bless mode too: a data change must come with a version bump.
		if blessed and blessed.version == current.version and blessed.fnv1a32 ~= current.fnv1a32 then
			A.fail("Definitions/Balance changed but BALANCE_VERSION is still " .. current.version .. ": bump it, then --bless")
		end
		Golden.check("balance_fingerprint", current)
	end)
end)
