--!nocheck
-- SPEC 4.5's vote: the 3D tilt, the step at 45 degrees, the Z handle, the level bar, the mirror, and the row of 17.2. Written from the words, tried on the build.
local V = require("./v1")
local MassProps = require("./tree/src/shared/Physics/MassProps")
local Mirror = require("./tree/src/shared/Blueprint/Mirror")
local Balance = require("./tree/src/shared/Definitions/Balance")
local fmt = string.format
local F4 = V.fixture("F4")
local grip
for _, p in ipairs(F4) do
	if p.slot == "Grip" then grip = p end
end
print(fmt("F4's grip: %s size %.3f %.3f %.3f; AXIS_MAX_TILT_COS %.17g", grip.shape, grip.size[1], grip.size[2], grip.size[3], Balance.Geometry.AXIS_MAX_TILT_COS))
local function run(a, b)
	local parts = V.copyParts(F4)
	for _, deg in ipairs({ a, b }) do
		local q = V.axisAngle(0, 0, 1, deg)
		table.insert(parts, V.part("Eq", grip.shape, "Grip", { grip.pos[1], grip.pos[2], grip.pos[3] }, q, { grip.size[1], grip.size[2], grip.size[3] }))
	end
	local ok, r = V.valid(parts)
	local ph = r.physics
	print(fmt("  equal parts at %+.1f and %+.1f: axis %.2f deg, balance %.3f, valid %s", a, b, math.deg(math.atan2(ph.gripAxis[1], ph.gripAxis[2])), ph.balance, tostring(ok)))
end
run(-45.1, 44.9)
run(-45, 45)
run(-44.9, 45.1)
-- votes by the part's own axis: unit cases
local function axisOf(shape, q, size)
	local P = V.Shapes.prepare(V.part("g", shape, "Grip", { 0, 1, 0 }, q, size), 1)
	local _, a = MassProps.gripFrame({ P })
	return a[1], a[2]
end
for _, c in ipairs({
	{ "Cylinder along Y", "Cylinder", V.Z90, { 0.9, 0.16, 0.16 } },
	{ "Cylinder along X (level)", "Cylinder", V.I, { 0.9, 0.16, 0.16 } },
	{ "Cylinder along Z (a handle out of the plane)", "Cylinder", V.axisAngle(0, 1, 0, 90), { 0.9, 0.16, 0.16 } },
	{ "Cylinder 44 from Y in the XY plane", "Cylinder", V.axisAngle(0, 0, 1, 90 - 44), { 0.9, 0.16, 0.16 } },
	{ "Cylinder 46 from Y in the XY plane", "Cylinder", V.axisAngle(0, 0, 1, 90 - 46), { 0.9, 0.16, 0.16 } },
	{ "Cylinder 46 from Y toward Z (XY projection straight up)", "Cylinder", V.Quat.mul(V.axisAngle(1, 0, 0, 46), V.Z90), { 0.9, 0.16, 0.16 } },
	{ "Cylinder 44 from Y toward Z", "Cylinder", V.Quat.mul(V.axisAngle(1, 0, 0, 44), V.Z90), { 0.9, 0.16, 0.16 } },
	{ "Block longest Y", "Block", V.I, { 0.1, 0.9, 0.1 } },
	{ "Block no longest (1.4 x)", "Block", V.I, { 0.1, 0.14, 0.1 } },
	{ "Ball", "Ball", V.I, { 0.3, 0.3, 0.3 } },
	{ "Dust rod", "Cylinder", V.Z90, { 0.5, 0.02, 0.02 } },
}) do
	local x, y = axisOf(c[2], c[3], c[4])
	print(fmt("  %-55s axis (%.4f, %.4f)", c[1], x, y))
end
-- a mirrored design: the axis mirrors, the balance stands
for _, n in ipairs({ "C06", "C15", "F4", "C05" }) do
	local parts = V.renumber((V.fixture(n)))
	local _, r = V.valid(parts)
	local core = { schema = 1, name = "x", type = "Sword", parts = parts }
	local mirrored = table.clone(core)
	mirrored.parts = {}
	for i, p in ipairs(parts) do
		mirrored.parts[i] = Mirror.part and Mirror.part(p) or nil
	end
	if mirrored.parts[1] then
		local r2 = V.Analyze.run(mirrored, { measureInvalid = true })
		print(fmt("  %s axis (%.6f, %.6f), mirrored (%.6f, %.6f), balance %.9f / %.9f", n, r.physics.gripAxis[1], r.physics.gripAxis[2], r2.physics.gripAxis[1], r2.physics.gripAxis[2], r.physics.balance, r2.physics.balance))
	end
end
