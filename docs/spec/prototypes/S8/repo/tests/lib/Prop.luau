--!strict
-- tests/lib/Prop.luau — minimal property-based testing: N seeded cases, no shrinking.
-- On failure the error names the case seed so it can be replayed in isolation:
--   lune run tests/run --filter "<case name>" --seed <seed>
-- PROTOTYPE (S8).

local TestRng = require("./TestRng")
local Dump = require("./Dump")

export type Gen<T> = (rng: TestRng.TestRng) -> T

local Prop = {}

-- The runner sets this from --seed; default base seed is fixed so runs are reproducible.
Prop.baseSeed = 0x5EED0001
Prop.only = nil :: number? -- when --seed is given, run exactly that case seed

function Prop.check<T>(n: number, gen: Gen<T>, property: (T) -> ())
	local master = TestRng.new(Prop.baseSeed)
	for i = 1, n do
		local caseSeed = master:u32()
		if Prop.only == nil or Prop.only == caseSeed then
			local input = gen(TestRng.new(caseSeed))
			local ok, err = pcall(property, input)
			if not ok then
				error(string.format("assert: property failed on case %d/%d (seed %d): %s\n  input = %s",
					i, n, caseSeed, tostring(err), Dump.short(input)), 0)
			end
		end
	end
end

return Prop
