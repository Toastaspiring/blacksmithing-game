--!nocheck
local L = require("../lib")
local name = (require("@lune/process")).args[1] or "F5"
local parts, full = L.fixture(name)
print(full, #parts)
for i, p in ipairs(parts) do
	print(string.format("%2d %-6s %-11s %-5s pos (%.3f, %.3f, %.3f) size (%.3f, %.3f, %.3f) rot (%.4f, %.4f, %.4f, %.4f) %s", i, p.slot, p.shape, p.material, p.pos[1], p.pos[2], p.pos[3], p.size[1], p.size[2], p.size[3], p.rot[1], p.rot[2], p.rot[3], p.rot[4], p.label or ""))
end
