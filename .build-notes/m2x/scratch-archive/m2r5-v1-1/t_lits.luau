--!nocheck
local V = require("./v1")
local H = require("./tree/tests/Physics/PhysicsHelpers")
local Sampling = V.Sampling
local fmt = string.format
-- the literals
local function units(list)
	local u = 0
	Sampling.exposure(list, function(n) u += n end)
	return u
end
local FAR = 0.5
local function lid(id, x0, x1, z0, z1)
	return H.solid(id, "Block", { (x0 + x1) / 2, 0.05, (z0 + z1) / 2 }, H.I, { x1 - x0, 0.1, z1 - z0 })
end
local plate = H.solid(1, "Block", { 0, -0.01, 0 }, H.I, { 0.5, 0.02, 0.5 })
local host = H.solid(2, "Block", { 0, -FAR, 0 }, H.I, { 2 * FAR, 2 * FAR, 2 * FAR })
print("slit units", units(H.prepared({ parts = { plate, host, lid(3, -FAR, 0.0625 + 0.0375, -FAR, FAR), lid(4, 0.0625 + 0.0575, FAR, -FAR, FAR) } })))
print("lone .6x.6x.3 units", units(H.prepared({ parts = { H.solid(1, "Block", { 0, 2, 0 }, H.I, { 0.6, 0.6, 0.3 }) } })))
-- a radius where ceil of the exact division rounds up
local bad = {}
local PI = 3.141592653589793
for k = 1, 2000000 do
	local d = 0.0726 + (k / 2000000) * (0.6 - 0.0726)
	local r = d / 2
	local x = PI * r / 2
	if math.ceil(x / (x / 4)) ~= 4 then
		table.insert(bad, d)
		if #bad >= 3 then break end
	end
end
print("diameters where the exact division rounds past 4:", #bad, bad[1], bad[2], bad[3])
