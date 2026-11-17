--!strict
-- T-PHY-02…08, 10 Physics/MassProps (SPEC §4.3, §4.5, E-S2.5, E-S2.7, E-S2.9, E-S8.3, E-S8.5): overlap ownership, mass,
-- centre of mass, grip frames, guard line, balance, reach, and what the fixtures measure. edgeLength and cutIndex are
-- M3's (T-EDG), as is the golden of E-S2.9's whole table; T-PHY-02 here checks the physics columns of F1–F5.

local Test = require("../lib/Test")
local A = require("../lib/Assert")
local Dump = require("../lib/Dump")
local Gen = require("../lib/Gen")
local Prop = require("../lib/Prop")
local TestRng = require("../lib/TestRng")
local Tol = require("../lib/Tol")
local Adversarial = require("../fixtures/Adversarial")
local Blueprints = require("../fixtures/Blueprints")
local H = require("./PhysicsHelpers")
local Balance = require("../../src/shared/Definitions/Balance")
local EquipmentTypes = require("../../src/shared/Definitions/EquipmentTypes")
local Limits = require("../../src/shared/Definitions/Limits")
local Materials = require("../../src/shared/Definitions/Materials")
local Versions = require("../../src/shared/Definitions/Versions")
local Mirror = require("../../src/shared/Blueprint/Mirror")
local Quat = require("../../src/shared/Blueprint/Quat")
local Analyze = require("../../src/shared/Physics/Analyze")
local MassProps = require("../../src/shared/Physics/MassProps")
local Shapes = require("../../src/shared/Physics/Shapes")

type Rng = TestRng.TestRng

local Geo = Balance.Geometry
local SWORD: any = EquipmentTypes.get("Sword")
local CTX = Gen.context(Limits, SWORD, Materials.enabled, Versions.BLUEPRINT_SCHEMA, Geo)
local PI = Shapes.PI
local IRON = (Materials.get("Iron") :: any).density
local STEEL = (Materials.get("Steel") :: any).density

local function physicsOf(core: any): any
	local report = Analyze.run(core)
	A.truthy(report.validation.ok, tostring(core.name) .. " must be valid: " .. Dump.short(report.validation.errors))
	return report.physics
end

local function blockAt(id: number, pos: { number }, size: { number }, rot: { number }?, slot: string?): any
	return H.solid(id, "Block", pos, rot or H.I, size, slot)
end

-- Midpoint sampling of p ∩ (q1 ∪ … ∪ qk) on an n³ grid over p's local box: T-PHY's slow, independent answer.
local function fineOverlap(p: any, H_: { any }, n: number): (number, number, number, number)
	local V, X, Y, Z = 0, 0, 0, 0
	local dx, dy, dz = 2 * p.hx / n, 2 * p.hy / n, 2 * p.hz / n
	local cell = dx * dy * dz
	for i = 0, n - 1 do
		for j = 0, n - 1 do
			for k = 0, n - 1 do
				local lx, ly, lz = -p.hx + (i + 0.5) * dx, -p.hy + (j + 0.5) * dy, -p.hz + (k + 0.5) * dz
				if Shapes.sdLocal(p, lx, ly, lz) < 0 then
					local x, y, z = Shapes.toWorld(p, lx, ly, lz)
					for _, q in ipairs(H_) do
						if Shapes.sd(q, x, y, z) < 0 then
							V += cell
							X += cell * x
							Y += cell * y
							Z += cell * z
							break
						end
					end
				end
			end
		end
	end
	return V, X, Y, Z
end

-- A box's half extents ∩ (a union of boxes {lo, hi} inside it, same frame): volume and first moment in that frame, by
-- compressing coordinates. The exact answer for parts that share a frame, independent of any clipping.
local function boxUnion(half: { number }, boxes: { any }): (number, number, number, number)
	local cuts: { { number } } = {}
	for k = 1, 3 do
		cuts[k] = { -half[k], half[k] }
		for _, box in ipairs(boxes) do
			table.insert(cuts[k], box.lo[k])
			table.insert(cuts[k], box.hi[k])
		end
		table.sort(cuts[k])
	end
	local V, X, Y, Z = 0, 0, 0, 0
	for i = 1, #cuts[1] - 1 do
		for j = 1, #cuts[2] - 1 do
			for l = 1, #cuts[3] - 1 do
				local x0, x1, y0, y1, z0, z1 = cuts[1][i], cuts[1][i + 1], cuts[2][j], cuts[2][j + 1], cuts[3][l], cuts[3][l + 1]
				local mx, my, mz = (x0 + x1) / 2, (y0 + y1) / 2, (z0 + z1) / 2
				for _, box in ipairs(boxes) do
					if mx > box.lo[1] and mx < box.hi[1] and my > box.lo[2] and my < box.hi[2] and mz > box.lo[3] and mz < box.hi[3] then
						local v = (x1 - x0) * (y1 - y0) * (z1 - z0)
						V, X, Y, Z = V + v, X + v * mx, Y + v * my, Z + v * mz
						break
					end
				end
			end
		end
	end
	return V, X, Y, Z
end

-- A rotation and a position within eps of the given ones.
local function nearly(rng: Rng, rot: { number }, pos: { number }, eps: number): ({ number }, { number })
	local tilt = { eps * rng:range(-1, 1), eps * rng:range(-1, 1), eps * rng:range(-1, 1), 1 }
	return Quat.normalize(Quat.mul(rot, tilt)), { pos[1] + eps * rng:range(-1, 1), pos[2] + eps * rng:range(-1, 1), pos[3] + eps * rng:range(-1, 1) }
end

-- E-S2.9's physics columns: mass, volume, balance, reach, blade length, with the digits it prints.
local E_S2_9: { { id: string, mass: number, volume: number, balance: number, reach: number, blade: number } } = {
	{ id = "F1", mass = 0.7924, volume = 0.10075, balance = 0.127, reach = 3.310, blade = 2.770 },
	{ id = "F2", mass = 1.0813, volume = 0.13740, balance = -0.057, reach = 3.102, blade = 2.500 },
	{ id = "F3", mass = 0.3065, volume = 0.03904, balance = -0.063, reach = 4.230, blade = 3.740 },
	{ id = "F4", mass = 3.2303, volume = 0.41046, balance = 0.913, reach = 3.257, blade = 2.675 },
	{ id = "F5", mass = 0.7929, volume = 0.10075, balance = 0.128, reach = 3.310, blade = 2.770 },
}

local function allowedMassError(id: string): number
	-- F3's ball quillons overlap its guard: refined sampling, whose box depends on the world AABB
	return if id == "F3" then Tol.TOL_MASS_REL else Tol.TOL_ANALYTIC_REL
end

