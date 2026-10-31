--!strict
-- tests/lib/Prop.luau — property checks (SPEC §14.3): n seeded cases, no shrinking. A failure names the case seed
-- and dumps the input, so the case can be replayed alone:
--   lune run tests/run -- --filter "<case name>" --seed <seed>
-- The runner and the specs share this module instance (Lune caches modules per file), which carries --seed; a
-- --seed that replays no case is a harness error (tests/run.luau reads `replayed`), so a mistyped seed cannot pass.

local Dump = require("./Dump")
local TestRng = require("./TestRng")
local Tol = require("./Tol")

export type Gen<T> = (rng: TestRng.TestRng) -> T

local Prop = {
	baseSeed = Tol.PROP_BASE_SEED, -- fixed, so every run draws the same case seeds
	only = nil :: number?, -- set by the runner from --seed: run exactly that case seed
	replayed = 0, -- cases run because their seed equals `only`
}

-- Case i draws its own seed from a master stream seeded with baseSeed; gen gets a fresh TestRng on that seed.
function Prop.check<T>(n: number, gen: Gen<T>, property: (T) -> ())
	local master = TestRng.new(Prop.baseSeed)
	for i = 1, n do
		local caseSeed = master:u32()
		if Prop.only == nil or Prop.only == caseSeed then
			if Prop.only == caseSeed then
				Prop.replayed += 1
			end
			local input = gen(TestRng.new(caseSeed))
			local ok, err = pcall(property :: any, input)
			if not ok then
				local reason = string.gsub(tostring(err), "^.-assert: ", "")
				error(string.format("assert: property failed on case %d/%d (seed %d): %s\n  input = %s", i, n,
					caseSeed, reason, Dump.short(input)), 0)
			end
		end
	end
end

return Prop
