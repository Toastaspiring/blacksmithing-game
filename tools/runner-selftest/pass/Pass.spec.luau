--!strict
-- Runner self-test root "pass" (SPEC §14.4 T-META-05): the runner exits 0, both plainly and with --seed 591835543;
-- tests/Meta/Runner.spec.luau runs it both ways. 591835543 is the first case seed Prop draws from
-- Tol.PROP_BASE_SEED, so under it both properties below replay only their case 1; that run also checks that the
-- runner and the specs share one Prop instance, since an unshared Prop would replay nothing (the runner exits 2).
local Test = require("../../../tests/lib/Test")
local A = require("../../../tests/lib/Assert")
local Prop = require("../../../tests/lib/Prop")
local Golden = require("../../../tests/lib/Golden")

return Test.suite("SelfTest/Pass", function(t)
	t.it("passes", function()
		A.eq(1 + 1, 2)
	end)
	t.it("shares the runner's Prop and Golden instances", function()
		-- nil when run plainly; with --seed 591835543 an unshared Prop leaves the runner's Prop.replayed at 0 (exit 2)
		A.truthy(Prop.only == nil or Prop.only == 591835543, "Prop.only is nil or carries --seed")
		local runs = 0
		Prop.check(1, function(rng)
			return rng:u32()
		end, function(_v: number)
			runs += 1
		end)
		A.eq(runs, 1, "case 1 runs (replayed under --seed 591835543)")
		A.eq(Golden.bless, false, "Golden.bless stays false without --bless")
	end)
	t.it("a property that holds", function()
		Prop.check(3, function(rng)
			return rng:int(1, 6)
		end, function(v: number)
			A.within(v, 1, 6)
		end)
	end)
	t.slow("a slow case, skipped by --quick", function()
		A.truthy(true)
	end)
	t.skip("a skipped case", function()
		error("a skipped case must not run")
	end)
end)
