--!strict
-- The regression fixtures X01–X07 and the union blades X01 and X02 are measured against (SPEC §14.7, E-S2.5): their
-- records and relations, their structure against Definitions, the port from S2's prototype bit for bit, the canonical
-- fixed point and Physics' verdict on them. The relations themselves are T-DIF-13's (M3, tests/Physics).

local Test = require("../lib/Test")
local A = require("../lib/Assert")
local Blueprints = require("../fixtures/Blueprints")
local Regression = require("../fixtures/Regression")
local M = require("./Measured")

-- E-S2.5's bounds by kind (the prototype's regression() list).
local BOUND: { [string]: number } = { D = 0.01, Thinness = 0.02, Edge = 0.02, G = 0.01, Asym = 0.02, ["G+mass"] = 0.01 }

return Test.suite("FixtureSet/Regression", function(t)
	t.it("X01–X07, every variant and base: ids, labels and records, in the prototype's order", function()
		M.records(Regression, 34)
		A.eq(table.concat(Regression.order, " "), "X01base X01 X01raw X02base X02 X03 X04a X04b X04-5-0.004 X04-5-0.006 "
			.. "X04-5-0.009 X04-10-0.004 X04-10-0.006 X04-10-0.009 X04g0.005 X04g0.010 X04g0.015 X04g0.020 X05+0.002 "
			.. "X05+0.004 X05+0.006 X05+0.009 X05-0.005 X05-0.020 X05-0.050 X06-0.00 X06-0.01 X06-0.02 X06-0.03 X06-0.04 "
			.. "X06-0.05 X07a X07b X07c", "order")
		M.expectations(Regression)
	end)

	t.it("relations name a base that exists, with E-S2.5's kind and bound", function()
		for _, f in Regression.list do
			local r = f.expect.relation
			if string.sub(f.id, -4) == "base" then
				A.eq(r, nil, f.id .. " is a base")
				continue
			end
			A.truthy(r ~= nil, f.id .. " has a relation")
			local rel = r :: { to: string, kind: string, bound: number }
			A.truthy(BOUND[rel.kind] ~= nil, f.id .. " kind " .. rel.kind)
			A.eq(rel.bound, if f.id == "X01raw" then 0.05 else BOUND[rel.kind], f.id .. " bound")
			if rel.to == "F4" or rel.to == "F5" then
				Blueprints.get(rel.to)
			else
				A.eq(rel.to, string.sub(f.id, 1, 3) .. "base", f.id .. " base")
				Regression.get(rel.to)
			end
		end
		A.eq((Regression.get("X01").expect.relation :: any).to, "X01base", "X01 against its union blade")
		A.eq((Regression.get("X03").expect.relation :: any).to, "F4", "X03 is F4 + a fin")
	end)

	t.it("T-DEF-06 fixtures inside: canonical cores within Definitions' limits, 0.02 stud inside the hitbox", function()
		M.structure(Regression)
	end)

	t.it("every fixture is a fixed point of the canonical form", function()
		M.canonical(Regression)
	end)

	t.it("the rows are the prototype's regression() and its union blades, bit for bit", function()
		M.port(Regression, Regression.order)
	end)

	t.it("X01 and X01raw are one design; X01base and X02base are F5 with one blade, its copies' union", function()
		local x01, raw = Regression.core("X01"), Regression.core("X01raw")
		raw.name = x01.name
		A.deepEq(raw, x01, "X01raw = X01")
		local f5 = Blueprints.get("F5").core
		for _, id in { "X01base", "X02base" } do
			local parts = Regression.get(id).core.parts
			A.eq(#parts, 5, id)
			for k = 1, 3 do
				A.deepEq(parts[k], f5.parts[k], id .. " part " .. k)
			end
		end
	end)

	t.it("Physics' verdict: every fixture valid, X02 cleans five of its six copies", function()
		M.verdicts(Regression)
		for _, f in Regression.list do
			A.eq(#f.expect.cleaned, if f.id == "X02" then 5 else 0, f.id)
		end
	end)

	t.it("deep-frozen; core(id) hands out a fresh mutable copy", function()
		M.frozen(Regression)
	end)
end)
