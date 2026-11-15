--!nocheck
local A1 = require("./tree/src/shared/Physics/Analyze")
local A2 = require("./lifted/src/shared/Physics/Analyze")
local Fx = require("./proto/fixtures")
local fmt = string.format
local U = { P1 = { 2.5286, 2.4719 }, P2 = { 1.0428, 2.5075 }, P3 = { 0.2799, 2.0065 }, P4 = { 1.3348, 2.5261 }, P5 = { 0.1034, 1.4457 } }
for _, b in ipairs(Fx.perf()) do
	local tag = string.sub(b.name, 1, 2)
	local core = { schema = 1, name = b.name, type = "Sword", parts = b.parts }
	local r1 = A1.run(core, { measureInvalid = true }).physics
	local r2 = A2.run(core, { measureInvalid = true }).physics
	print(fmt("%s union V %.4f COM y %.4f | build V %.4f (%+.2f %%) COM y %.4f dy %+.4f | lifted V %.4f (%+.2f %%) dy %+.4f", tag, U[tag][1], U[tag][2], r1.volume, (r1.volume / U[tag][1] - 1) * 100, r1.com[2], r1.com[2] - U[tag][2], r2.volume, (r2.volume / U[tag][1] - 1) * 100, r2.com[2] - U[tag][2]))
end
