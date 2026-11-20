--!strict
-- Runner self-test root "holder" (SPEC §14.4 T-META-05): a stand-in that holds a spec at Test.SELFTEST_SPEC's path,
-- as tests/ holds the runner self-test. A runner the self-test spawns (Test.SELFTEST_CHILD set) refuses such a root
-- before loading a spec (exit 2), so tests/Meta/Runner.spec.luau checks that refusal on this small root: a broken
-- check runs this one case and exits 0, never the whole suite.
local Test = require("../../../../tests/lib/Test")

return Test.suite("SelfTest/Holder", function(t)
	t.it("runs only by hand: a self-test runner refuses this root", function() end)
end)
