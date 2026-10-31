--!strict
local Test = require("../../tests/lib/Test")
local A = require("../../tests/lib/Assert")
return Test.suite("Demo/Failing", function(t)
	t.it("passes", function()
		A.eq(1 + 1, 2)
	end)
	t.it("fails an assertion", function()
		A.near(0.1 + 0.2, 0.3, 1e-18, "float compare")
	end)
	t.it("crashes", function()
		local x: any = nil
		local _ = x.field
	end)
end)
