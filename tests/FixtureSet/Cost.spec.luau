--!strict
-- The cost fixtures P1–P5, P1–P3 with a speck, X08's aliases, T-PERF-01's case list and the worst designs (SPEC §4.9,
-- §14.7, §14.11): records, structure against Definitions (P4 exempt from the 0.02 margin, D6), the port from S2's
-- prototype bit for bit, the canonical fixed point, Physics' verdict, and tests/fixtures/WorstDesigns against the docs
-- file it copies. Timing is T-PERF-01's (M3, tests/Physics).

local Test = require("../lib/Test")
local A = require("../lib/Assert")
local Gen = require("../lib/Gen")
local Build = require("../fixtures/Build")
local Cost = require("../fixtures/Cost")
local WorstDesigns = require("../fixtures/WorstDesigns")
local Shape = require("./Shape")
local M = require("./Measured")

local Docs: any = (require :: any)("../../docs/spec/prototypes/S2/cover/worst_designs")

-- P4's Balls (0.58 across, x = 0.2·sin i) come 0.01 from the hitbox's sides: kept as the prototype built them.
local EXEMPT: { [string]: number } = { P4 = 0.01 }

return Test.suite("FixtureSet/Cost", function(t)
	t.it("P1–P5 and the specks: ids, labels and records", function()
		M.records(Cost, 11)
		A.eq(table.concat(Cost.order, " "), "P1 P2 P3 P4 P5 P1-floating P2-floating P3-floating P1-attached P2-attached "
			.. "P3-attached", "order")
		M.expectations(Cost)
	end)

	t.it("T-DEF-06 fixtures inside: canonical cores within Definitions' limits, 0.02 stud inside the hitbox but P4",
		function()
			M.structure(Cost, EXEMPT)
			local margin = Gen.margin(M.CTX, Cost.get("P4").core.parts)
			A.near(margin, 0.01, 1e-12, "P4's margin")
		end)

	t.it("every fixture is a fixed point of the canonical form", function()
		M.canonical(Cost)
	end)

	t.it("P1–P5 are the prototype's perf(), bit for bit", function()
		M.port(Cost, { "P1", "P2", "P3", "P4", "P5" })
	end)

	t.it("a speck replaces part 24 by a 0.05 Iron cube in its slot, floating at (0.7, 0.2, 0.2) or at part 23's centre",
		function()
			for _, id in { "P1", "P2", "P3" } do
				local base = Cost.get(id).core.parts
				for _, kind in { "floating", "attached" } do
					local parts = Cost.get(id .. "-" .. kind).core.parts
					A.eq(#parts, 24, id .. " " .. kind)
					for k = 1, 23 do
						A.eq(Shape.bitDifference(parts[k], base[k]), nil, id .. " " .. kind .. " part " .. k)
					end
					local cube = Build.part(24, base[24].slot, "Block", "Iron",
						if kind == "floating" then { 0.7, 0.2, 0.2 } else base[23].pos, Build.I, { 0.05, 0.05, 0.05 })
					A.eq(Shape.bitDifference(parts[24], cube), nil, id .. " " .. kind .. " part 24")
				end
			end
		end)

	t.it("Physics' verdict: P1 cleans 9 blocks, a speck is Dust, a floating one Disconnected", function()
		M.verdicts(Cost)
		A.eq(#Cost.get("P1").expect.cleaned, 9)
		A.eq(#Cost.get("P1-attached").expect.cleaned, 9, "Giant15 kept without Giant24, the speck Dust")
	end)

	t.it("X08's aliases and T-PERF-01's cases: P1 once, the specks, every worst design", function()
		A.eq(Cost.X08.X08a, "P2")
		A.eq(Cost.X08.X08b, "P1")
		A.eq(Cost.X08.X08c, "P5")
		for _, id in Cost.X08 do
			Cost.get(id)
		end
		local cases = Cost.TPERF
		A.eq(#cases, 5 + 6 + #WorstDesigns.valid + #WorstDesigns.tooComplex, "cases")
		A.eq(#WorstDesigns.valid, 11, "valid worst designs")
		A.eq(#WorstDesigns.tooComplex, 17, "TooComplex worst designs")
		local names: { [string]: boolean } = {}
		local p1 = 0
		for _, c in cases do
			A.falsy(names[c.name], "duplicate case " .. c.name)
			names[c.name] = true
			if c.core == Cost.get("P1").core then
				p1 += 1
			end
			A.eq(c.measureInvalid, string.find(c.name, "floating", 1, true) ~= nil, c.name .. " measureInvalid")
			A.eq(table.concat(Shape.problems(c.core, M.DEFS), "; "), "", c.name)
		end
		A.eq(p1, 1, "P1 runs once, as X08b and as §14.11's adversarial fixture")
		A.eq(cases[1].name, "P2 (X08a)")
		A.eq(cases[2].name, "P1 (X08b)")
		A.eq(cases[3].name, "P5 (X08c)")
	end)

	t.it("WorstDesigns is docs/spec/prototypes/S2/cover/worst_designs.luau, bit for bit", function()
		A.eq(Shape.bitDifference(WorstDesigns, Docs), nil, "the copy")
		for _, d in WorstDesigns.valid do
			A.truthy(d.verdictMs ~= nil, d.name .. " has its verdict's time")
		end
	end)

	t.it("deep-frozen; core(id) hands out a fresh mutable copy", function()
		M.frozen(Cost)
		A.truthy(table.isfrozen(WorstDesigns.valid[1].parts[1].pos) and table.isfrozen(Cost.TPERF[1].core), "frozen")
	end)
end)
