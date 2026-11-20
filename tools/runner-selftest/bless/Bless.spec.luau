--!strict
-- Runner self-test root "bless" (SPEC §14.4 T-META-05): tests/Meta/Runner.spec.luau runs it plainly and with --bless,
-- with BLACKSMITH_BLESS_PROBE_DIR and BLACKSMITH_BLESS_PROBE_TOKEN set, and checks the exit codes: the case compares a
-- golden of its own in that folder, so a --bless run writes it and plain runs compare against it. It also checks that
-- the runner's --bless reached this spec's Golden instance and that the spawned runner carries Test.SELFTEST_CHILD.
-- Run by hand, without the folder, it only checks the flag.
local process = require("@lune/process")
local Test = require("../../../tests/lib/Test")
local A = require("../../../tests/lib/Assert")
local Golden = require("../../../tests/lib/Golden")

return Test.suite("SelfTest/Bless", function(t)
	t.it("blesses or compares a golden of its own", function()
		A.eq(Golden.bless, table.find(process.args, "--bless") ~= nil, "Golden.bless carries the runner's --bless")
		local dir = process.env.BLACKSMITH_BLESS_PROBE_DIR
		if dir == nil then
			return
		end
		A.eq(process.env[Test.SELFTEST_CHILD], "1", "the spawned runner carries " .. Test.SELFTEST_CHILD)
		local savedDir = Golden.dir
		Golden.dir = dir
		local ok, err = pcall((Golden.check :: any), "bless_probe", { token = process.env.BLACKSMITH_BLESS_PROBE_TOKEN or "" })
		Golden.dir = savedDir
		if not ok then
			error(err, 0)
		end
	end)
end)
