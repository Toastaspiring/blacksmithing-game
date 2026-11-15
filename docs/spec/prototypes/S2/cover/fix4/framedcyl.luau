--!nocheck
-- fix-4: Cover.spec (c)'s framed plate under a Ball's tip: a plate framed but for a window 0.05 wide under a Ball r 0.3
-- whose bottom stands HIDE_OFFSET + 0.0005 above it: the plate's reading and verdict on a tree (ROOT), the truth.
local R0 = require("@lune/process").env.ROOT or "C:/Users/louis/Documents/RANDOM/ROBLOX/Blacksmithing Game"
local H = require(R0 .. "/tests/Physics/PhysicsHelpers")
local Sampling = require(R0 .. "/src/shared/Physics/Sampling")
local Oracle = require(R0 .. "/tests/Physics/VisibleOracle")
local Geo = require(R0 .. "/src/shared/Definitions/Balance").Geometry
local window: { any } = {
	H.solid(1, "Block", { 0, -0.01, 0 }, H.I, { 0.16, 0.02, 0.16 }),
	H.solid(2, "Block", { 0, -0.07, 0 }, H.I, { 0.5, 0.1, 0.5 }),
}
for _, s in ipairs({ -1, 1 }) do
	table.insert(window, H.solid(#window + 1, "Block", { s * 0.105, -0.01, 0 }, H.I, { 0.04, 0.04, 0.26 }))
	table.insert(window, H.solid(#window + 1, "Block", { 0, -0.01, s * 0.105 }, H.I, { 0.26, 0.04, 0.04 }))
	table.insert(window, H.solid(#window + 1, "Block", { 0, 0.025, s * 0.0525 }, H.I, { 0.16, 0.04, 0.055 }))
	table.insert(window, H.solid(#window + 1, "Block", { s * 0.0525, 0.055, 0 }, H.I, { 0.055, 0.1, 0.05 }))
end
table.insert(window, H.solid(#window + 1, "Cylinder", { 0, Geo.HIDE_OFFSET + 0.0005 + 0.4, 0 }, H.axisAngle(0, 1, 0, 90), { 0.6, 0.8, 0.8 }))
local P = H.prepared({ parts = window })
local _, _, hider = Oracle.flags(P)
print(string.format("the framed plate under a Cylinder's edge: reads %.3f %%, truly %.3f %%, kept %s", 100 * H.reads(P, 1),
	100 * Oracle.measure(P, 1, hider, 400000), tostring(Sampling.exposure(P).kept[1])))
