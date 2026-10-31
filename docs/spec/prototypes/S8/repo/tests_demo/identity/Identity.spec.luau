--!strict
local Test = require("../../tests/lib/Test")
local A = require("../../tests/lib/Assert")
local Prop = require("../../tests/lib/Prop")
return Test.suite("Demo/ModuleIdentity", function(t)
	t.it("runner and spec share one Prop instance", function()
		A.eq(Prop.only, 12345)
	end)
end)