return Test.suite("Physics/MassProps", function(t)
	t.it("T-PHY-02 F1–F5 measure E-S2.9's physics table", function()
		for _, row in ipairs(E_S2_9) do
			local p = physicsOf(Blueprints.get(row.id).core)
			A.near(p.mass, row.mass, 5.1e-5, row.id .. " mass")
			A.near(p.volume, row.volume, 5.1e-6, row.id .. " volume")
			A.near(p.balance, row.balance, 5.1e-4, row.id .. " balance")
			A.near(p.reach, row.reach, 5.1e-4, row.id .. " reach")
			A.near(p.bladeLength, row.blade, 5.1e-4, row.id .. " bladeLength")
			for _, keep in ipairs(p.kept) do
				A.truthy(keep, row.id .. ": every part is kept")
			end
		end
	end)

	t.it("T-PHY-03 E-S2.9 = the independent oracle of E-S8.3", function()
		for _, id in ipairs(Blueprints.order) do
			local fixture = Blueprints.get(id)
			local oracle = fixture.expect.oracle
			local p = physicsOf(fixture.core)
			A.rel(p.volume, oracle.volume, Tol.TOL_MASS_REL, id .. " volume")
			A.rel(p.mass, oracle.mass, Tol.TOL_MASS_REL, id .. " mass")
			A.near(p.com[1], oracle.comX, Tol.TOL_BALANCE_ABS, id .. " COM x")
			A.near(p.com[2], oracle.comY, Tol.TOL_BALANCE_ABS, id .. " COM y")
			A.near(p.gripPoint[2], oracle.gripY, 1e-12, id .. " grip y")
			A.near(p.reach, oracle.reach, Tol.TOL_REACH_ABS, id .. " reach")
			A.near(p.balanceFromHand, oracle.balanceFromHand, Tol.TOL_BALANCE_ABS, id .. " COM_y − grip_y")
		end
	end)

	t.it("§4.5 F2 by hand: the guard line, balance, lengths and the off-axis COM", function()
		local p = physicsOf(Blueprints.get("F2").core)
		A.near(p.gripPoint[1], 0, 1e-12, "grip point x")
		A.near(p.gripPoint[2], 0.85, 1e-12, "grip point y")
		A.near(p.gripPoint[3], 0, 1e-12, "grip point z")
		A.near(p.gripAxis[1], 0, 1e-12, "grip axis x")
		A.near(p.gripAxis[2], 1, 1e-12, "grip axis y")
		A.near(p.guardPos, 1.45 - 0.85, 1e-12, "guardPos")
		A.near(p.balance, p.balanceFromHand - p.guardPos, 1e-12)
		A.near(p.bladeLength, 3.95 - 0.85 - 0.6, 1e-12, "bladeLength")
		A.near(p.totalLength, 3.95 - 0.05, 1e-12, "totalLength")
		A.near(p.reach, math.sqrt(0.1 * 0.1 + 3.1 * 3.1 + 0.04 * 0.04), 1e-12, "reach: the farthest Blade vertex")
		A.near(p.comOffAxis, 0, 1e-12, "F2 is symmetric")
		local cleaver = physicsOf(Blueprints.get("F4").core)
		A.near(cleaver.comOffAxis, cleaver.com[1], 1e-12, "F4: (COM − g)·N, N = +X for a grip along +Y")
		A.truthy(cleaver.comOffAxis > 0.1)
	end)

	t.it("§4.5 the guard line is the volume-weighted centroid of the Guard parts", function()
		local p = physicsOf(H.core("guards", {
			H.part(1, "Grip", "Block", "Iron", { 0, 1, 0 }, H.I, { 0.1, 1, 0.1 }),
			H.part(2, "Guard", "Block", "Iron", { 0, 1.55, 0 }, H.I, { 0.6, 0.1, 0.2 }),
			H.part(3, "Guard", "Block", "Iron", { 0, 1.65, 0 }, H.I, { 0.1, 0.1, 0.1 }),
			H.part(4, "Blade", "Block", "Iron", { 0, 2.7, 0 }, H.I, { 0.2, 2, 0.05 }),
		}))
		local v2, v3 = 0.6 * 0.1 * 0.2, 0.1 * 0.1 * 0.1
		A.near(p.guardPos, (v2 * 0.55 + v3 * 0.65) / (v2 + v3), 1e-12, "guardPos")
		local first = physicsOf(H.core("guardFirst", {
			H.part(1, "Guard", "Block", "Iron", { 0, 1.55, 0 }, H.I, { 0.6, 0.1, 0.2 }),
			H.part(2, "Grip", "Block", "Iron", { 0, 1, 0 }, H.I, { 0.1, 1, 0.1 }),
			H.part(3, "Blade", "Block", "Iron", { 0, 2.6, 0 }, H.I, { 0.2, 2, 0.05 }),
		}))
		A.near(first.guardPos, 0.55, 1e-12, "a Guard part with the lowest id")
	end)

	t.it("§4.5 COM takes the overlap's moment off every axis: an overlap off the design's centre", function()
		-- two Iron cubes, the Blade's owning the box they share: x 0.2…0.3, y 2.0…2.1, z −0.05…0.15
		local core = H.core("offset", {
			H.part(1, "Grip", "Block", "Iron", { 0.3, 2, 0.05 }, H.I, { 0.2, 0.2, 0.2 }),
			H.part(2, "Blade", "Block", "Iron", { 0.2, 2.1, 0.05 }, H.I, { 0.2, 0.2, 0.2 }),
		})
		local p = Analyze.run(core, { measureInvalid = true }).physics :: any
		local cube, shared = 0.2 * 0.2 * 0.2, 0.1 * 0.1 * 0.2
		local union = 2 * cube - shared
		A.rel(p.volume, union, 1e-12, "volume")
		A.near(p.com[1], (cube * 0.2 + cube * 0.3 - shared * 0.25) / union, 1e-12, "COM x")
		A.near(p.com[2], (cube * 2.1 + cube * 2 - shared * 2.05) / union, 1e-12, "COM y")
		A.near(p.com[3], 0.05, 1e-12, "COM z")
	end)

	t.it("§4.5 mass = Σ ρ·V_own and COM = Σ ρ·M1_own / M, by hand on a mixed-material design", function()
		local core = H.core("mix", {
			H.part(1, "Grip", "Block", "Iron", { 0, 1, 0 }, H.I, { 0.2, 1, 0.2 }),
			H.part(2, "Blade", "Block", "Steel", { 0, 2, 0 }, H.I, { 0.2, 1, 0.2 }),
		})
		local p = physicsOf(core)
		local v = 0.2 * 1 * 0.2
		A.rel(p.mass, (IRON + STEEL) * v, 1e-15)
		A.rel(p.volume, 2 * v, 1e-15)
		A.near(p.com[2], (IRON * 1 + STEEL * 2) / (IRON + STEEL), 1e-12)
		A.deepEq(p.ownedVolume, { v, v }, "per part, in blueprint order")
	end)

	t.it("T-PHY-04 Y/Z translation: mass within TOL_ANALYTIC_REL, COM moves by δ, balance and reach stay", function()
		for _, id in ipairs(Blueprints.order) do
			local base = physicsOf(Blueprints.get(id).core)
			for _, delta in ipairs({ { 0.013, 0 }, { -0.015, 0 }, { 0, 0.01 }, { 0.017, -0.019 } }) do
				local p = physicsOf(Gen.translate(Blueprints.core(id) :: any, delta[1], delta[2]))
				A.rel(p.mass, base.mass, Tol.TOL_ANALYTIC_REL, id .. " mass")
				A.near(p.com[1], base.com[1], 1e-9, id .. " COM x")
				A.near(p.com[2], base.com[2] + delta[1], 1e-9, id .. " COM y")
				A.near(p.com[3], base.com[3] + delta[2], 1e-9, id .. " COM z")
				A.near(p.gripPoint[2], base.gripPoint[2] + delta[1], 1e-12, id .. " grip point")
				A.near(p.balance, base.balance, 1e-9, id .. " balance")
				A.near(p.reach, base.reach, 1e-9, id .. " reach")
			end
		end
	end)

	-- Generated swords have round parts overlapping others: refined sampling, whose grid moves when a merely touching part
	-- falls in or out of the broad phase by rounding, so these hold to the player-facing tolerances, not the analytic one.
	-- Fast until M3's fix round 1 (§14.1's 27 s); --quick keeps T-PHY-04 on the fixtures, above.
	t.slow("T-PHY-04 Y/Z translation on generated swords, within TOL_MASS_REL and TOL_BALANCE_ABS", function()
		Prop.check(40, function(rng: Rng): any
			local core = Gen.validSword(rng, CTX)
			local moved, delta = Gen.translated(rng, CTX, core)
			return { core = core, moved = moved, delta = delta }
		end, function(c: any)
			local a, b = physicsOf(c.core), physicsOf(c.moved)
			A.rel(b.mass, a.mass, Tol.TOL_MASS_REL, "mass")
			for k = 1, 3 do
				A.near(b.com[k], a.com[k] + c.delta[k], Tol.TOL_BALANCE_ABS, "COM moves by δ")
			end
			A.near(b.reach, a.reach, 1e-9, "reach")
		end)
	end)

	t.it("T-PHY-05 any rotation keeps mass; about the grip axis, reach and balance too", function()
		for _, id in ipairs(Blueprints.order) do
			local core = Blueprints.core(id)
			local base = H.measure(core)
			local rng = TestRng.new(Tol.PROP_BASE_SEED)
			for _ = 1, 8 do
				local turned = H.measure(H.rotated(core, H.randomQuat(rng), { rng:range(-1, 1), rng:range(0, 5), rng:range(-1, 1) }))
				A.rel(turned.mass, base.mass, allowedMassError(id), id .. " any rotation keeps mass")
			end
			for _, degrees in ipairs({ 17, 45, 90, 123, 270 }) do
				local p = H.measure(H.rotated(core, H.axisAngle(0, 1, 0, degrees), base.gripPoint))
				A.rel(p.mass, base.mass, allowedMassError(id), id .. " mass")
				A.near(p.gripAxis[1], base.gripAxis[1], 1e-12, id .. " axis x")
				A.near(p.gripAxis[2], base.gripAxis[2], 1e-12, id .. " axis y")
				A.near(p.reach, base.reach, 1e-9, id .. " reach")
				local tolerance = if id == "F3" then Tol.TOL_BALANCE_ABS else 1e-9
				A.near(p.balance, base.balance, tolerance, id .. " balance")
			end
		end
	end)

	t.it("T-PHY-05 a design tilted in the plane, turned about its own grip axis, keeps reach and balance", function()
		local tilted = H.rotated(Blueprints.core("F2"), H.axisAngle(0, 0, 1, 25), { 0, 0.85, 0 })
		local base = H.measure(tilted)
		A.near(base.gripAxis[1], -math.sin(math.rad(25)), 1e-12, "the axis follows the elongated grip")
		A.near(base.gripAxis[2], math.cos(math.rad(25)), 1e-12)
		local q = H.axisAngle(base.gripAxis[1], base.gripAxis[2], 0, 60)
		local p = H.measure(H.rotated(tilted, q, base.gripPoint))
		A.rel(p.mass, base.mass, Tol.TOL_ANALYTIC_REL, "mass")
		A.near(p.reach, base.reach, 1e-9, "reach")
		A.near(p.balance, base.balance, 1e-9, "balance")
		-- off the plane x = 0: a shift across the axis moves nothing along it
		local shifted = Blueprints.core("F2")
		shifted.parts = H.rotated(Blueprints.core("F2"), H.axisAngle(0, 0, 1, 25), { 0, 0.85, 0 }).parts
		for _, part in ipairs(shifted.parts) do
			part.pos[1] += 0.1
		end
		local s = H.measure(shifted)
		A.near(s.guardPos, base.guardPos, 1e-9, "guardPos, off x = 0")
		A.near(s.balance, base.balance, 1e-9, "balance, off x = 0")
		A.near(s.balanceFromHand, base.balanceFromHand, 1e-9, "balanceFromHand, off x = 0")
		A.near(s.comOffAxis, base.comOffAxis, 1e-9, "comOffAxis, off x = 0")
		A.near(s.bladeLength, base.bladeLength, 1e-9, "bladeLength, off x = 0")
	end)

	t.it("T-PHY-06 q ↔ −q on every part: bit-identical", function()
		for _, id in ipairs(Blueprints.order) do
			local negated = Blueprints.core(id)
			for _, p in ipairs(negated.parts) do
				p.rot = { -p.rot[1], -p.rot[2], -p.rot[3], -p.rot[4] }
			end
			A.eq(Dump.canonical(Analyze.run(negated :: any)), Dump.canonical(Analyze.run(Blueprints.get(id).core :: any)), id)
		end
	end)

	t.it("T-PHY-07 density scales mass and leaves COM; a heavier pommel moves the balance toward the hand", function()
		local iron = Blueprints.core("F5")
		local steel = Blueprints.core("F5")
		for _, p in ipairs(steel.parts) do
			p.material = "Steel"
		end
		local a, b = physicsOf(iron), physicsOf(steel)
		A.rel(b.mass / a.mass, STEEL / IRON, Tol.TOL_ANALYTIC_REL, "mass ∝ density")
		for k = 1, 3 do
			A.near(b.com[k], a.com[k], 1e-12, "COM")
		end
		A.near(b.balance, a.balance, 1e-12, "balance")
		A.eq(b.reach, a.reach, "reach")
		A.eq(b.volume, a.volume, "volume")
		-- retired rows stay readable: Bronze 8.80, Wood 0.65
		local function withPommel(material: string): any
			local core = Blueprints.core("F5")
			core.parts[1].material = material
			return physicsOf(core)
		end
		local heavy, light = withPommel("Bronze"), withPommel("Wood")
		A.truthy(heavy.mass > a.mass and a.mass > light.mass, "mass follows the pommel's density")
		A.truthy(heavy.balance < a.balance and a.balance < light.balance, "a heavier pommel moves the balance toward the hand")
		A.near(heavy.balance - a.balance, heavy.balanceFromHand - a.balanceFromHand, 1e-12, "the guard line does not move")
		-- the same steps by volume: a larger pommel
		local bigger = Blueprints.core("F2")
		bigger.parts[1].size = { 0.5, 0.3, 0.5 }
		A.truthy(physicsOf(bigger).balance < physicsOf(Blueprints.get("F2").core).balance, "more pommel, closer to the hand")
	end)

	t.it("T-PHY-08 the physics frame is the kept Grip parts, V4's every one, the difficulty frame the kept ones' point with "
		.. "a fixed +Y axis", function()
		-- F1 + an enclosed grip core off the grip's axis, turned 20° about Z (A25)
		local core = H.f("F1")
		table.insert(core.parts, H.part(6, "Grip", "Block", "Iron", { 0.005, 0.85, 0 }, H.axisAngle(0, 0, 1, 20), { 0.04, 0.30, 0.06 }))
		local report = Analyze.run(core)
		A.deepEq(report.cleaned, { { partId = 6, reason = "Enclosed" } })
		local p = report.physics :: any
		local parts = H.prepared(core)
		local kept = p.kept
		A.deepEq(p.gripPoint, { 0, 0.75, 0 }, "physics: the kept Grip part only, a cleaned one steers nothing")
		A.deepEq(p.gripAxis, { 0, 1 }, "physics: the tilted core has no vote")
		local gripV, coreV = 0.16 * 0.9 * 0.16, 0.04 * 0.30 * 0.06
		local v4Point, v4Axis = MassProps.validationFrame(parts, "Grip")
		A.near(v4Point[1], (coreV * 0.005) / (gripV + coreV), 1e-12, "V4, before the verdict: every Grip part")
		A.near(v4Point[2], (gripV * 0.75 + coreV * 0.85) / (gripV + coreV), 1e-12)
		A.truthy(v4Axis[1] < 0, "V4: the tilted core tilts its axis")
		local point, axis = MassProps.difficultyFrame(parts, kept, "Grip")
		A.near(point[1], 0, 1e-12, "difficulty: the kept Grip part only")
		A.near(point[2], 0.75, 1e-12)
		A.near(point[3], 0, 1e-12)
		A.deepEq(axis, { 0, 1 }, "difficulty: fixed +Y")
		-- A25 measures F1 (E-S2.7): before M3's fix round 1 its core tilted the axis to (−0.010, 1.000), balance 0.1272
		-- (F1 0.1272) and cutIndex 0.724130 (0.724180)
		local a25 = H.f("F1")
		table.insert(a25.parts, H.part(6, "Grip", "Block", "Iron", { 0, 0.75, 0 }, H.axisAngle(0, 0, 1, 20), { 0.04, 0.30, 0.06 }))
		local a25p, f1p = physicsOf(a25), physicsOf(H.f("F1"))
		A.deepEq(a25p.gripAxis, { 0, 1 }, "A25 axis")
		for _, field in ipairs({ "guardPos", "balance", "balanceFromHand", "reach", "bladeLength", "cutIndex" }) do
			A.eq(a25p[field], f1p[field], "A25 " .. field)
		end
		-- A26: F1's grip as 4 rings (no axis), then a visible 40° strap
		local rings = H.f("F1")
		rings.parts[2] = H.part(2, "Grip", "Block", "Iron", { 0, 0.30 + 0.1125, 0 }, H.I, { 0.20, 0.225, 0.20 })
		for k = 1, 3 do
			table.insert(rings.parts, H.part(5 + k, "Grip", "Block", "Iron", { 0, 0.30 + 0.1125 + k * 0.225, 0 }, H.I, { 0.20, 0.225, 0.20 }))
		end
		local base = physicsOf(rings)
		A.deepEq(base.gripAxis, { 0, 1 }, "no ring is elongated: no axis, +Y")
		A.near(base.balance, 0.051, 5e-4, "ring grip balance")
		table.insert(rings.parts, H.part(9, "Grip", "Block", "Iron", { 0, 0.75, 0 }, H.axisAngle(0, 0, 1, 40), { 0.05, 0.40, 0.05 }))
		local strap = physicsOf(rings)
		A.near(strap.gripAxis[1], -0.643, 5e-4, "A26 axis x")
		A.near(strap.gripAxis[2], 0.766, 5e-4, "A26 axis y")
		A.near(strap.balance, 0.038, 5e-4, "A26 balance")
		A.near(strap.reach, 3.310, 5e-4, "A26 reach")
		-- a kept grip that tilts: the physics axis follows it, the difficulty axis stays +Y
		local tilted = H.prepared(H.core("tilted", {
			H.part(1, "Grip", "Block", "Iron", { 0, 1, 0 }, H.axisAngle(0, 0, 1, 25), { 0.1, 1, 0.1 }),
			H.part(2, "Blade", "Block", "Iron", { 0, 2, 0 }, H.I, { 0.2, 1, 0.1 }),
		}))
		local _, physicsAxis = MassProps.physicsFrame(tilted, { true, true }, "Grip")
		A.truthy(physicsAxis[1] < -0.3, "the physics axis follows the grip: " .. physicsAxis[1])
		A.deepEq({ MassProps.validationFrame(tilted, "Grip") }, { MassProps.physicsFrame(tilted, { true, true }, "Grip") },
			"nothing cleaned: V4's frame is the physics frame")
		A.deepEq({ MassProps.physicsFrame(tilted, { false, true }, "Grip") }, { { 0, 0, 0 }, { 0, 1 } },
			"no kept Grip part (measureInvalid only): the origin and +Y, as with none")
		local _, difficultyAxis = MassProps.difficultyFrame(tilted, { true, true }, "Grip")
		A.deepEq(difficultyAxis, { 0, 1 }, "fixed +Y")
		local difficultyPoint = MassProps.difficultyFrame(tilted, { true, true }, "Grip")
		A.near(difficultyPoint[2], 1, 1e-12, "the Grip part with the lowest index counts")
	end)

	-- M3's review (V2): with every Grip part in the frame, the strap tilted the axis to (−0.342, 0.940) and (−0.643, 0.766),
	-- bladeLength 2.7699 → 2.6029 and 2.1219, cutIndex 0.724180 → 0.668445 and 0.507963 (S4's Damage), D unchanged.
	t.it("§4.5 a cleaned Grip part steers nothing: a strap hidden in A26's ring grip, turned 20° and 40°, measures A26base",
		function()
			local base = Analyze.run(Adversarial.variant("A26base").draft())
			for _, degrees in ipairs({ 20, 40 }) do
				local core = Adversarial.variant("A26base").draft()
				table.insert(core.parts, H.part(9, "Grip", "Block", "Iron", { 0, 0.6375, 0 }, H.axisAngle(0, 0, 1, degrees),
					{ 0.05, 0.20, 0.05 }))
				local report = Analyze.run(core)
				local what = "the strap turned " .. degrees .. "°"
				A.truthy(report.validation.ok, what .. " is valid")
				A.deepEq(report.cleaned, { { partId = 9, reason = "Enclosed" } }, what)
				local p, q = report.physics :: any, base.physics :: any
				A.deepEq(p.gripPoint, q.gripPoint, what .. ": the grip point")
				A.deepEq(p.gripAxis, { 0, 1 }, what .. ": no vote, the rings have none")
				for _, field in ipairs({ "guardPos", "reach", "bladeLength", "totalLength", "cutIndex", "edgeLength" }) do
					A.eq(p[field], q[field], what .. ": " .. field)
				end
				A.near(p.balance, q.balance, 1e-12, what .. ": balance")
				A.eq(p.cutIndex, 0.72417951973367989, what .. ": cutIndex, F1's")
				A.eq(Dump.canonical(report.steps), Dump.canonical(base.steps), what .. ": steps")
				A.eq(Dump.canonical(report.edge), Dump.canonical(base.edge), what .. ": edge")
			end
		end)

	t.it("§4.5 the grip axis: which parts have one, the sign rule, the tilt rule", function()
		local function axisOf(parts: { any }): { number }
			local list = {}
			for i, p in ipairs(parts) do
				list[i] = Shapes.prepare(p, i)
			end
			local _, axis = MassProps.gripFrame(list)
			return axis
		end
		A.deepEq(axisOf({}), { 0, 1 }, "no part")
		A.deepEq(axisOf({ H.solid(1, "Ball", { 0, 0, 0 }, H.I, { 1, 1, 1 }) }), { 0, 1 }, "never a Ball")
		A.deepEq(axisOf({ H.solid(1, "Block", { 0, 0, 0 }, H.I, { 0.2, 0.25, 0.2 }) }), { 0, 1 }, "a stub is not elongated")
		A.deepEq(axisOf({ blockAt(1, { 0, 0, 0 }, { 0.03, 0.09, 0.03 }, H.axisAngle(0, 0, 1, 30)) }), { 0, 1 }, "never dust")
		local q = H.axisAngle(0, 0, 1, 30)
		local tilted = axisOf({ blockAt(1, { 0, 0, 0 }, { 0.1, 0.6, 0.1 }, q) })
		A.near(tilted[1], -0.5, 1e-12, "local Y, the longest axis")
		A.near(tilted[2], math.sqrt(3) / 2, 1e-12)
		-- which local axis is the longest, each way round
		local q110 = H.axisAngle(0, 0, 1, 110)
		A.near(axisOf({ blockAt(1, { 0, 0, 0 }, { 0.6, 0.1, 0.1 }, q110) })[1], -math.sin(math.rad(20)), 1e-12, "local X, Y = Z")
		A.near(axisOf({ blockAt(1, { 0, 0, 0 }, { 0.6, 0.1, 0.2 }, q110) })[1], -math.sin(math.rad(20)), 1e-12, "local X, Y < Z")
		A.deepEq(axisOf({ blockAt(1, { 0, 0, 0 }, { 0.6, 0.5, 0.1 }, q110) }), { 0, 1 }, "local X, under 1.5 × the middle")
		local tiltedZ = Quat.mul(H.axisAngle(0, 0, 1, 30), H.axisAngle(1, 0, 0, -70))
		A.deepEq(axisOf({ blockAt(1, { 0, 0, 0 }, { 0.1, 0.5, 0.6 }, tiltedZ) }), { 0, 1 }, "local Z, under 1.5 × the middle")
		-- the longest half extent must reach AXIS_ELONGATION × the middle one
		local ratio = Geo.AXIS_ELONGATION
		A.deepEq(axisOf({ blockAt(1, { 0, 0, 0 }, { 0.2, 0.2 * ratio * 0.999, 0.1 }, q) }), { 0, 1 }, "just under")
		A.near(axisOf({ blockAt(1, { 0, 0, 0 }, { 0.2, 0.2 * ratio, 0.1 }, q) })[1], -0.5, 1e-12, "exactly there")
		-- a cylinder: local X
		local along = axisOf({ H.solid(1, "Cylinder", { 0, 0, 0 }, H.Z90, { 0.2, 0.9, 0.9 }) })
		A.near(along[1], 0, 1e-12, "a short fat cylinder still has its axis")
		A.near(along[2], 1, 1e-12)
		-- tilted too: at Z90 a wrong axis falls back to +Y and looks right
		local tiltedCylinder = axisOf({ H.solid(1, "Cylinder", { 0, 0, 0 }, H.axisAngle(0, 0, 1, 110), { 0.6, 0.1, 0.1 }) })
		A.near(tiltedCylinder[1], -math.sin(math.rad(20)), 1e-12, "local X, flipped to ê_y ≥ 0")
		A.near(tiltedCylinder[2], math.cos(math.rad(20)), 1e-12)
		-- ê_y ≥ 0: a local axis pointing down counts upward
		local down = axisOf({ blockAt(1, { 0, 0, 0 }, { 0.1, 0.6, 0.1 }, H.axisAngle(0, 0, 1, 170)) })
		A.near(down[2], math.cos(math.rad(10)), 1e-12, "flipped to ê_y ≥ 0")
		A.near(down[1], math.sin(math.rad(10)), 1e-12)
		-- tilted more than 45° has no vote, so alone it leaves +Y
		A.deepEq(axisOf({ blockAt(1, { 0, 0, 0 }, { 0.1, 0.6, 0.1 }, H.axisAngle(0, 0, 1, 50)) }), { 0, 1 }, "> 45°")
		A.near(axisOf({ blockAt(1, { 0, 0, 0 }, { 0.1, 0.6, 0.1 }, H.axisAngle(0, 0, 1, 44)) })[1], -math.sin(math.rad(44)), 1e-12, "< 45°")
		-- volume-weighted over parts: two equal parts turned opposite ways cancel in X
		local sum = axisOf({
			blockAt(1, { 0, 0, 0 }, { 0.1, 0.6, 0.1 }, H.axisAngle(0, 0, 1, 20)),
			blockAt(2, { 0, 1, 0 }, { 0.1, 0.6, 0.1 }, H.axisAngle(0, 0, 1, -20)),
		})
		A.near(sum[1], 0, 1e-12)
		A.near(sum[2], 1, 1e-12)
		-- a level part has no vote, however it was turned: the tilted part below decides alone
		local steep = H.part(2, "Grip", "Block", "Iron", { 0, 2, 0 }, H.axisAngle(0, 0, 1, 10), { 0.3, 1.5, 0.3 })
		local level = axisOf({ H.part(1, "Grip", "Block", "Iron", { 0, 1, 0 }, H.I, { 0.6, 0.1, 0.1 }), steep })
		local turned = axisOf({ H.part(1, "Grip", "Block", "Iron", { 0, 1, 0 }, { 0, 0, 1, 0 }, { 0.6, 0.1, 0.1 }), steep })
		A.near(level[1], turned[1], 1e-12, "a level part turned 180°, x")
		A.near(level[2], turned[2], 1e-12, "a level part turned 180°, y")
	end)

	t.it("§4.5 a part past 45° from +Y has no vote: a level crossbar neither tilts the sword nor flips it", function()
		local baseAxis = (physicsOf(Blueprints.core("F2")) :: any).gripAxis
		local gripPos = Blueprints.core("F2").parts[2].pos
		local function withBar(degrees: number, x: number?): any
			local core = Blueprints.core("F2")
			table.insert(core.parts, H.part(9, "Grip", "Block", "Iron", { x or 0, gripPos[2], 0 }, H.axisAngle(0, 0, 1, degrees),
				{ 0.5, 0.1, 0.1 }))
			return core
		end
		-- turned from level: the bar's axis is 90° − |angle| from +Y (the bar shows: every Grip part's frame is the physics frame)
		for _, degrees in ipairs({ 0, 1, -1, 30, -30, 44, -44, 180, 179 }) do
			local core = withBar(degrees)
			local _, axis = MassProps.validationFrame(H.prepared(core), "Grip")
			A.deepEq(axis, baseAxis, degrees .. "°: no vote")
		end
		for _, degrees in ipairs({ 46, -46, 60, -60 }) do
			local _, axis = MassProps.validationFrame(H.prepared(withBar(degrees)), "Grip")
			A.truthy(math.abs(axis[1]) > 1e-3, degrees .. "°: a vote")
			A.truthy((axis[1] > 0) == (degrees > 0), degrees .. "°: toward the part's lean, " .. axis[1])
		end
		-- a symmetric design stays on the plane, so nothing off-axis comes from the bar
		local centred = physicsOf(withBar(0))
		A.near(centred.comOffAxis, 0, 1e-9, "COM on the axis")
		-- the tilt is the part's own, in 3D: a handle along Z nudged a little has no vote, whatever its projection on XY does
		for _, nudge in ipairs({ { 1, 0.9 }, { 1, -0.9 }, { 0.001, 0.0009 }, { 10, 9.9 }, { 1e-12, 0 } }) do
			local q = Quat.mul(H.axisAngle(0, 1, 0, nudge[2]), H.axisAngle(1, 0, 0, -nudge[1]))
			local _, axis = MassProps.gripFrame({ Shapes.prepare(blockAt(1, { 0, 1, 0 }, { 0.2, 0.2, 0.5 }, q, "Grip"), 1) })
			A.deepEq(axis, { 0, 1 }, "a handle along Z")
		end
		-- a voter off the plane XY still votes, with what it projects: tilted 30° from +Y, turned 80° about it
		local leaning = Quat.mul(H.axisAngle(0, 1, 0, 80), H.axisAngle(0, 0, 1, 30))
		local _, lean = MassProps.gripFrame({ Shapes.prepare(blockAt(1, { 0, 1, 0 }, { 0.1, 0.6, 0.1 }, leaning, "Grip"), 1) })
		local ex, ey = -math.sin(math.rad(30)) * math.cos(math.rad(80)), math.cos(math.rad(30))
		local length = math.sqrt(ex * ex + ey * ey)
		A.near(lean[1], ex / length, 1e-12, "x")
		A.near(lean[2], ey / length, 1e-12, "y")
	end)

	-- Whichever way up rounding would call a level part, the mirror image must agree: V4, balance and comOffAxis read it.
	-- The frame of every Grip part, V4's, is checked on any design (the physics frame lists the kept ones, by the same vote).
	t.it("§4.5 the grip frame mirrors with the design, level grip parts included (PROP_N)", function()
		local function mirrored(core: any): any
			local out = table.clone(core)
			out.parts = {}
			for i, part in ipairs(core.parts) do
				out.parts[i] = Mirror.reflect(part, "X")
			end
			return out
		end
		local function check(core: any, what: string)
			local point, axis = MassProps.validationFrame(H.prepared(core), "Grip")
			local imagePoint, imageAxis = MassProps.validationFrame(H.prepared(mirrored(core)), "Grip")
			A.near(imagePoint[1], -point[1], 1e-12, what .. " grip point x")
			A.near(imagePoint[2], point[2], 1e-12, what .. " grip point y")
			if axis[1] == 0 and axis[2] == 1 then
				A.deepEq(imageAxis, axis, what .. " +Y")
			else
				A.near(imageAxis[1], -axis[1], 1e-12, what .. " axis x")
				A.near(imageAxis[2], axis[2], 1e-12, what .. " axis y")
			end
		end
		-- the off-centre crossbar that used to read another balance across X
		local bar = Blueprints.core("F2")
		table.insert(bar.parts, H.part(9, "Grip", "Block", "Iron", { 0.1, bar.parts[2].pos[2], 0 }, H.I, { 0.5, 0.1, 0.1 }))
		check(bar, "crossbar")
		local p, q = physicsOf(bar), physicsOf(mirrored(bar))
		A.near(p.balance, q.balance, 1e-12, "balance")
		A.near(p.comOffAxis, -q.comOffAxis, 1e-12, "comOffAxis")
		Prop.check(Tol.PROP_N, function(rng: Rng): any
			local core = H.anyDesign(rng)
			-- turn some parts level, where the sign used to be rounding's choice
			for _, part in ipairs(core.parts) do
				if part.slot == "Grip" and rng:int(1, 2) == 1 then
					part.rot = if rng:int(1, 2) == 1 then H.I else H.axisAngle(0, 0, 1, 180)
					part.size = { 0.6, 0.1, 0.1 }
				end
			end
			return core
		end, function(core: any)
			check(core, "any design")
		end)
	end)

	t.it("§4.4 cleaned parts count for mass, COM and the total length, never for the physics frame, the guard line, reach "
		.. "or the blade's length", function()
		local base = physicsOf(Blueprints.get("F2").core)
		-- dust on top of the blade: above the kept blade top, heavy enough to see
		local dust = H.f("F2")
		table.insert(dust.parts, H.part(5, "Blade", "Block", "Iron", { 0, 3.975, 0 }, H.I, { 0.05, 0.05, 0.05 }))
		local report = Analyze.run(dust)
		A.deepEq(report.cleaned, { { partId = 5, reason = "Dust" } })
		local p = report.physics :: any
		A.falsy(p.kept[5], "not kept")
		A.rel(p.mass, base.mass + IRON * 0.05 * 0.05 * 0.05, 1e-12, "dust has mass")
		A.truthy(p.com[2] > base.com[2], "and moves the COM")
		A.eq(p.reach, base.reach, "reach ignores it")
		A.eq(p.bladeLength, base.bladeLength, "so does the blade's length")
		A.near(p.totalLength, base.totalLength + 0.05, 1e-12, "the total length is every part's")
		A.rel(p.ownedVolume[5], 0.05 * 0.05 * 0.05, 1e-12, "dust owns its volume")
		-- an enclosed Guard part owns nothing and leaves the guard line, the kept Guard parts' (§4.5): in the guard, or high in
		-- the blade, where every Guard part's centroid moved it 0.0738 up (balance −0.0570 → −0.1308, cutIndex 0.425 → 0.4065)
		for _, at in ipairs({ { pos = { 0.2, 1.45, 0 }, size = { 0.2, 0.1, 0.1 } }, { pos = { 0, 3.0, 0 }, size = { 0.1, 0.4, 0.04 } } }) do
			local hidden = H.f("F2")
			table.insert(hidden.parts, H.part(5, "Guard", "Block", "Iron", at.pos, H.I, at.size))
			local hiddenReport = Analyze.run(hidden)
			A.deepEq(hiddenReport.cleaned, { { partId = 5, reason = "Enclosed" } })
			local q = hiddenReport.physics :: any
			local what = "a Guard part hidden at y " .. at.pos[2]
			A.near(q.mass, base.mass, 1e-12, what .. " owns no volume")
			A.near(q.ownedVolume[5], 0, 1e-12)
			for _, field in ipairs({ "guardPos", "reach", "bladeLength", "cutIndex" }) do
				A.eq(q[field], base[field], what .. ": " .. field)
			end
			A.near(q.balance, base.balance, 1e-12, what .. ": balance")
		end
	end)

	t.it("§4.5 no guard: the guard line is the top of the grip; no kept blade: reach and blade length 0", function()
		local noGuard = H.f("F2")
		table.remove(noGuard.parts, 3)
		noGuard.parts[3].pos[2] = 2.55 -- the blade down onto the grip
		local p = physicsOf(noGuard)
		A.near(p.guardPos, 1.35 - 0.85, 1e-12, "the top of the grip above the grip point")
		-- the kept Grip parts make the top of the grip (§4.5), not a cleaned one: a dust cube on its side above its top (every
		-- Grip part's top was the cube's, 1.37), or a Grip block hidden in the blade (the line was 1.69 above the grip point,
		-- cutIndex 0.40 → 0.0875)
		for _, extra in ipairs({
			{ pos = { 0.125, 1.345, 0 }, size = { 0.05, 0.05, 0.05 }, reason = "Dust" },
			{ pos = { 0, 2.4, 0 }, size = { 0.1, 0.4, 0.04 }, reason = "Enclosed" },
		}) do
			local capped = H.f("F2")
			table.remove(capped.parts, 3)
			capped.parts[3].pos[2] = 2.55
			table.insert(capped.parts, H.part(5, "Grip", "Block", "Iron", extra.pos, H.I, extra.size))
			local top = Analyze.run(capped)
			A.deepEq(top.cleaned, { { partId = 5, reason = extra.reason } })
			local q = top.physics :: any
			for _, field in ipairs({ "guardPos", "reach", "bladeLength", "cutIndex" }) do
				A.eq(q[field], p[field], extra.reason .. " Grip part: " .. field)
			end
			A.deepEq(q.gripPoint, p.gripPoint, extra.reason .. " Grip part: the grip point")
		end
		-- measureInvalid on A22a: the only Blade part is dust
		local core = H.f("F2")
		core.parts[4] = H.part(4, "Blade", "Block", "Iron", { 0, 1.575, 0 }, H.I, { 0.05, 0.05, 0.05 })
		local report = Analyze.run(core, { measureInvalid = true })
		A.falsy(report.validation.ok)
		local q = report.physics :: any
		A.eq(q.reach, 0)
		A.eq(q.bladeLength, 0)
		H.finite(q, "A22a physics")
	end)

	t.it("§4.3 exactOverlap: axis-aligned boxes by hand, a part inside another, disjoint parts, touching parts", function()
		local p = H.prepare(blockAt(1, { 0, 0, 0 }, { 0.2, 1, 0.06 }))
		local q = H.prepare(blockAt(2, { 0.05, 0.4, 0.01 }, { 0.2, 0.4, 0.06 }))
		-- the overlap: x −0.05…0.1, y 0.2…0.5, z −0.02…0.03
		local V, X, Y, Z = MassProps.exactOverlap(p, { q })
		local expected = 0.15 * 0.3 * 0.05
		A.rel(V, expected, 1e-12, "volume")
		A.rel(X, expected * 0.025, 1e-9, "moment x")
		A.rel(Y, expected * 0.35, 1e-9, "moment y")
		A.rel(Z, expected * 0.005, 1e-9, "moment z")
		local big = H.prepare(blockAt(3, { 0, 0, 0 }, { 5, 5, 5 }))
		local v2, x2, y2, z2 = MassProps.exactOverlap(q, { big })
		A.rel(v2, q.volume, 1e-12, "wholly inside")
		A.rel(x2, q.volume * q.gx, 1e-12)
		A.rel(y2, q.volume * q.gy, 1e-12)
		A.rel(z2, q.volume * q.gz, 1e-12)
		A.eq(MassProps.exactOverlap(p, { H.prepare(blockAt(4, { 3, 3, 3 }, { 1, 1, 1 })) }), 0, "disjoint")
		A.near(MassProps.exactOverlap(p, { H.prepare(blockAt(5, { 0, 1, 0 }, { 0.2, 1, 0.06 })) }), 0, 1e-15, "touching")
		-- flush parts stay exact whatever the rounding: a contact has no volume at all, a face on the plane cuts nothing
		local q2 = H.axisAngle(1, 2, 3, 40)
		local turned = H.prepare(blockAt(6, { 0, 2, 0 }, { 0.3, 0.8, 0.1 }, q2))
		local up = { 0.8 * turned.vx, 2 + 0.8 * turned.vy, 0.8 * turned.vz }
		A.eq(MassProps.exactOverlap(turned, { H.prepare(blockAt(7, up, { 0.3, 0.8, 0.1 }, q2)) }), 0, "flush, turned")
		local inner = H.prepare(blockAt(8, { 0.05 * turned.ux, 2 + 0.05 * turned.uy, 0.05 * turned.uz }, { 0.2, 0.8, 0.1 }, q2))
		A.rel(MassProps.exactOverlap(inner, { turned }), inner.volume, 1e-12, "inside, sharing five face planes")
	end)

	t.it("§4.5 exactOverlap is exact on slivers, and reports its work", function()
		local unit = H.prepare(blockAt(1, { 0, 0, 0 }, { 1, 1, 1 }))
		A.rel(MassProps.exactOverlap(unit, { H.prepare(blockAt(2, { 0, 1 - 0.0005, 0 }, { 1, 1, 1 })) }), 0.0005, 1e-9,
			"a 0.0005 slab of overlap")
		A.rel(MassProps.exactOverlap(unit, { H.prepare(blockAt(3, { 0, 0.0005, 0 }, { 1, 1, 1 })) }), 0.9995, 1e-12,
			"all but a 0.0005 slab")
		A.rel(MassProps.exactOverlap(unit, { H.prepare(blockAt(3, { 0, 1 - 1e-11, 0 }, { 1, 1, 1 })) }), 1e-11, 1e-3,
			"a 1e-11 slab: only a contact within rounding counts as none")
		local units = 0
		MassProps.exactOverlap(unit, { H.prepare(blockAt(4, { 0, 0, 0 }, { 5, 5, 5 })) }, function(n: number)
			units += n
		end)
		A.truthy(units >= 100, "a clipped subset reports its work: " .. units)
	end)

	t.it("§4.3 exactOverlap: every polyhedron against a huge box gives its analytic volume and centroid", function()
		local big = H.prepare(blockAt(9, { 0, 0, 0 }, { 5, 5, 5 }))
		local q = H.axisAngle(0.3, 1, 0.2, 37)
		for _, shape in ipairs({ "Block", "Wedge", "CornerWedge" }) do
			local p = H.prepare(H.solid(1, shape, { 0.1, 0.2, 0.3 }, q, { 0.3, 0.5, 0.2 }))
			local V, X, Y, Z = MassProps.exactOverlap(p, { big })
			A.rel(V, p.volume, 1e-12, shape)
			A.near(X / V, p.gx, 1e-12, shape)
			A.near(Y / V, p.gy, 1e-12, shape)
			A.near(Z / V, p.gz, 1e-12, shape)
		end
	end)

	t.it("§4.3 exactOverlap against a fine midpoint grid: rotated polyhedra, 1 to 3 higher parts (inclusion–exclusion)", function()
		local rng = TestRng.new(Tol.PROP_BASE_SEED)
		local polyhedra = { "Block", "Wedge", "CornerWedge" }
		local function solid(): any
			local shape = polyhedra[rng:int(1, 3)]
			return H.prepare(H.solid(1, shape, { rng:range(-0.1, 0.1), rng:range(-0.1, 0.1), rng:range(-0.1, 0.1) }, H.randomQuat(rng),
				{ rng:range(0.15, 0.4), rng:range(0.15, 0.4), rng:range(0.15, 0.4) }))
		end
		for k = 1, 18 do
			local p = solid()
			local list = { solid() }
			if k > 6 then
				table.insert(list, solid())
			end
			if k > 12 then
				table.insert(list, solid())
			end
			local V, X, Y, Z = MassProps.exactOverlap(p, list)
			local fV, fX, fY, fZ = fineOverlap(p, list, 40)
			-- the grid's error is about (surface of the overlap) × (half a cell), up to 0.2 × 0.005
			A.near(V, fV, 5e-4, "volume, case " .. k)
			if fV > 2e-3 then
				A.near(X / V, fX / fV, 0.015, "centroid x, case " .. k)
				A.near(Y / V, fY / fV, 0.015, "centroid y, case " .. k)
				A.near(Z / V, fZ / fV, 0.015, "centroid z, case " .. k)
			end
		end
	end)

	-- Faces nearly coplanar with a cut, 3e-13 to 3e-11 off: the prototype's cut face, made of the vertices found on the
	-- plane, covered part of the surface twice here, up to the part's whole volume (it has no case this close, so
	-- Reference.spec cannot see it). Rounding reaches about 1e-15, far below these: they take a hand-made draft.
	t.it("§4.3 near copies 1e-12 away own nothing: mass, COM and balance stay F2's", function()
		local base = physicsOf(Blueprints.get("F2").core)
		local function near(id: number, off: { number }, tilt: { number }): any
			local q = Quat.hemisphere(Quat.normalize({ tilt[1], tilt[2], tilt[3], 1 }))
			return H.part(id, "Blade", "Block", "Iron", { off[1], 2.75 + off[2], off[3] }, q, { 0.2, 2.4, 0.08 })
		end
		local core = H.f("F2")
		table.insert(core.parts, near(5, { -2e-12, 1e-12, 0 }, { 0, 1e-12, -3e-12 }))
		table.insert(core.parts, near(6, { -2e-12, -2e-12, 2e-12 }, { -1e-12, 0, -2e-12 }))
		local r = Analyze.run(core)
		A.truthy(r.validation.ok)
		A.eq(#r.cleaned, 2, "2 of the 3 are cleaned: which goes by where they stand")
		local p = r.physics :: any
		A.rel(p.mass, base.mass, Tol.TOL_MASS_REL / 10, "mass")
		A.near(p.balance, base.balance, Tol.TOL_BALANCE_ABS / 10, "balance")
		A.near(p.com[2], base.com[2], Tol.TOL_BALANCE_ABS / 10, "COM y")
		for _, c in ipairs(r.cleaned) do
			local i = table.find({ core.parts[1].id, core.parts[2].id, core.parts[3].id, core.parts[4].id, 5, 6 }, c.partId) :: number
			A.truthy(p.ownedVolume[i] <= 1e-3 * 0.2 * 2.4 * 0.08, "part " .. i .. " owns " .. p.ownedVolume[i])
		end
	end)

	t.it("§4.3 a segment overlapping half another, sides coplanar within 1e-12: the analytic overlap", function()
		local q = H.axisAngle(1, 2, 3, 40)
		local size = { 0.3, 0.8, 0.1 }
		local p = H.prepare(H.solid(1, "Block", { 0, 2, 0 }, q, size))
		for _, tilt in ipairs({ { 1e-12, 0, 0 }, { 0, 1e-12, 0 }, { 0, 0, 1e-12 }, { 1e-12, -1e-12, 2e-12 }, { -2e-12, 1e-12, 1e-12 }, { 3e-12, 2e-12, -1e-12 } }) do
			for _, off in ipairs({ 0, 1e-12, -1e-12 }) do
				local turned = Quat.normalize(Quat.mul(q, { tilt[1], tilt[2], tilt[3], 1 }))
				local other = H.prepare(H.solid(2, "Block", { 0.4 * p.vx + off, 2 + 0.4 * p.vy - off, 0.4 * p.vz + off }, turned, size), 2)
				A.rel(MassProps.exactOverlap(p, { other }), p.volume / 2, 1e-3, "half of it")
			end
		end
	end)

	t.it("§4.3 exactOverlap on near copies of every polyhedron, 3e-13 to 3e-11 off: all of the part, 1 to 3 copies (PROP_N)", function()
		Prop.check(Tol.PROP_N, function(rng: Rng): any
			local shape = rng:pick({ "Block", "Wedge", "CornerWedge" })
			local size = { rng:range(0.1, 0.5), rng:range(0.1, 0.5), rng:range(0.1, 0.5) }
			local rot = if rng:float() < 0.5 then H.I else H.randomQuat(rng)
			local eps = rng:pick({ 3e-13, 1e-12, 3e-12, 1e-11, 3e-11 })
			local copies: { any } = {}
			for k = 1, rng:int(1, 3) do
				local q, pos = nearly(rng, rot, { 0, 2, 0 }, eps)
				copies[k] = H.solid(k + 1, shape, pos, q, size)
			end
			return { part = H.solid(1, shape, { 0, 2, 0 }, rot, size), copies = copies, eps = eps }
		end, function(c: any)
			local p = H.prepare(c.part)
			local list = {}
			for k, copy in ipairs(c.copies) do
				list[k] = H.prepare(copy, k + 1)
			end
			local V, X, Y, Z = MassProps.exactOverlap(p, list)
			A.rel(V, p.volume, 1e-3, "volume")
			-- the moment about the part's own centroid: what the volume's error does not already say
			local tolerance = 1e-3 * p.volume * (p.hx + p.hy + p.hz)
			A.near(X - V * p.gx, 0, tolerance, "moment x")
			A.near(Y - V * p.gy, 0, tolerance, "moment y")
			A.near(Z - V * p.gz, 0, tolerance, "moment z")
		end)
	end)

	t.it("§4.3 exactOverlap on boxes sharing a frame within 1e-12 to 1e-11: their exact union, 1 to 3 boxes (PROP_N)", function()
		Prop.check(Tol.PROP_N, function(rng: Rng): any
			local half = { rng:range(0.015, 0.8), rng:range(0.015, 1.5), rng:range(0.015, 0.3) }
			local rot = if rng:float() < 0.5 then H.I else H.randomQuat(rng)
			local eps = rng:pick({ 1e-12, 2e-12, 3e-12, 1e-11 })
			local part = H.solid(1, "Block", { 0, 2, 0 }, rot, { 2 * half[1], 2 * half[2], 2 * half[3] })
			local P = H.prepare(part)
			local boxes: { any }, others: { any } = {}, {}
			for k = 1, rng:int(1, 3) do
				-- per axis: flush on both sides of the part, on one side, or a cut through it
				local lo, hi = table.create(3, 0), table.create(3, 0)
				for a = 1, 3 do
					local mode = rng:int(1, 4)
					local u, v = rng:range(-half[a], half[a]), rng:range(-half[a], half[a])
					lo[a] = if mode == 1 or mode == 3 then -half[a] elseif mode == 2 then u else math.min(u, v)
					hi[a] = if mode == 1 or mode == 2 then half[a] elseif mode == 3 then u else math.max(u, v)
					if hi[a] - lo[a] < Limits.MIN_DIM then
						hi[a] = math.min(half[a], lo[a] + Limits.MIN_DIM)
						lo[a] = hi[a] - Limits.MIN_DIM
					end
				end
				boxes[k] = { lo = lo, hi = hi }
				local x, y, z = Shapes.toWorld(P, (lo[1] + hi[1]) / 2, (lo[2] + hi[2]) / 2, (lo[3] + hi[3]) / 2)
				local q, pos = nearly(rng, rot, { x, y, z }, eps)
				others[k] = H.solid(k + 1, "Block", pos, q, { hi[1] - lo[1], hi[2] - lo[2], hi[3] - lo[3] })
			end
			return { part = part, half = half, boxes = boxes, others = others, eps = eps }
		end, function(c: any)
			local p = H.prepare(c.part)
			local list = {}
			for k, other in ipairs(c.others) do
				list[k] = H.prepare(other, k + 1)
			end
			local V, X, Y, Z = MassProps.exactOverlap(p, list)
			local tV, tX, tY, tZ = boxUnion(c.half, c.boxes)
			A.near(V, tV, 1e-3 * p.volume, "volume")
			-- the moment about the part's centre: what the volume's error does not already say
			local tolerance = 1e-3 * p.volume * (p.hx + p.hy + p.hz)
			A.near(X - V * p.cx, tX * p.ux + tY * p.vx + tZ * p.wx, tolerance, "moment x")
			A.near(Y - V * p.cy, tX * p.uy + tY * p.vy + tZ * p.wy, tolerance, "moment y")
			A.near(Z - V * p.cz, tX * p.uz + tY * p.vz + tZ * p.wz, tolerance, "moment z")
		end)
	end)

	t.it("§4.3 sampledOverlap: half a ball, a ball lens and half a cylinder against their closed forms", function()
		local r = 0.13
		local ball = H.prepare(H.solid(1, "Ball", { 0, 0, 0 }, H.I, { 2 * r, 2 * r, 2 * r }))
		local half = H.prepare(blockAt(2, { 0, 1, 0 }, { 2, 2, 2 }))
		local lo, hi = MassProps.overlapBox(ball, { half })
		local V, _, Y = MassProps.sampledOverlap(ball, { half }, lo, hi, Geo.H_OVERLAP)
		A.rel(V, 2 * PI * r * r * r / 3, 0.005, "half a ball")
		A.near(Y / V, 3 * r / 8, 0.005 * r * 10, "its centroid")
		-- two equal balls d apart: V = π(2r − d)²(d + 4r)/12
		local d = 0.1
		local other = H.prepare(H.solid(2, "Ball", { d, 0, 0 }, H.I, { 2 * r, 2 * r, 2 * r }))
		local l2, h2 = MassProps.overlapBox(ball, { other })
		A.truthy(l2[1] >= -r and h2[1] <= r, "the box is clamped to the part")
		local lens = MassProps.sampledOverlap(ball, { other }, l2, h2, Geo.H_OVERLAP)
		A.rel(lens, PI * (2 * r - d) * (2 * r - d) * (d + 4 * r) / 12, 0.005, "a lens")
		-- a cylinder cut in half by a block across its axis
		local cylinder = H.prepare(H.solid(1, "Cylinder", { 0, 0, 0 }, H.I, { 0.6, 0.2, 0.2 }))
		local cut = H.prepare(blockAt(2, { 1, 0, 0 }, { 2, 2, 2 }))
		local l3, h3 = MassProps.overlapBox(cylinder, { cut })
		-- (16 cells across a disk: the midpoint rule's circle is 3.5 % off, the method's known resolution)
		A.rel(MassProps.sampledOverlap(cylinder, { cut }, l3, h3, Geo.H_OVERLAP), cylinder.volume / 2, 0.04, "half a cylinder")
		-- no overlap box: zero cells
		local far = H.prepare(blockAt(3, { 5, 0, 0 }, { 1, 1, 1 }))
		local l4, h4 = MassProps.overlapBox(ball, { far })
		local v4, _, _, _, cells = MassProps.sampledOverlap(ball, { far }, l4, h4, Geo.H_OVERLAP)
		A.eq(v4, 0)
		A.eq(cells, 0)
	end)

	t.it("§4.3 ownership: kept parts, then slot rank, then the larger part; an overlap counts once, for its owner", function()
		-- two overlapping blocks in different slots: the Blade owns the overlap, whichever comes first in the list
		local grip = H.part(1, "Grip", "Block", "Iron", { 0, 1, 0 }, H.I, { 0.2, 1, 0.2 })
		local blade = H.part(2, "Blade", "Block", "Iron", { 0, 1.4, 0 }, H.I, { 0.2, 1, 0.2 })
		local overlap = 0.2 * 0.6 * 0.2
		local _, _, owned = H.measure({ parts = { grip, blade } })
		A.rel(owned.ownedVolume[1], 0.2 * 1 * 0.2 - overlap, 1e-12, "the Grip gives the overlap up")
		A.rel(owned.ownedVolume[2], 0.2 * 1 * 0.2, 1e-12, "the Blade owns all of itself")
		A.eq(#owned.higher[1], 1)
		A.eq(owned.higher[1][1].id, 2)
		A.eq(#owned.higher[2], 0)
		-- the same slot: by rank, equal volumes by where they stand, whichever comes first
		local first = H.part(1, "Blade", "Block", "Iron", { 0, 1, 0 }, H.I, { 0.2, 1, 0.2 })
		for _, pair in ipairs({ { first, blade }, { blade, first } }) do
			local _, _, same = H.measure({ parts = pair })
			local low = if pair[1] == first then 1 else 2
			A.rel(same.ownedVolume[low], 0.2 * 1 * 0.2, 1e-12)
			A.rel(same.ownedVolume[3 - low], 0.2 * 1 * 0.2 - overlap, 1e-12)
		end
		-- the larger owns it, by no id
		local larger = H.part(3, "Blade", "Block", "Iron", { 0, 1.4, 0 }, H.I, { 0.2, 1, 0.3 })
		for _, pair in ipairs({ { first, larger }, { larger, first } }) do
			local _, _, same = H.measure({ parts = pair })
			local big = if pair[1] == larger then 1 else 2
			A.rel(same.ownedVolume[big], 0.2 * 1 * 0.3, 1e-12, "the larger owns all of itself")
			A.rel(same.ownedVolume[3 - big], 0.2 * 1 * 0.2 - overlap, 1e-12)
		end
		-- a cleaned Blade inside a kept Guard: kept comes before rank
		local guard = H.part(1, "Guard", "Block", "Iron", { 0, 1, 0 }, H.I, { 1, 0.4, 0.4 })
		local core = H.part(2, "Blade", "Block", "Iron", { 0, 1, 0 }, H.I, { 0.4, 0.2, 0.2 })
		local _, exposure, inner = H.measure({ parts = { guard, core } })
		A.deepEq(exposure.kept, { true, false })
		A.rel(inner.ownedVolume[1], 1 * 0.4 * 0.4, 1e-12, "the kept Guard owns everything")
		A.near(inner.ownedVolume[2], 0, 1e-15, "an enclosed part owns no volume")
		-- touching parts own their whole volume
		local _, _, flush = H.measure(Blueprints.get("F2").core)
		for i, p in ipairs(H.prepared(Blueprints.get("F2").core)) do
			A.eq(flush.ownedVolume[i], p.volume, "F2 part " .. i)
		end
		-- a gap is no overlap: a part 0.005 off is in contact (§4.2) and hides faces (§4.4), but it is no higher part. Turned
		-- 45°, so that their AABBs overlap and only GJK can tell.
		local q = H.axisAngle(0, 0, 1, 45)
		local d = (0.4 + 0.005) * math.sqrt(0.5)
		local _, _, apart = H.measure({ parts = {
			H.part(1, "Blade", "Block", "Iron", { 0, 1, 0 }, q, { 0.2, 0.8, 0.1 }),
			H.part(2, "Blade", "Block", "Iron", { d, 1 + d, 0 }, q, { 0.6, 0.8, 0.1 }),
		} })
		A.eq(#apart.higher[2], 0)
	end)

	t.it("§4.3 the exact path up to MAX_EXACT higher parts, refined sampling beyond it and for round parts", function()
		A.eq(Geo.MAX_EXACT, 3)
		-- a plate with n bars across it, close enough for the overlap box to keep H_OVERLAP's resolution
		local function plateWith(n: number): any
			local parts = { H.part(1, "Pommel", "Block", "Iron", { 0, 2, 0 }, H.I, { 0.2, 2, 0.1 }) }
			for k = 1, n do
				parts[k + 1] = H.part(k + 1, "Blade", "Block", "Iron", { 0, 1.85 + (k - 1) * 0.07, 0 }, H.I, { 0.3, 0.05, 0.2 })
			end
			return { parts = parts }
		end
		local _, _, three = H.measure(plateWith(3))
		A.eq(three.refinedCells, 0, "polyhedra with 3 higher parts: exact")
		A.rel(three.ownedVolume[1], 0.2 * 2 * 0.1 - 3 * (0.2 * 0.05 * 0.1), 1e-12, "and exact")
		local _, _, four = H.measure(plateWith(4))
		A.truthy(four.refinedCells > 0, "4 higher parts: sampled")
		A.rel(four.ownedVolume[1], 0.2 * 2 * 0.1 - 4 * (0.2 * 0.05 * 0.1), 0.005, "within 0.5 %")
		local _, _, round = H.measure({ parts = {
			H.part(1, "Blade", "Ball", "Iron", { 0, 1, 0 }, H.I, { 0.4, 0.4, 0.4 }),
			H.part(2, "Pommel", "Block", "Iron", { 0, 1.2, 0 }, H.I, { 0.4, 0.4, 0.4 }),
		} })
		A.truthy(round.refinedCells > 0, "a Ball involved: sampled")
	end)

	t.it("§4.9 cleaned parts cannot coarsen a kept part's overlap sampling: V_own stays bit-identical", function()
		local base = H.f("F3") -- two ball quillons overlap the guard: refined sampling at the base spacing
		local _, _, before = H.measure(base)
		A.eq(before.hOverlap, Geo.H_OVERLAP)
		A.truthy(before.refinedCells > 0)
		-- the parts Enclosed here are not copies: slightly smaller balls inside the pommel, so their overlap jobs are
		-- refined, 24³ cells each, and far past N_OVERLAP_WORK together
		local filler = H.f("F3")
		for k = 1, 3 do
			local size = filler.parts[1].size[1] - 0.002 * k
			table.insert(filler.parts, H.part(7 + k, "Pommel", "Ball", "Steel", filler.parts[1].pos, H.I, { size, size, size }))
		end
		local _, exposure, after = H.measure(filler)
		A.eq(#exposure.cleaned, 3, "the inner balls are Enclosed")
		A.truthy(after.refinedCells > before.refinedCells, "their jobs are refined")
		A.truthy(after.refinedCells * 2 <= Geo.N_OVERLAP_WORK, "they share what the kept jobs leave, cells × (1 + ≥ 1 higher part): " .. after.refinedCells)
		A.eq(after.hOverlap, before.hOverlap, "the kept parts' spacing")
		for i = 1, #base.parts do
			A.eq(after.ownedVolume[i], before.ownedVolume[i], "part " .. i)
			A.eq(after.overlapX[i], before.overlapX[i], "part " .. i)
			A.eq(after.overlapY[i], before.overlapY[i], "part " .. i)
			A.eq(after.overlapZ[i], before.overlapZ[i], "part " .. i)
		end
	end)

	t.it("§4.9 N_OVERLAP_WORK covers kept and cleaned parts together: cleaned parts share what the kept parts leave", function()
		-- each job has one higher part, the block: 24³ cells × 2 per ball at the base spacing. The kept ball's fits the
		-- budget alone and leaves too little for the same again.
		local _, exposure, owned = H.measure({ parts = {
			H.part(1, "Blade", "Block", "Iron", { 0, 2, 0 }, H.I, { 0.8, 0.8, 0.6 }),
			H.part(2, "Guard", "Ball", "Iron", { 0, 2.4, 0 }, H.I, { 0.6, 0.6, 0.6 }),
			H.part(3, "Pommel", "Ball", "Iron", { 0, 1.85, 0 }, H.I, { 0.3, 0.3, 0.3 }),
		} })
		A.deepEq(exposure.kept, { true, true, false }, "the second ball is Enclosed")
		A.eq(owned.hOverlap, Geo.H_OVERLAP, "the kept ball keeps the base spacing")
		A.truthy(owned.refinedCells > 24 * 24 * 24, "the Enclosed ball's job is refined too: " .. owned.refinedCells)
		A.truthy(owned.refinedCells * 2 <= Geo.N_OVERLAP_WORK, "cells × 2 within the budget: " .. owned.refinedCells)
	end)

	t.it("§4.3 exact copies own nothing, exactly, every shape: mass, COM and reach are the base's bits", function()
		for _, id in ipairs(Blueprints.order) do
			local base = Blueprints.get(id).core
			local p0 = H.measure(base)
			local pile = Blueprints.core(id)
			for i, part in ipairs(base.parts) do
				if part.slot ~= "Grip" and part.slot ~= "Guard" then -- those two weigh the frames, by §4.5
					local copy = H.part(100 + i, part.slot, part.shape, part.material, part.pos, part.rot, part.size)
					table.insert(pile.parts, copy)
				end
			end
			local p = H.measure(pile)
			A.eq(p.mass, p0.mass, id .. " mass")
			A.eq(p.volume, p0.volume, id .. " volume")
			A.deepEq(p.com, p0.com, id .. " COM")
			A.eq(p.reach, p0.reach, id .. " reach")
		end
		-- all of a copy is its overlap, the first moment too
		local copy = H.f("F2")
		local blade = copy.parts[4]
		table.insert(copy.parts, H.part(5, blade.slot, blade.shape, blade.material, blade.pos, blade.rot, blade.size))
		local _, _, owned = H.measure(copy)
		local volume = 0.2 * 2.4 * 0.08
		A.rel(owned.overlapVolume[5], volume, 1e-15, "volume")
		A.deepEq({ owned.overlapX[5], owned.overlapZ[5] }, { 0, 0 }, "centred on x = 0 and z = 0")
		A.rel(owned.overlapY[5], volume * 2.75, 1e-15, "moment y")
	end)

	t.it("§4.9 overlap budget: refined cells × (1 + higher parts) stay within N_OVERLAP_WORK on 24 overlapping blocks", function()
		local _, _, owned = H.measure(H.p1())
		A.truthy(owned.refinedCells > 0, "some overlaps are refined")
		A.truthy(owned.refinedCells <= Geo.N_OVERLAP_WORK / 2, "at most budget / (1 + 1 higher part): " .. owned.refinedCells)
		for _, v in ipairs(owned.ownedVolume) do
			A.finite(v)
			A.truthy(v >= 0, "owned volume ≥ 0")
		end
	end)

	t.it("T-PHY-10 overlap mass error ≤ 0.5 %: laminates and overlapping segments (X07)", function()
		local base = Blueprints.core("F5")
		local function withBlade(plates: { any }): any
			local core = Blueprints.core("F5")
			table.remove(core.parts, 4)
			for _, plate in ipairs(plates) do
				table.insert(core.parts, plate)
			end
			return core
		end
		local exact = physicsOf(base)
		local a = physicsOf(withBlade({
			H.part(6, "Blade", "Block", "Iron", { 0, 2.68, 0.015 }, H.I, { 0.16, 2.60, 0.03 }),
			H.part(7, "Blade", "Block", "Iron", { 0, 2.68, -0.015 }, H.I, { 0.16, 2.60, 0.03 }),
		}))
		A.rel(a.mass, exact.mass, 1e-9, "2 × 0.03 plates")
		local b = physicsOf(withBlade({
			H.part(6, "Blade", "Block", "Iron", { 0, 2.68, 0.0125 }, H.I, { 0.16, 2.60, 0.035 }),
			H.part(7, "Blade", "Block", "Iron", { 0, 2.68, -0.0125 }, H.I, { 0.16, 2.60, 0.035 }),
		}))
		A.rel(b.mass, exact.mass, 1e-9, "2 × 0.035 plates overlapping 0.01")
		local segments: { any } = {}
		for k = 0, 3 do
			table.insert(segments, H.part(6 + k, "Blade", "Block", "Iron", { 0, 1.38 + 0.35 + k * 0.63, 0 }, H.I, { 0.16, 0.70, 0.06 }))
		end
		local c = physicsOf(withBlade(segments))
		-- the union is really 0.01 shorter than F5's blade, the same mass as a single 2.59 blade
		local union = physicsOf(withBlade({ H.part(6, "Blade", "Block", "Iron", { 0, 1.38 + 1.295, 0 }, H.I, { 0.16, 2.59, 0.06 }) }))
		A.rel(c.mass, union.mass, 1e-9, "4 segments overlapping 0.07")
		A.rel(c.mass, exact.mass, Tol.TOL_MASS_REL, "and within 0.5 % of F5 itself")
		A.near(c.mass / exact.mass - 1, -0.00014, 5e-6, "E-S2.5: −0.014 %")
	end)

	t.it("P-NOMUT, P-DET: frozen fixtures measure twice to the same bits", function()
		for _, id in ipairs(Blueprints.order) do
			local core = Blueprints.get(id).core
			A.eq(Dump.canonical(physicsOf(core)), Dump.canonical(physicsOf(core)), id)
		end
	end)
end)
