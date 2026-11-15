--!nocheck
-- fix-4: Cover.spec (c)'s hovering hider made a Cylinder: the plate's reading, its verdict, with the hider handed over or not
local R = "C:/Users/louis/Documents/RANDOM/ROBLOX/Blacksmithing Game"
local H = require(R .. "/tests/Physics/PhysicsHelpers")
local Shapes = require(R .. "/src/shared/Physics/Shapes")
local Sampling = require(R .. "/src/shared/Physics/Sampling")
local Geo = require(R .. "/src/shared/Definitions/Balance").Geometry
local Oracle = require(R .. "/tests/Physics/VisibleOracle")
local c, w, r = 0.0625, 0.1052, 0.4
local x0, x1, FAR = c - w / 2, c + w / 2, 0.5
local lids = { { -FAR, x0, -FAR, FAR }, { x1, FAR, -FAR, FAR }, { x0, x1, -FAR, x0 }, { x0, x1, x1, FAR } }
for _, gap in ipairs({ 0.0125, 0.013, 0.0135 }) do
	local parts = H.partsUnder(lids)
	table.insert(parts, H.solid(#parts + 1, "Cylinder", { c, r + gap, c }, H.axisAngle(0, 1, 0, 90), { 0.6, 2 * r, 2 * r }))
	local P = H.prepared({ parts = parts })
	local _, _, hider = Oracle.flags(P)
	print(string.format("gap %.4f: past δ + 2 EPS %s; reads %.9f %%, kept %s; truth %.4f %%; axis (%.3g, %.3g, %.3g)", gap,
		tostring(not Shapes.aabbOverlap(P[1], P[#P], Geo.HIDE_OFFSET + 2 * Geo.EPS_GEOM)), 100 * H.reads(P, 1),
		tostring(Sampling.exposure(P).kept[1]), 100 * Oracle.share(P, 1, hider), P[#P].ux, P[#P].uy, P[#P].uz))
end
print(string.format("bare plate %.9f %%", 100 * H.reads(H.prepared({ parts = H.partsUnder(lids) }), 1)))
