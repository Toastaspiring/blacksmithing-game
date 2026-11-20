--!strict
-- Runner self-test root "nospec" (SPEC §14.4 T-META-05): discovery skips <root>/lib and <root>/studio, so this root
-- holds no spec the runner reads and the runner exits 2; a runner that read this file would run a failing case.
local Test = require("../../../../tests/lib/Test")

return Test.suite("SelfTest/NoSpecStudio", function(t)
	t.it("never runs: discovery skips <root>/studio", function()
		error("discovery read <root>/studio")
	end)
end)
