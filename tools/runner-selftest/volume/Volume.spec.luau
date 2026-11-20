--!strict
-- Runner self-test root "volume" (SPEC §14.1 L3V, §14.3 T-META-05): a plain run skips the t.volume case and lists
-- it, --volume runs every case, --quick skips the slow and the volume case alike, and --quick --volume is a harness
-- error; tests/Meta/Runner.spec.luau runs each. The volume case fails unless the runner was given --volume, so a
-- runner that ran it without the flag would exit 1.
local process = require("@lune/process")
local Test = require("../../../tests/lib/Test")
local A = require("../../../tests/lib/Assert")

return Test.suite("SelfTest/Volume", function(t)
	t.it("a fast case", function()
		A.eq(1 + 1, 2)
	end)
	t.slow("a slow case", function()
		A.truthy(true)
	end)
	t.volume("a volume case, run only by --volume", function()
		A.truthy(table.find(process.args, "--volume") ~= nil, "the runner was given --volume")
	end)
end)
