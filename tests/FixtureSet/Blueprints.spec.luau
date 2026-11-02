--!strict
-- The fixtures F1–F5 (SPEC §14.7): their structure against Definitions, and their coordinates against E-S8.3's
-- independent oracle, with an exact geometry of the test side (Gen's AABBs, volumes and centroids), so a typo in a
-- coordinate fails here. Physics, validity and tiers wait for M2/M3 (fixture.expect holds them as data).

local Test = require("../lib/Test")
local A = require("../lib/Assert")
local Gen = require("../lib/Gen")
local Blueprints = require("../fixtures/Blueprints")
local Build = require("../fixtures/Build")
local Shape = require("./Shape")
local Balance = require("../../src/shared/Definitions/Balance")
local EquipmentTypes = require("../../src/shared/Definitions/EquipmentTypes")
local Limits = require("../../src/shared/Definitions/Limits")
local Materials = require("../../src/shared/Definitions/Materials")
local Steps = require("../../src/shared/Definitions/Steps")
local Tiers = require("../../src/shared/Definitions/Tiers")
local Versions = require("../../src/shared/Definitions/Versions")

local SWORD = EquipmentTypes.get("Sword") :: any
local DEFS: Shape.Defs = {
	limits = Limits,
	typeDef = SWORD,
	materials = Materials,
	schema = Versions.BLUEPRINT_SCHEMA,
	shapes = Gen.SHAPES,
}
local CTX = Gen.context(Limits, SWORD, Materials.enabled, Versions.BLUEPRINT_SCHEMA, Balance.Geometry)

-- E-S8.3 prints its oracle to 3–5 decimals: a value agrees when it rounds to the printed one.
local function printed(actual: number, expected: number, decimals: number, what: string)
	local half = 0.5 * 10 ^ -decimals + 1e-12
	A.near(actual, expected, half, what)
end

local function gripPoint(parts: { Gen.Part }): Gen.Vec
	local v, x, y, z = 0, 0, 0, 0
	for _, p in parts do
		if p.slot == "Grip" then
			local dv = Gen.volume(p)
			local c = Gen.centroid(p)
			v += dv
			x += dv * c[1]
			y += dv * c[2]
			z += dv * c[3]
		end
	end
	return { x / v, y / v, z / v }
end

return Test.suite("FixtureSet/Blueprints", function(t)
	t.it("F1–F5: ids, labels and records", function()
		A.eq(table.concat(Blueprints.order, " "), "F1 F2 F3 F4 F5", "order")
		A.eq(#Blueprints.list, 5, "fixtures")
		for i, f in Blueprints.list do
			A.eq(f.id, Blueprints.order[i], "list order")
			A.eq(Blueprints.get(f.id), f, "get(" .. f.id .. ")")
			A.eq(string.sub(f.label, 1, #f.id + 1), f.id .. " ", f.id .. " label")
			A.truthy(#f.what > 0, f.id .. " has a description")
		end
		A.throws(function()
			Blueprints.get("F6")
		end, "no fixture F6")
	end)

	t.it("T-DEF-06 fixtures inside: every fixture is a canonical BlueprintCore within Definitions' limits", function()
		for _, f in Blueprints.list do
			local problems = Shape.problems(f.core, DEFS)
			A.eq(table.concat(problems, "; "), "", f.id)
			A.eq(table.concat(Shape.slotProblems(f.core, SWORD), "; "), "", f.id .. " slot counts")
		end
	end)

	t.it("T-DEF-06 fixtures inside: every part is at least 0.02 stud inside the Sword hitbox (SPEC §14.7)", function()
		A.deepEq(Build.copy(SWORD.geometry.hitboxMin), { -0.8, 0, -0.3 }, "hitbox min (E-S8.3's frame)")
		A.deepEq(Build.copy(SWORD.geometry.hitboxMax), { 0.8, 5, 0.3 }, "hitbox max")
		for _, f in Blueprints.list do
			local margin = Gen.margin(CTX, f.core.parts)
			A.truthy(margin >= 0.02 - 1e-12, string.format("%s margin %.17g", f.id, margin))
		end
	end)

	t.it("coordinates match E-S8.3: min side, margin, grip point, reach", function()
		for _, f in Blueprints.list do
			local o = f.expect.oracle
			local parts = f.core.parts
			local minSide = math.huge
			for _, p in parts do
				minSide = math.min(minSide, p.size[1], p.size[2], p.size[3])
			end
			printed(minSide, o.minSide, 3, f.id .. " min side")
			printed(Gen.margin(CTX, parts), o.margin, 3, f.id .. " margin")
			local g = gripPoint(parts)
			printed(g[2], o.gripY, 4, f.id .. " grip y")
			A.near(g[1], 0, 1e-15, f.id .. " grip x")
			-- reach: the farthest exact Blade vertex from the grip point (every F blade part is a polyhedron)
			local reach = 0
			for _, p in parts do
				if p.slot == "Blade" then
					local verts = Gen.vertices(p)
					A.truthy(verts ~= nil, f.id .. " blade parts are polyhedra")
					for _, v in verts :: { Gen.Vec } do
						local dx, dy, dz = v[1] - g[1], v[2] - g[2], v[3] - g[3]
						reach = math.max(reach, math.sqrt(dx * dx + dy * dy + dz * dz))
					end
				end
			end
			printed(reach, o.reach, 4, f.id .. " reach")
		end
	end)

	t.it("F2 and F4 (no overlaps) match E-S8.3's volume, mass, COM and balance exactly", function()
		for _, id in { "F2", "F4" } do
			local f = Blueprints.get(id)
			local o = f.expect.oracle
			local v, m, mx, my = 0, 0, 0, 0
			for _, p in f.core.parts do
				local dv = Gen.volume(p)
				local rho = (Materials.get(p.material) :: any).density
				local c = Gen.centroid(p)
				v += dv
				m += rho * dv
				mx += rho * dv * c[1]
				my += rho * dv * c[2]
			end
			printed(v, o.volume, 5, id .. " volume")
			printed(m, o.mass, 4, id .. " mass")
			printed(mx / m, o.comX, 4, id .. " COM x")
			printed(my / m, o.comY, 4, id .. " COM y")
			printed(my / m - gripPoint(f.core.parts)[2], o.balanceFromHand, 4, id .. " balance from the hand")
		end
	end)

	t.it("F5 is F1 with parts 4 and 5 in Iron", function()
		local f1, f5 = Blueprints.core("F1"), Blueprints.core("F5")
		A.eq(f1.parts[4].material, "Steel")
		A.eq(f1.parts[5].material, "Steel")
		for _, p in f5.parts do
			A.eq(p.material, "Iron", "F5 part " .. p.id)
		end
		f1.parts[4].material, f1.parts[5].material = "Iron", "Iron"
		f1.name = f5.name
		A.eq(Shape.bitDifference(f5, f1), nil, "F5 = F1 all Iron")
	end)

	t.it("fixtures are deep-frozen; core(id) hands out a fresh mutable copy", function()
		for _, f in Blueprints.list do
			A.truthy(table.isfrozen(f.core) and table.isfrozen(f.core.parts) and table.isfrozen(f.core.parts[1].pos),
				f.id .. " frozen")
			A.throws(function()
				(f.core.parts[1].pos :: any)[1] = 1
			end, nil, f.id .. " refuses writes")
			local copy = Blueprints.core(f.id)
			A.eq(Shape.bitDifference(copy, f.core), nil, f.id .. " copy equals")
			A.truthy(copy ~= f.core and copy.parts[1] ~= f.core.parts[1] and copy.parts[1].rot ~= f.core.parts[1].rot,
				f.id .. " copy shares no table")
			copy.parts[1].pos[1] = 0.5
			A.eq(f.core.parts[1].pos[1], 0, f.id .. " original untouched")
		end
	end)

	t.it("expectations name enabled tiers for every enabled step, as SPEC §5.5's table", function()
		local tierIds: { string } = {}
		for _, row in Tiers.ordered do
			table.insert(tierIds, row.id)
		end
		for _, f in Blueprints.list do
			local e = f.expect
			A.eq(e.canon.ok, true, f.id)
			A.eq(e.canon.equals, "draft", f.id)
			A.eq(e.validation.valid, true, f.id)
			A.eq(e.save, "Valid", f.id)
			A.eq(e.starter, f.id == "F5", f.id .. " starter margin applies to F5 only")
			local n = 0
			for _ in e.tiers do
				n += 1
			end
			A.eq(n, #Steps.enabled, f.id .. " one tier per enabled step")
			for _, step in Steps.enabled do
				local played = e.tiers[step.id]
				A.truthy(played and Tiers.isEnabled(played), f.id .. " " .. step.id .. " plays an enabled tier")
				local raw = e.tierRaw[step.id]
				A.truthy(raw and table.find(tierIds, raw) ~= nil, f.id .. " " .. step.id .. " tierRaw")
				if raw ~= played then
					A.eq(played, Tiers.enabled[#Tiers.enabled].id, f.id .. " " .. step.id .. " clamps to the last enabled tier")
				end
			end
			local o = e.oracle
			for _, value in { o.minSide, o.margin, o.volume, o.mass, o.comX, o.comY, o.gripY, o.reach, o.balanceFromHand } do
				A.finite(value, f.id .. " oracle value")
			end
		end
		local function tiers(id: string): string
			local e = Blueprints.get(id).expect.tiers
			return string.format("%s/%s/%s", string.sub(e.Smelting, 1, 1), string.sub(e.Hammering, 1, 1),
				string.sub(e.Sharpening, 1, 1))
		end
		A.eq(tiers("F1") .. " " .. tiers("F2") .. " " .. tiers("F3") .. " " .. tiers("F4") .. " " .. tiers("F5"),
			"N/N/N N/N/N N/H/H H/N/H N/N/N", "§5.5")
	end)
end)
