--!strict
-- Runner self-test root "broken" (SPEC §14.4 T-META-05): this spec does not parse, so the runner exits 2.
local Test = require("../../../../tests/lib/Test")

return Test.suite("SelfTest/Syntax", function(t)
	t.it("never loads" function() end) -- the missing comma is the point
end)
