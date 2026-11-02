--!strict
-- tests/Definitions/Versions.spec.luau — Definitions/Versions (SPEC §9.6, §16.1).

local A = require("../lib/Assert")
local Test = require("../lib/Test")
local Versions = require("../../src/shared/Definitions/Versions")

return Test.suite("Definitions/Versions", function(t)
	t.it("DATA_VERSION and BLUEPRINT_SCHEMA are 1 at launch (§16.1), and nothing else exists", function()
		-- BALANCE_VERSION is not pinned here: T-BAL-01's golden guards it, and §14.9's bump workflow must go green.
		A.eq(Versions.DATA_VERSION, 1)
		A.eq(Versions.BLUEPRINT_SCHEMA, 1)
		local keys: { string } = {}
		for k in pairs(Versions) do
			table.insert(keys, k)
		end
		table.sort(keys)
		A.deepEq(keys, { "BALANCE_VERSION", "BLUEPRINT_SCHEMA", "DATA_VERSION" })
	end)

	t.it("frozen positive integers (D7)", function()
		A.truthy(table.isfrozen(Versions))
		for _, k in { "DATA_VERSION", "BLUEPRINT_SCHEMA", "BALANCE_VERSION" } do
			local v = (Versions :: any)[k]
			A.truthy(type(v) == "number" and v >= 1 and v % 1 == 0, k)
		end
	end)
end)
