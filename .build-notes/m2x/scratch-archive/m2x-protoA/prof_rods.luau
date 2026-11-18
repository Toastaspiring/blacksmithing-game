--!nocheck
local S = require("./sets")
local L = require("./lib")
local fmt = string.format
local d
for _, x in ipairs(S.climbed()) do if string.find(x.name, "rods d 0.15 L 4.8", 1, true) then d = x break end end
print(d.name, #d.parts)
for i, p in ipairs(d.parts) do print(i, p.shape, p.slot, fmt("%.4f %.4f %.4f", p.pos[1], p.pos[2], p.pos[3]), fmt("%.4f %.4f %.4f", p.size[1], p.size[2], p.size[3]), fmt("%.5f %.5f %.5f %.5f", p.rot[1], p.rot[2], p.rot[3], p.rot[4])) end
local P = L.prep(d.parts)
local t0 = os.clock()
local share, kept, tests = L.newShares(P)
print(fmt("full read %.1f ms", (os.clock() - t0) * 1000))
for i = 1, #P do print(i, L.pct(share[i]), kept[i], tests[i]) end
