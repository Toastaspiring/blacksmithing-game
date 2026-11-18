--!nocheck
local S = require("./sets")
local L = require("./lib")
local Mirror = require("./repo/src/shared/Blueprint/Mirror")
local fmt = string.format
local d
for _, x in ipairs(S.protoFixtures()) do if string.sub(x.name, 1, 3) == "C04" then d = x end end
local parts = d.parts
local img = {}
for i, p in ipairs(parts) do img[i] = Mirror.reflect(p, "X") end
local P, Q = L.prep(parts), L.prep(img)
local s0 = L.newShares(P)
local s1 = L.newShares(Q)
local t0, t1 = L.truth(P), L.truth(Q)
local r0 = L.Sampling.ranked(P)
local r1 = L.Sampling.ranked(Q)
for i, p in ipairs(parts) do
	print(fmt("%d %-11s %-7s pos %.4f %.4f %.4f size %.4f %.4f %.4f | share %.6f image %.6f | truth %.4f image %.4f | rank %d image %d", i, p.shape, p.slot, p.pos[1], p.pos[2], p.pos[3], p.size[1], p.size[2], p.size[3], s0[i] or -1, s1[i] or -1, t0[i] or -1, t1[i] or -1, r0[i], r1[i]))
end
