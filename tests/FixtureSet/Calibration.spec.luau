--!strict
-- The calibration swords C01, C02, C02s, C04–C15 (SPEC §5.5, §14.7): their records, their structure against Definitions,
-- the port from S2's prototype bit for bit, the canonical fixed point and Physics' verdict on them. Their tiers are
-- T-DIF-11's (M3, tests/Physics); here only that each record names enabled tiers and §5.5's row.

local Test = require("../lib/Test")
local A = require("../lib/Assert")
local Calibration = require("../fixtures/Calibration")
local Build = require("../fixtures/Build")
local M = require("./Measured")

return Test.suite("FixtureSet/Calibration", function(t)
	t.it("C01, C02, C02s, C04–C15: ids, labels and records, in the prototype's order", function()
		M.records(Calibration, 15)
		A.eq(table.concat(Calibration.order, " "), "C01 C02 C02s C04 C05 C06 C07 C08 C09 C10 C11 C12 C13 C14 C15", "order")
		M.expectations(Calibration)
	end)

	t.it("SPEC §5.5's tiers, tierRaw where it differs", function()
		local function row(id: string): string
			local e = Calibration.get(id).expect
			local out: { string } = {}
			for _, step in { "Smelting", "Hammering", "Sharpening" } do
				local played, raw = e.tiers[step], e.tierRaw[step]
				table.insert(out, string.sub(played, 1, 1) .. (if raw ~= played then "(" .. raw .. ")" else ""))
			end
			return table.concat(out, "/")
		end
		local lines: { string } = {}
		for _, id in Calibration.order do
			table.insert(lines, id .. " " .. row(id))
		end
		A.eq(table.concat(lines, ", "), "C01 N/N/N, C02 N/N/N, C02s N/N/N, C04 N/H/H(Expert), C05 H(Expert)/N/H, "
			.. "C06 N/H/H(Expert), C07 N/N/N, C08 N/N/H, C09 N/H/N, C10 N/N/N, C11 N/N/N, C12 N/N/N, C13 N/N/N, C14 N/N/N, "
			.. "C15 N/H/H(Expert)", "§5.5")
	end)

	t.it("T-DEF-06 fixtures inside: canonical cores within Definitions' limits, 0.02 stud inside the hitbox", function()
		M.structure(Calibration)
	end)

	t.it("every fixture is a fixed point of the canonical form", function()
		M.canonical(Calibration)
	end)

	t.it("the rows are the prototype's calibration(), bit for bit", function()
		M.port(Calibration, Calibration.order)
	end)

	t.it("C02s is C02 in Steel; C14 is C02 moved (0, +0.27, +0.05)", function()
		local iron, steel = Calibration.core("C02"), Calibration.core("C02s")
		for i, p in iron.parts do
			A.eq(steel.parts[i].material, "Steel", "C02s part " .. i)
			p.material = "Steel"
		end
		iron.name = steel.name
		A.deepEq(iron, steel, "C02s = C02 all Steel")
		local moved = Calibration.get("C14").core
		for i, p in Calibration.get("C02").core.parts do
			local q = moved.parts[i]
			A.near(q.pos[1], p.pos[1], 0, "C14 part " .. i .. " x")
			A.near(q.pos[2], p.pos[2] + 0.27, 1e-15, "C14 part " .. i .. " y")
			A.near(q.pos[3], p.pos[3] + 0.05, 1e-15, "C14 part " .. i .. " z")
		end
	end)

	t.it("Physics' verdict: every fixture valid, C10 and C11 clean their 2 hidden blocks and 2 Dust specks", function()
		M.verdicts(Calibration)
		for _, f in Calibration.list do
			A.eq(#f.expect.cleaned, if f.id == "C10" or f.id == "C11" then 4 else 0, f.id)
		end
	end)

	t.it("deep-frozen; core(id) hands out a fresh mutable copy", function()
		M.frozen(Calibration)
		A.truthy(Build.YM90[2] == -Build.R and Build.YM90[4] == Build.R, "Build.YM90")
	end)
end)
