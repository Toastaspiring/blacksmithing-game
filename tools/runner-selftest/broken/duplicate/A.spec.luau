--!strict
-- Runner self-test root "broken" (SPEC §14.4 T-META-05): A and B declare the same suite, so the runner exits 2.
local Test = require("../../../../tests/lib/Test")

return Test.suite("SelfTest/Duplicate", function(t)
	t.it("a", function() end)
end)
